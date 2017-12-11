#!/bin/bash

# This script is coded to help generate SSL certificates and secure your 
# Percona XtraDB cluster with the generated certificates in the following 
# vectors:
# 	1. replication traffic between PXC nodes
# 	2. SST (state snapshot transfer) between donor and joiner
#
# This script is only tested on CentOS 6.5 and Ubuntu 14.04 LTS with Percona
# XtraDB Cluster 5.6.

NODE1_HOST_NAME=$1
NODE2_HOST_NAME=$2
NODE3_HOST_NAME=$3
CERTS_FOLDER="~/certs"
MYSQL_CERTS_FOLDER="/etc/mysql/newcerts"
CA_DEFAULT_CN="PXC-CA"

# Pass the following information to openssl to generate certificate
#
# $COUNTRY	= Country Name (2 letter code) [AU]:
# $STATE	= State or Province Name (full name) [Some-State]:
# $CITY		= Locality Name (eg, city) []:
# $ORGA 	= Organization Name (eg, company) [Internet Widgits Pty Ltd]:
# $UNIT 	= Organizational Unit Name (eg, section) []:
# $CN		= Common Name (e.g. server FQDN or YOUR name) []:
# $EMAIL 	= Email Address []
#
# Below are asked only when signing a certificate request
#
# $PASSWORD	= A challenge password []:
# $COMPANY	= An optional company name []:

COUNTRY="."
STATE="."
CITY="."
ORGA="."
UNIT="."
CN="."
EMAIL="."
PASSWORD=""
COMPANY=""

# Generates CA key and CA certificate.
generate_ca_key_cert() {
	CN=$1
	echo ""
	echo "Generating CA key and certificate with the following fields ..."
	echo "    country      = $COUNTRY"
	echo "    state        = $STATE"
	echo "    city         = $CITY"
	echo "    organization = $ORGA"
	echo "    unit         = $UNIT"
	echo "    common name  = $CN"
	echo "    email        = $EMAIL"

	echo "$COUNTRY
$STATE
$CITY
$ORGA
$UNIT
$CN
$EMAIL
" | openssl req -newkey rsa:2048 -x509 -nodes -days 36500 -keyout "${CERTS_FOLDER}/pxc-ca.key" -out "${CERTS_FOLDER}/pxc-ca.pem"
	
	echo "Generating CA key and certificate with the following fields ... done."
}

# Generates key and certificate for a node.
generate_key_cert_for_node() {
	nodeName=$1
	CN=$nodeName
	
	echo ""
	echo "Generating key and certificate for the node: $nodeName ..."
	
	echo "$COUNTRY
$STATE
$CITY
$ORGA
$UNIT
$CN
$EMAIL
$PASSWORD
$COMPANY
" | openssl req -newkey rsa:2048 -nodes -days 36500 -keyout "${CERTS_FOLDER}/${nodeName}.key" -out "${CERTS_FOLDER}/${nodeName}.csr"
	openssl rsa -in "${CERTS_FOLDER}/${nodeName}.key" -out "${CERTS_FOLDER}/${nodeName}.key"
	openssl x509 -req -in "${CERTS_FOLDER}/${nodeName}.csr" -days 36500 -CA "${CERTS_FOLDER}/pxc-ca.pem" -CAkey "${CERTS_FOLDER}/pxc-ca.key" -set_serial 01 -out "${CERTS_FOLDER}/${nodeName}.pem"
	
	echo "Generating key and certificate for the node: $nodeName ... done."
}

# Stops MySQL(PXC) service on all nodes.
stop_mysql_service_on_all_nodes() {
	echo ""
	echo "trying to stop mysql service ..."
	echo "on local,"
	service mysql stop
	
	echo "on ${NODE2_HOST_NAME},"
	ssh root@${NODE2_HOST_NAME} "service mysql stop"
	
	echo "on ${NODE3_HOST_NAME},"
	ssh root@${NODE3_HOST_NAME} "service mysql stop"
}

