#!/bin/bash
log(){
	while read line ; do
		echo "`date '+%D %T'` $line"
	done
}

set -e
logfile=/home/LogFiles/entrypoint.log
test ! -f $logfile && mkdir -p /home/LogFiles && touch $logfile
exec > >(log | tee -ai $logfile)
exec 2>&1

set_var_if_null(){
	local varname="$1"
	if [ ! "${!varname:-}" ]; then
		export "$varname"="$2"
	fi
}


setup_mariadb_data_dir(){
	test ! -d "$MARIADB_DATA_DIR" && echo "INFO: $MARIADB_DATA_DIR not found. creating ..." && mkdir -p "$MARIADB_DATA_DIR"

	# check if 'mysql' database exists
	if [ ! -d "$MARIADB_DATA_DIR/mysql" ]; then
		echo "INFO: 'mysql' database doesn't exist under $MARIADB_DATA_DIR. So we think $MARIADB_DATA_DIR is empty."
		echo "Copying all data files from the original folder /var/lib/mysql to $MARIADB_DATA_DIR ..."
		cp -R /var/lib/mysql/. $MARIADB_DATA_DIR
	else
		echo "INFO: 'mysql' database already exists under $MARIADB_DATA_DIR."
	fi

	rm -rf /var/lib/mysql
	ln -s $MARIADB_DATA_DIR /var/lib/mysql

	chown -R mysql:mysql $MARIADB_DATA_DIR
}

start_mariadb(){
	service mysql start
	rm -f /tmp/mysql.sock
	ln -s /var/run/mysqld/mysqld.sock /tmp/mysql.sock
}

setup_phpmyadmin(){
	test ! -d "$PHPMYADMIN_HOME" && echo "INFO: $PHPMYADMIN_HOME not found. creating ..." && mkdir -p "$PHPMYADMIN_HOME"

	cd $PHPMYADMIN_HOME
	mv $PHPMYADMIN_SOURCE/phpmyadmin.tar.gz $PHPMYADMIN_HOME/
	tar -xf phpmyadmin.tar.gz -C $PHPMYADMIN_HOME --strip-components=1
	# create config.inc.php
	mv $PHPMYADMIN_SOURCE/phpmyadmin-config.inc.php $PHPMYADMIN_HOME/config.inc.php
	rm $PHPMYADMIN_HOME/phpmyadmin.tar.gz
	rm -rf $PHPMYADMIN_SOURCE

	chown -R www-data:www-data $PHPMYADMIN_HOME
}

update_settings(){
	set_var_if_null "DATABASE_HOST" "localhost"
	set_var_if_null "DATABASE_NAME" "mysql"
	set_var_if_null "DATABASE_USERNAME" "mysql"
	set_var_if_null "DATABASE_PASSWORD" "MS173m_QN"
	if [ "${DATABASE_HOST,,}" = "localhost" -o "$DATABASE_HOST" = "127.0.0.1" ]; then
		export DATABASE_HOST="localhost"
	fi
}

set -e

echo "INFO: DATABASE_HOST:" $DATABASE_HOST
echo "INFO: DATABASE_NAME:" $DATABASE_NAME
echo "INFO: DATABASE_USERNAME:" $DATABASE_USERNAME
echo "INFO: PHPMYADMIN_USERNAME:" $PHPMYADMIN_USERNAME

test ! -d "$HTTPD_LOG_DIR" && echo "INFO: $HTTPD_LOG_DIR not found. creating ..." && mkdir -p "$HTTPD_LOG_DIR"
chown -R www-data:www-data $HTTPD_LOG_DIR
apachectl start

update_settings

# That settings.php doesn't exist means Drupal is not installed/configured yet.
if [ ! -d "$HOME" ]; then
	echo "INFO: path $HOME not found."
	echo "Installing app path for the first time ..."
	
	test ! -d "$HOME" && echo "INFO: $HOME not found. creating ..." && mkdir -p "$HOME"
	chown -R www-data:www-data $HOME
else
	echo "INFO: path $HOME already exists."
fi

# If local MariaDB is used 
if [ "${DATABASE_HOST,,}" = "localhost" ]; then
	echo "Setting up MariaDB data dir ..."
	setup_mariadb_data_dir
	echo "Setting up MariaDB log dir ..."
	test ! -d "$MARIADB_LOG_DIR" && echo "INFO: $MARIADB_LOG_DIR not found. creating ..." && mkdir -p "$MARIADB_LOG_DIR"
	chown -R mysql:mysql $MARIADB_LOG_DIR
	echo "Starting local MariaDB ..."
	start_mariadb

	echo "Granting user for phpMyAdmin ..."
	set_var_if_null 'PHPMYADMIN_USERNAME' 'phpmyadmin'
	set_var_if_null 'PHPMYADMIN_PASSWORD' 'MS173m_QN'
	mysql -u root -e "GRANT ALL ON *.* TO \`$PHPMYADMIN_USERNAME\`@'localhost' IDENTIFIED BY '$PHPMYADMIN_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"

	echo "Creating database for Drupal if not exists ..."
	mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`$DATABASE_NAME\` CHARACTER SET utf8 COLLATE utf8_general_ci;"
	echo "Granting user for Drupal ..."
	mysql -u root -e "GRANT ALL ON \`$DATABASE_NAME\`.* TO \`$DATABASE_USERNAME\`@\`$DATABASE_HOST\` IDENTIFIED BY '$DATABASE_PASSWORD'; FLUSH PRIVILEGES;"

	if [ ! -e "$PHPMYADMIN_HOME/config.inc.php" ]; then
		echo "INFO: $PHPMYADMIN_HOME/config.inc.php not found."
		echo "Installing phpMyAdmin ..."
		setup_phpmyadmin
		else
		echo "INFO: $PHPMYADMIN_HOME/config.inc.php already exists."
	fi

	echo "Loading phpMyAdmin conf ..."
	if ! grep -q "^Include conf/httpd-phpmyadmin.conf" $HTTPD_CONF_FILE; then
		echo 'Include conf/httpd-phpmyadmin.conf' >> $HTTPD_CONF_FILE
	fi

else
	echo "INFO: local MariaDB is NOT used as DATABASE_HOST in settings.php."
fi

apachectl stop
# delay 2 seconds to try to avoid "httpd (pid XX) already running"
sleep 2s

echo "Starting Apache httpd -D FOREGROUND ..."
apachectl start -D FOREGROUND