ARG PHP_VERSION=8.4
ARG NODE_VERSION=24
ARG BASE_IMAGE=ghcr.io/samuelreichor/craftcms-docker

### Stage 1: Nuxt Build Environment
FROM node:${NODE_VERSION}-alpine AS nuxtbuilder

# Nuxt reads these in nuxt.config.ts at build time (craftcms baseUrl + siteMap),
# so they have to be passed in as build args, not only as runtime env vars.
ARG NUXT_PRIMARY_SITE_URL
ARG NUXT_PRIMARY_SITE_URL_DE
ARG NUXT_PRIMARY_SITE_URL_ES
ARG NUXT_CRAFT_TOKEN
ENV NUXT_PRIMARY_SITE_URL=${NUXT_PRIMARY_SITE_URL} \
  NUXT_PRIMARY_SITE_URL_DE=${NUXT_PRIMARY_SITE_URL_DE} \
  NUXT_PRIMARY_SITE_URL_ES=${NUXT_PRIMARY_SITE_URL_ES} \
  NUXT_CRAFT_TOKEN=${NUXT_CRAFT_TOKEN}

WORKDIR /app

COPY package.json package-lock.json ./
COPY frontend/package.json ./frontend/

# --ignore-scripts skips the `nuxt prepare` postinstall, which needs the frontend
# sources. `nuxt build` runs prepare itself later.
RUN npm ci --ignore-scripts

COPY frontend ./frontend

RUN npm run build

### Stage 2: Nuxt Server - runs the Nitro SSR server
FROM node:${NODE_VERSION}-alpine AS nuxt

ENV NODE_ENV=production \
  HOST=0.0.0.0 \
  PORT=3000

WORKDIR /app

COPY --from=nuxtbuilder --chown=node:node /app/frontend/.output ./.output

USER node

EXPOSE 3000

CMD ["node", ".output/server/index.mjs"]

### Stage 3: Composer Dependencies
FROM ${BASE_IMAGE}:${PHP_VERSION}-cli AS vendor

COPY composer.json composer.lock ./

# --no-scripts skips composer hooks that need a working DB connection or the
# project sources. --no-autoloader because the PSR-4 modules/ aren't copied yet.
RUN composer install --no-interaction --no-dev --no-scripts --no-autoloader

COPY modules ./modules

RUN composer dump-autoload --no-dev --optimize

### Stage 4: Web (nginx + php-fpm)
FROM ${BASE_IMAGE}:${PHP_VERSION}-web AS web

USER root

# Serves Craft and proxies everything else to the nuxt service on the same domain.
# Replaces the whole site config instead of adding snippets to server-opts.d.
COPY .coolify/nginx/http.conf.template /etc/nginx/site-opts.d/http.conf.template

COPY . .
COPY --from=vendor /app/vendor ./vendor

RUN craft-prepare

USER www-data

### Stage 5: Queue Worker - runs craft queue/listen
FROM ${BASE_IMAGE}:${PHP_VERSION}-cli AS queue

USER root

COPY . .
COPY --from=vendor /app/vendor ./vendor

RUN craft-prepare

USER www-data

CMD ["php", "craft", "queue/listen", "--verbose"]
