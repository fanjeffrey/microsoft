#
# Dockerfile for Django
#
FROM ubuntu:16.04
MAINTAINER Azure App Service Container Images <appsvc-images@microsoft.com>


#
ENV DOCKER_BUILD_HOME "/dockerbuild"
WORKDIR $DOCKER_BUILD_HOME
RUN set -ex \
	&& apt-get update \
        && apt-get install -y -V --no-install-recommends wget \
        && rm -r /var/lib/apt/lists/*

# nginx
ENV NGINX_LOG_DIR "/home/LogFiles/nginx"
RUN set -ex \
	&& apt-get update \
	&& apt-get install -y -V --no-install-recommends nginx \
	&& rm -r /var/lib/apt/lists/*


# postgresql
ENV POSTGRESQL_DATA_DIR "/home/data/postgresql"
ENV POSTGRESQL_LOG_DIR "/home/LogFiles/postgresql"
RUN set -ex \
	&& apt-get update \
	&& apt-get install -y -V --no-install-recommends postgresql \
	&& rm -r /var/lib/apt/lists/*


# python
RUN set -ex \
	&& apt-get update \
	&& apt-get install -y -V --no-install-recommends python3 \
	&& rm -r /var/lib/apt/lists/*


# pgadmin
ENV PGADMIN_HOME "/home/pgadmin"


# django
RUN set -ex \
	&& wget https://bootstrap.pypa.io/get-pip.py --no-check-certificate \
	&& python3 get-pip.py \
	&& pip install django


# post-install
RUN set -ex \
	&& ln -s /usr/bin/python3 /usr/bin/python \
	##
	&& rm -rf /var/log/nginx \
	&& ln -s $NGINX_LOG_DIR /var/log/nginx \
	##
	&& rm -rf /var/log/postgresql \
	&& ln -s $POSTGRESQL_LOG_DIR /var/log/postgresql \
	##
	&& ln -s $PGADMIN_HOME /var/www/pgadmin


EXPOSE 80
