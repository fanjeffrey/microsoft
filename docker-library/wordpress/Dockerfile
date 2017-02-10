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
### see https://www.apache.org/dist/httpd/httpd-$HTTPD_VERSION.tar.gz.sha1
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
RUN ./configure \
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

EXPOSE 80

CMD ["/usr/local/httpd/bin/httpd","-DFOREGROUND"]

# php
ENV PHP_VERSION 7.1.1

# wordpress
ENV WORDPRESS_VERSION 4.7.2

# mysql
ENV MYSQL_VERSION 5.7.17

# phpMyAdmin
ENV PHPMYADMIN_VERSION 4.6.6

# redis
ENV REDIS_VERSION 3.2.7

# clean up
RUN apt-get purge -y --auto-remove $tools