# Starts MySQL(PXC) service on all nodes.
start_mysql_service_on_all_nodes() {
	echo ""
	echo "trying to start mysql service ..."
	echo "on local,"
	service mysql bootstrap-pxc
	
	echo "on ${NODE2_HOST_NAME},"
	ssh root@${NODE2_HOST_NAME} "service mysql start"
	
	echo "on ${NODE3_HOST_NAME},"
	ssh root@${NODE3_HOST_NAME} "service mysql start"
}

# Deploys key and cert on local.
deploy_key_cert_to_local() {
	echo ""
	echo "deploying key and certs to local ..."
	echo "creating $MYSQL_CERTS_FOLDER ..."
	create_directory $MYSQL_CERTS_FOLDER
	
	echo "copying key, cert and CA cert ..."
	cp "${CERTS_FOLDER}/${NODE1_HOST_NAME}.key" $MYSQL_CERTS_FOLDER
	cp "${CERTS_FOLDER}/${NODE1_HOST_NAME}.pem" $MYSQL_CERTS_FOLDER
	cp "${CERTS_FOLDER}/pxc-ca.pem" $MYSQL_CERTS_FOLDER
	echo "copying key, cert and CA cert ... done."
	
	chown -R mysql:mysql $MYSQL_CERTS_FOLDER
	chmod -R o-rwx $MYSQL_CERTS_FOLDER
	echo "deploying key and certs to local ... done."	
}

# Deploys key and cert to a specified node.
deploy_key_cert_to_node() {
	nodeName=$1
	
	echo ""
	echo "deploying key and certs to the node: ${nodeName} ..."
	echo "creating $MYSQL_CERTS_FOLDER ..."
	ssh root@${nodeName} "mkdir -p $MYSQL_CERTS_FOLDER"
	
	echo "copying key, cert and CA cert ..."
	scp "${CERTS_FOLDER}/${nodeName}.key" root@${nodeName}:$MYSQL_CERTS_FOLDER
	scp "${CERTS_FOLDER}/${nodeName}.pem" root@${nodeName}:$MYSQL_CERTS_FOLDER
	scp "${CERTS_FOLDER}/pxc-ca.pem" root@${nodeName}:$MYSQL_CERTS_FOLDER
	echo "copying key, cert and CA cert ... done."
	
	ssh root@${nodeName} "chown -R mysql:mysql $MYSQL_CERTS_FOLDER"
	ssh root@${nodeName} "chmod -R o-rwx $MYSQL_CERTS_FOLDER"
	echo "deploying key and certs to the node: ${nodeName} ... done."
}

# Gets my.cnf folder path.
get_mycnf_folder() {
	grep centos /proc/version > /dev/null 2>&1
	isCentOS=${?}
	if [ $isCentOS -eq 0 ]
	then
		echo "/etc"
	fi
	
	grep ubuntu /proc/version > /dev/null 2>&1
	isUbuntu=${?}
	if [ $isUbuntu -eq 0 ]
	then
		echo "/etc/mysql"
	fi
}

