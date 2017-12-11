This tutorial will show you how to enable SSL for the PXC cluster that built in the previous tutorial **PXC-with-HAProxy**.

## Generate CA key and certificate

On the cluster node **pxc1**, use the following command to generate an unencreypted private key and a self-signed certificate. 

	openssl req -newkey rsa:2048 -x509 -nodes -days 36500 -keyout pxc-ca-key.pem -out pxc-ca-cert.pem

When you're asked to enter information for some fields, enter **PXC-CA** for the **Common Name** field, as for other field, leave them blank by entering a ".".  
Verify the CA certificate.

	openssl x509 -in pxc-ca-cert.pem -noout -text

In the output, you'll see the Serial Number, the Issuer, the Validaty, **the Subject which is same as the Issuer**, the Public Key, **the CA flag which is set to True**, and the Signature.

## Secure replication traffic

#### Generate key and certificate for the cluster node pxc1

Use the following command to generate a private key and a certificate request. When you're asked to enter information for the Common Name field, type **pxc1**. Leave other fields blank.

	openssl req -newkey rsa:2048 -nodes -days 36500 -keyout pxc1-key.pem -out pxc1-req.pem

Remove the passphrase in the private key.

	openssl rsa -in pxc1-key.pem -out pxc1-key.pem

Sign the certificate request with the CA key and certificate.

	openssl x509 -req -in pxc1-req.pem -days 36500 -CA pxc-ca-cert.pem -CAkey pxc-ca-key.pem -set_serial 01 -out pxc1-cert.pem

Verify the certificate.

	openssl verify -CAfile pxc-ca-cert.pem pxc1-cert.pem

#### Generate key and certificate for the cluster node pxc2

Generate a private key and a certificate request. Type **pxc2** for the Common Name field, and leave other fields blank.

	openssl req -newkey rsa:2048 -nodes -days 36500 -keyout pxc2-key.pem -out pxc2-req.pem

Remove the passphrase in the private key.

	openssl rsa -in pxc2-key.pem -out pxc2-key.pem

Sign the certificate request.

	openssl x509 -req -in pxc2-req.pem -days 36500 -CA pxc-ca-cert.pem -CAkey pxc-ca-key.pem -set_serial 01 -out pxc2-cert.pem

Verify the certificate.

	openssl verify -CAfile pxc-ca-cert.pem pxc2-cert.pem

#### Generate key and certificate for the cluster node pxc3

Generate a private key and a certificate request. Type **pxc3** for the Common Name field, and leave other fields blank.

	openssl req -newkey rsa:2048 -nodes -days 36500 -keyout pxc3-key.pem -out pxc3-req.pem

Remove the passphrase in the private key.

	openssl rsa -in pxc3-key.pem -out pxc3-key.pem

Sign the certificate request.

	openssl x509 -req -in pxc3-req.pem -days 36500 -CA pxc-ca-cert.pem -CAkey pxc-ca-key.pem -set_serial 01 -out pxc3-cert.pem

Verify the certificate.

	openssl verify -CAfile pxc-ca-cert.pem pxc3-cert.pem

#### Deploy certificates to the cluster node pxc1

Stop mysql service first.

	sudo service mysql stop

Create the directory /etc/mysql/certs to store certificates, and set proper permissions to the directory.

	sudo mkdir /etc/mysql/certs
	sudo cp pxc1-key.pem /etc/mysql/certs
	sudo cp pxc1-cert.pem /etc/mysql/certs
	sudo cp pxc-ca-cert.pem /etc/mysql/certs
	sudo chown -R mysql:mysql /etc/mysql/certs
	sudo chmod -R o-rwx /etc/mysql/certs

Open mysql configuration file /etc/mysql/my.cnf, and add the following lines to the **[mysqld]** section.

	wsrep_provider_options="socket.ssl_cert=/etc/mysql/certs/pxc1-cert.pem;socket.ssl_key=/etc/mysql/certs/pxc1-key.pem;socket.ssl_ca=/etc/mysql/certs/pxc-ca-cert.pem"

#### Deploy certificates to the cluster node pxc2

Stop mysql service first.

	sudo service mysql stop

Create the directory /etc/mysql/certs to store certificates, and set proper permissions to the directory. Note the user name **jeffrey** in the scp commands, you need replace this with your user name.

	sudo mkdir /etc/mysql/certs
	sudo scp jeffrey@pxc1:/home/jeffrey/certs/pxc2-key.pem /etc/mysql/certs
	sudo scp jeffrey@pxc1:/home/jeffrey/certs/pxc2-cert.pem /etc/mysql/certs
	sudo scp jeffrey@pxc1:/home/jeffrey/certs/pxc-ca-cert.pem /etc/mysql/certs
	sudo chown -R mysql:mysql /etc/mysql/certs
	sudo chmod -R o-rwx /etc/mysql/certs

Open mysql configuration file /etc/mysql/my.cnf, and add the following lines to the **[mysqld]** section.

	wsrep_provider_options="socket.ssl_cert=/etc/mysql/certs/pxc2-cert.pem;socket.ssl_key=/etc/mysql/certs/pxc2-key.pem;socket.ssl_ca=/etc/mysql/certs/pxc-ca-cert.pem"

#### Deploy certificates to the cluster node pxc3

Stop mysql service first.

	sudo service mysql stop

