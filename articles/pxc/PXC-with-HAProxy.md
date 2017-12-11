This tutorial will show you how to build a sample HA environment with Percona XtraDB Cluster and HA-Proxy. This sample environment consists of a cluster running on 3 Ubuntu 14.04 nodes with Percona XtraDB Cluster 5.6 installed, and a load balancer running on a seperate Ubuntu 14.04 node with HA-Proxy installed. Below are the names, IP addresses and roles for each node in this sample environment.

Name    |    IP Address         |    Role
--------|-----------------------|-----------------------
pxc0    |    192.168.122.200    |    Load Balancer node
pxc1    |    192.168.122.201    |    Cluster node
pxc2    |    192.168.122.202    |    Cluster node
pxc3    |    192.168.122.203    |    Cluster node

This sample environment is verified-and-works with the software versions listed below.
    
* Ubuntu 14.04                # all 4 nodes
* Percona XtraDB Cluster 5.6  # all 3 cluster nodes (pxc1 ~ 3)
* HA-Proxy 1.4.24             # LB node (pxc0)
* Sysbench 0.4.12             # LB node (pxc0)
    
## Install and configure PXC

#### Install PXC on all cluster nodes(pxc1, pxc2, pxc3)

Percona uses the keys from keys.gnupg.net to verify packages after package download completes in apt-get install. Let's get the keys with the following command.

	sudo apt-key adv --keyserver keys.gnupg.net --recv-keys 1C4CBDCDCD2EFD2A

Create a new source list file for Percona.

	sudo vi /etc/apt/sources.list.d/percona.list

Add the following 2 lines to the file percona.list.

	deb http://repo.percona.com/apt trusty main
	deb-src http://repo.percona.com/apt trusty main

Update repo and install PXC.

	sudo apt-get update
	sudo apt-get install percona-xtradb-cluster-56

Stop mysql first before start to configure the cluster.

	sudo service mysql stop

#### Configure pxc1

Open pxc/mysql configuration file with the command below.

	sudo vi /etc/mysql/my.cnf

Find the line 'bind-address = 127.0.0.1', and remove it or comment it out by prefixing the character '#'.
And then add the following lines under the section [mysqld].

	# ----------------
	# Cluster Settings
	# ----------------
	wsrep_cluster_name=pxc_ubuntu_1
	wsrep_cluster_address=gcomm://192.168.122.201,192.168.122.202,192.168.122.203
	wsrep_node_address=192.168.122.201
	wsrep_provider=/usr/lib/libgalera_smm.so
	binlog_format=ROW
	default_storage_engine=InnoDB
	innodb_autoinc_lock_mode=2
	wsrep_sst_method=xtrabackup-v2
	wsrep_sst_auth="sstuser:s3cretPass"

Start the first node with **bootstrap-pxc**.

	sudo service mysql bootstrap-pxc

Open mysql client,

	mysql -u root -p

And execute the following queries to create a user for State Snapshot Transfer using Percona XtraBackup.

	CREATE USER 'sstuser'@'localhost' IDENTIFIED BY 's3cretPass'; 
	GRANT RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO 'sstuser'@'localhost'; 
	FLUSH PRIVILEGES;

#### Verify pxc1

Execute the following query on mysql client.

	show status like 'wsrep%';

The output should look like below.

	wsrep_local_state_uuid      = xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
	...
	wsrep_local_state           = 4
	wsrep_local_state_comment   = Synced
	...
	wsrep_cluster_size          = 1
	wsrep_cluster_status        = Primary
	wsrep_connected             = ON
	...
	wsrep_ready                 = ON

#### Configure pxc2

Open pxc/mysql configuration file.

	sudo vi /etc/mysql/my.cnf

Find the line 'bind-address = 127.0.0.1', and remove it or comment it out by prefixing the character '#'.
And then add the following lines under the section [mysqld].

	# ----------------
	# Cluster Settings
	# ----------------
	wsrep_cluster_name=pxc_ubuntu_1
	wsrep_cluster_address=gcomm://192.168.122.201,192.168.122.202,192.168.122.203
	wsrep_node_address=192.168.122.202
	wsrep_provider=/usr/lib/libgalera_smm.so
	binlog_format=ROW
	default_storage_engine=InnoDB
	innodb_autoinc_lock_mode=2
	wsrep_sst_method=xtrabackup-v2
	wsrep_sst_auth="sstuser:s3cretPass"

Start mysql.

	sudo service mysql start

#### Verify pxc2

Execute the following query on mysql client.

	show status like 'wsrep%';

The output should look like below.

	wsrep_local_state_uuid      = xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
	...
	wsrep_local_state           = 4
	wsrep_local_state_comment   = Synced
	...
	wsrep_cluster_size          = 2
	wsrep_cluster_status        = Primary
	wsrep_connected             = ON
	...
	wsrep_ready                 = ON

#### Configure pxc3

Open pxc/mysql configuration file

	sudo vi /etc/mysql/my.cnf

Find the line 'bind-address = 127.0.0.1', and remove it or comment it out by prefixing the character '#'.
And then add the following lines under the section [mysqld].

	# ----------------
	# Cluster Settings
	# ----------------
	wsrep_cluster_name=pxc_ubuntu_1
	wsrep_cluster_address=gcomm://192.168.122.201,192.168.122.202,192.168.122.203
	wsrep_node_address=192.168.122.203
	wsrep_provider=/usr/lib/libgalera_smm.so
	binlog_format=ROW
	default_storage_engine=InnoDB
	innodb_autoinc_lock_mode=2
	wsrep_sst_method=xtrabackup-v2
	wsrep_sst_auth="sstuser:s3cretPass"

Start mysql.

	sudo service mysql start

