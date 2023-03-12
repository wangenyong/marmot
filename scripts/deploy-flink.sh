#!/bin/bash

#############################################################################################
#
# hadoop version "1.13.0"
#
# install and configuer flink
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

printf -- "${INFO}========== INSTALL FLINK ==========${END}\n"
if [ -d $PROJECT_DIR/flink* ]; then
    printf -- "${SUCCESS}========== FLINK INSTALLED ==========${END}\n"
    printf -- "\n"
    exit 0
fi

#############################################################################################
# install flink
#############################################################################################
printf -- "${INFO}>>> Install flink.${END}\n"
pv $HOME_DIR/softwares/hadoop/flink-${flink_version}-*.tgz | tar -zx -C $PROJECT_DIR/

#############################################################################################
# configure environment variables
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure flink environment variables.${END}\n"

if [ $(grep -c "FLINK_HOME" $MARMOT_PROFILE) -eq '0' ]; then
    FLINK_PATH="FLINK_HOME="$PROJECT_DIR/flink-${flink_version}

    echo -e >>$MARMOT_PROFILE
    echo '#***** FLINK_HOME *****' >>$MARMOT_PROFILE
    echo "export "$FLINK_PATH >>$MARMOT_PROFILE
    echo 'export PATH=$PATH:$FLINK_HOME/bin' >>$MARMOT_PROFILE

    source /etc/profile
    printf -- "${SUCCESS}FLINK_HOME configure successful: $FLINK_HOME${END}\n"
else
    source /etc/profile
    printf -- "${WARN}FLINK_HOME configurtion is complete.${END}\n"
fi

#############################################################################################
# distributing flink
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Distributing flink to all cluster nodes.${END}\n"

# modify permissions
chown $HADOOP_USER:$HADOOP_USER -R $FLINK_HOME
# distributing flink
sh $SCRIPT_DIR/msync $HADOOP_WORKERS $FLINK_HOME
printf -- "\n"
# distributing environment variables
sh $SCRIPT_DIR/msync $HADOOP_WORKERS /etc/profile.d/marmot_env.sh

printf -- "\n"
printf -- "${SUCCESS}========== FLINK INSTALL SUCCESSFUL ==========${END}\n"