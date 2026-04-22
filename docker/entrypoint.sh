#!/usr/bin/env sh
# Runs once every container start, before supervisor takes over.
# Handles first-run setup so `docker compose up` is all someone needs.

set -e

cd /var/www/html

# 1. Copy .env.example → .env on first boot.
if [ ! -f .env ]; then
    echo "[entrypoint] .env missing — copying from .env.example..."
    cp .env.example .env
fi

# 2. Install composer dependencies if vendor/ is empty (fresh clone).
if [ ! -f vendor/autoload.php ]; then
    echo "[entrypoint] vendor/ missing — running composer install..."
    composer install --no-interaction --prefer-dist
fi

# 3. Generate APP_KEY if it's blank.
if ! grep -q "^APP_KEY=base64:" .env; then
    echo "[entrypoint] APP_KEY missing — generating..."
    php artisan key:generate --force
fi

# 4. Ensure storage + bootstrap/cache are writable by www-data.
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

# 5. Run migrations. Safe to re-run every boot (idempotent).
php artisan migrate --force

echo "[entrypoint] boot complete — handing off to supervisor."

exec "$@"
