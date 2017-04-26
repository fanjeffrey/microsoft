#!/bin/bash

set_var_if_null(){
	local varname="$1"
	if [ ! "${!varname:-}" ]; then
		export "$varname"="$2"
	fi
}

setup_httpd_log_dir(){
	test ! -d "$HTTPD_LOG_DIR" && echo "INFO: $HTTPD_LOG_DIR not found. creating ..." && mkdir -p "$HTTPD_LOG_DIR"

	chown -R www-data:www-data $HTTPD_LOG_DIR
}
# mariadb
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

setup_mariadb_log_dir(){
	test ! -d "$MARIADB_LOG_DIR" && echo "INFO: $MARIADB_LOG_DIR not found. creating ..." && mkdir -p "$MARIADB_LOG_DIR"

	chown -R mysql:mysql $MARIADB_LOG_DIR
}

start_mariadb(){
	service mysql start
	rm -f /tmp/mysql.sock
	ln -s /var/run/mysqld/mysqld.sock /tmp/mysql.sock
}

# phpmyadmin
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

load_phpmyadmin(){
        if ! grep -q "^Include conf/httpd-phpmyadmin.conf" $HTTPD_CONF_FILE; then
                echo 'Include conf/httpd-phpmyadmin.conf' >> $HTTPD_CONF_FILE
        fi
}

setup_localenv(){
	# If local MariaDB is used in settings.php
	if [ "${MAGENTO_DB_HOST,,}" = "127.0.0.1" ]; then
	#if grep "'host' => '127.0.0.1'" "$MAGENTO_HOME/app/etc/env.php"; then
		echo "INFO: local MariaDB is used as DB_HOST in settings.php."
		echo "Setting up MariaDB data dir ..."
		setup_mariadb_data_dir
		echo "Setting up MariaDB log dir ..."
		setup_mariadb_log_dir
		echo "Starting local MariaDB ..."
		start_mariadb
		echo "Granting user for phpMyAdmin ..."
		set_var_if_null 'PHPMYADMIN_USERNAME' 'phpmyadmin'
		set_var_if_null 'PHPMYADMIN_PASSWORD' 'MS173m_QN'
		mysql -u root -e "GRANT ALL ON *.* TO \`$PHPMYADMIN_USERNAME\`@'localhost' IDENTIFIED BY '$PHPMYADMIN_PASSWORD' WITH GRANT OPTION; FLUSH PRIVILEGES;"

		echo "Creating database for MAGENTO if not exists ..."
		mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`$MAGENTO_DB_NAME\` CHARACTER SET utf8 COLLATE utf8_general_ci;"
		echo "Granting user for MAGENTO ..."
		mysql -u root -e "GRANT ALL ON \`$MAGENTO_DB_NAME\`.* TO \`$MAGENTO_DB_USERNAME\`@\`$MAGENTO_DB_HOST\` IDENTIFIED BY '$MAGENTO_DB_PASSWORD'; FLUSH PRIVILEGES;"

		# start redis and cron.
		redis-server --daemonize yes
		service cron start

		# setup phpMyAdmin.
		if [ ! -e "$PHPMYADMIN_HOME/config.inc.php" ]; then
			echo "INFO: $PHPMYADMIN_HOME/config.inc.php not found."
			echo "Installing phpMyAdmin ..."
			setup_phpmyadmin
		else
			echo "INFO: $PHPMYADMIN_HOME/config.inc.php already exists."
		fi

		echo "Loading phpMyAdmin conf ..."
		load_phpmyadmin
	else
		echo "INFO: local MariaDB is NOT used as DB_HOST in settings.php."
	fi
}


#magento
setup_magento(){
	test ! -d "$MAGENTO_HOME" && echo "INFO: $MAGENTO_HOME not found. creating ..." && mkdir -p "$MAGENTO_HOME"

	cd $MAGENTO_HOME
	echo "copying Magento source files to $MAGENTO_HOME ..."
	cp -R $MAGENTO_SOURCE/. $MAGENTO_HOME/
	rm -rf $MAGENTO_SOURCE
}

update_defaultvars(){
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
}

update_settings(){

	# see http://devdocs.magento.com/guides/v2.1/install-gde/prereq/file-system-perms.html
	echo "chown -R www-data:www-data $MAGENTO_HOME/ ..."
	chown -R www-data:www-data $MAGENTO_HOME

	echo "chmod g+ws for the dirs: app/etc, public/media, public/static, var, and vendor ..."
	find $MAGENTO_HOME/app/etc $MAGENTO_HOME/pub/media $MAGENTO_HOME/pub/static $MAGENTO_HOME/var $MAGENTO_HOME/vendor -type d -exec chmod g+ws {} \;
	echo "chmod g+w for the files: app/etc, public/media, public/static, var, and vendor ..."
	find $MAGENTO_HOME/app/etc $MAGENTO_HOME/pub/media $MAGENTO_HOME/pub/static $MAGENTO_HOME/var $MAGENTO_HOME/vendor -type f -exec chmod g+w {} \;
	chmod ug+x $MAGENTO_HOME/bin/magento

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
                # magento cron jobs
                # see http://devdocs.magento.com/guides/v2.1/config-guide/cli/config-cli-subcommands-cron.html
                $MAGENTO_HOME/bin/magento cron:run && $MAGENTO_HOME/bin/magento cron:run
                # change the user/group again after switching
                chown -R www-data:www-data $MAGENTO_HOME/
        fi
}

load_magento(){
	if ! grep -q "^Include conf/httpd-magento.conf" $HTTPD_CONF_FILE; then
		echo 'Include conf/httpd-magento.conf' >> $HTTPD_CONF_FILE
	fi
}


set -e

echo "INFO: MAGENTO_DB_HOST:" $MAGENTO_DB_HOST
echo "INFO: MAGENTO_DB_NAME:" $MAGENTO_DB_NAME
echo "INFO: MAGENTO_DB_USERNAME:" $MAGENTO_DB_USERNAME
echo "INFO: PHPMYADMIN_USERNAME:" $PHPMYADMIN_USERNAME

setup_httpd_log_dir
apachectl start

# That app/etc/env.php doesn't exist means Magento is not installed/configured yet.
if [ ! -f "$MAGENTO_HOME/app/etc/env.php" ]; then
	echo "$MAGENTO_HOME/app/etc/env.app not found. installing magento ..."
	setup_magento
	update_defaultvars
	setup_localenv
	update_settings
else
	echo  "$MAGENTO_HOME/app/etc/env.app already exists."
	setup_localenv
fi

apachectl stop
# delay 2 seconds to try to avoid "httpd (pid XX) already running"
sleep 2s

echo "Loading MAGENTO conf ..."
load_magento

echo "Starting Apache httpd -D FOREGROUND ..."
apachectl start -D FOREGROUND
