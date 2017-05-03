# Docker Image for Django
## Overview
This Django Docker image is built for [Azure Web App on Linux](https://docs.microsoft.com/en-us/azure/app-service-web/app-service-linux-intro).

## Components
This Docker image contains the following components:

1. Django
2. Python
3. Nginx
4. uWSGI

Ubuntu 16.04 is used as the base image.

## Features
This docker image enables you to:

- run a Django Web framework on **Azure Web App on Linux**;
- And this is our stack
    ```
    the web client <-> Nginx <-> the socket <-> uWSGI <-> Python
    ```
## Limitations
- Support only remote database server

### Deploying to Azure
With the button below, you can easily deploy the image to Azure.

[![Deploy to Azure](http://azuredeploy.net/deploybutton.png)](https://azuredeploy.net/)


## Django with uWSGI and Nginx
1. Nginx handle static file in folder /home/site/wwwroot:images, css, js, static;
2. uWSGI configuration file: /home/uwsgi/uwsgi.ini.

## How to change database connection to a remote server
1. Get publish profile on Azure portal, FTP Login Parameters:publishUrl, userName, userPWD;
![Django publish profile for FTP](https://raw.githubusercontent.com/Song2017/Microsoft/devDjango/docker-library/django/django_publish_profile.PNG)

2. Use any FTP tool(e.g. WinSCP) you prefer to connect to the site;
3. Edit /home/site/wwwroot/sites/myproject/settings.py to your database configure;
    ```
    # change database SQLite to PostgreSQL
    DATABASES = {
    'default': {
        #'ENGINE': 'django.db.backends.sqlite3',
        #'NAME': 'mydatabase',
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'mydatabase',
        'USER': 'mydatabaseuser',
        'PASSWORD': 'mypassword',
        'HOST': '127.0.0.1',
        'PORT': '5432',
        }
    }
    ```
4. For more detail, please see: https://docs.djangoproject.com/en/1.11/ref/settings/#std:setting-DATABASES.

## How to upload your django project
1. Get publish profile on Azure portal, FTP Login Parameters:publishUrl, userName, userPWD;
![Django publish profile for FTP](https://raw.githubusercontent.com/Song2017/Microsoft/devDjango/docker-library/django/django_publish_profile.PNG)

2. Use any FTP tool(e.g. WinSCP) you prefer to connect to the site;
3. Upload the file of the django project that you want to upload to the folder /home/site/wwwroot;
![Django default project for FTP](https://raw.githubusercontent.com/Song2017/Microsoft/devDjango/docker-library/django/django_default_project.PNG)

4. To create your Django project, please see: https://docs.djangoproject.com/en/1.11/intro/tutorial01/.

## Log Files Location
1. Docker Log:        /home/LogFiles/docker/docker_xx_err.log
2. Entrypoint.sh Log: /home/LogFiles/entrypoint.log
2. Nginx Log:         /home/LogFiles/nginx/error.log


