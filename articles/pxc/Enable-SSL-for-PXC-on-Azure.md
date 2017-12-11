# Enable SSL for a Percona XtraDB Cluster (PXC) on Azure

This document will show you how to generate SSL certificates and then how to secure a Percona XtraDB cluster with the generated certificates. In a PXC cluster, wh there are 3 vectors you can secure with SSL:

1. replication traffic between PXC nodes
2. SST (state snapshot transfer) between donor and joiner
3. connections/communications between database server and client application

The client application here refers to not only MySQL/PXC command-line client, but also any scripts (coded in Python, PHP, etc) or any applications (like famous WordPress, phpMyAdmin, etc.) that need connections to database servers in the cluster.  

## Sections at a glance

* Prepare a sample PXC
* Genereate SSL certificates
  * Genereate CA key and CA certificate
  * Generate key and certificate for a-pxcnd
  * Generate key and certificate for k-pxcnd
  * Generate key and certificate for z-pxcnd 
  * Deploy certificates to a-pxcnd
  * Deploy certificates to k-pxcnd
  * Deploy certificates to z-pxcnd
* Secure replication traffic between PXC servers 
* Secure state snapshot transfer between donor and joiner
* Secure connection between PXC database servers and client applications
  * Secure PXC database servers
  * Secure MySQL/PXC command-line client
  * Secure a Python script
  * Secure a PHP script
  * Secure WordPress
  * Secure phpMyAdmin

## Prepare a sample PXC

Before we start to work through the setting/steps in this document, make sure you've already had a PXC cluster available. If not yet, you can easily get a PXC cluster ready by using [this Azure quickstart template] (https://github.com/azure/azure-quickstart-templates/tree/master/mysql-ha-pxc), or DIY a PXC cluster with 3 virtual machines on your local Hyper-V host (Here is a [document] (./PXC-with-HAProxy.md) you can refer to). 

The sample PXC cluster that will be secured in this document is built with the template and the parameters below.

Parameter Name          |   Parameter Value
------------------------|------------------
STORAGEACCOUNT (string)	|   pxcsa
DNSNAME (string)        |   pxc
USERNAME (string)       |   **pxcuser**
PASSWORD (string)       |   **p@ssw0rd**

