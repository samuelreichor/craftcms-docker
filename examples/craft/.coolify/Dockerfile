ARG PHP_VERSION=8.4
ARG NODE_VERSION=22
ARG BASE_IMAGE=ghcr.io/samuelreichor/craftcms-docker

### Stage 1: Node Build Environment
FROM node:${NODE_VERSION}-alpine AS nodebuilder

WORKDIR /app

COPY package.json package-lock.json ./

# Install Node.js dependencies using npm ci for clean and consistent installs.
RUN npm ci

COPY . .

# Build the frontend assets using the build script defined in package.json.
RUN npm run build

### Stage 2: Composer Dependencies
# Resolves PHP packages once and is reused by web + queue stages.
FROM ${BASE_IMAGE}:${PHP_VERSION}-cli AS vendor

COPY composer.json composer.lock ./

# --no-scripts skips the post-install-cmd hook which calls `craft install/check`.
# That hook needs a working DB connection and would fail inside the build container.
RUN composer install --no-interaction --no-dev --no-scripts --optimize-autoloader

### Stage 3: Web (nginx + php-fpm)
FROM ${BASE_IMAGE}:${PHP_VERSION}-web AS web

USER root

# Project specific PHP extensions, e.g.:
# RUN install-php-extensions redis

# Custom nginx directives, included inside the server block.
COPY .coolify/nginx/ /etc/nginx/server-opts.d/

COPY . .
COPY --from=vendor /app/vendor ./vendor
COPY --from=nodebuilder /app/web/dist ./web/dist

RUN craft-prepare

USER www-data

### Stage 4: Queue Worker - runs craft queue/listen
FROM ${BASE_IMAGE}:${PHP_VERSION}-cli AS queue

USER root

COPY . .
COPY --from=vendor /app/vendor ./vendor
COPY --from=nodebuilder /app/web/dist ./web/dist

RUN craft-prepare

USER www-data

CMD ["php", "craft", "queue/listen", "--verbose"]
