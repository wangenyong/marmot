#!/bin/bash

#############################################################################################
#
# java version "1.8.0_212"
#
# configure java sdk
#
#############################################################################################

# get script directory and home directory
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"
# loading config file
source $HOME_DIR/conf/config.conf
# loading printf file
source $HOME_DIR/conf/printf.conf

printf -- "${INFO}========== INSTALL JAVA SDK ==========${END}\n"
if [ -d $PROJECT_DIR/jdk* ]; then
    printf -- "${SUCCESS}========== JAVA SDK INSTALLED ==========${END}\n"
    printf -- "\n"
    exit 0
fi

#############################################################################################
# install java sdk
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Install java sdk.${END}\n"
pv $HOME_DIR/softwares/jdk-8u212-linux-x64.tar.gz | tar -zx -C $PROJECT_DIR/

#############################################################################################
# configure environment variables
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure java environment variables.${END}\n"

if [ $(grep -c "JAVA_HOME" $MARMOT_PROFILE) -eq '0' ]; then
    cd $PROJECT_DIR/jdk*
    JDK_PATH="JAVA_HOME=$(pwd)"
    cd - >/dev/null 2>&1

    echo '#***** JAVA_HOME *****' >>$MARMOT_PROFILE
    echo "export $JDK_PATH" >>$MARMOT_PROFILE
    echo 'export PATH=$PATH:$JAVA_HOME/bin' >>$MARMOT_PROFILE

    source /etc/profile
    printf -- "${SUCCESS}JAVA_HOME configure successful: $JAVA_HOME${END}\n"
else
    source /etc/profile
    printf -- "${WARN}JAVA_HOME configurtion is complete.${END}\n"
fi

#############################################################################################
# distributing jdk
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Distributing jdk to all cluster nodes.${END}\n"

# modify permissions
chown $HADOOP_USER:$HADOOP_USER -R $JAVA_HOME
# distributing jdk
sh $SCRIPT_DIR/msync $HADOOP_WORKERS $JAVA_HOME
printf -- "\n"
# distributing environment variables
sh $SCRIPT_DIR/msync $HADOOP_WORKERS /etc/profile.d/marmot_env.sh

printf -- "\n"
printf -- "${SUCCESS}========== JAVA INSTALL SUCCESSFUL ==========${END}\n"
