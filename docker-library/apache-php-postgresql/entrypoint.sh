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

set -e

test ! -d "$HTTPD_LOG_DIR" && echo "INFO: $HTTPD_LOG_DIR not found. creating ..." && mkdir -p "$HTTPD_LOG_DIR"
chown -R www-data:www-data $HTTPD_LOG_DIR
#apachectl start

# That settings.php doesn't exist means App is not installed/configured yet.
if [ ! -d "$HOME" ]; then
	echo "INFO: path $HOME not found."
	echo "Installing app path for the first time ..."
	
	test ! -d "$HOME" && echo "INFO: $HOME not found. creating ..." && mkdir -p "$HOME"
	chown -R www-data:www-data $HOME
else
	echo "INFO: path $HOME already exists."
fi

echo "Starting Apache httpd -D FOREGROUND ..."
apachectl start -D FOREGROUND
