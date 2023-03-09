# Marmot

![marmot](https://img.shields.io/badge/marmot-v0.0.3-blue)


> **This project is use for testing now. Not prepared for production.**

<!-- [中文版](translations/README-cn.md) -->

## Architecture
![hadoop architecture](https://development-1253817761.cos.ap-chengdu.myqcloud.com/marmot/hadoop%20architecture.png)

## Environments
* MySQL `5.7.16`
* Hadoop `3.1.3`
* Spark `3.0.0`
* Hive `3.1.2`
* Dolphinscheduler `2.0.5`
* Zookeeper `3.5.7`
* Kettle `7.1.0`

## OS Adaptation
* CentOS `7.5`

## Cluster Node
* 192.168.10.101
* 192.168.10.102
* 192.168.10.103
* 192.168.10.104

## Downloads

### Scripts
[Latest Release Url](https://github.com/wangenyong/marmot/releases/tag/v0.0.3)

### Softwares dependencies
[Baidu Netdisk Url](https://pan.baidu.com/s/1koS5BsZcj-6DTjGW2_eEaw?pwd=n4am)

## Install
Copy script files to first node of cluster.
```bash
scp marmot-0.0.3.tar.gz root@192.168.10.101:/root/
```
Decompress to the current directory.
```bash
ssh root@192.168.10.101
tar -zxvf marmot-0.0.3.tar.gz
```
Copy softwares to marmot project directory.
```bash
scp -v -r softwares root@192.168.10.101:/root/marmot/
```
Final project dir list:
```bash
[root@hadoop101 ~]# tree marmot
marmot
├── README.md
├── conf
│   ├── config.conf
│   ├── printf.conf
│   └── welcome.figlet
├── scripts
│   ├── config-environment.sh
│   ├── deploy-azkaban.sh
│   ├── deploy-dolphinscheduler.sh
│   ├── deploy-flink.sh
│   ├── deploy-hadoop.sh
│   ├── deploy-hive.sh
│   ├── deploy-jdk.sh
│   ├── deploy-kafka.sh
│   ├── deploy-kettle.sh
│   ├── deploy-mysql.sh
│   ├── deploy-spark.sh
│   ├── deploy-sqoop.sh
│   ├── deploy-vsftp.sh
│   ├── deploy-zookeeper.sh
│   ├── marmot
│   └── msync
├── softwares
│   ├── apache-dolphinscheduler-2.0.5-bin.tar.gz
│   ├── apache-dolphinscheduler-2.0.8-bin.tar.gz
│   ├── apache-dolphinscheduler-3.1.4-bin.tar.gz
│   ├── apache-hive-3.1.2-bin.tar.gz
│   ├── apache-zookeeper-3.5.7-bin.tar.gz
│   ├── azkaban
│   │   ├── azkaban-db-3.84.4.tar.gz
│   │   ├── azkaban-exec-server-3.84.4.tar.gz
│   │   └── azkaban-web-server-3.84.4.tar.gz
│   ├── flink-1.13.0-bin-scala_2.12.tgz
│   ├── hadoop-3.1.3.tar.gz
│   ├── jars
│   │   ├── hadoop-lzo-0.4.20.jar
│   │   └── sqljdbc4.jar
│   ├── jdk-8u212-linux-x64.tar.gz
│   ├── kafka_2.11-2.4.1.tgz
│   ├── kafka_2.12-3.0.0.tgz
│   ├── mysql
│   │   ├── 01_mysql-community-common-5.7.16-1.el7.x86_64.rpm
│   │   ├── 02_mysql-community-libs-5.7.16-1.el7.x86_64.rpm
│   │   ├── 03_mysql-community-libs-compat-5.7.16-1.el7.x86_64.rpm
│   │   ├── 04_mysql-community-client-5.7.16-1.el7.x86_64.rpm
│   │   ├── 05_mysql-community-server-5.7.16-1.el7.x86_64.rpm
│   │   ├── mysql-connector-java-5.1.27-bin.jar
│   │   └── mysql-connector-java-8.0.16.jar
│   ├── packages
│   │   ├── psmisc-22.20-17.el7.x86_64.rpm
│   │   ├── pv-1.4.6-1.el7.x86_64.rpm
│   │   ├── rsync-3.1.2-10.el7.x86_64.rpm
│   │   ├── sshpass-1.06-1.el7.x86_64.rpm
│   │   ├── unzip-6.0-21.el7.x86_64.rpm
│   │   └── vsftpd-3.0.2-28.el7.x86_64.rpm
│   ├── pdi-ce-7.1.0.0-12.zip
│   ├── spark-3.0.0-bin-hadoop3.2.tgz
│   ├── spark-3.0.0-bin-without-hadoop.tgz
│   └── sqoop-1.4.6.bin__hadoop-2.0.4-alpha.tar.gz
├── template
│   └── configuration.xml
├── tips.md
└── translations
    └── README-cn.md
```

## Usage

### Edit the configuration file `conf/config.conf`

```bash
# project home dir
PROJECT_DIR="/opt/marmot"
MARMOT_PROFILE="/etc/profile.d/marmot_env.sh"
# operation environment, software dependency
ENVIRONMENT_STATUS=1

# administrator user info
ADMIN_USER="root"
ADMIN_PASS="660011"

# hadoop user info
HADOOP_USER="marmot"
HADOOP_PASS="marmot"

# hadoop clusters
HADOOP_WORKERS="192.168.10.101,192.168.10.102,192.168.10.103,192.168.10.104"

# kettle user info
KETTLE_USER="kettle"
KETTLE_PASS="kettle"

# kettle clusters
KETTLE_NODES="192.168.10.80,192.168.10.81"

MYSQL_ROOT_PASS="yee-ha7X"
MYSQL_NORMAL_USER="marmot"
MYSQL_NORMAL_PASS="Phee]d1f"
MYSQL_AZKABAN_USER="azkaban"
MYSQL_AZKABAN_PASS="Tai~pui2"
MYSQL_DOLPHINSCHEDULER_USER="dolphinscheduler"
MYSQL_DOLPHINSCHEDULER_PASS="Quie<Du4"

# azkaban clusters
AZKABAN_NODES="192.168.10.101,192.168.10.102,192.168.10.103"
AZKABAN_USER="marmot"
AZKABAN_PASS="azkaban"

# zookeeper clusters
ZOOKEEPER_NODES="192.168.10.101,192.168.10.102,192.168.10.103,192.168.10.104"

# kafka clusters
KAFKA_NODES="192.168.10.101,192.168.10.102,192.168.10.103"

# dolphinscheduler clusters
DOLPHINSCHEDULER_NODES="192.168.10.101,192.168.10.102,192.168.10.103,192.168.10.104"
```

### Enter the project directory
```bash
ssh root@192.168.10.101
cd marmot
```
### Install hadoop
```bash
./scripts/marmot install hadoop
```
### Start hadoop
```bash
./scripts/marmot start hadoop
```
### Show hadoop status
```bash
./scripts/marmot status hadoop
```
### Stop hadoop
```bash
./scripts/marmot stop hadoop
```
### Remove hadoop
```bash
./scripts/marmot remove hadoop
```

## Common Service Address

* HDFS NameNode: http://192.168.10.101:9870
* YARN ResourceManager: http://192.168.10.102:8088
* JobHistory: http://192.168.10.101:19888/jobhistory
* Dolphinscheduler http://192.168.10.104:12345/dolphinscheduler
* Kettle master http://192.168.10.80:8080/
* Kettle cluster01 http://192.168.10.81:8081/
