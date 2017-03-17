# Magento2 CE Docker Image
## Overview
A Magento2 CE Docker image which is built with the Dockerfile under this repo can run on both [Azure Web App on Linux](https://docs.microsoft.com/en-us/azure/app-service-web/app-service-linux-intro) and your Docker engines's host.

## Components
This docker image currently contains the following components:

1. Magento2 CE  **2.1.5**
2. PHP          **7.1.2**
3. Apache HTTPD **2.4.25**
4. MariaDB      **10.0+**
5. Redis        **3.2.8**
6. phpMyAdmin   **4.6.6**
7. cron

## Features
This docker image enables you to:

- run a Magento site on **Azure Web App on Linux** or your Docker engine's host;
- connect your Magento site to **Azure ClearDB** or the builtin MariaDB;
- leverage **Azure Redis Cache** or the builtin Redis cache server;

## Limitations
- If you deploy a Magento site on Azure with this docker image and use the MariaDB built in this docker image as the database, then scaling out your site to multiple instances is not recommended.
- The Redis cache built in this docker image is available only when you use the MariaDB built in this docker image as the database.
- The phpMyAdmin built in this docker image is available only when you use the MariaDB built in this docker image as the database.

## Deploying / Running
You can specify the following environment variables when deploying the image to Azure or running it on your Docker engine's host.

Name | Default Value
---- | -------------
MAGENTO_ADMIN_USER | admin
MAGENTO_ADMIN_PASSWORD | MS173m_QN
MAGENTO_ADMIN_FIRSTNAME | firstname
MAGENTO_ADMIN_LASTNAME | lastname
MAGENTO_ADMIN_EMAIL | admin@example.com
MAGENTO_BACKEND_FRONTNAME | admin_1qn
MAGENTO_DB_HOST | 127.0.0.1
MAGENTO_DB_NAME | magento
MAGENTO_DB_USERNAME | magento
MAGENTO_DB_PASSWORD | MS173m_QN
MAGENTO_DB_PREFIX | m2_
PHPMYADMIN_USERNAME | phpmyadmin
PHPMYADMIN_PASSWORD | MS173m_QN

### Deploying to Azure
With the button below, you can easily deploy the image to Azure.

[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://azuredeploy.net/)

At the SETUP page, as shown below, you can change default values of these environment variables with yours.

![Magento Deploy to Azure SETUP page](https://raw.githubusercontent.com/fanjeffrey/Images/master/Microsoft/docker-library/magento_deploy_setup.PNG)

### Running on Docker engine's host
The **docker run** command below will get you a container that has a Magento2 CE site connected to the builtin MariaDB, and has the builtin Redis cache server started, and has the builtin phpMyAdmin site enabled, and has the builtin cron started.
```
docker run -d -t -p 80:80 fanjeffrey/magento:ce-2.1.5
```

The command below will connect the Magento2 CE site within your Docker container to an Azure ClearDb.
```
docker run -d -t -p 80:80 \
    -e "MAGENTO_DB_HOST=<your_cleardb_host_name>" \
    -e "MAGENTO_DB_NAME=<your_db_name>" \
    -e "MAGENTO_DB_USERNAME=<your_db_username>" \
    -e "MAGENTO_DB_PASSWORD=<your_db_password>" \
    -e "MAGENTO_DB_TABLE_NAME_PREFIX=<your_table_name_prefix>" \
    fanjeffrey/magento:ce-2.1.5
```

When you use 127.0.0.1 as the database host, you can customize phpMyAdmin username and password.
```
docker run -d -t -p 80:80 \
    -e "MAGENTO_DB_HOST=127.0.0.1" \
    -e "MAGENTO_DB_NAME=<your_db_name>" \
    -e "MAGENTO_DB_USERNAME=<your_db_username>" \
    -e "MAGENTO_DB_PASSWORD=<your_db_password>" \
    -e "MAGENTO_DB_TABLE_NAME_PREFIX=<your_table_name_prefix>" \
    -e "PHPMYADMIN_USERNAME=<your_phpmyadmin_username>" \
    -e "PHPMYADMIN_PASSWORD=<your_phpmyadmin_password>" \
    fanjeffrey/magento:ce-2.1.5
```

## The Builtin MariaDB server
The builtin MariaDB server uses port 3306.

## The Builtin phpMyAdmin Site
If you're using the builtin MariaDB, you can access the builtin phpMyAdmin site with a URL like below:

**http://hostname[port]/phpmyadmin**

## The Builtin Redis Cache Server
The builtin Redis cache server uses port 6379.