Other parameters that are not listed in the table above will use default value defined in this file [azuredeploy.json] (https://github.com/Azure/azure-quickstart-templates/blob/master/mysql-ha-pxc/azuredeploy.json). The sample PXC cluster is described as below:

* The cluster consists of **1** Azure load balancer and **3** PXC nodes.
* The load balancer gets a public IP address assigned. (Here assuming that the IP address is **7.7.7.7**. Yours must be different from this.)
* All these 3 PXC nodes are built on **CentOS** (That is default).
* The 3 PXC node names are **a-pxcnd**, **k-pxcnd**, **z-pxcnd** respectively.
* The SSH ports for the 3 PXC nodes are **64001**, **64002**, **64003** respectively.

## Genereate SSL certificates

Before start to generate keys and certificates for each PXC node, you need to know that Common Name (CN) in each certificate must be unique, otherwise they will not work.

#### Genereate CA key and CA certificate

If you already have a CA key and CA certificate avaliable, just use it to generate certificates for PXC nodes and clients. But if you don't have, here will show you how to generate one.

Log in the PXC node **a-pxcnd**.

    ssh pxcuser@7.7.7.7 -p 64001

Run the following command to generate a private key and a self-signed certificate.

    openssl req -newkey rsa:2048 -x509 -nodes -days 36500 -keyout pxc-ca-key.pem -out pxc-ca-cert.pem

When you're asked to enter information for some fields, type proper value for each field. Here we enter **PXC-CA** for the **Common Name** field, and leave other fields blank by entering '.'.

Verify the CA certificate.

    openssl x509 -in pxc-ca-cert.pem -noout -text

In the output, you'll see the **Serial Number**, the **Issuer**, the **Validaty**, the **Subject** which is same as the Issuer, the **Public Key**, the **CA** flag which is set to **True**, and the **Signature**, etc.

#### Generate key and certificate for a-pxcnd

On **a-pxcnd**, run the following command to generate a private key and a certificate request. When you're asked to enter information, type proper value for each field. Here we type **a-pxcnd** for the **Common Name** field, and leave other fields blank.

    openssl req -newkey rsa:2048 -nodes -days 36500 -keyout a-pxcnd-key.pem -out a-pxcnd-req.pem

Remove the passphrase in the private key.

    openssl rsa -in a-pxcnd-key.pem -out a-pxcnd-key.pem

Sign the certificate request with the CA key and CA certificate.

    openssl x509 -req -in a-pxcnd-req.pem -days 36500 -CA pxc-ca-cert.pem -CAkey pxc-ca-key.pem -set_serial 01 -out a-pxcnd-cert.pem

Verify the certificate.

    openssl verify -CAfile pxc-ca-cert.pem a-pxcnd-cert.pem

If everything goes well, the output should be the same as below.

    a-pxcnd-cert.pem: OK

#### Generate key and certificate for k-pxcnd

On **a-pxcnd**, run the following commands, and type **k-pxcnd** for the **Common Name** field when you're asked.

    openssl req -newkey rsa:2048 -nodes -days 36500 -keyout k-pxcnd-key.pem -out k-pxcnd-req.pem
    openssl rsa -in k-pxcnd-key.pem -out k-pxcnd-key.pem
    openssl x509 -req -in k-pxcnd-req.pem -days 36500 -CA pxc-ca-cert.pem -CAkey pxc-ca-key.pem -set_serial 01 -out k-pxcnd-cert.pem

Verify the certificate.

    openssl verify -CAfile pxc-ca-cert.pem k-pxcnd-cert.pem

#### Generate key and certificate for z-pxcnd

On **a-pxcnd**, run the following commands, and type **z-pxcnd** for the **Common Name** field when you're asked.

    openssl req -newkey rsa:2048 -nodes -days 36500 -keyout z-pxcnd-key.pem -out z-pxcnd-req.pem
    openssl rsa -in z-pxcnd-key.pem -out z-pxcnd-key.pem
    openssl x509 -req -in z-pxcnd-req.pem -days 36500 -CA pxc-ca-cert.pem -CAkey pxc-ca-key.pem -set_serial 01 -out z-pxcnd-cert.pem

Verify the certificate.

    openssl verify -CAfile pxc-ca-cert.pem z-pxcnd-cert.pem

#### Deploy certificates to a-pxcnd

Log in **a-pxcnd**, if you have not.

    ssh pxcuser@7.7.7.7 -p 64001 

Create directory /etc/mysql/certs.

    sudo mkdir -p /etc/mysql/certs
    
Copy key and certificates to the directory.

    sudo cp a-pxcnd-key.pem /etc/mysql/certs
    sudo cp a-pxcnd-cert.pem /etc/mysql/certs
    sudo cp pxc-ca-cert.pem /etc/mysql/certs
    
Set proper permission for the directory.

    sudo chown -R mysql:mysql /etc/mysql/certs
    sudo chmod -R o-rwx /etc/mysql/certs

#### Deploy certificates to k-pxcnd

Log in **k-pxcnd**. Note the public ssh port for k-pxcnd is **64002**.

    ssh pxcuser@7.7.7.7 -p 64002 

Create directory /etc/mysql/certs.

    sudo mkdir -p /etc/mysql/certs
    
Copy key and certificates to the directory. Note key name and certificate name in the commands, as well as that here we'll use **scp** to copy certificates from **a-pxcnd** to **k-pxcnd**.

    sudo scp pxcuser@a-pxcnd:./k-pxcnd-key.pem /etc/mysql/certs
    sudo scp pxcuser@a-pxcnd:./k-pxcnd-cert.pem /etc/mysql/certs
    sudo scp pxcuser@a-pxcnd:./pxc-ca-cert.pem /etc/mysql/certs
    
Set proper permission for the directory.

    sudo chown -R mysql:mysql /etc/mysql/certs
    sudo chmod -R o-rwx /etc/mysql/certs

#### Deploy certificates to z-pxcnd

Log in **z-pxcnd**. The public ssh port for k-pxcnd is **64003**.

    ssh pxcuser@7.7.7.7 -p 64003 

Create directory /etc/mysql/certs.

    sudo mkdir -p /etc/mysql/certs
    
Copy key and certificates to the directory. Like above, we're using **scp** to copy certificates from **a-pxcnd**.

    sudo scp pxcuser@a-pxcnd:./z-pxcnd-key.pem /etc/mysql/certs
    sudo scp pxcuser@a-pxcnd:./z-pxcnd-cert.pem /etc/mysql/certs
    sudo scp pxcuser@a-pxcnd:./pxc-ca-cert.pem /etc/mysql/certs
    
Set proper permission for the directory.

    sudo chown -R mysql:mysql /etc/mysql/certs
    sudo chmod -R o-rwx /etc/mysql/certs

## Secure replication traffic between PXC nodes

#### On a-pxcnd

Stop mysql service first.

    sudo service mysql stop

Open PXC configuration file. The path to PXC configuration file on **CentOS** is /etc/my.cnf by default. On **Ubuntn** the default path is /etc/mysql/my.cnf.

    sudo vi /etc/my.cnf
    # if your PXC node is running on Ubuntu Server, use /etc/mysql/my.cnf
    # sudo vi /etc/mysql/my.cnf
    
Find the **[mysqld]** configuration section, and add the **wsrep_provider_options** configuration item under this section like below. 

    [mysqld]
    ...
    wsrep_provider_options="socket.ssl_cert=/etc/mysql/certs/a-pxcnd-cert.pem;socket.ssl_key=/etc/mysql/certs/a-pxcnd-key.pem;socket.ssl_ca=/etc/mysql/certs/pxc-ca-cert.pem"
    ...

#### On k-pxcnd

Stop mysql service first.

    sudo service mysql stop

Open PXC configuration file.

    sudo vi /etc/my.cnf
    # if your PXC node is running on Ubuntu Server, use /etc/mysql/my.cnf
    # sudo vi /etc/mysql/my.cnf
    
Add the **wsrep_provider_options** configuration item under **[mysqld]**. 

    wsrep_provider_options="socket.ssl_cert=/etc/mysql/certs/k-pxcnd-cert.pem;socket.ssl_key=/etc/mysql/certs/k-pxcnd-key.pem;socket.ssl_ca=/etc/mysql/certs/pxc-ca-cert.pem"

#### On z-pxcnd

Stop mysql service first.

    sudo service mysql stop

Open PXC configuration file.

    sudo vi /etc/my.cnf
    # if your PXC node is running on Ubuntu Server, use /etc/mysql/my.cnf
    # sudo vi /etc/mysql/my.cnf
    
Add the **wsrep_provider_options** configuration item under **[mysqld]**. 

    wsrep_provider_options="socket.ssl_cert=/etc/mysql/certs/z-pxcnd-cert.pem;socket.ssl_key=/etc/mysql/certs/z-pxcnd-key.pem;socket.ssl_ca=/etc/mysql/certs/pxc-ca-cert.pem"

#### Verify WSREP is using SSL

On **z-pxcnd**, bootstrap the mysql service.

    sudo service mysql bootstrap-pxc

On **k-pxcnd**, start the mysql service.

    sudo service mysql start

On **a-pxcnd**, start the mysql service.

    sudo service mysql start

Run the command below to check the log.

    sudo cat /var/log/mysqld.log | grep ssl
    # if you PXC node is running on Ubuntu, use the log file path below instead.
    # cat /var/log/mysql/error.log

In the output, you should see some lines containing the keyword "ssl" which are saying "SSL handshake successful". Below is the output from my cluster. Yours should be looking like this, but must be different.

    ...
    2015-08-21 02:38:39 60644 [Note] WSREP: SSL handshake successful, remote endpoint ssl://10.0.1.5:50125 local endpoint ssl://10.0.1.6:4567 cipher: AES128-SHA compression:
    ...
    2015-08-21 02:39:18 60644 [Note] WSREP: SSL handshake successful, remote endpoint ssl://10.0.1.4:39647 local endpoint ssl://10.0.1.6:4567 cipher: AES128-SHA compression:
    ...

## Secure state snapshot transfer between donor and joiner

#### On a-pxcnd

Open PXC configuration file. The path to PXC configuration file on **CentOS** is /etc/my.cnf by default. On **Ubuntn** the default path is /etc/mysql/my.cnf.

    sudo vi /etc/my.cnf
    # if your PXC node is running on Ubuntu Server, use /etc/mysql/my.cnf
    # sudo vi /etc/mysql/my.cnf
    
Find the **[sst]** configuration section, and add the following configuration items under this section like below. 

    [sst]
    encrypt=3
    tkey=/etc/mysql/certs/a-pxcnd-key.pem
    tcert=/etc/mysql/certs/a-pxcnd-cert.pem

#### On k-pxcnd

Open PXC configuration file.

    sudo vi /etc/my.cnf
    # if your PXC node is running on Ubuntu Server, use /etc/mysql/my.cnf
    # sudo vi /etc/mysql/my.cnf
    
Add the following configuration items under **[sst]**.

    [sst]
    encrypt=3
    tkey=/etc/mysql/certs/k-pxcnd-key.pem
    tcert=/etc/mysql/certs/k-pxcnd-cert.pem

#### On z-pxcnd

Open PXC configuration file.

    sudo vi /etc/my.cnf
    # if your PXC node is running on Ubuntu Server, use /etc/mysql/my.cnf
    # sudo vi /etc/mysql/my.cnf
    
Add the following configuration items under **[sst]**.

    [sst]
    encrypt=3
    tkey=/etc/mysql/certs/z-pxcnd-key.pem
    tcert=/etc/mysql/certs/z-pxcnd-cert.pem

#### Verify SST is using SSL

On **z-pxcnd**, stop mysql service to make this node exit the cluster.

    sudo service mysql stop

On **k-pxcnd**, open mysql client, and create a new table in the database test.

    mysql -u root
    mysql> use test;
    mysql> create table t1 (id int primary key, name nvarchar(50));
    mysql> insert into t1 values(1, 'name#1');

The new table and the new row should be replicated to **a-pxcnd** via WSREP. You can check this change on **a-pxcnd**. Now let's verify that SST is using SSL when **z-pxcnd** joins the cluster. 

On **z-pxcnd**, start mysql service.

    sudo service mysql start

On **a-pxcnd** and **z-pxcnd**, open mysql log (/var/log/mysqld.log on CentOS, /var/log/mysql/error.log on Ubuntu), you should see some lines like below near the end of the log.

    2015-09-14 02:51:03 11291 [Note] WSREP: Member 1.0 (z-pxcnd) requested state transfer from '*any*'. Selected 2.0 (a-pxcnd)(SYNCED) as donor.
    ...
    2015-09-14 02:51:03 11291 [Note] WSREP: IST request: 5eef7f9e-4639-11e5-93ae-93947197546e:294-297|ssl://10.0.1.6:4568
    ...
    2015-09-14 02:51:03 11291 [Note] WSREP: Running: 'wsrep_sst_xtrabackup-v2 --role 'donor' --address '10.0.1.6:4444/xtrabackup_sst//1' --auth 'XXXXXXX:XXXXXXX' --socket '/var/lib/mysql/mysql.sock' --datadir '/var/lib/mysql/' --defaults-file '/etc/my.cnf' --defaults-group-suffix ''   '' --gtid '5eef7f9e-4639-11e5-93ae-93947197546e:294' --bypass'
    2015-09-14 02:51:03 11291 [Note] WSREP: sst_donor_thread signaled with 0
    2015-09-14 02:51:03 11291 [Note] WSREP: IST sender using ssl
    2015-09-14 02:51:03 11291 [Note] WSREP: async IST sender starting to serve ssl://10.0.1.6:4568 sending 295-297
    WSREP_SST: [INFO] Streaming with xbstream (20150914 02:51:04.383)
    WSREP_SST: [INFO] Using socat as streamer (20150914 02:51:04.387)
    WSREP_SST: [INFO] Using openssl based encryption with socat: with key and crt (20150914 02:51:04.393)
    WSREP_SST: [INFO] Encrypting with certificate /etc/mysql/certs/a-pxcnd-cert.pem, key /etc/mysql/certs/a-pxcnd-key.pem (20150914 02:51:04.396)
    WSREP_SST: [INFO] Bypassing the SST for IST (20150914 02:51:04.400)
    WSREP_SST: [INFO] Evaluating xbstream -c ${INFO_FILE} ${IST_FILE} | socat -u stdio openssl-connect:10.0.1.6:4444,cert=/etc/mysql/certs/a-pxcnd-cert.pem,key=/etc/mysql/certs/a-pxcnd-key.pem,verify=0; RC=( ${PIPESTATUS[@]} ) (20150914 02:51:04.721)
    2015-09-14 02:51:04 11291 [Note] WSREP: 2.0 (a-pxcnd): State transfer to 1.0 (z-pxcnd) complete.
    ...
    2015-09-14 02:51:06 11291 [Note] WSREP: async IST sender served
    2015-09-14 02:51:06 11291 [Note] WSREP: 1.0 (z-pxcnd): State transfer from 2.0 (a-pxcnd) complete.
    2015-09-14 02:51:06 11291 [Note] WSREP: Member 1.0 (z-pxcnd) synced with group.

On **z-pxcnd**, check mysql log.

    2015-09-14 02:51:02 36678 [Note] WSREP: State transfer required:
        Group state: 5eef7f9e-4639-11e5-93ae-93947197546e:297
        Local state: 5eef7f9e-4639-11e5-93ae-93947197546e:294
    ...
    2015-09-14 02:51:02 36678 [Warning] WSREP: Gap in state sequence. Need state transfer.
    2015-09-14 02:51:02 36678 [Note] WSREP: Running: 'wsrep_sst_xtrabackup-v2 --role 'joiner' --address '10.0.1.6' --auth 'XXXXXXX:XXXXXXX' --datadir '/var/lib/mysql/' --defaults-file '/etc/my.cnf' --defaults-group-suffix '' --parent '36678'  '' '
    WSREP_SST: [INFO] Streaming with xbstream (20150914 02:51:03.437)
    WSREP_SST: [INFO] Using socat as streamer (20150914 02:51:03.440)
    WSREP_SST: [INFO] Using openssl based encryption with socat: with key and crt (20150914 02:51:03.447)
    WSREP_SST: [INFO] Decrypting with certificate /etc/mysql/certs/z-pxcnd-cert.pem, key /etc/mysql/certs/z-pxcnd-key.pem (20150914 02:51:03.450)
    WSREP_SST: [INFO] Evaluating timeout -s9 100 socat -u openssl-listen:4444,reuseaddr,cert=/etc/mysql/certs/z-pxcnd-cert.pem,key=/etc/mysql/certs/z-pxcnd-key.pem,verify=0 stdio | xbstream -x; RC=( ${PIPESTATUS[@]} ) (20150914 02:51:03.492)
    2015-09-14 02:51:03 36678 [Note] WSREP: Prepared SST request: xtrabackup-v2|10.0.1.6:4444/xtrabackup_sst//1
    ...
    2015-09-14 02:51:03 36678 [Note] WSREP: IST receiver using ssl
    2015-09-14 02:51:03 36678 [Note] WSREP: Prepared IST receiver, listening at: ssl://10.0.1.6:4568
    2015-09-14 02:51:03 36678 [Note] WSREP: Member 1.0 (z-pxcnd) requested state transfer from '*any*'. Selected 2.0 (a-pxcnd)(SYNCED) as donor.
    2015-09-14 02:51:03 36678 [Note] WSREP: Shifting PRIMARY -> JOINER (TO: 297)
    2015-09-14 02:51:03 36678 [Note] WSREP: Requesting state transfer: success, donor: 2
    2015-09-14 02:51:04 36678 [Note] WSREP: 2.0 (a-pxcnd): State transfer to 1.0 (z-pxcnd) complete.
    2015-09-14 02:51:04 36678 [Note] WSREP: Member 2.0 (a-pxcnd) synced with group.

## Secure connection between PXC database servers and client applications

#### Secure PXC database servers

Log in **a-pxcnd**.

    ssh pxcuser@7.7.7.7 -p 64001

Open /etc/my.cnf, and add the following lines under the section **[mysqld]**. Open /etc/mysql/my.cnf if your PXC node is on Ubuntu.

    ssl-cert = /etc/mysql/certs/a-pxcnd-cert.pem
    ssl-key = /etc/mysql/certs/a-pxcnd-key.pem
    ssl-ca = /etc/mysql/certs/pxc-ca-cert.pem

Restart mysql.

	sudo service mysql restart

Log in **k-pxcnd**.

    ssh pxcuser@7.7.7.7 -p 64002

Open /etc/my.cnf, and add the following lines under the section **[mysqld]**.

    ssl-cert = /etc/mysql/certs/k-pxcnd-cert.pem
    ssl-key = /etc/mysql/certs/k-pxcnd-key.pem
    ssl-ca = /etc/mysql/certs/pxc-ca-cert.pem

Restart mysql.

    sudo service mysql restart

Log in **z-pxcnd**.

    ssh pxcuser@7.7.7.7 -p 64003

Add the following lines under the section **[mysqld]** in /etc/my.cnf.

    ssl-cert = /etc/mysql/certs/z-pxcnd-cert.pem
    ssl-key = /etc/mysql/certs/z-pxcnd-key.pem
    ssl-ca = /etc/mysql/certs/pxc-ca-cert.pem

Restart mysql.

    sudo service mysql restart

On any PXC node, open mysql command-line client.

    mysql -u root -p

Create a new database user that has only SSL connection permitted.

    grant select on *.* to 'ssluser'@'%' identified by 'ssluserpass' require ssl;
    flush privileges;

#### Secure PXC/MySQL command-line client

To demo how to secure a PXC/MySQL client, we built a Ubuntu vm on local hyper-v host and use it as a PXC client. Its hostname is **pxc-console**.

Log in **a-pxcnd**, and generate a key and a certificate for **pxc-console** with the following commands. Enter **pxc-console** for the **Common Name** field when you're asked.

    openssl req -newkey rsa:2048 -nodes -days 36500 -keyout pxc-console-key.pem -out pxc-console-req.pem
    openssl rsa -in pxc-console-key.pem -out pxc-console-key.pem
    openssl x509 -req -in pxc-console-req.pem -days 36500 -CA pxc-ca-cert.pem -CAkey pxc-ca-key.pem -set_serial 01 -out pxc-console-cert.pem

Verify the certificate.

    openssl verify -CAfile pxc-ca-cert.pem pxc-console-cert.pem

Log in **pxc-console**, and execute the command below to install PXC client.

    sudo apt-get install percona-xtradb-cluster-client-5.5

Create a directory on this client to store key and certificates.

    sudo mkdir /etc/mysql/certs

Copy key and certificates from **a-pxcnd**. Note here uses scp also, and you need replace **7.7.7.7** with your LB public IP address.

    sudo scp -P 64001 pxcuser@7.7.7.7:./pxc-console-key.pem /etc/mysql/certs
    sudo scp -P 64001 pxcuser@7.7.7.7:./pxc-console-cert.pem /etc/mysql/certs
    sudo scp -P 64001 pxcuser@7.7.7.7:./pxc-ca-cert.pem /etc/mysql/certs

Set proper permissions for the certs directory.

    sudo chmod o-wx /etc/mysql/certs/*.pem

Open /etc/mysql/my.cnf, and add the following lines under the section **[mysql]**.

    ssl-cert = /etc/mysql/certs/pxc-console-cert.pem
    ssl-key = /etc/mysql/certs/pxc-console-key.pem
    ssl-ca = /etc/mysql/certs/pxc-ca-cert.pem

Verify if PXC command-line client can connect to the cluster with the SSL-required user **ssluser**. 

    mysql -u ssluser -h 7.7.7.7 -p

#### Secure a Python script

You've secured PXC database servers in the section [Secure PXC database servers]. Here we just talk about how to create a SSL connection in a Python script. Here also uses the **pxc-console** to run a Python script that will create a SSL connection to the cluster.

Install Python MySQL module.

    sudo apt-get install python-mysqldb

Create a python script **test-ssl.py**.

    vi test-ssl.py

And add the following lines to the script.

    import MySQLdb
    ssl = {'cert': '/etc/mysql/certs/pxc-console-cert.pem', 'key': '/etc/mysql/certs/pxc-console-key.pem', 'ca': '/etc/mysql/certs/pxc-ca-cert.pem'}
    conn = MySQLdb.connect(host='7.7.7.7', user='ssluser', passwd='ssluserpass', ssl=ssl)
    cursor = conn.cursor()
    cursor.execute('SHOW STATUS like "wsrep%"')
    print cursor.fetchone()

Execute the script.

    python test-ssl.py

The output should look like below.

    ('wsrep_local_state_uuid', 'c48a4d0a-398e-11e5-92ea-7fd4da84789f')

#### Secure a PHP script

Log on **pxc-console**. Install php5 command-line interpreter and MySQL module.

    sudo apt-get install php5-cli php5-mysql

Create a php script.

    vi test-ssl.php

Add the following lines into the script.

    <?php
        $conn=mysqli_init();
        mysqli_ssl_set($conn, '/etc/mysql/certs/pxc-console-key.pem', '/etc/mysql/certs/pxc-console-cert.pem', '/etc/mysql/certs/pxc-ca-cert.pem', NULL, NULL);
        if (!mysqli_real_connect($conn, '7.7.7.7', 'ssluser', 'ssluserpass')) { die(); }
        $res = mysqli_query($conn, 'show variables like "have_ssl"');
        print_r(mysqli_fetch_row($res));
        mysqli_close($conn);
    ?>

Execute the script.

    php test-ssl.php

You should see the output looking like below.

    Array
    (
        [0] => have_ssl
        [1] => YES
    )

#### Secure WordPress

Assuming that you've installed WordPress on **pxc-console** and got it running well without SSL-enabled db connection, and you've generated key and certificate for **pxc-console** and copied them to /etc/mysql/certs.

Open /var/www/html/wordpress/wp-config.php, and add the following lines.

    /** SSL */
    define('MYSQL_CLIENT_FLAGS', MYSQL_CLIENT_SSL);
    define('SSL_KEY', '/etc/mysql/certs/pxc0-key.pem');
    define('SSL_CERT', '/etc/mysql/certs/pxc0-cert.pem');
    define('SSL_CA', '/etc/mysql/certs/pxc-ca-cert.pem');

Open /var/www/html/wordpress/wp-includes/wp-db.php, and find and replace the function **db_connect** with below.

    public function db_connect( $allow_bail = true ) {
        $this->is_mysql = true;
        $new_link = defined( 'MYSQL_NEW_LINK' ) ? MYSQL_NEW_LINK : true;
        $client_flags = defined( 'MYSQL_CLIENT_FLAGS' ) ? MYSQL_CLIENT_FLAGS : 0;
        
        $this->dbh = mysqli_init();
        
        $port = null;
        $socket = null;
        $host = $this->dbhost;
        $port_or_socket = strstr( $host, ':' );
        if ( ! empty( $port_or_socket ) ) {
                $host = substr( $host, 0, strpos( $host, ':' ) );
                $port_or_socket = substr( $port_or_socket, 1 );
                if ( 0 !== strpos( $port_or_socket, '/' ) ) {
                        $port = intval( $port_or_socket );
                        $maybe_socket = strstr( $port_or_socket, ':' );
                        if ( ! empty( $maybe_socket ) ) {
                                $socket = substr( $maybe_socket, 1 );
                        }
                } else {
                        $socket = $port_or_socket;
                }
        }
        
        mysqli_ssl_set ( $this->dbh, SSL_KEY, SSL_CERT, SSL_CA, null, null );
        
        if ( WP_DEBUG ) {
            mysqli_real_connect( $this->dbh, $host, $this->dbuser, $this->dbpassword, null, $port, $socket, $client_flags );
        } else {
            @mysqli_real_connect( $this->dbh, $host, $this->dbuser, $this->dbpassword, null, $port, $socket, $client_flags );
        }
                
        if ( ! $this->dbh && $allow_bail ) {
            wp_load_translations_early();
            // Load custom DB error template, if present.
            if ( file_exists( WP_CONTENT_DIR . '/db-error.php' ) ) {
                    require_once( WP_CONTENT_DIR . '/db-error.php' );
                    die();
            }
                        
            $this->bail( sprintf( __( "
                <h1>Error establishing a database connection</h1>
                <p>This either means that the username and password information in your <code>wp-config.php</code> file is incorrect or we can't contact the database server at <code>%s</code>. This could mean your host's database server is down.</p>
                <ul>
                    <li>Are you sure you have the correct username and password?</li>
                    <li>Are you sure that you have typed the correct hostname?</li>
                    <li>Are you sure that the database server is running?</li>
                </ul>
                <p>If you're unsure what these terms mean you should probably contact your host. If you still need help you can always visit the <a href='https://wordpress.org/support/'>WordPress Support Forums</a>.</p>
            " ), htmlspecialchars( $this->dbhost, ENT_QUOTES ) ), 'db_connect_fail' );
                        
            return false;
        } elseif ( $this->dbh ) {
            if ( ! $this->has_connected ) {
                    $this->init_charset();
            }
            $this->has_connected = true;
            $this->set_charset( $this->dbh );
            $this->ready = true;
            $this->set_sql_mode();
            $this->select( $this->dbname, $this->dbh );
            return true;
        }
        
        return false;
    }

Open your browser and access your WordPress site. Everything should go well.

#### Secure phpMyAdmin

Here will continue using **pxc-console**. If you have not installed phpMyAdmin on this machine, below are steps you can follow.

    sudo apt-get update
    sudo apt-get install apache2
    sudo apt-get install mariadb-server-5.5
    sudo apt-get install php5 libapache2-mod-php5 php5-mcrypt
    sudo apt-get install phpmyadmin

After installation completes, you should be able to access phpMyAdmin via http://pxc-console/phpmyadmin. Open /etc/phpmyadmin/config.inc.php, find the following lines:

    /* Configure according to dbconfig-common if enabled */
    if (!empty($dbname)) {
        ...
        /* Advance to next server for rest of config */
        $i++;
    }
    
and add the following lines below the "}".

    // ------------------------
    // ----Server on Azure ----
    $cfg['Servers'][$i]['host'] = '7.7.7.7';
    $cfg['Servers'][$i]['connect_type'] = 'tcp';
    $cfg['Servers'][$i]['ssl'] = true;
    $cfg['Servers'][$i]['extension'] = 'mysqli';
    $cfg['Servers'][$i]['ssl_key'] = '/etc/mysql/certs/pxc-console-key.pem';
    $cfg['Servers'][$i]['ssl_cert'] = '/etc/mysql/certs/pxc-console-cert.pem';
    $cfg['Servers'][$i]['ssl_ca'] = '/etc/mysql/certs/pxc-ca-cert.pem';
    // ------------------------------
    // ----advance to next server----
    $i++;

Log out phpMyAdmin, or refresh the page http://pxc-console/phpmyadmin, you should see a **Server Choice** drop down list. Expand the drop down list, you should see your remote database server **7.7.7.7**.
