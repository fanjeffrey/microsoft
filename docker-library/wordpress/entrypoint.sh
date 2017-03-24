#!/bin/bash

set_var_if_null(){
	local varname="$1"
	if [ ! "${!varname:-}" ]; then
		export "$varname"="$2"
	fi
}

process_vars(){
	set_var_if_null "WORDPRESS_DB_HOST" "127.0.0.1"
    set_var_if_null "WORDPRESS_DB_NAME" "wordpress"
    set_var_if_null "WORDPRESS_DB_USERNAME" "wordpress"
    set_var_if_null "WORDPRESS_DB_PASSWORD" "MS173m_QN"
    set_var_if_null "WORDPRESS_DB_PREFIX" "wp_"

	if [ "${WORDPRESS_DB_HOST,,}" = "localhost" ]; then
		export WORDPRESS_DB_HOST="localhost"
	fi
}

setup_httpd_log_dir(){
	rm -rf $HTTPD_LOG_DIR
	if [ -d "$WORDPRESS_HOME_AZURE" ]; then
		test ! -d $HTTPD_LOG_DIR_AZURE && mkdir -p $HTTPD_LOG_DIR_AZURE
		ln -s $HTTPD_LOG_DIR_AZURE $HTTPD_LOG_DIR
	else
		mkdir -p $HTTPD_LOG_DIR
	fi
	chown -R www-data:www-data $HTTPD_LOG_DIR/
}

setup_mariadb(){
	if [ -d "$WORDPRESS_HOME_AZURE" ]; then
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

	if [ -d "$WORDPRESS_HOME_AZURE" ]; then
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

setup_wordpress(){
	# Because Azure Web App on Linux uses /home/site/wwwroot,
	# so if /home/site/wwwroot exists,
	# we think the container is running on Auzre.
	if [ -d "$WORDPRESS_HOME_AZURE" ]; then
		ln -s $WORDPRESS_HOME_AZURE $WORDPRESS_HOME
	else
		mkdir -p $WORDPRESS_HOME
	fi

	# create wp-config.php
	mv $WORDPRESS_SOURCE/wp-config.php.microsoft $WORDPRESS_SOURCE/wp-config.php
	# update wp-config.php with the vars
	sed -i "s/connectstr_dbhost = '';/connectstr_dbhost = '$WORDPRESS_DB_HOST';/" "$WORDPRESS_SOURCE/wp-config.php"
	sed -i "s/connectstr_dbname = '';/connectstr_dbname = '$WORDPRESS_DB_NAME';/" "$WORDPRESS_SOURCE/wp-config.php"
	sed -i "s/connectstr_dbusername = '';/connectstr_dbusername = '$WORDPRESS_DB_USERNAME';/" "$WORDPRESS_SOURCE/wp-config.php"
	sed -i "s/connectstr_dbpassword = '';/connectstr_dbpassword = '$WORDPRESS_DB_PASSWORD';/" "$WORDPRESS_SOURCE/wp-config.php"
	sed -i "s/table_prefix  = 'wp_';/table_prefix  = '$WORDPRESS_DB_PREFIX';/" "$WORDPRESS_SOURCE/wp-config.php"

	echo "Copying WordPress source files to $WORDPRESS_HOME ..."
	cp -R $WORDPRESS_SOURCE/. $WORDPRESS_HOME/ && rm -rf $WORDPRESS_SOURCE

	echo "chown -R www-data:www-data $WORDPRESS_HOME/ ..."
	chown -R www-data:www-data $WORDPRESS_HOME/

	echo 'Include conf/httpd-wordpress.conf' >> $HTTPD_CONF_FILE
}

set -e

test ! -d "$WORDPRESS_HOME_AZURE" && echo "INFO: $WORDPRESS_HOME_AZURE not found."

# That wp-config.php doesn't exist means WordPress is not installed/configured yet.
if [ ! -e "$WORDPRESS_HOME/wp-config.php" ]; then
	echo "INFO: $WORDPRESS_HOME/wp-config.php not found."
	echo "Installing WordPress for the first time ..."

	process_vars
	setup_httpd_log_dir
	apachectl start > /dev/null 2>&1

	# If the local MariaDB is used.
	if [ "$WORDPRESS_DB_HOST" = "localhost" -o "$WORDPRESS_DB_HOST" = "127.0.0.1" ]; then
        echo "Local MariaDB chosen. setting it up ..."
		setup_mariadb

		echo "Starting local MariaDB ..."
		start_mariadb

		echo "Enabling phpMyAdmin ..."
		setup_phpmyadmin

		echo "Creating database and user for WordPress ..."
        mysql -u root -e "CREATE DATABASE \`$WORDPRESS_DB_NAME\` CHARACTER SET utf8 COLLATE utf8_general_ci; GRANT ALL ON \`$WORDPRESS_DB_NAME\`.* TO \`$WORDPRESS_DB_USERNAME\`@\`$WORDPRESS_DB_HOST\` IDENTIFIED BY '$WORDPRESS_DB_PASSWORD'; FLUSH PRIVILEGES;"

		echo "Starting local Redis ..."
		redis-server --daemonize yes
	fi

	setup_wordpress
	apachectl stop > /dev/null 2>&1
else
	if grep -q "connectstr_dbhost = 'localhost'" "$WORDPRESS_HOME/wp-config.php"; then
		echo "Starting local MariaDB ..." >> /dockerbuild/log_debug
		start_mariadb

		echo "Starting local Redis ..." >> /dockerbuild/log_debug
		redis-server --daemonize yes
	fi
fi

# start Apache HTTPD
echo "Starting httpd -DFOREGROUND ..."
httpd -DFOREGROUND > /dev/null 2>&1
