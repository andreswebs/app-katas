FROM wordpress:latest

COPY ./config/uploads.ini "${PHP_INI_DIR}/conf.d/"

COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

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
