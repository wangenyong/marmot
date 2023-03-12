#!/bin/bash

#############################################################################################
#
# zookeeper version "3.5.7"
#
# configure zookeeper
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
# loading zookeeper nodes
IFS=',' read -ra zookeeper_nodes <<<$ZOOKEEPER_NODES

printf -- "${INFO}========== INSTALL ZOOKEEPER ==========${END}\n"
if [ -d $PROJECT_DIR/zookeeper* ]; then
    printf -- "${SUCCESS}========== ZOOKEEPER INSTALLED ==========${END}\n"
    printf -- "\n"
    exit 0
fi

#############################################################################################
# install zookeeper
#############################################################################################
printf -- "${INFO}>>> Install zookeeper.${END}\n"
pv $HOME_DIR/softwares/hadoop/apache-zookeeper-${zookeeper_version}-bin.tar.gz | tar -zx -C $PROJECT_DIR/
mv $PROJECT_DIR/apache-zookeeper* $PROJECT_DIR/zookeeper-${zookeeper_version}

#############################################################################################
# configure environment variables
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure zookeeper environment variables.${END}\n"

if [ $(grep -c "ZOOKEEPER_HOME" $MARMOT_PROFILE) -eq '0' ]; then
    ZOOKEEPER_PATH="ZOOKEEPER_HOME="$PROJECT_DIR/zookeeper-${zookeeper_version}

    echo -e >>$MARMOT_PROFILE
    echo '#***** ZOOKEEPER_HOME *****' >>$MARMOT_PROFILE
    echo "export "$ZOOKEEPER_PATH >>$MARMOT_PROFILE

    source /etc/profile
    printf -- "${SUCCESS}ZOOKEEPER_HOME configure successful: $ZOOKEEPER_HOME${END}\n"
else
    source /etc/profile
    printf -- "${WARN}ZOOKEEPER_HOME configurtion is complete.${END}\n"
fi

#############################################################################################
# configure zookeeper cluster nodes
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure zookeeper cluster nodes.${END}\n"

if [ ! -d "$ZOOKEEPER_HOME/data" ]; then
    mkdir -p $ZOOKEEPER_HOME/data
    touch $ZOOKEEPER_HOME/data/myid

    mv $ZOOKEEPER_HOME/conf/zoo_sample.cfg $ZOOKEEPER_HOME/conf/zoo.cfg

    sed -i -r '/^dataDir/s|.*|dataDir='$ZOOKEEPER_HOME'/data|' $ZOOKEEPER_HOME/conf/zoo.cfg
    echo "########## cluster ###########" >>$ZOOKEEPER_HOME/conf/zoo.cfg

    # modify permissions
    chown $HADOOP_USER:$HADOOP_USER -R $ZOOKEEPER_HOME

    # distributing zookeeper
    sh $SCRIPT_DIR/msync $ZOOKEEPER_NODES $ZOOKEEPER_HOME
    # distributing environment variables
    sh $SCRIPT_DIR/msync $ZOOKEEPER_NODES /etc/profile.d/marmot_env.sh

    i=1
    for node in ${zookeeper_nodes[@]}; do
        echo "server.$i=$node:2888:3888" >>$ZOOKEEPER_HOME/conf/zoo.cfg
        ssh $HADOOP_USER@$node "echo $i >>$ZOOKEEPER_HOME/data/myid"
        let i+=1
    done
    # adapt to solr
    echo "4lw.commands.whitelist=mntr,conf,ruok" >>$ZOOKEEPER_HOME/conf/zoo.cfg

    # distributing zookeeper config file
    sh $SCRIPT_DIR/msync $ZOOKEEPER_NODES $ZOOKEEPER_HOME/conf/zoo.cfg
    
    printf -- "${SUCCESS}Configure zookeeper successful.${END}\n"
else
    printf -- "${SUCCESS}Zookeeper configurtion is complete.${END}\n"
fi

printf -- "\n"
printf -- "${SUCCESS}========== ZOOKEEPER INSTALL SUCCESSFUL ==========${END}\n"