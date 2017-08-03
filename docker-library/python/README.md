# Docker Image for Python
## Overview
This Python Docker image is built for [Azure Web App on Linux](https://docs.microsoft.com/en-us/azure/app-service-web/app-service-linux-intro).

## Components
This Docker image contains the following components:

1. Python **3.6.1**
2. Nginx **1.10.0**
3. uWSGI **2.0.15**
4. Psycopg2 **2.7.1**
5. Pip **9.0.1**
6. SSH

Ubuntu 16.04 is used as the base image.

The stack of components:
```
Browser <-> nginx <-> /tmp/uwsgi.sock <-> uWSGI <-> Your Python app <-> Psycopg2 <-> remote PostgreSQL database
```

## Features
This docker image enables you to:
- run your Python app on **Azure Web App on Linux**;
- connect you Python app to a remote PostgreSQL database;
- ssh to the docker container via the URL like below;
```
        https://<your sitename>.scm.azurewebsites.net/webssh/host
```

## Predefined Nginx Locations
This docker image defines the following nginx locations for your static files.
- /images
- /css
- /js
- /static

For more information, see [nginx default site conf](./3.6.1/nginx-default-site).

## Startup Log
The startup log file (**entrypoint.log**) is placed under the folder /home/LogFiles.

## How to Deploy Django Project
- Access ssh host
- Install Django and Upload your Django Project
    ```
    pip install Django==1.11.3
    ```
- Configuring [uWSGI .ini file](https://docs.djangoproject.com/en/1.11/howto/deployment/wsgi/uwsgi/#configuring-and-starting-the-uwsgi-server-for-django): /home/uwsgi/uwsgi.ini
- Run app server uWSGI 
    ```
    uwsgi --uid www-data --gid www-data –ini=/home/uwsgi/uwsgi.ini
    ```

## Change Log
- **Version 3.6.1** 
  1. Remove azuredeploy.json.