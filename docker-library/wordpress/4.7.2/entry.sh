#!/bin/bash

service mysql start
mysql -u root -e "create user 'phpmyadmin'@'localhost' identified by 'P@sSw0rd'; grant all on *.* to 'phpmyadmin'@'localhost' with grant option; create user 'phpmyadmin'@'127.0.0.1' identified by 'P@sSw0rd'; grant all on *.* to 'phpmyadmin'@'127.0.0.1' with grant option; flush privileges;"

httpd -DFOREGROUND
