# Single-stage image for development.
# A multi-stage refactor (builder + prod runtime) lands in a later commit
# when we add the production compose file.
#
# PHP 8.4 matches the host (Herd default) and satisfies composer.lock,
# which resolves some deps to require >= 8.4.
FROM php:8.4-fpm-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_NO_INTERACTION=1

# System packages: nginx + supervisor for the app, build deps for PHP extensions,
# libpq for Postgres, image libs for gd, unzip for composer, curl for healthcheck.
# $PHPIZE_DEPS is provided by the PHP base image — it's the compiler toolchain
# (gcc, make, autoconf, etc.) needed to build PECL extensions like redis.
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

# PHP extensions Laravel + the app need.
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

# Composer: copy the binary out of the official image rather than installing twice.
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# Config files.
COPY docker/php/php.ini /usr/local/etc/php/conf.d/zz-app.ini
COPY docker/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY docker/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh

# Remove the Debian nginx default site so our conf.d/default.conf wins.
RUN rm -f /etc/nginx/sites-enabled/default \
 && chmod +x /usr/local/bin/entrypoint.sh \
 && mkdir -p /var/log/supervisor /run/nginx /run/php

WORKDIR /var/www/html

# Healthcheck hits Laravel's built-in /up endpoint (Laravel 11+).
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -fsS http://127.0.0.1/up || exit 1

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
