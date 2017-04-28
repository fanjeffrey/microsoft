#!/bin/bash

set_var_if_null(){
	local varname="$1"
	if [ ! "${!varname:-}" ]; then
		export "$varname"="$2"
	fi
}

# Set password
set_var_if_null "DJANGO_HOST" "40.74.243.74"
set_var_if_null "DJANGO_DB_NAME" "django"
set_var_if_null "DJANGO_DB_USERNAME" "django"
set_var_if_null "DJANGO_DB_PASSWORD" "password"
set_var_if_null "DJANGO_ADMIN_PASSWORD" "password"

echo "INFO: DJANGO_HOST:" $DJANGO_HOST
echo "INFO: DJANGO_DB_NAME:" $DJANGO_DB_NAME
echo "INFO: DJANGO_DB_USERNAME:" $DJANGO_DB_USERNAME 

startproject_django(){
	echo 'begin startproject_django'
	
	test ! -d "$POSTGRESQL_LOG_DIR" && echo "INFO: $POSTGRESQL_LOG_DIR not found. creating ..." && mkdir -p "$POSTGRESQL_LOG_DIR"
	test ! -d "$DJANGO_HOME" && echo "INFO: $DJANGO_HOME not found. creating ..." && mkdir -p "$DJANGO_HOME"
	SETTING_PATH=`find /home/site/wwwroot -name settings.py`

	# Check is there already exist any django project
	if [ -z "$SETTING_PATH" ] ; then
	    # Create new django project
	    mkdir -p /home/site/wwwroot/
	    django-admin startproject website /home/site/wwwroot

	    SETTING_PATH=`find /home/site/wwwroot/ -name settings.py`
	else
	    # Install requirements
	    if [ -f /home/site/wwwroot/requirements.txt ]; then
		pip install -r /home/site/wwwroot/requirements.txt
	    fi
	fi
	sed -i "s|ALLOWED_HOSTS = \[\]|ALLOWED_HOSTS = \[\'$DJANGO_HOST\'\]|g" $SETTING_PATH
}

# Init postgresql
setup_postgresql(){
	test ! -d "$POSTGRESQL_DATA_DIR" && echo "INFO: $POSTGRESQL_DATA_DIR not found. creating ..." && mkdir -p "$POSTGRESQL_DATA_DIR"
	chown -R postgres:postgres $POSTGRESQL_DATA_DIR
	test ! -d "$POSTGRESQL_LOG_DIR" && echo "INFO: $POSTGRESQL_LOG_DIR not found. creating ..." && mkdir -p "$POSTGRESQL_LOG_DIR"
	chown -R postgres:postgres $POSTGRESQL_LOG_DIR

	# start postgresql
	echo 'service postgresql start'
	service postgresql start & sleep 2s

	#Init postgres
	sed -i "s|dbdjango|$DJANGO_DB_NAME|g" $POSTGRESQL_SOURCE/init.sql	
	sed -i "s|dbuserdjango|$DJANGO_DB_USERNAME|g" $POSTGRESQL_SOURCE/init.sql
	sed -i "s|password|$DJANGO_DB_PASSWORD|g" $POSTGRESQL_SOURCE/init.sql
	su - postgres -c "psql -f $POSTGRESQL_SOURCE/init.sql"
}

setup_phppgadmin(){		
	chown -R www-data:www-data /usr/share/phppgadmin
	#start php7.0-fpm
	service php7.0-fpm start
}

setup_model_example(){

	# Create model_example app
	mkdir -p /home/site/wwwroot/model_example/
	django-admin startapp model_example /home/site/wwwroot/model_example/
	mv /home/site/wwwroot/django/admin.py /home/site/wwwroot/model_example/
	mv /home/site/wwwroot/django/models.py /home/site/wwwroot/model_example/

	# Add model_example app
	sed -i "s|'django.contrib.staticfiles'|'django.contrib.staticfiles',\n    'model_example'|g" $SETTING_PATH

	# Add model_example app
	sed -i "s|ALLOWED_HOSTS = \[\]|ALLOWED_HOSTS = \[\'$DJANGO_HOST\'\]|g" $SETTING_PATH

	# Modify database setting to Postgres
	sed -i "s|django.db.backends.sqlite3|django.db.backends.postgresql_psycopg2|g" $SETTING_PATH
	sed -i "s|os.path.join(BASE_DIR, 'db.sqlite3')|'django',\n        'HOST': '127.0.0.1',\n        'USER': 'django',\n        'PASSWORD': '$DJANGO_DB_PASSWORD'|g" $SETTING_PATH

	# Modify static files setting
	sed -i "s|STATIC_URL = '/static/'|STATIC_URL = '/static/'\n\nSTATIC_ROOT = os.path.join(BASE_DIR, 'static')|g" $SETTING_PATH

	# Django setting
	python3 /home/site/wwwroot/manage.py makemigrations
	python3 /home/site/wwwroot/manage.py migrate
	echo yes | python3 /home/site/wwwroot/manage.py collectstatic
	echo "from django.contrib.auth.models import User; User.objects.create_superuser('admin', 'admin@example.com', '$DJANGO_ADMIN_PASSWORD')" | python3 /home/site/wwwroot/manage.py shell	
}

setup_nginx(){
	test ! -d "$NGINX_LOG_DIR" && echo "INFO: $NGINX_LOG_DIR not found. creating ..." && mkdir -p $NGINX_LOG_DIR
	chown -R www-data:www-data $NGINX_LOG_DIR
	chmod -R 766 $NGINX_LOG_DIR
}
startproject_django
setup_postgresql
setup_phppgadmin
#setup_model_example
setup_nginx

# Start all the services
/usr/bin/supervisord -n
