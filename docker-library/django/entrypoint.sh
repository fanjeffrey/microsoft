#!/bin/bash

POSTGRESQL_DATA_DIR="/home/data/postgresql"
POSTGRESQL_LOG_DIR="/home/LogFiles/postgresql"


set_var_if_null(){
	local varname="$1"
	if [ ! "${!varname:-}" ]; then
		export "$varname"="$2"
	fi
}


SETTING_PATH=`find /home/django/ -name settings.py`

# Check is there already exist any django project
if [ -z "$SETTING_PATH" ] ; then

    # Create new django project
    mkdir -p /home/django/website/
    django-admin startproject website /home/django/website

    SETTING_PATH=`find /home/django/ -name settings.py`
else

    # Install requirements
    if [ -f /home/django/website/requirements.txt ]; then
        pip install -r /home/django/website/requirements.txt
    fi

fi


# Init postgresql
setup_postgresql(){
	test ! -d "$POSTGRESQL_LOG_DIR" && echo "INFO: $POSTGRESQL_LOG_DIR not found. creating ..." && mkdir -p "$POSTGRESQL_LOG_DIR"
	chown -R postgres:postgres $POSTGRESQL_LOG_DIR

	# start postgresql
	service postgresql start & sleep 2s

	#Init postgres
	su - postgres -c 'psql -f /home/django/init.sql'
}

setup_phppgadmin(){
	echo 'begin phppgadmin';
	#start php7.0-fpm
	service php7.0-fpm start
	
	chown -R www-data:www-data /usr/share/phppgadmin
}

setup_nginx(){
	test ! -d "$NGINX_LOG_DIR" && echo "INFO: $NGINX_LOG_DIR not found. creating ..." && mkdir -p $NGINX_LOG_DIR
	chown -R www-data:www-data $NGINX_LOG_DIR
	chmod -R 766 $NGINX_LOG_DIR
	echo $NGINX_LOG_DIR
	
	nginx -t
	service nginx start
}

setup_postgresql
setup_phppgadmin
setup_nginx
