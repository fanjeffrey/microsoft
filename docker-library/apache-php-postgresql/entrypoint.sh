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

setup_postgresql_data_dir(){
	test ! -d "$POSTGRESQL_DATA_DIR" && echo "INFO: $POSTGRESQL_DATA_DIR not found. creating ..." && mkdir -p "$POSTGRESQL_DATA_DIR"

	# check if 'postgresql' database exists
	if [ ! -d "$POSTGRESQL_DATA_DIR/9.5" ]; then
		echo "INFO: 'postgresql' database doesn't exist under $POSTGRESQL_DATA_DIR. So we think $POSTGRESQL_DATA_DIR is empty."
		echo "Copying all data files from the original folder /var/lib/postgresql to $POSTGRESQL_DATA_DIR ..."
		cp -nR /var/lib/postgresql/. $POSTGRESQL_DATA_DIR
	else
		echo "INFO: 'postgresql' database already exists under $POSTGRESQL_DATA_DIR."
	fi

	rm -rf /var/lib/postgresql
	ln -s $POSTGRESQL_DATA_DIR /var/lib/postgresql

	chown -R postgres:postgres $POSTGRESQL_DATA_DIR
}

setup_postgresql_log_dir(){
	test ! -d "$POSTGRESQL_LOG_DIR" && echo "INFO: $POSTGRESQL_LOG_DIR not found. creating ..." && mkdir -p "$POSTGRESQL_LOG_DIR"
	# check if postgresql log exists
	if [ ! -e "$POSTGRESQL_LOG_DIR/postgresql-9.5-main.log" ]; then
		echo "INFO: 'postgresql' log doesn't exist under $POSTGRESQL_LOG_DIR. So we think $POSTGRESQL_LOG_DIR is empty."
		echo "Copying all data files from the original folder /var/log/postgresql to $POSTGRESQL_LOG_DIR ..."
		cp -nR /var/log/postgresql/. $POSTGRESQL_DATA_DIR
	else
		echo "INFO: 'postgresql' log already exists under $POSTGRESQL_LOG_DIR."
	fi

	rm -rf /var/log/postgresql
	ln -s $POSTGRESQL_LOG_DIR /var/log/postgresql

	chown -R postgres:postgres $POSTGRESQL_LOG_DIR
}

start_postgresql(){
	#setup client authentication
	sed -i "s/\:\:1\/128                 md5/\:\:1\/128                 trust/g" /etc/postgresql/9.5/main/pg_hba.conf

	service postgresql start
}

setup_phppgadmin(){
	test ! -d "$PHPPGADMIN_HOME" && echo "INFO: $PHPPGADMIN_HOME not found. creating ..." && mkdir -p "$PHPPGADMIN_HOME"

	cd $PHPPGADMIN_HOME
	mv $PHPPGADMIN_SOURCE/phppgadmin.tar.gz $PHPPGADMIN_HOME/
	tar -xf phppgadmin.tar.gz -C $PHPPGADMIN_HOME --strip-components=1
	# setup config.inc.php
	sed -i "s/= ''/= 'localhost'/g" $PHPPGADMIN_HOME/conf/config.inc.php
	sed -i "s/extra_login_security'\] = true/extra_login_security'\] = false/g" $PHPPGADMIN_HOME/conf/config.inc.php
	rm $PHPPGADMIN_HOME/phppgadmin.tar.gz
	rm -rf $PHPPGADMIN_SOURCE

	chown -R www-data:www-data $PHPPGADMIN_HOME
}

update_settings(){
	set_var_if_null "DATABASE_NAME" "appdb"
	set_var_if_null "DATABASE_USERNAME" "appuser"
	set_var_if_null "DATABASE_PASSWORD" "MS173m_QN"
	set_var_if_null 'PHPPGADMIN_USERNAME' 'phppgadmin'
	set_var_if_null 'PHPPGADMIN_PASSWORD' 'MS173m_QN'
}

set -e

update_settings

echo "INFO: DATABASE_NAME:" $DATABASE_NAME
echo "INFO: DATABASE_USERNAME:" $DATABASE_USERNAME
echo "INFO: PHPPGADMIN_USERNAME:" $PHPPGADMIN_USERNAME

test ! -d "$HTTPD_LOG_DIR" && echo "INFO: $HTTPD_LOG_DIR not found. creating ..." && mkdir -p "$HTTPD_LOG_DIR"
chown -R www-data:www-data $HTTPD_LOG_DIR
apachectl start

# That settings.php doesn't exist means App is not installed/configured yet.
if [ ! -d "$HOME" ]; then
	echo "INFO: path $HOME not found."
	echo "Installing app path for the first time ..."
	
	test ! -d "$HOME" && echo "INFO: $HOME not found. creating ..." && mkdir -p "$HOME"
	chown -R www-data:www-data $HOME
else
	echo "INFO: path $HOME already exists."
fi

# local PostgreSQL is used 
echo "Setting up PostgreSQL data dir ..."
setup_postgresql_data_dir
echo "Setting up PostgreSQL log dir ..."
setup_postgresql_log_dir

echo "Starting local PostgreSQL ..."
start_postgresql

if [ ! -e "$PHPPGADMIN_HOME/config.inc.php" ]; then
	echo "Granting user for phpPgAdmin ..."

	echo "Creating database if not exists ..."
	echo "Granting user ..."

	echo "INFO: $PHPPGADMIN_HOME/config.inc.php not found."
	echo "Installing phpPgAdmin ..."
	setup_phppgadmin
else
	echo "INFO: $PHPPGADMIN_HOME/config.inc.php already exists."
fi

echo "Loading phpPgAdmin conf ..."
if ! grep -q "^Include conf/httpd-phppgadmin.conf" $HTTPD_CONF_FILE; then
	echo 'Include conf/httpd-phppgadmin.conf' >> $HTTPD_CONF_FILE
fi

apachectl stop
# delay 2 seconds to try to avoid "httpd (pid XX) already running"
sleep 2s

echo "Starting Apache httpd -D FOREGROUND ..."
apachectl start -D FOREGROUND
