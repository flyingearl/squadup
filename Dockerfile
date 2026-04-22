# Multi-stage build.
#
#   base    — system packages + PHP extensions (shared between dev and prod)
#   dev     — base + dev php.ini + dev entrypoint (composer install on boot,
#             migrate on boot, bind-mounted source expected at runtime)
#   vendor  — base + composer install --no-dev (just the output `vendor/`)
#   assets  — node + npm run build (just the output `public/build/`)
#   prod    — base + prod php.ini + prod entrypoint + baked code + vendor +
#             built assets (no bind mounts, no composer at runtime)
#
# Dev:  `docker compose up --build` builds the `dev` target by default
#       because `docker-compose.yml` doesn't pin `target:`.
# Prod: `docker compose -f docker-compose.yml -f docker-compose.prod.yml up --build`
#       sets `build.target: prod` on the app service.

# --- base -------------------------------------------------------------------
# PHP 8.4 matches the host (Herd) and satisfies composer.lock, which resolves
# some deps to require >= 8.4.
FROM php:8.4-fpm-bookworm AS base

ENV DEBIAN_FRONTEND=noninteractive \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_NO_INTERACTION=1

# System packages: nginx + supervisor for the app, build deps for PHP
# extensions, libpq for Postgres, image libs for gd, unzip for composer,
# curl for healthcheck. $PHPIZE_DEPS is the compiler toolchain needed by
# PECL extensions like redis.
RUN apt-get update && apt-get install -y --no-install-recommends \
        $PHPIZE_DEPS \
        nginx \
        supervisor \
        git \
        unzip \
        curl \
        ca-certificates \
        libpq-dev \
        libpng-dev \
        libjpeg-dev \
        libfreetype6-dev \
        libzip-dev \
        libicu-dev \
    && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" \
        pdo_pgsql \
        pgsql \
        gd \
        intl \
        zip \
        bcmath \
        exif \
        opcache \
        pcntl \
 && pecl install redis \
 && docker-php-ext-enable redis

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY docker/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY docker/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN rm -f /etc/nginx/sites-enabled/default \
 && mkdir -p /var/log/supervisor /run/nginx /run/php

WORKDIR /var/www/html

# --- dev --------------------------------------------------------------------
FROM base AS dev

COPY docker/php/php.ini /usr/local/etc/php/conf.d/zz-app.ini
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -fsS http://127.0.0.1/up || exit 1

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# --- vendor -----------------------------------------------------------------
# Builds a cached layer of production composer deps. The prod stage copies
# the resulting vendor/ directory — nothing else from this stage ships.
FROM base AS vendor

COPY composer.json composer.lock ./
RUN composer install \
        --no-dev \
        --prefer-dist \
        --optimize-autoloader \
        --no-scripts \
        --no-progress

# --- wayfinder --------------------------------------------------------------
# Wayfinder enumerates Laravel routes and writes matching TS files into
# resources/js/{actions,routes,wayfinder}/ — which Vue components import
# via `@/routes`, `@/actions`, etc. The files are gitignored, so the Vite
# build in the assets stage can't find them unless we generate here first.
# The assets stage (Node) has no PHP, so we do it in this PHP-enabled stage
# and copy the output across.
FROM base AS wayfinder

COPY --from=vendor /var/www/html/vendor ./vendor
COPY . .
# A throwaway env is enough — wayfinder:generate enumerates routes and
# writes TS, it doesn't hit the database or Redis.
RUN cp .env.example .env \
 && php artisan key:generate --force --ansi \
 && php artisan wayfinder:generate --with-form --ansi

# --- assets -----------------------------------------------------------------
# Separate Node image to build public/build/. Kept lean — only package.json,
# package-lock.json, source, and the wayfinder-generated imports.
FROM node:20-bookworm-slim AS assets

WORKDIR /var/www/html

COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund

# SKIP_WAYFINDER_AUTO — the vite plugin otherwise shells out to `php artisan
# wayfinder:generate`, which has no PHP in this Node image. Types come in
# from the wayfinder stage via COPY below.
ENV SKIP_WAYFINDER_AUTO=1

COPY . .
COPY --from=wayfinder /var/www/html/resources/js/routes    ./resources/js/routes
COPY --from=wayfinder /var/www/html/resources/js/actions   ./resources/js/actions
COPY --from=wayfinder /var/www/html/resources/js/wayfinder ./resources/js/wayfinder

RUN npm run build

# --- prod -------------------------------------------------------------------
FROM base AS prod

COPY docker/php/php.prod.ini /usr/local/etc/php/conf.d/zz-app.ini
COPY docker/entrypoint.prod.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# App source (honours .dockerignore — .env, vendor, node_modules excluded).
COPY . /var/www/html

# Bake vendor/ and public/build/ from the dedicated stages.
COPY --from=vendor /var/www/html/vendor /var/www/html/vendor
COPY --from=assets /var/www/html/public/build /var/www/html/public/build

# Regenerate the package manifest against the --no-dev vendor. Without
# this, a host-built bootstrap/cache/packages.php can bleed through and
# reference dev-only providers (e.g. laravel/boost → "Class not found").
# The vendor stage couldn't run this itself because it lacks artisan.
RUN rm -f bootstrap/cache/packages.php bootstrap/cache/services.php bootstrap/cache/config.php \
 && php artisan package:discover --ansi

# Writable paths owned by www-data. Everything else is read-only by default
# because php-fpm runs as www-data (see php-fpm config).
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -fsS http://127.0.0.1/up || exit 1

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
