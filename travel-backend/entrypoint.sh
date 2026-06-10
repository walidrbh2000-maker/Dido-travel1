#!/bin/bash

# Exit immediately on unhandled errors, treat unset variables as errors.
set -euo pipefail

ENV_FILE="/var/www/html/.env"
ARTISAN="/var/www/html/artisan"
APP_DIR="/var/www/html"
LARAVEL_TMP="/tmp/laravel-base"

# ── 0. Bootstrap Laravel if missing ──────────────────────────────────────────
if [ ! -f "${ARTISAN}" ]; then
    echo "▶ No Laravel project found (artisan missing) — creating fresh install..."

    # Always clean up any leftover directory from a previous failed attempt.
    rm -rf "${LARAVEL_TMP}"

    # Step A: download the laravel/laravel skeleton only (skip dependency install).
    echo "  Step A: downloading Laravel 11 skeleton (no dependency install)..."
    composer create-project laravel/laravel "${LARAVEL_TMP}" "^11.0" \
        --prefer-dist \
        --no-interaction \
        --no-scripts \
        --no-install

    # Step B: install dependencies bypassing security-advisory blocking.
    # NOTE: this Composer version exposes --no-security-blocking (not --no-audit).
    echo "  Step B: installing dependencies (--no-security-blocking)..."
    cd "${LARAVEL_TMP}"
    composer install \
        --no-interaction \
        --no-scripts \
        --no-security-blocking \
        --optimize-autoloader

    echo "  Copying skeleton into ${APP_DIR}..."
    cd /
    # -n : do not overwrite existing custom files already present in the volume
    cp -rn "${LARAVEL_TMP}/." "${APP_DIR}/"
    rm -rf "${LARAVEL_TMP}"

    echo "  Installing additional packages (JWT, PDF, Firebase)..."
    cd "${APP_DIR}"
    composer require \
        tymon/jwt-auth \
        barryvdh/laravel-dompdf \
        kreait/laravel-firebase \
        --no-interaction \
        --no-security-blocking \
        --optimize-autoloader

    # Publish vendor configs
    php "${ARTISAN}" vendor:publish \
        --provider="Tymon\JWTAuth\Providers\LaravelServiceProvider" \
        --no-interaction || true

    # Publish Firebase config so config/firebase.php exists before config:cache
    php "${ARTISAN}" vendor:publish \
        --provider="Kreait\Laravel\Firebase\ServiceProvider" \
        --no-interaction || true

    echo "✔ Laravel project ready."

else
    echo "✔ Laravel project already exists (artisan found)."

    # Ensure Firebase config is published even on pre-existing images
    if [ ! -f "${APP_DIR}/config/firebase.php" ]; then
        echo "▶ Firebase config missing — publishing..."
        cd "${APP_DIR}"
        php "${ARTISAN}" vendor:publish \
            --provider="Kreait\Laravel\Firebase\ServiceProvider" \
            --no-interaction || true
        echo "✔ Firebase config published."
    fi
fi

cd "${APP_DIR}"

# ── 1. Wait for MySQL ─────────────────────────────────────────────────────────
echo "▶ Waiting for database connection..."
DB_HOST="${DB_HOST:-db}"
DB_PORT="${DB_PORT:-3306}"
DB_DATABASE="${DB_DATABASE:-travel}"
DB_USERNAME="${DB_USERNAME:-travel_user}"
DB_PASSWORD="${DB_PASSWORD:-secret}"

MAX_RETRIES=30
for i in $(seq 1 ${MAX_RETRIES}); do
    if php -r "
        try {
            new PDO(
                'mysql:host=${DB_HOST};port=${DB_PORT};dbname=${DB_DATABASE}',
                '${DB_USERNAME}',
                '${DB_PASSWORD}'
            );
            exit(0);
        } catch (Exception \$e) {
            exit(1);
        }
    " 2>/dev/null; then
        echo "✔ Database is ready."
        break
    fi

    echo "  DB not ready — retrying (${i}/${MAX_RETRIES})..."
    sleep 3

    if [ "${i}" = "${MAX_RETRIES}" ]; then
        echo "✗ Could not connect to database after ${MAX_RETRIES} attempts. Aborting."
        exit 1
    fi
done

# ── 2. Install / update Composer dependencies ─────────────────────────────────
echo "▶ Installing Composer dependencies..."
composer install \
    --no-interaction \
    --no-security-blocking \
    --optimize-autoloader

# ── 3. Verify .env exists ─────────────────────────────────────────────────────
if [ ! -f "${ENV_FILE}" ]; then
    echo "✗ .env file not found at ${ENV_FILE}. Make sure custom/.env is present."
    exit 1
fi

# ── 4. Generate APP_KEY if missing ────────────────────────────────────────────
APP_KEY_VALUE=$(grep -E "^APP_KEY=" "${ENV_FILE}" | cut -d= -f2- | tr -d '[:space:]')
if [ -z "${APP_KEY_VALUE}" ]; then
    echo "▶ APP_KEY missing — generating..."
    php "${ARTISAN}" key:generate --force
    echo "✔ APP_KEY generated."
else
    echo "✔ APP_KEY already set."
fi

# ── 5. Generate JWT_SECRET if missing ─────────────────────────────────────────
JWT_SECRET_VALUE=$(grep -E "^JWT_SECRET=" "${ENV_FILE}" | cut -d= -f2- | tr -d '[:space:]')
if [ -z "${JWT_SECRET_VALUE}" ]; then
    echo "▶ JWT_SECRET missing — generating..."
    php "${ARTISAN}" jwt:secret --force
    echo "✔ JWT_SECRET generated."
else
    echo "✔ JWT_SECRET already set."
fi

# ── 6. Fix storage permissions ────────────────────────────────────────────────
echo "▶ Fixing storage permissions..."
mkdir -p \
    "${APP_DIR}/storage/logs" \
    "${APP_DIR}/storage/framework/cache/data" \
    "${APP_DIR}/storage/framework/sessions" \
    "${APP_DIR}/storage/framework/views" \
    "${APP_DIR}/bootstrap/cache"

chown -R www-data:www-data \
    "${APP_DIR}/storage" \
    "${APP_DIR}/bootstrap/cache"

chmod -R 775 \
    "${APP_DIR}/storage" \
    "${APP_DIR}/bootstrap/cache"

echo "✔ Permissions fixed."

# ── 7. Run migrations ─────────────────────────────────────────────────────────
echo "▶ Running migrations..."
php "${ARTISAN}" migrate --force || echo "⚠ Migrations already applied — continuing."
echo "✔ Migrations step done."

# ── 8. Run seeders ────────────────────────────────────────────────────────────
echo "▶ Seeding database..."
php "${ARTISAN}" db:seed --force || echo "⚠ Seeding skipped (already seeded or error) — continuing."

# ── 9. Build config & route caches ───────────────────────────────────────────
echo "▶ Caching config and routes..."
su -s /bin/sh www-data -c "php ${ARTISAN} config:clear"
su -s /bin/sh www-data -c "php ${ARTISAN} config:cache"
su -s /bin/sh www-data -c "php ${ARTISAN} route:clear"
su -s /bin/sh www-data -c "php ${ARTISAN} route:cache"
echo "✔ Cache built."

# ── 10. Start PHP-FPM ────────────────────────────────────────────────────────
echo "▶ Starting PHP-FPM..."
exec "$@"
