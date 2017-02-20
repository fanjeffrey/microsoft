#
# Dockerfile for WordPress
#
FROM ubuntu:16.04
LABEL maintainer "v-jifan@microsoft.com"

# tools
RUN set -ex \
	&& tools=" \
        gcc \
        make \
		wget \
	" \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends -V $tools \
    && rm -r /var/lib/apt/lists/*

# apache httpd
## runtime deps
RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		libapr1 \
		libaprutil1 \
		libaprutil1-ldap \
		libapr1-dev \
		libaprutil1-dev \
	&& rm -r /var/lib/apt/lists/*

## build deps
RUN set -ex \
	&& buildDeps=" \
        libpcre++-dev \
	" \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends -V $buildDeps \
    && rm -r /var/lib/apt/lists/*

ENV HTTPD_VERSION "2.4.25"
ENV HTTPD_DOWNLOAD_URL "https://www.apache.org/dist/httpd/httpd-$HTTPD_VERSION.tar.gz"
## see https://www.apache.org/dist/httpd/httpd-$HTTPD_VERSION.tar.gz.sha1
ENV HTTPD_SHA1 "377c62dc6b25c9378221111dec87c28f8fe6ac69"

ENV HTTPD_HOME "/usr/local/httpd"
ENV HTTPD_SOURCE "$HTTPD_HOME/src"
WORKDIR $HTTPD_HOME
RUN set -ex \
    && wget -O httpd.tar.gz "$HTTPD_DOWNLOAD_URL" --no-check-certificate \
    && echo "$HTTPD_SHA1 *httpd.tar.gz" | sha1sum -c - \
    && mkdir src \
    && tar -xf httpd.tar.gz -C $HTTPD_SOURCE --strip-components=1 \
    && rm httpd.tar.gz

WORKDIR $HTTPD_SOURCE
RUN set -ex \
	&& ./configure \
		--prefix="$HTTPD_HOME" \
		--enable-mods-shared=reallyall \
	&& make -j "$(nproc)" \
    && make install

WORKDIR $HTTPD_HOME
RUN rm -r src man manual \
    && sed -ri \
		-e 's!^(\s*CustomLog)\s+\S+!\1 /proc/self/fd/1!g' \
		-e 's!^(\s*ErrorLog)\s+\S+!\1 /proc/self/fd/2!g' \
		"$HTTPD_HOME/conf/httpd.conf" \
    && apt-get purge -y --auto-remove $buildDeps


# php
## see http://php.net/manual/en/install.unix.apache2.php
## see http://linuxfromscratch.org/blfs/view/svn/general/php.html
ENV PHP_VERSION "7.1.1"
ENV PHP_DOWNLOAD_URL "https://secure.php.net/get/php-7.1.1.tar.gz/from/this/mirror"
ENV PHP_SHA256 "c136279d539c3c2c25176bf149c14913670e79bb27ee6b73e1cd69003985a70d"

#IMP# /usr/local/httpd/bin/a2dismod mpm_event && /usr/local/httpd/bin/a2enmod mpm_prefork

## runtime deps

## build deps
RUN set -ex \
	### zlib1g-dev >> with-zlib >> Uncaught Error: Call to undefined function gzinflate() in /var/www/wp-includes/class-requests.php:947
	&& buildDeps=" \
		libxml2-dev \		
		zlib1g-dev \
	" \
	&& apt-get update \
	&& apt-get install -y $buildDeps --no-install-recommends \
	&& rm -rf /var/lib/apt/lists/*

ENV PHP_HOME "/usr/local/php"
ENV PHP_SOURCE "$PHP_HOME/src"
WORKDIR $PHP_HOME
RUN set -ex \
    && wget -O php.tar.gz "$PHP_DOWNLOAD_URL" --no-check-certificate \
    && echo "$PHP_SHA256 *php.tar.gz" | sha256sum -c - \
    && mkdir src \
    && tar -xf php.tar.gz -C $PHP_SOURCE --strip-components=1 \
    && rm php.tar.gz
	
WORKDIR $PHP_SOURCE
RUN set -ex \
    && ./configure \
		--prefix="$PHP_HOME" \
		--with-apxs2="$HTTPD_HOME/bin/apxs" \
		### see http://php.net/manual/en/mysqlnd.overview.php
		### see http://php.net/manual/en/mysqlinfo.api.choosing.php
		--with-mysqli=mysqlnd \
		--with-zlib \
	&& make -j "$(nproc)" \
	&& make install \
	&& make clean \
	&& apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false $buildDeps

## change DocumentRoot, User, Group
RUN set -ex \
	&& sed -i 's_DocumentRoot "/usr/local/httpd/htdocs"_DocumentRoot "/var/www"_' "$HTTPD_HOME/conf/httpd.conf" \
	&& sed -i 's_User daemon_User www-data_' "$HTTPD_HOME/conf/httpd.conf" \
	&& sed -i 's_Group daemon_Group www-data_' "$HTTPD_HOME/conf/httpd.conf"

## copy php.conf
COPY php.conf "$HTTPD_HOME/conf/extra/"

## include php.conf
RUN set -ex \
	&& echo 'Include conf/extra/php.conf' | tee -a "$HTTPD_HOME/conf/httpd.conf"

WORKDIR /var/www
### kept for test, will remove this on final release
RUN echo '<?php phpinfo();' | tee /var/www/info.php


# wordpress
ENV WORDPRESS_VERSION 4.7.2
### see https://wordpress.org/download/release-archive/
ENV WORDPRESS_DOWNLOAD_URL "https://wordpress.org/wordpress-$WORDPRESS_VERSION.tar.gz"
ENV WORDPRESS_SHA1 "7b687f1af589c337124e6247229af209ec1d52c3"

RUN set -ex \
	&& wget -O wordpress.tar.gz "$WORDPRESS_DOWNLOAD_URL" --no-check-certificate \
	&& echo "$WORDPRESS_SHA1 *wordpress.tar.gz" | sha1sum -c - \
	&& tar -xf wordpress.tar.gz --strip-components=1 \
	&& rm wordpress.tar.gz \
	&& chown -R www-data:www-data /var/www

# mysql
ENV MYSQL_VERSION 5.7.17

# phpMyAdmin
ENV PHPMYADMIN_VERSION 4.6.6

# redis
ENV REDIS_VERSION 3.2.7

# clean up
RUN apt-get purge -y --auto-remove $tools

# 
EXPOSE 80
CMD ["/usr/local/http/bin/apachectl","start"]
