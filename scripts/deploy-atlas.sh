#!/bin/bash

#############################################################################################
#
# atlas version "2.1.0"
#
# install atlas
#
#############################################################################################

# get script directory and home directory
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"
# loading config file
source $HOME_DIR/conf/config.conf
# loading printf file
source $HOME_DIR/conf/printf.conf
# loading cluster nodes
IFS=',' read -ra workers <<<$HADOOP_WORKERS
# loading zookeeper nodes
IFS=',' read -ra zookeeper_nodes <<<$ZOOKEEPER_NODES

printf -- "${INFO}========== INSTALL ATLAS ==========${END}\n"
if [ -d $PROJECT_DIR/atlas* ]; then
    printf -- "${SUCCESS}========== ATLAS INSTALLED ==========${END}\n"
    printf -- "\n"
    exit 0
fi

#############################################################################################
# install atlas
#############################################################################################
printf -- "${INFO}>>> Install atlas.${END}\n"
pv $HOME_DIR/softwares/atlas/apache-atlas-2.1.0-server.tar.gz | tar -zx -C $PROJECT_DIR/
# modify directory name
mv $PROJECT_DIR/apache-atlas* $PROJECT_DIR/atlas

#############################################################################################
# configure atlas
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure atlas.${END}\n"

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

APPLICATION_PROPERTIES_FILE=$PROJECT_DIR/atlas/conf/atlas-application.properties

sed -i -r '/^atlas\.graph\.storage\.hostname/s|.*|atlas\.graph\.storage\.hostname="'$zookeeper_servers'"|' $APPLICATION_PROPERTIES_FILE

echo "# hbase conf dir" >>$PROJECT_DIR/atlas/conf/atlas-env.sh
echo 'export HBASE_CONF_DIR='$HBASE_HOME/conf >>$PROJECT_DIR/atlas/conf/atlas-env.sh

# -------------------------------------------------------------------------------------------
# registry server config
# -------------------------------------------------------------------------------------------