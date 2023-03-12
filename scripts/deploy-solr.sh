#!/bin/bash

#############################################################################################
#
# solr version "7.7.3"
#
# configure solr
#
#############################################################################################

# get script directory and home directory
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"
# loading config file
source $HOME_DIR/conf/config.conf
# loading printf file
source $HOME_DIR/conf/printf.conf
# loading version file
source $HOME_DIR/conf/version.conf
# loading cluster nodes
IFS=',' read -ra workers <<<$HADOOP_WORKERS
# loading zookeeper nodes
IFS=',' read -ra zookeeper_nodes <<<$ZOOKEEPER_NODES

printf -- "${INFO}========== INSTALL SOLR ==========${END}\n"
if [ -d $PROJECT_DIR/solr* ]; then
    printf -- "${SUCCESS}========== SOLR INSTALLED ==========${END}\n"
    printf -- "\n"
    exit 0
fi

#############################################################################################
# install solr
#############################################################################################
printf -- "${INFO}>>> Install solr.${END}\n"
pv $HOME_DIR/softwares/solr/solr-${solr_version}.tgz | tar -zx -C $PROJECT_DIR/

#############################################################################################
# configure solr
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure solr solr.in.sh.${END}\n"

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

sed -i -r '/^#ZK_HOST/s|.*|ZK_HOST="'$zookeeper_servers'"|' $PROJECT_DIR/solr-${solr_version}/bin/solr.in.sh

#############################################################################################
# distributing solr
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Distributing solr to all cluster nodes.${END}\n"

# modify permissions
chown $SOLR_USER:$SOLR_USER -R $PROJECT_DIR/solr-${solr_version}
# distributing hive
sh $SCRIPT_DIR/msync $HADOOP_WORKERS $PROJECT_DIR/solr-${solr_version}

printf -- "\n"
printf -- "${SUCCESS}========== SOLR INSTALL SUCCESSFUL ==========${END}\n"