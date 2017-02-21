#!/bin/bash

service mysql start
mysql -u root -e "create user 'phpmyadmin'@'127.0.0.1' identified by 'P@sSword'; grant all on *.* to 'phpmyadmin'@'127.0.0.1' with grant option; flush privileges;"

/usr/local/httpd/bin/httpd -DFOREGROUND
