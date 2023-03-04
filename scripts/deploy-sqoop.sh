#!/bin/bash

#############################################################################################
#
# sqoop version "1.4.6"
#
# install sqoop
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

printf -- "${INFO}========== INSTALL SQOOP ==========${END}\n"
if [ -d $PROJECT_DIR/sqoop* ]; then
    printf -- "${SUCCESS}========== SQOOP INSTALLED ==========${END}\n"
    printf -- "\n"
    exit 0
fi

#############################################################################################
# install sqoop
#############################################################################################
printf -- "${INFO}>>> Install sqoop.${END}\n"

pv $HOME_DIR/softwares/sqoop-1.4.6.bin__hadoop-2.0.4-alpha.tar.gz | tar -zx -C $PROJECT_DIR/

#############################################################################################
# configure environment variables
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure sqoop environment variables.${END}\n"

if [ $(grep -c "SQOOP_HOME" $MARMOT_PROFILE) -eq '0' ]; then
    cd $PROJECT_DIR/sqoop*
    SQOOP_PATH="SQOOP_HOME="$(pwd)
    cd - >/dev/null 2>&1

    echo -e >>$MARMOT_PROFILE
    echo '#***** SQOOP_HOME *****' >>$MARMOT_PROFILE
    echo "export "$SQOOP_PATH >>$MARMOT_PROFILE
    echo 'export PATH=$PATH:$SQOOP_HOME/bin' >>$MARMOT_PROFILE

    source /etc/profile
    printf -- "${SUCCESS}SQOOP_HOME configure successful: $SQOOP_HOME${END}\n"
else
    source /etc/profile
    printf -- "${WARN}SQOOP_HOME configurtion is complete.${END}\n"
fi

#############################################################################################
# configure sqoop-env.sh
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure hive hive-site.xml.${END}\n"

SQOOP_ENV_FILE=$SQOOP_HOME/conf/sqoop-env.sh
# copy jdbc driver
cp $HOME_DIR/softwares/mysql/mysql-connector-java-5.1.27-bin.jar $SQOOP_HOME/lib/
cp $HOME_DIR/softwares/jars/sqljdbc4.jar $SQOOP_HOME/lib/

if [ ! -f $SQOOP_ENV_FILE ]; then
    mv $SQOOP_HOME/conf/sqoop-env-template.sh $SQOOP_ENV_FILE
    echo '#***** CUSTOM CONFIG *****' >>$SQOOP_ENV_FILE
    echo 'export HADOOP_COMMON_HOME='$HADOOP_HOME >>$SQOOP_ENV_FILE
    echo 'export HADOOP_MAPRED_HOME='$HADOOP_HOME >>$SQOOP_ENV_FILE
    echo 'export HIVE_HOME='$HIVE_HOME >>$SQOOP_ENV_FILE
    printf -- "${SUCCESS}Configure sqoop-env.sh successful.${END}\n"
else
    printf -- "${SUCCESS}File sqoop-env.sh configurtion is complete.${END}\n"
fi

#############################################################################################
# distributing sqoop
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Distributing sqoop to all cluster nodes.${END}\n"

# modify permissions
chown $HADOOP_USER:$HADOOP_USER -R $SQOOP_HOME
# distributing hive
sh $SCRIPT_DIR/msync $HADOOP_WORKERS $SQOOP_HOME
printf -- "\n"
# distributing environment variables
sh $SCRIPT_DIR/msync $HADOOP_WORKERS /etc/profile.d/marmot_env.sh

printf -- "\n"
printf -- "${SUCCESS}========== SQOOP INSTALL SUCCESSFUL ==========${END}\n"