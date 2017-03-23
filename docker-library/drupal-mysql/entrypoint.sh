#!/bin/bash

set_var_if_null(){
	local varname="$1"
	if [ ! "${!varname:-}" ]; then
		export "$varname"="$2"
	fi
}

process_vars(){
	set_var_if_null 'DRUPAL_DB_HOST' 'localhost'
	set_var_if_null 'DRUPAL_DB_NAME' 'drupal'
	set_var_if_null 'DRUPAL_DB_USERNAME' 'drupal'
	set_var_if_null 'DRUPAL_DB_PASSWORD' 'MS173m_QN'

	if [ "${DRUPAL_DB_HOST,,}" = "localhost" ]; then
		export DRUPAL_DB_HOST="localhost"
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
}

start_mariadb(){
	service mysql start > /dev/null
	rm -f /tmp/mysql.sock
	ln -s /var/run/mysqld/mysqld.sock /tmp/mysql.sock
}

setup_phpmyadmin(){
	set_var_if_null 'PHPMYADMIN_USERNAME' 'phpmyadmin'
	set_var_if_null 'PHPMYADMIN_PASSWORD' 'MS173m_QN'

	echo "Creating user for phpMyAdmin ..."
	mysql -u root -e "GRANT ALL ON *.* TO \`$PHPMYADMIN_USERNAME\`@'localhost' IDENTIFIED BY '$PHPMYADMIN_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"

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
	# Because Azure Web App on Linux uses /home/site/wwwroot,
	# so if /home/site/wwwroot exists,
	# we think the container is running on Auzre.
	if [ -d "$AZURE_SITE_ROOT" ]; then
		ln -s $AZURE_SITE_ROOT $DRUPAL_HOME
	else
		mkdir -p $DRUPAL_HOME
	fi

	echo "Copying drupal source files to $DRUPAL_HOME ..."
	cp -R $DRUPAL_SOURCE/. $DRUPAL_HOME/ && rm -rf $DRUPAL_SOURCE

	echo "chown -R www-data:www-data $DRUPAL_HOME/ ..."
	chown -R www-data:www-data $DRUPAL_HOME/	

	echo 'Include conf/httpd-drupal.conf' >> $HTTPD_CONF_FILE
}

set -e

test ! -d "$AZURE_SITE_ROOT" && echo "INFO: $AZURE_SITE_ROOT not found."

# That sites/default/settings.php doesn't exist means Drupal is not installed/configured yet.
if [ ! -e "$DRUPAL_HOME/sites/default/settings.php" ]; then
	echo "INFO: $DRUPAL_HOME/sites/default/settings.php not found."
	echo "Installing drupal for the first time ..."

	process_vars
	setup_httpd_log_dir
	apachectl start > /dev/null 2>&1

	# If the local MariaDB is used.
	if [ "$DRUPAL_DB_HOST" = "localhost" -o "$DRUPAL_DB_HOST" = "127.0.0.1" ]; then
                echo "Local MariaDB chosen. setting it up ..."	
		setup_mariadb
		echo "Starting local MariaDB ..."
		start_mariadb
		echo "Enabling phpMyAdmin ..."
		setup_phpmyadmin
		echo "Creating database and user for Drupal ..."
                mysql -u root -e "CREATE DATABASE \`$DRUPAL_DB_NAME\` CHARACTER SET utf8 COLLATE utf8_general_ci; GRANT ALL ON \`$DRUPAL_DB_NAME\`.* TO \`$DRUPAL_DB_USERNAME\`@\`$DRUPAL_DB_HOST\` IDENTIFIED BY '$DRUPAL_DB_PASSWORD'; FLUSH PRIVILEGES;"
	fi

	setup_drupal
	apachectl stop > /dev/null 2>&1
else
	if [ grep "'host' => 'localhost'" "$DRUPAL_HOME/sites/default/settings.php" -o grep "'host' => '127.0.0.1'" "$DRUPAL_HOME/sites/default/settings.php" ]; then
		echo "Starting local MariaDB on rebooting ..." >> /dockerbuild/log_debug
		start_mariadb
	fi
fi

# start Apache HTTPD
echo "Starting httpd -DFOREGROUND ..."
httpd -DFOREGROUND > /dev/null 2>&1 
