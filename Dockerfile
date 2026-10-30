# Base images for Craft CMS projects deployed with Coolify (or any Docker host).
#
#   cli  PHP CLI + Composer. Used for `composer install` and the queue worker.
#   web  nginx + php-fpm (s6-overlay), webroot /app/web.
#
# Both targets share the same PHP extensions and tools, so projects only copy
# their code on top instead of compiling extensions on every deploy.

ARG PHP_VERSION=8.4

FROM composer:2 AS composer

### CLI
FROM serversideup/php:${PHP_VERSION}-cli-alpine AS cli

ARG IMAGICK_VERSION=3.8.1

USER root

# bcmath required by craftcms/cms + moneyphp/money, gd required by phpoffice/phpspreadsheet,
# intl required by craftcms/cms, imagick for Craft's image transforms.
# imagick is built from GitHub instead of PECL, which regularly times out.
# mariadb-connector + mysql-client are needed for craft db/backup + mysqldump.
RUN install-php-extensions bcmath gd intl Imagick/imagick@${IMAGICK_VERSION} \
  && apk add --no-cache git unzip bash mariadb-connector-c mysql-client

COPY --from=composer /usr/bin/composer /usr/bin/composer
COPY --chmod=755 rootfs/usr/local/bin/ /usr/local/bin/

# mysql/mysqldump wrappers take precedence over /usr/bin via PATH.
RUN ln -s mariadb-client-wrapper /usr/local/bin/mysql \
  && ln -s mariadb-client-wrapper /usr/local/bin/mysqldump \
  && mkdir -p /app \
  && chown www-data:www-data /app

WORKDIR /app

USER www-data

### Web
FROM serversideup/php:${PHP_VERSION}-fpm-nginx-alpine AS web

ARG IMAGICK_VERSION=3.8.1

USER root

# Point nginx at Craft's web root and enable opcache for production.
ENV NGINX_WEBROOT=/app/web
ENV PHP_OPCACHE_ENABLE=1

RUN install-php-extensions bcmath gd intl Imagick/imagick@${IMAGICK_VERSION} \
  && apk add --no-cache git unzip bash vim mariadb-connector-c mysql-client

COPY --chmod=755 rootfs/usr/local/bin/ /usr/local/bin/

RUN ln -s mariadb-client-wrapper /usr/local/bin/mysql \
  && ln -s mariadb-client-wrapper /usr/local/bin/mysqldump \
  && mkdir -p /app \
  && chown www-data:www-data /app

WORKDIR /app

USER www-data
