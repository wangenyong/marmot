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
pv $HOME_DIR/softwares/solr-7.7.3.tgz | tar -zx -C $PROJECT_DIR/

#############################################################################################
# configure environment variables
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure solr environment variables.${END}\n"

if [ $(grep -c "SOLR_HOME" $MARMOT_PROFILE) -eq '0' ]; then
    cd $PROJECT_DIR/solr*
    SOLR_PATH="SOLR_HOME="$(pwd)
    cd - >/dev/null 2>&1

    echo -e >>$MARMOT_PROFILE
    echo '#***** SOLR_HOME *****' >>$MARMOT_PROFILE
    echo "export "$SOLR_PATH >>$MARMOT_PROFILE

    source /etc/profile
    printf -- "${SUCCESS}SOLR_HOME configure successful: $SOLR_HOME${END}\n"
else
    source /etc/profile
    printf -- "${WARN}SOLR_HOME configurtion is complete.${END}\n"
fi

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

sed -i -r '/^#ZK_HOST/s|.*|ZK_HOST="'$zookeeper_servers'"|' $SOLR_HOME/bin/solr.in.sh

#############################################################################################
# distributing solr
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Distributing solr to all cluster nodes.${END}\n"

# modify permissions
chown $HADOOP_USER:$HADOOP_USER -R $SOLR_HOME
# distributing hive
sh $SCRIPT_DIR/msync $HADOOP_WORKERS $SOLR_HOME
printf -- "\n"
# distributing environment variables
sh $SCRIPT_DIR/msync $HADOOP_WORKERS /etc/profile.d/marmot_env.sh

printf -- "\n"
printf -- "${SUCCESS}========== SOLR INSTALL SUCCESSFUL ==========${END}\n"