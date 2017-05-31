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

setup_phppgadmin(){
	test ! -d "$PHPPGADMIN_HOME" && echo "INFO: $PHPPGADMIN_HOME not found. creating ..." && mkdir -p "$PHPPGADMIN_HOME"

	cd $PHPPGADMIN_HOME
	mv $PHPPGADMIN_SOURCE/phppgadmin.tar.gz $PHPPGADMIN_HOME/
	tar -xf phppgadmin.tar.gz -C $PHPPGADMIN_HOME --strip-components=1
	# create config.inc.php
	cp -nR $PHPPGADMIN_SOURCE/phppgadmin-config.inc.php $PHPPGADMIN_HOME/config.inc.php
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


if [ ! -e "$PHPPGADMIN_HOME/config.inc.php" ]; then
	echo "Granting user for phpMyAdmin ..."

	echo "Creating database if not exists ..."
	echo "Granting user ..."

	echo "INFO: $PHPPGADMIN_HOME/config.inc.php not found."
	echo "Installing phpPgAdmin ..."
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