# Configures MySQL(PXC) on local by modifying my.cnf.
configure_mysql_on_local() {
	echo ""	
	echo "backuping my.cnf ..."
	mycnfFolder=$(get_mycnf_folder)
	myconfBackup=$(date +my.cnf.backup_%Y-%m-%d_%H%M%S)
	cp "${mycnfFolder}/my.cnf" "${mycnfFolder}/${myconfBackup}"
	echo "backuping my.cnf ... done."
	
	echo "configuring wsrep_provider_options in my.cnf on local ..."
	echo "commenting out wsrep_provider_options if it already exists ..."	
	echo "adding wsrep_provider_options under [mysqld] ..."
	wsrep_provider_options='wsrep_provider_options="socket.ssl_cert='${MYSQL_CERTS_FOLDER}'/'${NODE1_HOST_NAME}'.pem; socket.ssl_key='${MYSQL_CERTS_FOLDER}'/'${NODE1_HOST_NAME}'.key; socket.ssl_ca='${MYSQL_CERTS_FOLDER}'/pxc-ca.pem"'
	echo $wsrep_provider_options
	sed -i 's/^wsrep_provider_options/#wsrep_provider_options/g' ${mycnfFolder}/my.cnf
	sed -i "/^\[mysqld\]$/ a ${wsrep_provider_options}" ${mycnfFolder}/my.cnf
	echo "configuring wsrep_provider_options in my.cnf on local ... done."

	echo "configuring [sst] in my.cnf on local ..."
	sst=$(cat ${mycnfFolder}/my.cnf | grep -i '^\[sst\]$')
	if [ "$sst" != "[sst]" ];
	then
		echo "Not found [sst], adding one before [mysqld] ..."
		sed -i '/^\[mysqld\]$/ i [sst]' ${mycnfFolder}/my.cnf
	fi
	item_encrypt="encrypt=3"
	item_tkey="tkey=${MYSQL_CERTS_FOLDER}/${NODE1_HOST_NAME}.key"
	item_tcert="tcert=${MYSQL_CERTS_FOLDER}/${NODE1_HOST_NAME}.pem"
	sed -i "s/^encrypt/#encrypt/g" ${mycnfFolder}/my.cnf
	sed -i "s/^tkey/#tkey/g" ${mycnfFolder}/my.cnf
	sed -i "s/^tcert/#tcert/g" ${mycnfFolder}/my.cnf
	echo "adding $item_tcert ..."
	sed -i "/^\[sst\]$/ a $item_tcert" ${mycnfFolder}/my.cnf
	echo "adding $item_tkey ..."
	sed -i "/^\[sst\]$/ a $item_tkey" ${mycnfFolder}/my.cnf
	echo "adding $item_encrypt ..."
	sed -i "/^\[sst\]$/ a $item_encrypt" ${mycnfFolder}/my.cnf
	echo "configuring [sst] in my.cnf on local ... done."
}

# Configures MySQL(PXC) on a specified node by modifying my.cnf.
configure_mysql_on_node() {
	nodeName=$1
	
	echo ""
	echo "backuping my.cnf on node: $nodeName ..."
	mycnfFolder=$(get_mycnf_folder)
	myconfBackup=$(date +my.cnf.backup_%Y-%m-%d_%H%M%S)
	ssh root@$nodeName "cp ${mycnfFolder}/my.cnf ${mycnfFolder}/${myconfBackup}"
	echo "backuping my.cnf on node: $nodeName ... done."
	
	echo "configuring wsrep_provider_options in my.cnf on node: $nodeName ..."
	echo "commenting out wsrep_provider_options if it already exists ..."	
	echo "adding wsrep_provider_options under [mysqld] ..."
	wsrep_provider_options='wsrep_provider_options="socket.ssl_cert='${MYSQL_CERTS_FOLDER}'/'${nodeName}'.pem; socket.ssl_key='${MYSQL_CERTS_FOLDER}'/'${nodeName}'.key; socket.ssl_ca='${MYSQL_CERTS_FOLDER}'/pxc-ca.pem"'
	echo $wsrep_provider_options
	ssh root@$nodeName "sed -i 's/^wsrep_provider_options/#wsrep_provider_options/g' ${mycnfFolder}/my.cnf"
	ssh root@$nodeName "sed -i '/^\[mysqld\]$/ a ${wsrep_provider_options}' ${mycnfFolder}/my.cnf"
	echo "configuring wsrep_provider_options in my.cnf on node: $nodeName ... done."

	echo "configuring [sst] in my.cnf on node: $nodeName ..."
	sst=$(ssh root@$nodeName "cat ${mycnfFolder}/my.cnf | grep -i '^\[sst\]$'")
	if [ "$sst" != "[sst]" ];
	then
		echo "Not found [sst], adding one before [mysqld] ..."
		ssh root@$nodeName "sed -i '/^\[mysqld\]$/ i [sst]' ${mycnfFolder}/my.cnf"
	fi
	item_encrypt="encrypt=3"
	item_tkey="tkey=${MYSQL_CERTS_FOLDER}/${nodeName}.key"
	item_tcert="tcert=${MYSQL_CERTS_FOLDER}/${nodeName}.pem"
	ssh root@$nodeName "sed -i 's/^encrypt/#encrypt/g' ${mycnfFolder}/my.cnf"
	ssh root@$nodeName "sed -i 's/^tkey/#tkey/g' ${mycnfFolder}/my.cnf"
	ssh root@$nodeName "sed -i 's/^tcert/#tcert/g' ${mycnfFolder}/my.cnf"
	echo "adding $item_tcert ..."
	ssh root@$nodeName "sed -i '/^\[sst\]$/ a $item_tcert' ${mycnfFolder}/my.cnf"
	echo "adding $item_tkey ..."
	ssh root@$nodeName "sed -i '/^\[sst\]$/ a $item_tkey' ${mycnfFolder}/my.cnf"
	echo "adding $item_encrypt ..."
	ssh root@$nodeName "sed -i '/^\[sst\]$/ a $item_encrypt' ${mycnfFolder}/my.cnf"
	echo "configuring [sst] in my.cnf on node: $nodeName ... done."
}

