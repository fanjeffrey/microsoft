# Docker Image for Drupal with MySQL
## Overview
This Drupal (with MySQL) Docker image is built for [Azure Web App on Linux](https://docs.microsoft.com/en-us/azure/app-service-web/app-service-linux-intro).

## Components
This docker image contains the following components:

1. PHP          **7.1.2**
2. Apache HTTPD **2.4.25**
3. MariaDB      **10.0+**
4. phpMyAdmin   **4.6.6**

Ubuntu 16.04 is used as the base image.

## Features
This docker image enables you to:

- run a Apache Environment on **Azure Web App on Linux**;
- connect your App site to **Azure ClearDB** or the builtin MariaDB;

## Limitations
- The phpMyAdmin built in this docker image is available only when you use the MariaDB built in this docker image as the database.

## Deploying / Running
You can specify the following environment variables when deploying the image to Azure or running it on your Docker engine's host.

Name | Default Value
---- | -------------
DATABASE_HOST | localhost
DATABASE_NAME | drupal
DATABASE_USERNAME | drupal
DATABASE_PASSWORD | MS173m_QN
PHPMYADMIN_USERNAME | phpmyadmin
PHPMYADMIN_PASSWORD | MS173m_QN

### Deploying to Azure
With the button below, you can easily deploy the image to Azure.

[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://azuredeploy.net/)

## The Builtin MariaDB server
The builtin MariaDB server uses port 3306.

## The Builtin phpMyAdmin Site
If you're using the builtin MariaDB, you can access the builtin phpMyAdmin site with a URL like below:

**http://hostname[:port]/phpmyadmin**

## How to install APP
1. Use any FTP tool you prefer to connect to the site (you can get the credentials on Azure portal);
2. Upload the tar file of the APP that you want to install to the folder /home/site/wwwroot/;
3. Extract the contents into a sub-folder under /home/site/wwwroot;
