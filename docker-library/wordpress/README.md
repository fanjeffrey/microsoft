# WordPress Docker Image
## Overview
This repo contains a Dockerfile and essential files that are used to build a WordPress Docker image which can run on both [Azure Web App on Linux](https://docs.microsoft.com/en-us/azure/app-service-web/app-service-linux-intro) and your Docker engines's host.

## Application Stack in this Image
This docker image currently contains the following application stack:

1. WordPress    4.7.2
2. PHP          7.1.1
3. Apache HTTPD 2.4.25
4. MariaDB      10.0+
5. Redis        3.2.8

and provides native phpmyadmin to help manage native MariaDB.

6. phpmyadmin   4.6.6

## Features
This docker image enables you to:

- run a WordPress site on *Azure Web App on Linux* or your Docker engine's host;
- connect your WordPress site to *Azure ClearDB* or the MariaDB built in the docker image;
- leverage *Azure Redis Cache* or the Redis cache build in the docker image;

## Limitations
- Some unexpected issues may happen after you scale out your site to multiple instances, if you deploy a WordPress site on Azure with this image and choose the MariaDB built in this image as the database.
- The Redis cache built in this image is available only when you choose the MariaDB built in this image as the database.
- The phpMyAdmin build in this image is available only when you choose the MariaDB built in this image as the database.

## Fast deploying a WordPress site on Azure

[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://azuredeploy.net/)

## Configurations in this image

Name | Default Value
---- | -------------
WORDPRESS_DB_HOST | 127.0.0.1
WORDPRESS_DB_NAME | wordpress
WORDPRESS_DB_USERNAME | wordpress
WORDPRESS_DB_PASSWORD | MS173m_QN
WORDPRESS_DB_TABLE_NAME_PREFIX | wp_
PHPMYADMIN_USERNAME | phpmyadmin
PHPMYADMIN_PASSWORD | MS173m_QN

You can change these default values on the *SETUP* page when deploying with the *Deploy to Azure* button above.

![WordPress Deploy to Azure SETUP page](https://raw.githubusercontent.com/fanjeffrey/Images/master/Microsoft/docker-library/wordpress_deploy_setup.PNG)

Or use the command below if you run this image on your Docker engine's host.
```
docker run -d -t -p 80:80 \
    -e "WORDPRESS_DB_HOST=<your_db_host>" \
    -e "WORDPRESS_DB_NAME=<your_db_name>" \
    -e "WORDPRESS_DB_USERNAME=<your_db_username>" \
    -e "WORDPRESS_DB_PASSWORD=<your_db_password>" \
    -e "WORDPRESS_DB_TABLE_NAME_PREFIX=<your_table_name_prefix>" \
    fanjeffrey/wordpress:4.7.2
```