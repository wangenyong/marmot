#!/bin/bash

#############################################################################################
#
# datax version "2.4.11"
#
# configure datax
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

printf -- "${INFO}========== INSTALL DATAX ==========${END}\n"
if [ -d $PROJECT_DIR/datax ]; then
    printf -- "${SUCCESS}========== DATAX INSTALLED ==========${END}\n"
    printf -- "\n"
    exit 0
fi

#############################################################################################
# install datax
#############################################################################################
printf -- "${INFO}>>> Install datax.${END}\n"
pv $HOME_DIR/softwares/datax.tar.gz | tar -zx -C $PROJECT_DIR/

#############################################################################################
# configure environment variables
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure datax environment variables.${END}\n"

if [ $(grep -c "DATAX_HOME" $MARMOT_PROFILE) -eq '0' ]; then
    DATAX_PATH="DATAX_HOME="$PROJECT_DIR/datax

    echo -e >>$MARMOT_PROFILE
    echo '#***** DATAX_HOME *****' >>$MARMOT_PROFILE
    echo "export "$mDATAX_PATH >>$MARMOT_PROFILE

    source /etc/profile
    printf -- "${SUCCESS}DATAX_HOME configure successful: $DATAX_HOME${END}\n"
else
    source /etc/profile
    printf -- "${WARN}DATAX_HOME configurtion is complete.${END}\n"
fi

#############################################################################################
# distributing datax
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Distributing datax to all cluster nodes.${END}\n"

# modify permissions
chown $HADOOP_USER:$HADOOP_USER -R $DATAX_HOME
# distributing hive
sh $SCRIPT_DIR/msync $HADOOP_WORKERS $DATAX_HOME
printf -- "\n"
# distributing environment variables
sh $SCRIPT_DIR/msync $HADOOP_WORKERS /etc/profile.d/marmot_env.sh

printf -- "\n"
printf -- "${SUCCESS}========== DATAX INSTALL SUCCESSFUL ==========${END}\n"