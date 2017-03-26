#!/bin/bash

set_var_if_null(){
	local varname="$1"
	if [ ! "${!varname:-}" ]; then
		export "$varname"="$2"
	fi
}

setup_httpd_log_dir(){
	chown -R www-data:www-data $HTTPD_LOG_DIR
}

setup_mariadb_data_dir(){
	cp -R /var/lib/mysql/. $MARIADB_DATA_DIR
	rm -rf /var/lib/mysql
	ln -s $MARIADB_DATA_DIR /var/lib/mysql
	chown -R mysql:mysql $MARIADB_DATA_DIR
}

setup_mariadb_log_dir(){
	chown -R mysql:mysql $MARIADB_LOG_DIR
}

start_mariadb(){
	service mysql start
	rm -f /tmp/mysql.sock
	ln -s /var/run/mysqld/mysqld.sock /tmp/mysql.sock
}

setup_phpmyadmin(){
	cd $PHPMYADMIN_HOME
	mv $PHPMYADMIN_SOURCE/phpmyadmin.tar.gz $PHPMYADMIN_HOME/
	tar -xf phpmyadmin.tar.gz -C $PHPMYADMIN_HOME --strip-components=1
	# create config.inc.php
	mv $PHPMYADMIN_SOURCE/phpmyadmin-config.inc.php $PHPMYADMIN_HOME/config.inc.php
	
	rm $PHPMYADMIN_HOME/phpmyadmin.tar.gz
	rm -rf $PHPMYADMIN_SOURCE
}

setup_wordpress(){
	cd $WORDPRESS_HOME
	mv $WORDPRESS_SOURCE/wordpress.tar.gz $WORDPRESS_HOME/
	tar -xf wordpress.tar.gz -C $WORDPRESS_HOME/ --strip-components=1
	# create wp-config.php
	mv $WORDPRESS_SOURCE/wp-config.php.microsoft $WORDPRESS_HOME/wp-config.php

	rm $WORDPRESS_HOME/wordpress.tar.gz
	rm -rf $WORDPRESS_SOURCEi

	chown -R www-data:www-data $WORDPRESS_HOME 
}

update_wp_config(){
	# update wp-config.php with the vars
        sed -i "s/connectstr_dbhost = '';/connectstr_dbhost = '$WORDPRESS_DB_HOST';/" "$WORDPRESS_HOME/wp-config.php"
        sed -i "s/connectstr_dbname = '';/connectstr_dbname = '$WORDPRESS_DB_NAME';/" "$WORDPRESS_HOME/wp-config.php"
        sed -i "s/connectstr_dbusername = '';/connectstr_dbusername = '$WORDPRESS_DB_USERNAME';/" "$WORDPRESS_HOME/wp-config.php"
        sed -i "s/connectstr_dbpassword = '';/connectstr_dbpassword = '$WORDPRESS_DB_PASSWORD';/" "$WORDPRESS_HOME/wp-config.php"
        sed -i "s/table_prefix  = 'wp_';/table_prefix  = '$WORDPRESS_DB_PREFIX';/" "$WORDPRESS_HOME/wp-config.php"
}

set -ex 

test ! -d "$WORDPRESS_HOME" && echo "INFO: $WORDPRESS_HOME not found. creating ..." && mkdir -p "$WORDPRESS_HOME"
test ! -d "$PHPMYADMIN_HOME" && echo "INFO: $PHPMYADMIN_HOME not found. creating ..." && mkdir -p "$PHPMYADMIN_HOME"
test ! -d "$HTTPD_LOG_DIR" && echo "INFO: $HTTPD_LOG_DIR not found. creating ..." && mkdir -p "$HTTPD_LOG_DIR"
test ! -d "$MARIADB_DATA_DIR" && echo "INFO: $MARIADB_DATA_DIR not found. creating ..." && mkdir -p "$MARIADB_DATA_DIR"
test ! -d "$MARIADB_LOG_DIR" && echo "INFO: $MARIADB_LOG_DIR not found. creating ..." && mkdir -p "$MARIADB_LOG_DIR"

setup_httpd_log_dir

# That wp-config.php doesn't exist means WordPress is not installed/configured yet.
if [ ! -e "$WORDPRESS_HOME/wp-config.php" ]; then
	apachectl start

	echo "INFO: $WORDPRESS_HOME/wp-config.php not found."
	echo "Installing WordPress for the first time ..."
	
	set_var_if_null "WORDPRESS_DB_HOST" "localhost"
        set_var_if_null "WORDPRESS_DB_NAME" "wordpress"
        set_var_if_null "WORDPRESS_DB_USERNAME" "wordpress"
        set_var_if_null "WORDPRESS_DB_PASSWORD" "MS173m_QN"
        set_var_if_null "WORDPRESS_DB_PREFIX" "wp_"
	if [ "${WORDPRESS_DB_HOST,,}" = "localhost" ]; then
                export WORDPRESS_DB_HOST="localhost"
        fi
	
	# If the local MariaDB is used.
	if [ "$WORDPRESS_DB_HOST" = "localhost" -o "$WORDPRESS_DB_HOST" = "127.0.0.1" ]; then
		echo "Local MariaDB chosen."
		if [ ! -d "$MARIADB_DATA_DIR/mysql" ]; then
			echo "INFO: $MARIADB_DATA_DIR not in use."
			echo "Setting up MariaDB data dir ..."
			setup_mariadb_data_dir
			echo "Setting up MariaDB log dir ..."
			setup_mariadb_log_dir
			echo "Starting local MariaDB ..."
			start_mariadb
		
			echo "Creating user for phpMyAdmin ..."
			set_var_if_null 'PHPMYADMIN_USERNAME' 'phpmyadmin'
                        set_var_if_null 'PHPMYADMIN_PASSWORD' 'MS173m_QN'
                        mysql -u root -e "GRANT ALL ON *.* TO \`$PHPMYADMIN_USERNAME\`@'localhost' IDENTIFIED BY '$PHPMYADMIN_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"
			
			echo "Creating database and user for WordPress ..."
	                mysql -u root -e "CREATE DATABASE \`$WORDPRESS_DB_NAME\` CHARACTER SET utf8 COLLATE utf8_general_ci; GRANT ALL ON \`$WORDPRESS_DB_NAME\`.* TO \`$WORDPRESS_DB_USERNAME\`@\`$WORDPRESS_DB_HOST\` IDENTIFIED BY '$WORDPRESS_DB_PASSWORD'; FLUSH PRIVILEGES;"
		else
			echo "INFO: $MARIADB_DATA_DIR already exists."
			echo "Starting local MariaDB ..."
                        start_mariadb
		fi


		if [ ! -e "$PHPMYADMIN_HOME/config.inc.php" ]; then
			echo "INFO: $PHPMYADMIN_HOME/config.inc.php not found."	
			echo "Installing phpMyAdmin ..."
			setup_phpmyadmin
		fi
	
		echo "Starting local Redis ..."
		redis-server --daemonize yes
	fi

	setup_wordpress
	update_wp_config

	apachectl stop
else
	echo "INFO: $WORDPRESS_HOME/wp-config.php already exists."
	
	if grep -q "connectstr_dbhost = 'localhost'" "$WORDPRESS_HOME/wp-config.php"; then
		echo "Starting local MariaDB ..."
		start_mariadb

		echo "Starting local Redis ..."
		redis-server --daemonize yes
	fi
fi

# start Apache HTTPD
echo "Starting apache httpd -D FOREGROUND ..."
apachectl start -D FOREGROUND
