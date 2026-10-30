# Versions: only change them here.
ARG PHP_VERSION=8.4
ARG NODE_VERSION=22

### Frontend assets
FROM node:${NODE_VERSION}-alpine AS assets

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

### Craft (web + queue)
FROM ghcr.io/samuelreichor/craftcms-docker:${PHP_VERSION}

# Project specific PHP extensions, e.g.:
# USER root
# RUN install-php-extensions redis
# USER www-data

# Custom nginx directives, included inside the server block.
COPY .coolify/nginx/ /etc/nginx/server-opts.d/

# Dependencies first, so they stay cached until composer.lock changes.
# --no-scripts skips hooks that need a DB connection, --no-autoloader because
# the project code (e.g. modules/) isn't copied yet.
COPY --chown=www-data:www-data composer.json composer.lock ./
RUN composer install --no-interaction --no-dev --no-scripts --no-autoloader

COPY --chown=www-data:www-data . .
COPY --chown=www-data:www-data --from=assets /app/web/dist ./web/dist

RUN composer dump-autoload --no-dev --optimize
