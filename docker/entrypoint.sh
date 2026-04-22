#!/usr/bin/env bash
# Runs once every container start, before supervisor takes over.
# Handles first-run setup so `docker compose up` is all someone needs.
#
# Boot-time setup that TOUCHES SHARED STATE (the bind-mounted .env and DB)
# runs inside a flock, so parallel app replicas can't race on
# key:generate, migrate, or wayfinder:generate.

set -e

cd /var/www/html

# `env_file: .env` in compose loads .env vars into the container env at
# boot. If .env had a blank APP_KEY at that moment, APP_KEY="" lands in
# the process env and vlucas/phpdotenv (Laravel's loader) will refuse to
# override it with whatever we write to .env later in this script.
# Unset it so Laravel re-reads from the .env file cleanly on every boot.
unset APP_KEY

# 1. Copy .env.example → .env on first boot.
#    Safe per-replica; operates on the bind-mounted file, but the first
#    replica wins and the others see the file already present.
if [ ! -f .env ]; then
    echo "[entrypoint] .env missing — copying from .env.example..."
    cp .env.example .env
fi

# 2. Install composer dependencies if vendor/ is empty (fresh clone).
#    Per-replica is fine — both would produce the same output; Composer's
#    own locking inside the vendor/ writes doesn't cross containers cleanly
#    so if you see weirdness here, rerun `docker compose exec app
#    composer install` once.
if [ ! -f vendor/autoload.php ]; then
    echo "[entrypoint] vendor/ missing — running composer install..."
    composer install --no-interaction --prefer-dist
fi

# 3. Ensure storage + bootstrap/cache are writable by www-data.
#    Safe to run from every replica; chown/chmod are idempotent.
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

# 4. Everything below this line writes to shared state (.env, database,
#    generated JS files) and MUST serialize across replicas. flock on a
#    bind-mounted file is cross-container on the same host.
mkdir -p storage
(
    flock -x 200

    # Clear any stale bootstrap caches. The bind mount means a previous
    # prod-mode run can leave config:cache output here, which would then
    # poison dev (e.g. APP_ENV=production, stale password rules, etc.).
    php artisan config:clear  > /dev/null 2>&1 || true
    php artisan route:clear   > /dev/null 2>&1 || true
    php artisan view:clear    > /dev/null 2>&1 || true

    # APP_KEY: missing, blank, or malformed (more than one base64: prefix).
    APP_KEY_BASE64_COUNT=$(grep -c '^APP_KEY=base64:' .env 2>/dev/null || echo 0)
    APP_KEY_EXTRA_PREFIXES=$(grep -c 'base64:' .env 2>/dev/null || echo 0)
    if [ "$APP_KEY_BASE64_COUNT" != "1" ] || [ "$APP_KEY_EXTRA_PREFIXES" != "1" ]; then
        echo "[entrypoint] APP_KEY missing or malformed — regenerating..."
        # Blank the line first so the loaded env var doesn't trigger
        # Laravel's "APP_KEY already present" refusal.
        sed -i 's|^APP_KEY=.*|APP_KEY=|' .env
        APP_KEY= php artisan key:generate --force
    fi

    # Migrations + wayfinder only from the web role. Queue workers, the
    # scheduler, and Reverb all boot with CONTAINER_ROLE != web.
    if [ "${CONTAINER_ROLE:-web}" = "web" ]; then
        php artisan migrate --force
        php artisan wayfinder:generate --with-form \
            || echo "[entrypoint] wayfinder:generate failed (non-fatal)"
    fi
) 200>storage/.boot.lock

echo "[entrypoint] boot complete (role=${CONTAINER_ROLE:-web}) — handing off to supervisor."

exec "$@"
