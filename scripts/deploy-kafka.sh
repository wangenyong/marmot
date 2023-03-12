#!/bin/bash

#############################################################################################
#
# kafka version "3.0.0"
#
# configure kafka
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
# loading kafka nodes
IFS=',' read -ra kafka_nodes <<<$KAFKA_NODES

printf -- "${INFO}========== INSTALL KAFKA ==========${END}\n"
if [ -d $PROJECT_DIR/kafka* ]; then
    printf -- "${SUCCESS}========== KAFKA INSTALLED ==========${END}\n"
    printf -- "\n"
    exit 0
fi

#############################################################################################
# install zookeeper
#############################################################################################
printf -- "${INFO}>>> Install kafka.${END}\n"
pv $HOME_DIR/softwares/kafka/kafka_${kafka_version}-3.0.0.tgz | tar -zx -C $PROJECT_DIR/
mv $PROJECT_DIR/kafka* $PROJECT_DIR/kafka-${kafka_version}

#############################################################################################
# configure environment variables
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure kafka environment variables.${END}\n"

if [ $(grep -c "KAFKA_HOME" $MARMOT_PROFILE) -eq '0' ]; then
    KAFKA_PATH="KAFKA_HOME="$PROJECT_DIR/kafka-${kafka_version}

    echo -e >>$MARMOT_PROFILE
    echo '#***** KAFKA_HOME *****' >>$MARMOT_PROFILE
    echo "export "$KAFKA_PATH >>$MARMOT_PROFILE
    echo 'export PATH=$PATH:$KAFKA_HOME/bin' >>$MARMOT_PROFILE

    source /etc/profile
    printf -- "${SUCCESS}KAFKA_HOME configure successful: $KAFKA_HOME${END}\n"
else
    source /etc/profile
    printf -- "${WARN}KAFKA_HOME configurtion is complete.${END}\n"
fi

#############################################################################################
# configure kafka cluster nodes
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure kakfa cluster nodes.${END}\n"

if [ ! -d "$KAFKA_HOME/logs" ]; then
    mkdir -p $KAFKA_HOME/logs

    i=1
    connect=""
    length=${#kafka_nodes[@]}
    for node in ${kafka_nodes[@]}; do
        if [ $i -eq $length ]; then
            connect="$connect$node:2181/kafka"
        else
            connect="$connect$node:2181,"
        fi
        let i+=1
    done
    cp $KAFKA_HOME/config/server.properties $KAFKA_HOME/config/server.properties.bak
    sed -i -r '/^log.dirs/s|.*|log.dirs='$KAFKA_HOME'/logs|' $KAFKA_HOME/config/server.properties
    sed -i -r '/^zookeeper.connect=/s|.*|zookeeper.connect='$connect'|' $KAFKA_HOME/config/server.properties

    # modify permissions
    chown $HADOOP_USER:$HADOOP_USER -R $KAFKA_HOME

    # distributing kafka
    sh $SCRIPT_DIR/msync $KAFKA_NODES $KAFKA_HOME
    # distributing environment variables
    sh $SCRIPT_DIR/msync $KAFKA_NODES /etc/profile.d/marmot_env.sh

    i=1
    for node in ${kafka_nodes[@]}; do
        cmd="sed -i -r '/^broker.id=/s|.*|broker.id='$i'|' $KAFKA_HOME/config/server.properties"
        ssh $HADOOP_USER@$node $cmd
        let i+=1
    done
    printf -- "${SUCCESS}Configure kafka successful.${END}\n"
else
    printf -- "${SUCCESS}Kafka configurtion is complete.${END}\n"
fi

printf -- "\n"
printf -- "${SUCCESS}========== KAFKA INSTALL SUCCESSFUL ==========${END}\n"