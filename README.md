# craftcms-docker

Shared base image for Craft CMS projects deployed with [Coolify](https://coolify.io) (or any Docker host).
Built on [serversideup/php](https://serversideup.net/open-source/docker-php/) and rebuilt weekly to pick up upstream security updates.

PHP extensions, the MySQL client and Composer live in the image, so a project deploy only installs
dependencies and copies code instead of compiling extensions every time.

## Image

```
ghcr.io/samuelreichor/craftcms-docker:<php>
```

`<php>` is `8.3`, `8.4` or `8.5`, for `linux/amd64` and `linux/arm64`. Every build is also tagged with its
date (e.g. `8.4-20261102`), so a project can pin a specific build.

What's inside:

- nginx + php-fpm, webroot `/app/web`, opcache enabled
- PHP extensions `bcmath`, `gd`, `intl`, `imagick` on top of the serversideup defaults (`pdo_mysql`, `zip`, `opcache`, …)
- Composer, `git`, `unzip`, `bash`, `vim`
- MariaDB client as `mysql`/`mysqldump`, wrapped to skip TLS verification of MySQL's self-signed certificate, so `craft db/backup` works
- Craft's writable paths (`storage`, `web/cpresources`, `web/assets`, `.env`) owned by `www-data`

The same image runs the queue worker: any command other than the default skips nginx and php-fpm
(`command: ["php", "craft", "queue/listen", "--verbose"]`).

## Usage in a project

Copy one of the examples into the project root:

- [`examples/craft`](examples/craft): classic Craft site (Twig + Vite assets) with `web`, `queue` and `db`
- [`examples/craft-nuxt`](examples/craft-nuxt): headless Craft + Nuxt SSR on one domain

The project Dockerfile is short:

```dockerfile
ARG PHP_VERSION=8.4
ARG NODE_VERSION=22

FROM node:${NODE_VERSION}-alpine AS assets
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM ghcr.io/samuelreichor/craftcms-docker:${PHP_VERSION}
COPY .coolify/nginx/ /etc/nginx/server-opts.d/
COPY --chown=www-data:www-data composer.json composer.lock ./
RUN composer install --no-interaction --no-dev --no-scripts --no-autoloader
COPY --chown=www-data:www-data . .
COPY --chown=www-data:www-data --from=assets /app/web/dist ./web/dist
RUN composer dump-autoload --no-dev --optimize
```

## Configuration

Every setting lives in exactly one place:

| What | Where |
| --- | --- |
| PHP version | `ARG PHP_VERSION` at the top of `.coolify/Dockerfile` |
| Node version | `ARG NODE_VERSION` at the top of `.coolify/Dockerfile` |
| MySQL version | `image: mysql:8.4` in `docker-compose.yml` |
| nginx snippets | `.conf` files in `.coolify/nginx/`, included inside the `server` block |
| nginx site config | replace `/etc/nginx/site-opts.d/http.conf.template` completely (see `examples/craft-nuxt`) |
| Extra PHP extensions | `USER root` + `RUN install-php-extensions redis` + `USER www-data` in the project Dockerfile |
| PHP settings | serversideup env vars at runtime, e.g. `PHP_MEMORY_LIMIT`, `PHP_UPLOAD_MAX_FILE_SIZE` ([list](https://serversideup.net/open-source/docker-php/docs/reference/environment-variable-specification)) |

> Upgrading MySQL to a newer major version on an existing volume usually works; downgrading does not. Take a backup first.

## Maintenance

- **Security updates**: the workflow rebuilds all images every Monday without cache. PHP patch releases
  (8.4.x) arrive the same way. Trigger "Run workflow" in the Actions tab to rebuild right away.
- **New PHP version**: add it to the list in the `versions` job of `.github/workflows/build.yml` and push.
  Dropped versions keep their last tags on GHCR but are no longer updated.
- **Changes to the image** (new extension, …): edit `Dockerfile` and push to `main`.
- Projects pick up a new base image on their next deploy, as long as Docker pulls it. Pin a dated tag
  (`8.4-20261102`) if a project should only change on purpose.

## Local build

```sh
docker build --build-arg PHP_VERSION=8.4 -t craftcms-docker:8.4 .
```