Create the directory /etc/mysql/certs to store certificates, and set proper permissions to the directory.

	sudo mkdir /etc/mysql/certs
	sudo scp jeffrey@pxc1:/home/jeffrey/certs/pxc3-key.pem /etc/mysql/certs
	sudo scp jeffrey@pxc1:/home/jeffrey/certs/pxc3-cert.pem /etc/mysql/certs
	sudo scp jeffrey@pxc1:/home/jeffrey/certs/pxc-ca-cert.pem /etc/mysql/certs
	sudo chown -R mysql:mysql /etc/mysql/certs
	sudo chmod -R o-rwx /etc/mysql/certs

Open mysql configuration file /etc/mysql/my.cnf, and add the following lines to the **[mysqld]** section.

	wsrep_provider_options="socket.ssl_cert=/etc/mysql/certs/pxc3-cert.pem;socket.ssl_key=/etc/mysql/certs/pxc3-key.pem;socket.ssl_ca=/etc/mysql/certs/pxc-ca-cert.pem"

#### Start the cluster nodes

On pxc1,

	sudo service mysql bootstrap-pxc

On pxc2 and pxc3,

	sudo service mysql start

## Secure communication between servers in the cluster and various clients

#### Secure servers

###### On pxc1

Open /etc/mysql/my.cnf, and add the following lines under the section **[mysqld]**.

	ssl-cert = /etc/mysql/certs/pxc1-cert.pem
	ssl-key = /etc/mysql/certs/pxc1-key.pem
	ssl-ca = /etc/mysql/certs/pxc-ca-cert.pem

Restart mysql.

	sudo service mysql restart

###### On pxc2

Open /etc/mysql/my.cnf, and add the following lines under the section **[mysqld]**.

	ssl-cert = /etc/mysql/certs/pxc2-cert.pem
	ssl-key = /etc/mysql/certs/pxc2-key.pem
	ssl-ca = /etc/mysql/certs/pxc-ca-cert.pem

Restart mysql.

	sudo service mysql restart

###### On pxc3

Open /etc/mysql/my.cnf, and add the following lines under the section **[mysqld]**.

	ssl-cert = /etc/mysql/certs/pxc3-cert.pem
	ssl-key = /etc/mysql/certs/pxc3-key.pem
	ssl-ca = /etc/mysql/certs/pxc-ca-cert.pem

Restart mysql.

	sudo service mysql restart

###### On any cluster node

Open PXC command line client.

	mysql -u root -p

Execute the following queries to create an user that has only SSL connection permitted.

	grant all on *.* to 'ssluser'@'%' identified by 'ssluserpass' require ssl;
	flush privileges;

#### Secure the connection from PXC command line client

Here the load balancer node **pxc0** will be used as PXC command line client.

###### On pxc1  

Generate a key and a certificate for pxc0 with the following commands.

	openssl req -newkey rsa:2048 -nodes -days 36500 -keyout pxc0-key.pem -out pxc0-req.pem
	openssl rsa -in pxc0-key.pem -out pxc0-key.pem
	openssl x509 -req -in pxc0-req.pem -days 36500 -CA pxc-ca-cert.pem -CAkey pxc-ca-key.pem -set_serial 01 -out pxc0-cert.pem

###### On pxc0

Execute the following command to install PXC client.

	sudo apt-get install percona-xtradb-cluster-client-5.5

Create a directory to store keys and certificates, and then copy the CA certificate and pxc0's key and certificate from pxc1 to pxc0.

	sudo mkdir /etc/mysql/certs
	sudo scp jeffrey@pxc1:/home/jeffrey/certs/pxc0-key.pem /etc/mysql/certs
	sudo scp jeffrey@pxc1:/home/jeffrey/certs/pxc0-cert.pem /etc/mysql/certs
	sudo scp jeffrey@pxc1:/home/jeffrey/certs/pxc-ca-cert.pem /etc/mysql/certs
	sudo chmod -R o-rwx /etc/mysql/certs

Open /etc/mysql/my.cnf, and add the following lines under the section **[mysql]**.

	ssl-cert = /etc/mysql/certs/pxc0-cert.pem
	ssl-key = /etc/mysql/certs/pxc0-key.pem
	ssl-ca = /etc/mysql/certs/pxc-ca-cert.pem

Verify if the PXC client can connect to the cluster with the new user **ssluser**. Make sure that haproxy is already started before run the command below.

	sudo mysql -u ssluser -h 127.0.0.1 -p

#### Secure the connection from Python application

Like above, here also uses the load balancer node **pxc0** to run a Python script that will create a SSL connection to the cluster.

Install Python MySQL module.

	sudo apt-get install python-mysqldb 

Create a python script test-ssl.py, and add the following lines.

	import MySQLdb
	
	ssl = {'cert': '/etc/mysql/certs/pxc0-cert.pem', 'key': '/etc/mysql/certs/pxc0-key.pem', 'ca': '/etc/mysql/certs/pxc-ca-cert.pem'}
	conn = MySQLdb.connect(host='127.0.0.1', user='ssluser', passwd='ssluserpass', ssl=ssl)
	cursor = conn.cursor()
	cursor.execute('SHOW STATUS like "wsrep%"')
	print cursor.fetchone()

Execute the script.

	python test-ssl.py

The output should look like below.

	('wsrep_local_state_uuid', 'c48a4d0a-398e-11e5-92ea-7fd4da84789f')
