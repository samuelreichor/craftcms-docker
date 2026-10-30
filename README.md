# craftcms-docker

Shared base images for Craft CMS projects deployed with [Coolify](https://coolify.io) (or any Docker host).
Built on [serversideup/php](https://serversideup.net/open-source/docker-php/) and rebuilt weekly to pick up upstream security updates.

PHP extensions (bcmath, gd, intl, imagick), the MySQL client and Composer live in the image, so a project
deploy only installs dependencies and copies code instead of compiling extensions every time.

## Images

| Tag | Use |
| --- | --- |
| `ghcr.io/samuelreichor/craftcms-docker:<php>-web` | nginx + php-fpm, webroot `/app/web` |
| `ghcr.io/samuelreichor/craftcms-docker:<php>-cli` | PHP CLI + Composer, for `composer install` and the queue worker |

`<php>` is `8.3`, `8.4` or `8.5`. Every build is also tagged with its date (e.g. `8.4-web-20261102`),
so a project can pin a specific build. Images are published for `linux/amd64` and `linux/arm64`.

Included in both images:

- PHP extensions `bcmath`, `gd`, `intl`, `imagick` on top of the serversideup defaults (`pdo_mysql`, `zip`, `opcache`, …)
- `git`, `unzip`, `bash`, MariaDB client (`mysql`/`mysqldump`), plus `vim` in `web`
- `mysql`/`mysqldump` wrappers that skip TLS verification of MySQL's self-signed certificate, so `craft db/backup` works
- `craft-prepare`, which creates Craft's writable paths and hands them to `www-data`
- Composer (`cli` only)

## Usage in a project

Copy one of the examples into the project root:

- [`examples/craft`](examples/craft): classic Craft site (Twig + Vite assets), with `web`, `queue` and `db` services
- [`examples/craft-nuxt`](examples/craft-nuxt): headless Craft + Nuxt SSR on one domain

A project Dockerfile then looks like this:

```dockerfile
ARG PHP_VERSION=8.4
ARG BASE_IMAGE=ghcr.io/samuelreichor/craftcms-docker

FROM ${BASE_IMAGE}:${PHP_VERSION}-cli AS vendor
COPY composer.json composer.lock ./
RUN composer install --no-interaction --no-dev --no-scripts --optimize-autoloader

FROM ${BASE_IMAGE}:${PHP_VERSION}-web AS web
USER root
COPY .coolify/nginx/ /etc/nginx/server-opts.d/
COPY . .
COPY --from=vendor /app/vendor ./vendor
RUN craft-prepare
USER www-data
```

## Configuration

| What | How |
| --- | --- |
| PHP version | `PHP_VERSION` build arg, picks the image tag |
| Node version | `NODE_VERSION` build arg, uses the official `node` image in the project's build stage |
| MySQL version | `MYSQL_VERSION` in `docker-compose.yml` (`image: mysql:${MYSQL_VERSION:-8.4}`) |
| nginx snippets | `.conf` files in `.coolify/nginx/`, copied to `/etc/nginx/server-opts.d/` and included inside the `server` block |
| nginx site config | replace `/etc/nginx/site-opts.d/http.conf.template` completely (see `examples/craft-nuxt`) |
| Extra PHP extensions | `RUN install-php-extensions redis` in the project's `web`/`queue` stage (as `root`) |
| PHP settings | serversideup env vars at runtime, e.g. `PHP_MEMORY_LIMIT`, `PHP_UPLOAD_MAX_FILE_SIZE`, `PHP_MAX_EXECUTION_TIME` ([list](https://serversideup.net/open-source/docker-php/docs/reference/environment-variable-specification)) |
| Writable paths | `CRAFT_WRITABLE_PATHS` for `craft-prepare` (default `config storage web/cpresources web/assets`) |

`PHP_VERSION`, `NODE_VERSION` and `MYSQL_VERSION` can be set as environment variables in Coolify; the examples fall back to sensible defaults.

> Upgrading MySQL to a newer major version on an existing volume usually works; downgrading does not. Take a backup first.

## Updating

- **Upstream security updates**: the workflow rebuilds all images every Monday without cache.
- **Changes to the images** (new extension, new PHP version): edit `Dockerfile` or the matrix in
  `.github/workflows/build.yml` and push to `main`.
- Projects pick up a new base image on their next deploy, as long as Docker pulls it. Pin a dated tag
  (`8.4-web-20261102`) if a project should only change on purpose.

## Local build

```sh
docker build --target web --build-arg PHP_VERSION=8.4 -t craftcms-docker:8.4-web .
docker build --target cli --build-arg PHP_VERSION=8.4 -t craftcms-docker:8.4-cli .
```
