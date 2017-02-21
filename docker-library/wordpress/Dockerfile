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
	&& apt-get install $tools -y -V --no-install-recommends \
	&& rm -r /var/lib/apt/lists/*

# apache httpd
ENV HTTPD_VERSION "2.4.25"
ENV HTTPD_DOWNLOAD_URL "https://www.apache.org/dist/httpd/httpd-$HTTPD_VERSION.tar.gz"
ENV HTTPD_SHA1 "377c62dc6b25c9378221111dec87c28f8fe6ac69"
ENV HTTPD_HOME "/usr/local/httpd"
ENV HTTPD_SOURCE "$HTTPD_HOME/src"
WORKDIR "$HTTPD_HOME"
RUN set -ex \
	
	## runtime deps
	&& runtimeDeps=" \
		libapr1 \
		libaprutil1 \
		libaprutil1-ldap \
		libapr1-dev \
		libaprutil1-dev \
	" \
	&& apt-get update \
	&& apt-get install $runtimeDeps -y -V --no-install-recommends \
	&& rm -r /var/lib/apt/lists/* \
	
	## build deps
	&& buildDeps=" \
		libpcre++-dev \
	" \
	&& apt-get update \
	&& apt-get install $buildDeps -y -V --no-install-recommends \
	&& rm -r /var/lib/apt/lists/* \
	
	## download, validate, extract
	&& wget -O httpd.tar.gz "$HTTPD_DOWNLOAD_URL" --no-check-certificate \
	&& echo "$HTTPD_SHA1 *httpd.tar.gz" | sha1sum -c - \
	&& mkdir "$HTTPD_SOURCE" \
	&& tar -xf httpd.tar.gz -C "$HTTPD_SOURCE" --strip-components=1 \
	
	## configure, make, install
	&& cd "$HTTPD_SOURCE" \
	&& ./configure \
		--prefix="$HTTPD_HOME" \
		--enable-mods-shared=reallyall \
	&& make -j "$(nproc)" \
	&& make install \

	## clean up
	&& cd "$HTTPD_HOME" \
	&& rm httpd.tar.gz \
	&& rm -r src man manual \
	&& apt-get purge $buildDeps -y -V -o APT::AutoRemove::RecommendsImportant=false --auto-remove


# php
## see http://php.net/manual/en/install.unix.apache2.php
## see http://linuxfromscratch.org/blfs/view/svn/general/php.html
ENV PHP_VERSION "7.1.1"
ENV PHP_DOWNLOAD_URL "https://secure.php.net/get/php-7.1.1.tar.gz/from/this/mirror"
ENV PHP_SHA256 "c136279d539c3c2c25176bf149c14913670e79bb27ee6b73e1cd69003985a70d"
ENV PHP_HOME "/usr/local/php"
ENV PHP_SOURCE "$PHP_HOME/src"
WORKDIR $PHP_HOME
RUN set -ex \
	
	## build deps
	### zlib1g-dev >> with-zlib >> Uncaught Error: Call to undefined function gzinflate() in /var/www/wp-includes/class-requests.php:947
	&& buildDeps=" \
		libxml2-dev \		
		zlib1g-dev \
	" \
	&& apt-get update \
	&& apt-get install $buildDeps -y -V --no-install-recommends \
	&& rm -rf /var/lib/apt/lists/* \

	## download, validate, extract
	&& wget -O php.tar.gz "$PHP_DOWNLOAD_URL" --no-check-certificate \
	&& echo "$PHP_SHA256 *php.tar.gz" | sha256sum -c - \
	&& mkdir "$PHP_SOURCE" \
	&& tar -xf php.tar.gz -C "$PHP_SOURCE" --strip-components=1 \
	
	## configure, make, install
	&& cd "$PHP_SOURCE" \
	&& ./configure \
		--prefix="$PHP_HOME" \
		--disable-cgi \
		--enable-mbstring \
		--enable-zip \
		--with-apxs2="$HTTPD_HOME/bin/apxs" \
		--with-config-file-path="$PHP_HOME/etc" \
		--with-config-file-scan-dir="$PHP_HOME/etc/conf.d" \
                ### see http://php.net/manual/en/mysqlnd.overview.php
		### see http://php.net/manual/en/mysqlinfo.api.choosing.php
		--with-mysqli=mysqlnd \
		--with-zlib \
	&& make -j "$(nproc)" \
	&& make install \
	
	## clean up
	&& cd "$PHP_HOME" \
	&& rm php.tar.gz \
	&& rm -r "$PHP_SOURCE" \
	&& apt-get purge $buildDeps -y -V -o APT::AutoRemove::RecommendsImportant=false --auto-remove \

	## change DocumentRoot, User, Group
	&& sed -i 's_DocumentRoot "/usr/local/httpd/htdocs"_DocumentRoot "/var/www"_' "$HTTPD_HOME/conf/httpd.conf" \
	&& sed -i 's_User daemon_User www-data_' "$HTTPD_HOME/conf/httpd.conf" \
	&& sed -i 's_Group daemon_Group www-data_' "$HTTPD_HOME/conf/httpd.conf" \
	&& echo 'Include conf/extra/php.conf' | tee -a "$HTTPD_HOME/conf/httpd.conf"
COPY php.conf "$HTTPD_HOME/conf/extra/"

# wordpress
ENV WORDPRESS_VERSION "4.7.2"
ENV WORDPRESS_DOWNLOAD_URL "https://wordpress.org/wordpress-$WORDPRESS_VERSION.tar.gz"
ENV WORDPRESS_SHA1 "7b687f1af589c337124e6247229af209ec1d52c3"
ENV WORDPRESS_HOME "/var/www"
WORKDIR "$WORDPRESS_HOME"
RUN set -ex \
	&& wget -O wordpress.tar.gz "$WORDPRESS_DOWNLOAD_URL" --no-check-certificate \
	&& echo "$WORDPRESS_SHA1 *wordpress.tar.gz" | sha1sum -c - \
	&& tar -xf wordpress.tar.gz --strip-components=1 \
	&& rm wordpress.tar.gz \
	&& chown -R www-data:www-data "$WORDPRESS_HOME"


# MariaDB
RUN set -ex \
	&& apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install mariadb-server -y -V --no-install-recommends \
	&& rm -r /var/lib/apt/lists/*


# phpMyAdmin
ENV PHPMYADMIN_VERSION 4.6.6
ENV PHPMYADMIN_DOWNLOAD_URL "https://files.phpmyadmin.net/phpMyAdmin/$PHPMYADMIN_VERSION/phpMyAdmin-$PHPMYADMIN_VERSION-all-languages.tar.gz"
ENV PHPMYADMIN_SHA256 "54086600558613b31c4daddf4ae58fbc1c252a2b8e3e6fae12f851f78677d72e"
ENV PHPMYADMIN_HOME "/usr/local/phpmyadmin"
WORKDIR $PHPMYADMIN_HOME
RUN set -ex \
	&& wget -O phpmyadmin.tar.gz "$PHPMYADMIN_DOWNLOAD_URL" --no-check-certificate \
	&& echo "$PHPMYADMIN_SHA256 *phpmyadmin.tar.gz" | sha256sum -c - \
	&& tar -xf phpmyadmin.tar.gz -C "$PHPMYADMIN_HOME" --strip-components=1 \
	&& rm phpmyadmin.tar.gz 
COPY config.inc.php "$PHPMYADMIN_HOME"
COPY vhost-phpmyadmin.conf "$HTTPD_HOME/conf/extra/"
RUN set -ex \
	&& chown -R www-data:www-data "$PHPMYADMIN_HOME"


# redis
ENV REDIS_VERSION 3.2.7


# clean up
RUN set -ex \
	&& apt-get purge $tools -y -V --auto-remove


# 
EXPOSE 80

COPY docker-entry.sh /docker-entry.sh
RUN set -ex \
	&& chmod +x /docker-entry.sh
ENTRYPOINT ["/docker-entry.sh"]

