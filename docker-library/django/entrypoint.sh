#!/bin/bash

set_var_if_null(){
	local varname="$1"
	if [ ! "${!varname:-}" ]; then
		export "$varname"="$2"
	fi
}

# setup nginx log dir
test ! -d "$NGINX_LOG_DIR" && echo "INFO: $NGINX_LOG_DIR not found, creating ..." && mkdir -p "$NGINX_LOG_DIR"

# setup uWSGI ini dir
test ! -d "$UWSGI_INI_DIR" && echo "INFO: $UWSGI_INI_DIR not found, creating ..." && mkdir -p "$UWSGI_INI_DIR"

# setup django project home dir
test ! -d "$DJANGO_PROJECT_HOME" && echo "INFO: $DJANGO_PROJECT_HOME not found, creating ..." && mkdir -p $DJANGO_PROJECT_HOME
WSGI_PY_PATH=`find $DJANGO_PROJECT_HOME -name wsgi.py`
if [ "$WSGI_PY_PATH" ]; then
	echo "INFO: wsgi.py found at $WSGI_PY_PATH. So we think a project already exists under $DJANGO_PROJECT_HOME."
else
	# create a sample django project
	echo "INFO: creating sample django project 'myproject' under $DJANGO_PROJECT_HOME ..."
	django-admin startproject myproject "$DJANGO_PROJECT_HOME"
	echo "INFO: set ALLOWED_HOSTS = ['*'] in settings.py to eliminate DisallowedHost warning. "
	sed -i "s/ALLOWED_HOSTS = \[\]/ALLOWED_HOSTS = \['\*'\]/" "$DJANGO_PROJECT_HOME/myproject/settings.py"
	mv /tmp/uwsgi.ini "$UWSGI_INI_DIR/"
fi

chown -R www-data:www-data "$NGINX_LOG_DIR"
chown -R www-data:www-data "$UWSGI_INI_DIR"
chown -R www-data:www-data "$DJANGO_PROJECT_HOME"

echo "INFO: starting nginx ..."
nginx #-g "daemon off;"

# setup postgresql log dir
test ! -d "$POSTGRESQL_LOG_DIR" && echo "INFO: $POSTGRESQL_LOG_DIR not found, creating ..." && mkdir -p "$POSTGRESQL_LOG_DIR"
chown -R postgres:postgres "$POSTGRESQL_LOG_DIR"

# setup postgresql data dir
test ! -d "$POSTGRESQL_DATA_DIR" && echo "INFO: $POSTGRESQL_DATA_DIR not found, creating ..." && mkdir -p "$POSTGRESQL_DATA_DIR"

MAIN_FOLDER=`find $POSTGRESQL_DATA_DIR -name main`
if [ "$MAIN_FOLDER" ]; then
	echo "INFO: found 'main' folder under $POSTGRESQL_DATA_DIR."
else
	echo "INFO: the 'main' folder under $POSTGRESQL_DATA_DIR not found. So we think $POSTGRESQL_DATA_DIR is empty."
	echo "INFO: copying all files under /var/lib/postgresql to $POSTGRESQL_DATA_DIR ..."
	cp -R /var/lib/postgresql/. $POSTGRESQL_DATA_DIR
fi

rm -rf /var/lib/postgresql
ln -s $POSTGRESQL_DATA_DIR /var/lib/postgresql
chown -R postgres:postgres $POSTGRESQL_DATA_DIR

echo "INFO: starting postgresql ..."
service postgresql start

# setup phpPgAdmin user/password
set_var_if_null 'PHPPGADMIN_USERNAME' 'phppgadmin'
set_var_if_null 'PHPPGADMIN_PASSWORD' 'MS173m_QN'
echo "INFO: creating role '$PHPPGADMIN_USERNAME' for phpPgAdmin site ..."
su - postgres -c "psql -c \"create role $PHPPGADMIN_USERNAME superuser login encrypted password '$PHPPGADMIN_PASSWORD';\""

# setup phpPgAdmin
test ! -d "$PHPPGADMIN_HOME" && echo "INFO: $PHPPGADMIN_HOME not found. creating ..." && mkdir -p "$PHPPGADMIN_HOME"

if [ -e "$PHPPGADMIN_HOME/config.inc.php" ]; then
	echo "INFO: $PHPPGADMIN_HOME/config.inc.php already exists."
else
	echo "INFO: $PHPPGADMIN_HOME/config.inc.php not found."
	echo "INFO: copying all files under /usr/share/phppgadmin to $PHPPGADMIN_HOME ..."
	cp -R /usr/share/phppgadmin/. $PHPPGADMIN_HOME
	echo "INFO: copying all files under /usr/share/php/adodb to $PHPPGADMIN_HOME/libraries/adodb ..."
	rm -rf $PHPPGADMIN_HOME/libraries/adodb
	mkdir -p $PHPPGADMIN_HOME/libraries/adodb
	rm -f $PHPPGADMIN_HOME/libraries/js/jquery.js
	cp /usr/share/javascript/jquery/jquery.js $PHPPGADMIN_HOME/libraries/js/jquery.js
	cp -R /usr/share/php/adodb/. $PHPPGADMIN_HOME/libraries/adodb
	echo "INFO: copying config.inc.php to $PHPPGADMIN_HOME/conf ..."
	rm -f $PHPPGADMIN_HOME/conf/config.inc.php
	mv /etc/phppgadmin/config.inc.php $PHPPGADMIN_HOME/conf
fi

rm -rf /usr/share/phppgadmin
chown -R www-data:www-data $PHPPGADMIN_HOME

echo "INFO: start php7.0-fpm for phpPgAdmin site ..."
service php7.0-fpm start

#
echo "INFO: starting uwsgi ..."
uwsgi --uid www-data --gid www-data --ini=$UWSGI_INI_DIR/uwsgi.ini

