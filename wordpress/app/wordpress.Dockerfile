FROM wordpress:latest

ARG LOCAL_UID=1000
ARG LOCAL_GID=1000

COPY ./config/uploads.ini "${PHP_INI_DIR}/conf.d/"

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

USER root

RUN \
    usermod --uid "${LOCAL_UID}" www-data && \
    groupmod --gid "${LOCAL_GID}" www-data

RUN install-php-extensions \
      curl \
      dom \
      mbstring \
      exif \
      fileinfo \
      imagick \
      igbinary \
      openssl \
      pcre \
      xml \
      xmlreader \
      zip \
      zlib

USER www-data
