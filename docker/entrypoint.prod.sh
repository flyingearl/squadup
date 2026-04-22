#!/usr/bin/env bash
# Production entrypoint.
#
# Deliberately minimal — unlike dev, we assume:
#   - code is baked into the image (no bind mounts, no composer install)
#   - vendor/ is baked in (from the vendor stage)
#   - public/build/ is baked in (from the assets stage)
#   - .env is mounted/injected by the orchestrator, with APP_KEY set
#   - database migrations are run as a separate deploy step, not on boot
#
# This entrypoint only primes Laravel's caches. Everything else is the
# orchestrator's or CI/CD pipeline's responsibility.

set -e

cd /var/www/html

# dotenv immutable-mode precaution: if the orchestrator injects APP_KEY
# via real env (e.g. Kubernetes Secret, Docker secret), we don't want
# to unset it here. But if it's empty we clear so .env can be consulted.
if [ -z "${APP_KEY:-}" ]; then
    unset APP_KEY
fi

# Cache config, routes, views. Non-fatal — if a cache step fails (e.g.
# a route uses a container that's not ready), the server still boots.
php artisan config:cache || echo "[entrypoint.prod] config:cache failed (non-fatal)"
php artisan route:cache  || echo "[entrypoint.prod] route:cache failed (non-fatal)"
php artisan view:cache   || echo "[entrypoint.prod] view:cache failed (non-fatal)"

echo "[entrypoint.prod] boot complete (role=${CONTAINER_ROLE:-web}) — handing off to supervisor."

exec "$@"
