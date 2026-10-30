# Versions: only change them here.
ARG PHP_VERSION=8.4
ARG NODE_VERSION=24

### Nuxt build
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

### Nuxt server - runs the Nitro SSR server (target: nuxt)
FROM node:${NODE_VERSION}-alpine AS nuxt

ENV NODE_ENV=production \
  HOST=0.0.0.0 \
  PORT=3000

WORKDIR /app

COPY --from=nuxtbuilder --chown=node:node /app/frontend/.output ./.output

USER node

EXPOSE 3000

CMD ["node", ".output/server/index.mjs"]

### Craft (web + queue)
FROM ghcr.io/samuelreichor/craftcms-docker:${PHP_VERSION}

# Serves Craft and proxies everything else to the nuxt service on the same domain.
# Replaces the whole site config instead of adding snippets to server-opts.d.
COPY .coolify/nginx/http.conf.template /etc/nginx/site-opts.d/http.conf.template

# Dependencies first, so they stay cached until composer.lock changes.
# --no-scripts skips hooks that need a DB connection, --no-autoloader because
# the PSR-4 modules/ aren't copied yet.
COPY --chown=www-data:www-data composer.json composer.lock ./
RUN composer install --no-interaction --no-dev --no-scripts --no-autoloader

COPY --chown=www-data:www-data . .

RUN composer dump-autoload --no-dev --optimize
