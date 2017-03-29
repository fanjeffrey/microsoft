# Docker Image for Drupal with MySQL
## Overview
A Drupal (with MySQL) Docker image which is built with the Dockerfile under this repo can run on both [Azure Web App on Linux](https://docs.microsoft.com/en-us/azure/app-service-web/app-service-linux-intro) and your Docker engines's host.

## Components
This docker image contains the following components:

1. Drupal       **8.3.0-rc2**
2. PHP          **7.1.2**
3. Apache HTTPD **2.4.25**
4. MariaDB      **10.0+**
5. phpMyAdmin   **4.6.6**

Ubuntu 16.04 is used as the base image.

## Features
This docker image enables you to:

- run a Drupal site on **Azure Web App on Linux** or your Docker engine's host;
- connect your Drupal site to **Azure ClearDB** or the builtin MariaDB;

## Limitations
- Some unexpected issues may happen after you scale out your site to multiple instances, if you deploy a Drupal site on Azure with this docker image and use the MariaDB built in this docker image as the database.
- The phpMyAdmin built in this docker image is available only when you use the MariaDB built in this docker image as the database.

## Deploying / Running
You can specify the following environment variables when deploying the image to Azure or running it on your Docker engine's host.

Name | Default Value
---- | -------------
DRUPAL_DB_HOST | localhost
DRUPAL_DB_NAME | drupal
DRUPAL_DB_USERNAME | drupal
DRUPAL_DB_PASSWORD | MS173m_QN
PHPMYADMIN_USERNAME | phpmyadmin
PHPMYADMIN_PASSWORD | MS173m_QN

### Deploying to Azure
With the button below, you can easily deploy the image to Azure.

[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://azuredeploy.net/)

At the SETUP page, as shown below, you can change default values of these environment variables with yours.

![Drupal Deploy to Azure SETUP page](https://raw.githubusercontent.com/fanjeffrey/Images/master/Microsoft/docker-library/drupal_deploy_setup.PNG)

### Running on Docker engine's host
The **docker run** command below will get you a container that has a Drupal site connected to the builtin MariaDB, and has the builtin phpMyAdmin site enabled.
```
docker run -d -t -p 80:80 fanjeffrey/drupal-mysql:latest
```

The command below will connect the Drupal site within your Docker container to an Azure ClearDb.
```
docker run -d -t -p 80:80 \
    -e "DRUPAL_DB_HOST=<your_cleardb_host_name>" \
    -e "DRUPAL_DB_NAME=<your_db_name>" \
    -e "DRUPAL_DB_USERNAME=<your_db_username>" \
    -e "DRUPAL_DB_PASSWORD=<your_db_password>" \
    fanjeffrey/drupal-mysql:latest
```

When you use "localhost" as the database host, you can customize phpMyAdmin username and password.
```
docker run -d -t -p 80:80 \
    -e "DRUPAL_DB_HOST=localhost" \
    -e "DRUPAL_DB_NAME=<your_db_name>" \
    -e "DRUPAL_DB_USERNAME=<your_db_username>" \
    -e "DRUPAL_DB_PASSWORD=<your_db_password>" \
    -e "PHPMYADMIN_USERNAME=<your_phpmyadmin_username>" \
    -e "PHPMYADMIN_PASSWORD=<your_phpmyadmin_password>" \
    fanjeffrey/drupal-mysql:latest
```

## The Builtin MariaDB server
The builtin MariaDB server uses port 3306.

## The Builtin phpMyAdmin Site
If you're using the builtin MariaDB, you can access the builtin phpMyAdmin site with a URL like below:

**http://hostname[:port]/phpmyadmin**
