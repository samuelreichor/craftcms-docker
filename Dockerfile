# Base image for Craft CMS projects deployed with Coolify (or any Docker host).
#
# nginx + php-fpm with the PHP extensions Craft needs, Composer and the MySQL
# client. The same image runs the queue worker: any command other than the
# default skips nginx/php-fpm, e.g. `php craft queue/listen`.

ARG PHP_VERSION=8.4

FROM serversideup/php:${PHP_VERSION}-fpm-nginx-alpine

ARG IMAGICK_VERSION=3.8.1

USER root

# Point nginx at Craft's web root and enable opcache for production.
ENV NGINX_WEBROOT=/app/web
ENV PHP_OPCACHE_ENABLE=1

# Coolify's Traefik sits in a private Docker network and sets X-Forwarded-For,
# so trust private ranges to see real visitor IPs. Set TRUSTED_PROXY=cloudflare
# when Cloudflare proxies the site.
ENV TRUSTED_PROXY=local

# bcmath required by craftcms/cms + moneyphp/money, gd required by phpoffice/phpspreadsheet,
# intl required by craftcms/cms, imagick for Craft's image transforms.
# imagick is built from GitHub instead of PECL, which regularly times out.
# mariadb-connector + mysql-client are needed for craft db/backup + mysqldump.
RUN install-php-extensions bcmath gd intl Imagick/imagick@${IMAGICK_VERSION} \
  && apk add --no-cache git unzip bash vim mariadb-connector-c mysql-client

# Wrappers take precedence over /usr/bin via PATH.
COPY --chmod=755 bin/mysql-wrapper /usr/local/bin/mysql
COPY --chmod=755 bin/mysql-wrapper /usr/local/bin/mysqldump

# Craft's writable paths have to exist in the image, otherwise Docker creates
# mounted volumes (e.g. web/assets) owned by root. .env is touched so Craft can
# write to it even when Coolify injects env vars at runtime instead.
RUN mkdir -p /app/storage /app/web/cpresources /app/web/assets \
  && touch /app/.env \
  && chown -R www-data:www-data /app

WORKDIR /app

USER www-data