#### Verify pxc3

Execute the following query on mysql client.

	show status like 'wsrep%';

The output should look like below.

	wsrep_local_state_uuid      = xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
	...
	wsrep_local_state           = 4
	wsrep_local_state_comment   = Synced
	...
	wsrep_cluster_size          = 3
	wsrep_cluster_status        = Primary
	wsrep_connected             = ON
	...
	wsrep_ready                 = ON

#### Verify replication in the whole cluster.

On pxc3,

	CREATE DATABASE testrep;

On pxc2,

	USE testrep;
	CREATE TABLE t1 (id INT PRIMARY KEY, name NVARCHAR(50));

On pxc1,

	INSERT INTO testrep.t1 VALUES (1, 'name #1');

On pxc3,

	SELECT * FROM testrep.t1;

## Install and configure HA-Proxy

On any cluster node, execute the following mysql queries to create a user for cluster check.

	GRANT PROCESS ON *.* TO 'clustercheckuser'@'localhost' IDENTIFIED BY 'clustercheckuserpass'; 
	FLUSH PRIVILEGES;

On all cluster nodes(pxc1, pxc2, pxc3), execute the following commands and mysql queries.

	sudo vi /usr/bin/clustercheck

Find the following 2 lines,

    MYSQL_USERNAME="${1-clustercheckuser}" 
    MYSQL_PASSWORD="${2-clustercheckpassword!}" 

and then replace them with below.

    MYSQL_USERNAME="clustercheckuser"
    MYSQL_PASSWORD="clustercheckuserpass"

Install xinetd.

	sudo apt-get install xinetd

Open the file /etc/services,

	sudo vi /etc/services

Append mysqlchk to the /etc/services

	mysqlchk			9200/tcp			# mysqlchk

Restart xinetd.

	sudo service xinetd restart

On the load balancer node (pxc0), runt the following commands to install haproxy.

	sudo apt-get update
	sudo apt-get install haproxy

After installation completes, open the haproxy configuration file,

	sudo vi /etc/haproxy/haproxy.cfg

Replace the content with below.

	global
		log /dev/log	local0
		log /dev/log	local1 notice
		chroot  /var/lib/haproxy
		user    haproxy
		group   haproxy
		daemon
	
	defaults
		log     global
		mode	http
		option	tcplog
		option	dontlognull
	    contimeout 5000
	    clitimeout 50000
	    srvtimeout 50000
		errorfile 400 /etc/haproxy/errors/400.http
		errorfile 403 /etc/haproxy/errors/403.http
		errorfile 408 /etc/haproxy/errors/408.http
		errorfile 500 /etc/haproxy/errors/500.http
		errorfile 502 /etc/haproxy/errors/502.http
		errorfile 503 /etc/haproxy/errors/503.http
		errorfile 504 /etc/haproxy/errors/504.http
	
	frontend pxc-front
		bind *:3307
		mode tcp
		default_backend pxc-back
	
	frontend stats-front
		bind *:8336
		mode http
		default_backend stats-back
	
	frontend pxc-onenode-front
		bind *:3306
		mode tcp
		default_backend pxc-onenode-back
	
	backend pxc-back
		mode tcp
		balance leastconn
		option httpchk
		server pxc1 192.168.122.201:3306 check port 9200 inter 12000 rise 3 fall 3
		server pxc2 192.168.122.202:3306 check port 9200 inter 12000 rise 3 fall 3
		server pxc3 192.168.122.203:3306 check port 9200 inter 12000 rise 3 fall 3
	
	backend stats-back
		mode http
		balance roundrobin
		stats uri /haproxy/stats
		stats auth pxcstats:secret
	
	backend pxc-onenode-back
		mode tcp
		balance leastconn
		option httpchk
		server pxc1 192.168.122.201:3306 check port 9200 inter 12000 rise 3 fall 3
		server pxc2 192.168.122.202:3306 check port 9200 inter 12000 rise 3 fall 3 backup
		server pxc3 192.168.122.203:3306 check port 9200 inter 12000 rise 3 fall 3 backup

Start haproxy with new configurations.

	sudo haproxy -f /etc/haproxy/haproxy.cfg

Verify if haproxy works. On a machine that has a browser installed and can access to pxc0/192.168.122.200, open the browser and type http://192.168.122.200:8336/haproxy/stats in the address bar. You'll see the response content containing tables.

## Test with sysbench

On any cluster node, execute mysql queries to create the database 'sbtest' and a user for sysbench.

	CREATE DATABASE sbtest; 
	GRANT ALL ON sbtest.* TO 'sbtestuser'@'%' IDENTIFIED BY 'sbtestuserpass'; 
	FLUSH PRIVILEGES;

On the load balancer node, install sysbench.

	sudo apt-get install sysbench

Now we can run sysbench test now. Please note, if the sysbench version on your machine is 0.5, replace '--test=oltp' with '--test=/usr/share/doc/sysbench/tests/db/oltp.lua'.

    sysbench --test=oltp --db-driver=mysql --mysql-engine-trx=yes --mysql-table-engine=innodb \
	--mysql-host=127.0.0.1 --mysql-port=3307 --mysql-user=sbtestuser --mysql-password=sbtestuserpass \
	--oltp-table-size=10000 prepare

    sysbench --test=oltp --db-driver=mysql --mysql-engine-trx=yes --mysql-table-engine=innodb \
	--mysql-host=127.0.0.1 --mysql-port=3307 --mysql-user=sbtestuser --mysql-password=sbtestuserpass \
	--oltp-table-size=10000 --num-threads=8 run

After threads started, refresh http://192.168.122.200:8336/haproxy/stats in your browser, you'll see the changes in the tables.
