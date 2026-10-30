# For projects without a frontend build (e.g. headless/API-only or plain Twig
# without Vite). Versions: only change them here.
ARG PHP_VERSION=8.4

### Craft (web + queue)
FROM ghcr.io/samuelreichor/craftcms-docker:${PHP_VERSION}

# Custom nginx directives, included inside the server block.
COPY .coolify/nginx/ /etc/nginx/server-opts.d/

# Code and dependencies belong to root, so PHP can't modify them.
USER root

# Project specific PHP extensions, e.g.:
# RUN install-php-extensions redis

# Dependencies first, so they stay cached until composer.lock changes.
# --no-scripts skips hooks that need a DB connection, --no-autoloader because
# the project code (e.g. modules/) isn't copied yet.
COPY composer.json composer.lock ./
RUN composer install --no-interaction --no-dev --no-scripts --no-autoloader

COPY . .

# COPY resets folders that exist in the repo (e.g. storage/) to root, so hand
# Craft's writable paths back to www-data.
RUN composer dump-autoload --no-dev --optimize \
  && chown -R www-data:www-data storage web/cpresources web/assets .env

USER www-data
