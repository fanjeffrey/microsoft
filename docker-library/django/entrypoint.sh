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

test ! -d "$DJANGO_HOME" && echo "INFO: $DJANGO_HOME not found. creating ..." && mkdir -p "$DJANGO_HOME" && touch "$DJANGO_HOME/website.sock"


# Init postgresql
setup_postgresql(){
	test ! -d "$POSTGRESQL_DATA_DIR" && echo "INFO: $POSTGRESQL_DATA_DIR not found. creating ..." && mkdir -p "$POSTGRESQL_DATA_DIR"
	chown -R postgres:postgres $POSTGRESQL_DATA_DIR
	ln -s /var/lib/postgresql/9.5/main $POSTGRESQL_DATA_DIR
	test ! -d "$POSTGRESQL_LOG_DIR" && echo "INFO: $POSTGRESQL_LOG_DIR not found. creating ..." && mkdir -p "$POSTGRESQL_LOG_DIR"
	chown -R postgres:postgres $POSTGRESQL_LOG_DIR
	
	#set postgresql log
	sed -i "s|\#logging_collector|logging_collector|g" /etc/postgresql/9.5/main/postgresql.conf
	sed -i "s|\#logging_directory = \'pg\_log\'|logging_directory = \'var\/log\/postgresql\'|g" /etc/postgresql/9.5/main/postgresql.conf 
	sed -i "s|\#logging_filename|logging_filename|g" /etc/postgresql/9.5/main/postgresql.conf

	# start postgresql
	echo 'service postgresql start'
	service postgresql start & sleep 2s

	#Init postgres
	sed -i "s|dbdjango|$DJANGO_DB_NAME|g" $POSTGRESQL_SOURCE/init.sql	
	sed -i "s|dbuserdjango|$DJANGO_DB_USERNAME|g" $POSTGRESQL_SOURCE/init.sql
	sed -i "s|password|$DJANGO_DB_PASSWORD|g" $POSTGRESQL_SOURCE/init.sql
	su - postgres -c "psql -f $POSTGRESQL_SOURCE/init.sql"

}

#start phppgadmin
setup_phppgadmin(){		
	chown -R www-data:www-data /usr/share/phppgadmin
	#start php7.0-fpm
	service php7.0-fpm start
}

setup_nginx(){
	test ! -d "$NGINX_LOG_DIR" && echo "INFO: $NGINX_LOG_DIR not found. creating ..." && mkdir -p $NGINX_LOG_DIR
	chown -R www-data:www-data $NGINX_LOG_DIR
	test ! -d "$NGINX_DATA_DIR" && echo "INFO: $NGINX_DATA_DIR not found. creating ..." && mkdir -p $NGINX_DATA_DIR
	ln -s /etc/nginx $NGINX_DATA_DIR  
}

setup_postgresql
setup_phppgadmin
setup_nginx

# Start all the services
/usr/bin/supervisord -n
