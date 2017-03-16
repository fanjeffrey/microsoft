#!/bin/bash

set_var_if_null(){
	local varname="$1"
	if [ ! "${!varname:-}" ]; then
		export "$varname"="$2"
	fi
}

process_vars(){
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

startup_local_servers_if(){
	# Check if the local MariaDB is used.
	# If yes, we allow users to use cron and local Redis.
	if [ $MAGENTO_DB_HOST = "127.0.0.1" ]; then
		echo "using $MAGENTO_DB_HOST as database host ..."
		# MariaDB
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
		# Redis
		redis-server --daemonize yes
		# cron
		service cron start
	fi
}

setup_phpmyadmin_if(){
	if [ $MAGENTO_DB_HOST = "127.0.0.1" ]; then
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
	fi
}

setup_magento(){
	if [ $MAGENTO_DB_HOST = "127.0.0.1" ]; then
		# create Magento database and database user
		mysql -u root -e "create database $MAGENTO_DB_NAME; grant all on $MAGENTO_DB_NAME.* to '$MAGENTO_DB_USERNAME'@'127.0.0.1' identified by '$MAGENTO_DB_PASSWORD'; flush privileges;"
	fi

	# Because Azure Web App on Linux uses /home/site/wwwroot,
	# so if /home/site/wwwroot exists,
	# we think the container is running on Auzre.
	if [ -d "$AZURE_SITE_ROOT" ]; then
		ln -s $AZURE_SITE_ROOT $MAGENTO_HOME
	else
		mkdir -p $MAGENTO_HOME
	fi

	echo "copying Magento source files to $MAGENTO_HOME ..."
	cp -R $MAGENTO_SOURCE/. $MAGENTO_HOME/ && rm -rf $MAGENTO_SOURCE

	# see http://devdocs.magento.com/guides/v2.1/install-gde/prereq/file-system-perms.html
	chown -R www-data:www-data $MAGENTO_HOME/
	find $MAGENTO_HOME/app/etc $MAGENTO_HOME/pub/media $MAGENTO_HOME/pub/static $MAGENTO_HOME/var $MAGENTO_HOME/vendor -type d -exec chmod g+ws {} \;
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

# That app/etc/env.php doesn't exist means Magento is not installed/configured yet.
if [ ! -f "$MAGENTO_HOME/app/etc/env.php" ]; then
	echo "$MAGENTO_HOME/app/etc/env.app not found. installing magento ..."
	process_vars
	setup_httpd_log_dir
	startup_local_servers_if
	setup_phpmyadmin_if
	setup_magento
else
	if grep "'host' => '127.0.0.1'" "$MAGENTO_HOME/app/etc/env.php"; then
		service mysql start
		redis-server --daemonize yes
		service cron start
	fi
fi

# start Apache HTTPD
httpd -DFOREGROUND

