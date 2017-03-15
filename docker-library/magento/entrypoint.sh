#!/bin/bash

set_var_if_null(){
	local varname="$1"
	if [ ! "${!varname:-}" ]; then
		export "$varname"="$2"
	fi
}

# That app/etc/env.php doesn't exist means Magento is not installed/configured yet.
if [ ! -f "$MAGENTO_HOME/app/etc/env.php" ]; then
	echo "env.app not found. installing magento ..."

	# see http://devdocs.magento.com/guides/v2.1/install-gde/install/cli/install-cli-install.html
	set_var_if_null 'MAGENTO_ADMIN_USER' 'admin'
	set_var_if_null 'MAGENTO_ADMIN_PASSWORD' 'MS173m_QN'
	set_var_if_null 'MAGENTO_ADMIN_FIRSTNAME' 'firstname'
	set_var_if_null 'MAGENTO_ADMIN_LASTNAME' 'lastname'
	set_var_if_null 'MAGENTO_ADMIN_EMAIL' 'admin@example.com'
	set_var_if_null 'MAGENTO_BACKEND_FRONTNAME' 'admin_1qn'

	set_var_if_null 'MAGENTO_DB_HOST' '127.0.0.1'
	set_var_if_null 'MAGENTO_DB_NAME' 'magento'
	set_var_if_null 'MAGENTO_DB_USERNAME' 'magento'
	set_var_if_null 'MAGENTO_DB_PASSWORD' 'MS173m_QN'
	set_var_if_null 'MAGENTO_DB_PREFIX' 'm2_'
	
	# replace {'localhost',,} with '127.0.0.1'
	if [ "${MAGENTO_DB_HOST,,}" = "localhost" ]; then
		export MAGENTO_DB_HOST="127.0.0.1"
		echo "Replace localhost with 127.0.0.1 ... $MAGENTO_DB_HOST"
	fi       	

	# Because Azure Web App on Linux uses /home/site/wwwroot,
	# so if /home/site/wwwroot doesn't exist, 
	# we think the container is not running on Auzre.
	if [ ! -d "$MAGENTO_HOME_AZURE" ]; then
		echo "INFO: $MAGENTO_HOME_AZURE not found!"
		rm -rf $MAGENTO_HOME && mkdir -p $MAGENTO_HOME
		rm -rf $PHPMYADMIN_HOME && mkdir -p $PHPMYADMIN_HOME
		rm -rf $MARIADB_DATA_DIR && mkdir -p $MARIADB_DATA_DIR
		rm -rf $HTTPD_LOG_DIR && mkdir -p $HTTPD_LOG_DIR
		rm -rf $MARIADB_LOG_DIR && mkdir -p $MARIADB_LOG_DIR
	else
		test ! -d $PHPMYADMIN_HOME_AZURE && mkdir -p $PHPMYADMIN_HOME_AZURE
		test ! -d $MARIADB_DATA_DIR_AZURE && mkdir -p $MARIADB_DATA_DIR_AZURE
		test ! -d $HTTPD_LOG_DIR_AZURE && mkdir -p $HTTPD_LOG_DIR_AZURE
		test ! -d $MARIADB_LOG_DIR_AZURE && mkdir -p $MARIADB_LOG_DIR_AZURE
	fi
	
	cp -R $PHPMYADMIN_SOURCE/. $PHPMYADMIN_HOME/ && chown -R www-data:www-data $PHPMYADMIN_HOME/ && rm -rf $PHPMYADMIN_SOURCE
	cp -R $MARIADB_DATA_DIR_TEMP/. $MARIADB_DATA_DIR/ && chown -R mysql:mysql $MARIADB_DATA_DIR/ && rm -rf $MARIADB_DATA_DIR_TEMP
	chown -R www-data:www-data $HTTPD_LOG_DIR/
	chown -R mysql:mysql $MARIADB_LOG_DIR/

	# check if use native MariaDB
	# if yes, we allow users to use native phpMyAdmin and native Redis server
	if [ $MAGENTO_DB_HOST = "127.0.0.1" ]; then
		echo "using $MAGENTO_DB_HOST as database host ..."
		# set vars for phpMyAdmin if not provided
		set_var_if_null 'PHPMYADMIN_USERNAME' 'phpmyadmin'
		set_var_if_null 'PHPMYADMIN_PASSWORD' 'MS173m_QN'
		# start native database 
		service mysql start
		# create database and databse user for Magento
		mysql -u root -e "create database $MAGENTO_DB_NAME; grant all on $MAGENTO_DB_NAME.* to '$MAGENTO_DB_USERNAME'@'127.0.0.1' identified by '$MAGENTO_DB_PASSWORD'; flush privileges;"
		# create database user for phpMyAdmin
		mysql -u root -e "create user '$PHPMYADMIN_USERNAME'@'127.0.0.1' identified by '$PHPMYADMIN_PASSWORD'; grant all on *.* to '$PHPMYADMIN_USERNAME'@'127.0.0.1' with grant option; flush privileges;"	
		# start native Redis server
		redis-server --daemonize yes
	fi

	echo "copying Magento source files to $MAGENTO_HOME ..."
	cp -R $MAGENTO_SOURCE/. $MAGENTO_HOME/ && rm -rf $MAGENTO_SOURCE

	# see http://devdocs.magento.com/guides/v2.0/install-gde/prereq/file-system-perms.html
	find $MAGENTO_HOME/app/etc $MAGENTO_HOME/pub/media $MAGENTO_HOME/pub/static $MAGENTO_HOME/var $MAGENTO_HOME/vendor -type d -exec chmod g+ws {} \;
	find $MAGENTO_HOME/app/etc $MAGENTO_HOME/pub/media $MAGENTO_HOME/pub/static $MAGENTO_HOME/var $MAGENTO_HOME/vendor -type f -exec chmod g+w {} \;
	chown -R www-data:www-data $MAGENTO_HOME/
	chmod ug+x $MAGENTO_SOURCE/bin/magento

	$MAGENTO_HOME/bin/magento setup:install \
		--admin-user=$MAGENTO_ADMIN_USER \
		--admin-password=$MAGENTO_ADMIN_PASSWORD \
		--admin-firstname=$MAGENTO_ADMIN_FIRSTNAME \
		--admin-lastname=$MAGENTO_ADMIN_LASTNAME \
		--admin-email=$MAGENTO_ADMIN_EMAIL \
		--admin-use-security-key=1 \
		--backend-frontname=$MAGENTO_BACKEND_FRONTNAME \
		--db-host=$MAGENTO_DB_HOST \
		--db-name=$MAGENTO_DB_NAME \
		--db-user=$MAGENTO_DB_USERNAME \
		--db-password=$MAGENTO_DB_PASSWORD \
		--db-prefix=$MAGENTO_DB_PREFIX \
		--use-rewrites=1 \
		--base-url=$MAGENTO_BASE_URL

	if [ -f $MAGENTO_HOME/app/etc/env.php ]; then
		echo "switching to PRODUCTION mode..."
		$MAGENTO_HOME/bin/magento deploy:mode:set production

		# see http://devdocs.magento.com/guides/v2.0/config-guide/prod/prod_file-sys-perms.html
		find $MAGENTO_HOME/app/code $MAGENTO_HOME/app/etc $MAGENTO_HOME/lib $MAGENTO_HOME/pub/static $MAGENTO_HOME/var/di $MAGENTO_HOME/var/generation $MAGENTO_HOME/var/view_preprocessed $MAGENTO_HOME/vendor \( -type d -or -type f \) -exec chmod g-w {} \; 
		chmod o-rwx app/etc/env.php
	fi


else
	if grep "'host' => '127.0.0.1'" "$MAGENTO_HOME/app/etc/env.php"; then
		service mysql start
		redis-server --daemonize yes
	fi
fi

# start Apache HTTPD
httpd -DFOREGROUND
