#!/bin/bash

set_var_if_null(){
	local varname="$1"
	if [ ! "${!varname:-}" ]; then
		export "$varname"="$2"
	fi
}

test ! -d $MAGENTO_HOME_AZURE && echo "INFO: Magento site home on Azure: $MAGENTO_HOME_AZURE not found!"

# That wp-config.php doesn't exist means Magento is not installed/configured yet.
if [ ! -f "$MAGENTO_HOME/wp-config.php" ]; then
	# create wp-config.php
	mv $MAGENTO_SOURCE/wp-config.php.microsoft $MAGENTO_SOURCE/wp-config.php
	# set Magento vars if they're not declared or unset
        set_var_if_null "MAGENTO_DB_HOST" "127.0.0.1"
        set_var_if_null "MAGENTO_DB_NAME" "magento"
        set_var_if_null "MAGENTO_DB_USERNAME" "magento"
        set_var_if_null "MAGENTO_DB_PASSWORD" "MS173m_QN"
        set_var_if_null "MAGENTO_DB_TABLE_NAME_PREFIX" "wp_"
        # replace {'localhost',,} with '127.0.0.1'
        if [ "${MAGENTO_DB_HOST,,}" = "localhost" ]; then
                export MAGENTO_DB_HOST="127.0.0.1"
                echo "Replace localhost with 127.0.0.1 ... $MAGENTO_DB_HOST"
        fi
       	# update wp-config.php with the vars above 
        sed -i "s/connectstr_dbhost = '';/connectstr_dbhost = '$MAGENTO_DB_HOST';/" "$MAGENTO_SOURCE/wp-config.php"
        sed -i "s/connectstr_dbname = '';/connectstr_dbname = '$MAGENTO_DB_NAME';/" "$MAGENTO_SOURCE/wp-config.php"
        sed -i "s/connectstr_dbusername = '';/connectstr_dbusername = '$MAGENTO_DB_USERNAME';/" "$MAGENTO_SOURCE/wp-config.php"
        sed -i "s/connectstr_dbpassword = '';/connectstr_dbpassword = '$MAGENTO_DB_PASSWORD';/" "$MAGENTO_SOURCE/wp-config.php"
        sed -i "s/table_prefix  = 'wp_';/table_prefix  = '$MAGENTO_DB_TABLE_NAME_PREFIX';/" "$MAGENTO_SOURCE/wp-config.php"

	# Because Azure Web App on Linux uses /home/site/wwwroot,
	# so if /home/site/wwwroot doesn't exist, 
	# we think the container is not running on Auzre.
	if [ ! -d "$MAGENTO_HOME_AZURE" ]; then
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
        cp -R $MAGENTO_SOURCE/* $MAGENTO_HOME/ && chown -R www-data:www-data $MAGENTO_HOME/ && rm -rf $MAGENTO_SOURCE
        cp -R $PHPMYADMIN_SOURCE/* $PHPMYADMIN_HOME/ && chown -R www-data:www-data $PHPMYADMIN_HOME/ && rm -rf $PHPMYADMIN_SOURCE
        cp -R $MARIADB_DATA_DIR_TEMP/* $MARIADB_DATA_DIR/ && chown -R mysql:mysql $MARIADB_DATA_DIR/ && rm -rf $MARIADB_DATA_DIR_TEMP
	chown -R www-data:www-data $HTTPD_LOG_DIR/
	chown -R mysql:mysql $MARIADB_LOG_DIR/

	# check if use native MariaDB
	# if yes, we allow users to use native phpMyAdmin and native Redis server
	if [ $MAGENTO_DB_HOST = "127.0.0.1" ]; then
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
else
	if grep "connectstr_dbhost = '127.0.0.1'" "$MAGENTO_HOME/wp-config.php"; then
		service mysql start
		redis-server --daemonize yes
	fi
fi

# start Apache HTTPD
httpd -DFOREGROUND
