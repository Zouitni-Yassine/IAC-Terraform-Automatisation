FROM php:8.3-apache

RUN apt-get update \
 && apt-get install -y --no-install-recommends libpq-dev \
 && docker-php-ext-install pdo pdo_mysql pdo_pgsql \
 && a2enmod rewrite \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

COPY www/ /var/www/html/

RUN mkdir -p /var/www/html/uploads \
 && chown -R www-data:www-data /var/www/html \
 && chmod 755 /var/www/html \
 && chmod 777 /var/www/html/uploads

EXPOSE 80
