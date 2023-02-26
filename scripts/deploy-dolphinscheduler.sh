#!/bin/bash

#############################################################################################
#
# dolphinscheduler version "2.0.5"
#
# configure dolphinscheduler
#
#############################################################################################

# get script directory and home directory
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"
# loading config file
source $HOME_DIR/conf/config.conf
# loading printf file
source $HOME_DIR/conf/printf.conf
# loading environment
source /etc/profile
# loading dolphinscheduler nodes
IFS=',' read -ra dolphinscheduler_nodes <<<$DOLPHINSCHEDULER_NODES
# loading zookeeper nodes
IFS=',' read -ra zookeeper_nodes <<<$ZOOKEEPER_NODES
# loading hadoop nodes
IFS=',' read -ra workers <<<$HADOOP_dolphinscheduler_workers

#############################################################################################
# install dolphinscheduler
#############################################################################################
DOLPHINSCHEDULER_TMP_DIR=$HOME_DIR/softwares/dolphinscheduler
if [ -d $DOLPHINSCHEDULER_TMP_DIR ]; then
    rm -rf $DOLPHINSCHEDULER_TMP_DIR
fi
mkdir $DOLPHINSCHEDULER_TMP_DIR
pv $HOME_DIR/softwares/apache-dolphinscheduler-2.0.5-bin.tar.gz | tar -zx -C $DOLPHINSCHEDULER_TMP_DIR --strip-components 1

#############################################################################################
# configure dolphinscheduler inftall conf file
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure dolphinscheduler install config.${END}\n"

DOLPHINSCHEDULER_INSTALL_CONF=$DOLPHINSCHEDULER_TMP_DIR/conf/config/install_config.conf

i=1
dolphinscheduler_workers=""
length=${#dolphinscheduler_nodes[@]}
for node in ${dolphinscheduler_nodes[@]}; do
    if [ $i -eq $length ]; then
        dolphinscheduler_workers="$dolphinscheduler_workers$node:default"
    else
        dolphinscheduler_workers="$dolphinscheduler_workers$node:default,"
    fi
    let i+=1
done

i=1
zookeeper_servers=""
length=${#zookeeper_nodes[@]}
for node in ${zookeeper_nodes[@]}; do
    if [ $i -eq $length ]; then
        zookeeper_servers="$zookeeper_servers$node:2181"
    else
        zookeeper_servers="$zookeeper_servers$node:2181,"
    fi
    let i+=1
done
# -------------------------------------------------------------------------------------------
# install machine config
# -------------------------------------------------------------------------------------------
sed -i -r '/^ips/s|.*|ips='\"$DOLPHINSCHEDULER_NODES\"'|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^masters/s|.*|masters='\"${dolphinscheduler_nodes[2]}\"'|' $DOLPHINSCHEDULER_INSTALL_CONF

sed -i -r '/^dolphinscheduler_workers/s|.*|dolphinscheduler_workers='\"${dolphinscheduler_workers}\"'|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^alertServer/s|.*|alertServer='\"${dolphinscheduler_nodes[2]}\"'|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^apiServers/s|.*|apiServers='\"${dolphinscheduler_nodes[2]}\"'|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^pythonGatewayServers/s|(.*)|# \1|' $DOLPHINSCHEDULER_INSTALL_CONF

installPath=$PROJECT_DIR/dolphinscheduler
sed -i -r '/^installPath/s|.*|installPath='\"$installPath\"'|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^deployUser/s|.*|deployUser="root"|' $DOLPHINSCHEDULER_INSTALL_CONF

# -------------------------------------------------------------------------------------------
# dolphinscheduler env config
# -------------------------------------------------------------------------------------------
sed -i -r '/^javaHome/s|.*|javaHome='\"$JAVA_HOME\"'|' $DOLPHINSCHEDULER_INSTALL_CONF

# -------------------------------------------------------------------------------------------
# database config
# -------------------------------------------------------------------------------------------
sed -i -r '/^DATABASE_TYPE/s|.*|DATABASE_TYPE="mysql"|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^SPRING_DATASOURCE_URL/s|.*|SPRING_DATASOURCE_URL="jdbc:mysql://'${workers[0]}':3306/dolphinscheduler?useUnicode=true\&characterEncoding=UTF-8"|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^SPRING_DATASOURCE_USERNAME/s|.*|SPRING_DATASOURCE_USERNAME="'$MYSQL_DOLPHINSCHEDULER_USER'"|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^SPRING_DATASOURCE_PASSWORD/s|.*|SPRING_DATASOURCE_PASSWORD="'$MYSQL_DOLPHINSCHEDULER_PASS'"|' $DOLPHINSCHEDULER_INSTALL_CONF

# -------------------------------------------------------------------------------------------
# registry server config
# -------------------------------------------------------------------------------------------
sed -i -r '/^registryServers/s|.*|registryServers='\"${zookeeper_servers}\"'|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^registryNamespace/s|.*|registryNamespace="dolphinscheduler"|' $DOLPHINSCHEDULER_INSTALL_CONF

# -------------------------------------------------------------------------------------------
# dolphinscheduler_workers task server config
# -------------------------------------------------------------------------------------------
sed -i -r '/^resourceStorageType/s|.*|resourceStorageType="HDFS"|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^defaultFS/s|.*|defaultFS="hdfs://'${workers[0]}':8020"|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^yarnHaIps/s|.*|yarnHaIps=|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^singleYarnIp/s|.*|singleYarnIp="'${workers[1]}'"|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^hdfsRootUser/s|.*|hdfsRootUser="'$HADOOP_USER'"|' $DOLPHINSCHEDULER_INSTALL_CONF
