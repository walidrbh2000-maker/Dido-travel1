FROM php:8.2-fpm

# ── System dependencies ───────────────────────────────────────────────────────
# libzip-dev  → required by ext-zip
# libicu-dev  → required by ext-intl
# libxml2-dev → required by ext-xml, ext-dom (was already present but ext not declared)
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    libicu-dev \
    zip \
    unzip \
    nginx \
    supervisor \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# ── PHP extensions ────────────────────────────────────────────────────────────
# Previously missing: xml, dom, zip, intl
# xml + dom → needed by Laravel 11 core & many Composer packages
# zip        → needed by Composer itself and laravel/framework
# intl       → needed by kreait/firebase-php and other deps
RUN docker-php-ext-install \
    pdo_mysql \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    xml \
    dom \
    zip \
    intl

# ── Redis extension (via PECL) ────────────────────────────────────────────────
RUN pecl install redis \
 && docker-php-ext-enable redis

# ── Composer ──────────────────────────────────────────────────────────────────
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# ── Entrypoint ────────────────────────────────────────────────────────────────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /var/www/html

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]
