# Backup PXC with Percona XtraBackup

This document will introduce you to how to backup databases in a Percona XtraDB cluster with Percona XtraBackup. XtraBackup is a MySQL/PXC hot backup tool that performs non-blocking backups for InnoDB and XtraDB databases.

Assuming that you've deployed a PXC cluster on Azure with the template [here] (https://github.com/Azure/azure-quickstart-templates/tree/master/mysql-ha-pxc) and got the following output:

* The cluster consists of **1** Azure load balancer and **3** PXC nodes.
* The load balancer gets a public IP address assigned. (Assume that the IP address is **7.7.7.7**. Yours must be different from this.)
* All these 3 PXC nodes are built on CentOS by default.
* The 3 PXC node names are **a-pxcnd**, **k-pxcnd**, **z-pxcnd** respectively.
* The SSH ports for the 3 PXC nodes are **64001**, **64002**, **64003** respectively.

Before start to backup databases, we need to create a directory to store backups and a database user to perform backup. In this document we choose **a-pxcnd** as the node to store backups. Log on **a-pxcnd**.

    ssh pxcuser@7.7.7.7 -p 64001

Create a directory to store backups.

    sudo mkdir -p /pxc/backups

Open mysql command-line client, and create a user to perform backup.

    mysql> grant select, super, reload, replication client on *.* to 'backupuser'@'localhost';
    mysql> flush privileges;

#### Create a standard full backup

The command below will copy all your databases in the datadir specified in your my.cnf to the directory /pxc/backups.

    sudo innobackupex --user=backupuser /pxc/backups

If backup succeeds, you should see a line like below at the end of the output.

    150826 08:39:26  innobackupex: completed OK!

Check /pxc/backups, you should see a time stamped subdirectory.

    ls /pxc/backups

#### Create a streamed, compressed and encrypted full backup

Generate an encryption key.

    openssl rand -base64 24 | tee keyfile

The output looks like below.

    lMVmOQAmxxBsXawPMfpw8bJwNA0Rgxxh

Make a streamed, compressed and encrypted backup.

    sudo innobackupex --user=backupuser --stream=xbstream --compress --encrypt=AES256 \
    --encrypt-key='lMVmOQAmxxBsXawPMfpw8bJwNA0Rgxxh' ./ > ./full.xbstream; sudo mv ./full.xbstream /pxc/backups/

#### Create incremental backups

To create incremental backups, you need a full backup as the base.

    sudo innobackupex --user=backupuser --no-timestamp /pxc/backups/full

Create an incremental backup **inc1**.

    sudo innobackupex --user=backupuser --no-timestamp /pxc/backups/inc1 --incremental --incremental-basedir=/pxc/backups/full

Create another incremental backup **inc2**.

    sudo innobackupex --user=backupuser --no-timestamp /pxc/backups/inc2 --incremental --incremental-basedir=/pxc/backups/inc1

#### Automate backup with CRON

Open root's cron table.

    sudo crontab -u root -e

Add the following line to the cron table.

    0 2 * * * innobackupex --user=backupuser --stream=xbstream --compress --encrypt=AES256 --encrypt-key='lMVmOQAmxxBsXawPMfpw8bJwNA0Rgxxh' ./ > ./full.xbstream; sudo mv ./full.xbstream /pxc/backups/

 This will perform a full, streamed, compressed and encrypted backup at 2:00 a.m. every day. If you want to automate incremental backups with CRON, you can code a shell script to do this. Assuming that the script name is **incrementalbackup.sh**, add below to root's cron table.

    */30 * * * * incrementalbackup.sh

This will create an incremental backup at every 30 minutes. Save and exit, CRON will do backup work for you in the background.