# Creates a directory with a specified path.
create_directory() {
	dirPath=$1
	if [ -d $dirPath ];
	then
		echo "The folder $dirPath already exists!"
	else
		echo "The folder $dirPath does not exist! creating ..."
		mkdir -p $dirPath
		test -d $dirPath && echo "The folder $dirPath created."
	fi
}

# Tests if 'ssh root@nodeName' works by using key-based authentication (without entering password).
test_ssh_root_at_host() {
	nodeName=$1
	echo "testing ssh root@$nodeName ..."
	ssh root@$nodeName 'pwd' > /dev/null 2>&1
	sshnode2=${?}
	if [ $sshnode2 -ne 0 ];
	then
		echo "Can't ssh to root@$nodeName, please make sure you're using key-based SSH logins for root@$nodeName. For how-to, refer to the document [ https://help.ubuntu.com/community/SSH/OpenSSH/Keys ]."
		exit 3
	fi
}

#
echo "running $0 $1 $2 $3 ..."
echo "verifying parameters ..."
if [[ -z $NODE1_HOST_NAME || -z $NODE2_HOST_NAME || -z $NODE3_HOST_NAME ]];
then
    echo "Wrong usage: this script needs 3 host names as the parameters like below, each represents one of your PXC nodes."
    echo "================================="
    echo "./enable-ssl.sh node1 node2 node3"
    echo "================================="    
    exit 1
fi

echo "verifying the first parameter matches the host name ..."
hostName=$(hostname)
if [ "$hostName" != "$NODE1_HOST_NAME" ];
then
    echo "Wrong usage: the first host name '$1' is not valid."
    echo "The first host name should be the name of the node on which you're running this script. For example, you have 3 nodes (a-pxcnd, k-pxcnd, z-pxcnd) in your PXC, and you're going to run this script on the node 'a-pxcnd', enter 'a-pxcnd' as the first parameter like below."
    echo "======================================="
    echo "./enable-ssl.sh a-pxcnd k-pxcnd z-pxcnd"
    echo "======================================="
    exit 2
fi

test_ssh_root_at_host $NODE2_HOST_NAME
test_ssh_root_at_host $NODE3_HOST_NAME

create_directory $CERTS_FOLDER
generate_ca_key_cert $CA_DEFAULT_CN
generate_key_cert_for_node $NODE1_HOST_NAME
generate_key_cert_for_node $NODE2_HOST_NAME
generate_key_cert_for_node $NODE3_HOST_NAME
deploy_key_cert_to_local
deploy_key_cert_to_node $NODE2_HOST_NAME
deploy_key_cert_to_node $NODE3_HOST_NAME

stop_mysql_service_on_all_nodes
configure_mysql_on_local
configure_mysql_on_node $NODE2_HOST_NAME
configure_mysql_on_node $NODE3_HOST_NAME
start_mysql_service_on_all_nodes

exit 0