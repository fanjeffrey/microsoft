#!/bin/bash

set_var_if_null(){
	local varname="$1"
	if [ ! "${!varname:-}" ]; then
		export "$varname"="$2"
	fi
}

process_vars(){
	
	set_var_if_null 'DRUPAL_DB_HOST' '127.0.0.1'
	set_var_if_null 'DRUPAL_DB_NAME' 'drupal'
	set_var_if_null 'DRUPAL_DB_USERNAME' 'drupal'
	set_var_if_null 'DRUPAL_DB_PASSWORD' 'MS173m_QN'
	set_var_if_null 'DRUPAL_DB_PREFIX' 'd8_'

	# replace {'localhost',,} with '127.0.0.1'
	if [ "${DRUPAL_DB_HOST,,}" = "localhost" ]; then
		export DRUPAL_DB_HOST="127.0.0.1"
		echo "Replace localhost with 127.0.0.1 ... $DRUPAL_DB_HOST"
	fi
}

setup_httpd_log_dir(){	
	rm -rf $HTTPD_LOG_DIR

	if [ -d "$AZURE_SITE_ROOT" ]; then
		test ! -d $HTTPD_LOG_DIR_AZURE && mkdir -p $HTTPD_LOG_DIR_AZURE
		ln -s $HTTPD_LOG_DIR_AZURE $HTTPD_LOG_DIR
	else
		mkdir -p $HTTPD_LOG_DIR
	fi

	chown -R www-data:www-data $HTTPD_LOG_DIR/
}

setup_mariadb(){
	if [ -d "$AZURE_SITE_ROOT" ]; then
		test ! -d $MARIADB_DATA_DIR_AZURE && mkdir -p $MARIADB_DATA_DIR_AZURE
		cp -R $MARIADB_DATA_DIR/. $MARIADB_DATA_DIR_AZURE/
		rm -rf $MARIADB_DATA_DIR && ln -s $MARIADB_DATA_DIR_AZURE $MARIADB_DATA_DIR
		test ! -d $MARIADB_LOG_DIR_AZURE && mkdir -p $MARIADB_LOG_DIR_AZURE
		rm -rf $MARIADB_LOG_DIR	&& ln -s $MARIADB_LOG_DIR_AZURE $MARIADB_LOG_DIR
	fi
	chown -R mysql:mysql $MARIADB_DATA_DIR/
	chown -R mysql:mysql $MARIADB_LOG_DIR/
	service mysql start
}

setup_phpmyadmin(){
	set_var_if_null 'PHPMYADMIN_USERNAME' 'phpmyadmin'
	set_var_if_null 'PHPMYADMIN_PASSWORD' 'MS173m_QN'

	mysql -u root -e "create user '$PHPMYADMIN_USERNAME'@'127.0.0.1' identified by '$PHPMYADMIN_PASSWORD'; grant all on *.* to '$PHPMYADMIN_USERNAME'@'127.0.0.1' with grant option; flush privileges;"	

	if [ -d "$AZURE_SITE_ROOT" ]; then
		test ! -d $PHPMYADMIN_HOME_AZURE && mkdir -p $PHPMYADMIN_HOME_AZURE
		ln -s $PHPMYADMIN_HOME_AZURE $PHPMYADMIN_HOME
	else
		mkdir -p $PHPMYADMIN_HOME
	fi
	cp -R $PHPMYADMIN_SOURCE/. $PHPMYADMIN_HOME/
	rm -rf $PHPMYADMIN_SOURCE
	chown -R www-data:www-data $PHPMYADMIN_HOME/

	echo 'Include conf/httpd-phpmyadmin.conf' >> $HTTPD_CONF_FILE
}

setup_drupal(){
	if [ $DRUPAL_DB_HOST = "127.0.0.1" ]; then
		# create Drupal database and database user
		mysql -u root -e "create database $DRUPAL_DB_NAME; grant all on $DRUPAL_DB_NAME.* to '$DRUPAL_DB_USERNAME'@'127.0.0.1' identified by '$DRUPAL_DB_PASSWORD'; flush privileges;"
	fi

	# Because Azure Web App on Linux uses /home/site/wwwroot,
	# so if /home/site/wwwroot exists,
	# we think the container is running on Auzre.
	if [ -d "$AZURE_SITE_ROOT" ]; then
		ln -s $AZURE_SITE_ROOT $DRUPAL_HOME
	else
		mkdir -p $DRUPAL_HOME
	fi

	echo "copying drupal source files to $DRUPAL_HOME ..."
	cp -R $DRUPAL_SOURCE/. $DRUPAL_HOME/ && rm -rf $DRUPAL_SOURCE
	echo "chown -R www-data:www-data $DRUPAL_HOME/ ..."
	chown -R www-data:www-data $DRUPAL_HOME/	

	echo 'Include conf/httpd-drupal.conf' >> $HTTPD_CONF_FILE
}

# That sites/default/settings.php doesn't exist means Drupal is not installed/configured yet.
if [ ! -f "$DRUPAL_HOME/sites/default/settings.php" ]; then
	echo "$DRUPAL_HOME/sites/default/settings.php not found. installing drupal ..."
	process_vars
	setup_httpd_log_dir
	apachectl start

	# If the local MariaDB is used.
	if [ $DRUPAL_DB_HOST = "127.0.0.1" ]; then
		echo "using $DRUPAL_DB_HOST as database host ..."
		setup_mariadb
	fi

	setup_drupal

	apachectl stop

	# If the local MariaDB is used,
	# setup phpMyAdmin, 
	if [ $DRUPAL_DB_HOST = "127.0.0.1" ]; then
		setup_phpmyadmin
	fi
else
	if grep "'host' => '127.0.0.1" "$DRUPAL_HOME/sites/default/settings.php"; then
		echo "start mysql on rebooting ..." >> /dockerbuild/log_debug
		service mysql start
	fi
fi

# start Apache HTTPD
echo "starting httpd -DFOREGROUND ..."
httpd -DFOREGROUND
