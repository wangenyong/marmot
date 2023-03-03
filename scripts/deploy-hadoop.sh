#!/bin/bash

#############################################################################################
#
# hadoop version "3.1.3"
#
# install and configuer hadoop
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
# loading cluster nodes
IFS=',' read -ra workers <<<$HADOOP_WORKERS

printf -- "${INFO}========== INSTALL HADOOP ==========${END}\n"
if [ -d $PROJECT_DIR/hadoop* ]; then
    printf -- "${SUCCESS}========== HADOOP INSTALLED ==========${END}\n"
    printf -- "\n"
    exit 0
fi

#############################################################################################
# install hadoop
#############################################################################################
printf -- "${INFO}>>> Install hadoop.${END}\n"
pv $HOME_DIR/softwares/hadoop-3.1.3.tar.gz | tar -zx -C $PROJECT_DIR/

#############################################################################################
# configure environment variables
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure hadoop environment variables.${END}\n"

if [ $(grep -c "HADOOP_HOME" $MARMOT_PROFILE) -eq '0' ]; then
    cd $PROJECT_DIR/hadoop*
    HADOOP_PATH="HADOOP_HOME="$(pwd)
    HADOOP_HOME=$(pwd)
    cd - >/dev/null 2>&1

    echo -e >>$MARMOT_PROFILE
    echo '#***** HADOOP_HOME *****' >>$MARMOT_PROFILE
    echo "export "$HADOOP_PATH >>$MARMOT_PROFILE
    echo 'export PATH=$PATH:$HADOOP_HOME/bin' >>$MARMOT_PROFILE
    echo 'export PATH=$PATH:$HADOOP_HOME/sbin' >>$MARMOT_PROFILE
    echo "export HADOOP_CONF_DIR=${HADOOP_HOME}/etc/hadoop" >>$MARMOT_PROFILE
    echo 'export HADOOP_CLASSPATH=`hadoop classpath`' >>$MARMOT_PROFILE

    source /etc/profile
    printf -- "${SUCCESS}HADOOP_HOME configure successful: $HADOOP_HOME${END}\n"
else
    source /etc/profile
    printf -- "${WARN}HADOOP_HOME configurtion is complete.${END}\n"
fi

#############################################################################################
# copy lzo jar
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Copy hadoop lzo jar file.${END}\n"
cp $HOME_DIR/softwares/jars/hadoop-lzo-0.4.20.jar $HADOOP_HOME/share/hadoop/common

#############################################################################################
# configure core-site.xml
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure hadoop core-site.xml.${END}\n"

NAME_NODE_CONFIG='
    <!--namenode work address -->\
    <property>\
        <name>fs.defaultFS</name>\
        <value>hdfs://'${workers[0]}':8020</value>\
    </property>'

DATA_DIR_CONFIG='
    <!-- hadoop data directory -->\
    <property>\
        <name>hadoop.tmp.dir</name>\
        <value>'$HADOOP_HOME'/data</value>\
    </property>'

HDFS_USER_CONFIG='
    <!-- hdfs web user -->\
    <property>\
        <name>hadoop.http.staticuser.user</name>\
        <value>'$HADOOP_USER'</value>\
    </property>'

USER_MARMOT_HOSTS='
    <property>\
        <name>hadoop.proxyuser.'$HADOOP_USER'.hosts</name>\
        <value>*</value>\
    </property>'

USER_MARMOT_GROUPS='
    <property>\
        <name>hadoop.proxyuser.'$HADOOP_USER'.groups</name>\
        <value>*</value>\
    </property>'

COMPRESSION_CONFIG='
    <property>\
        <name>io.compression.codecs</name>\
        <value>\
            org.apache.hadoop.io.compress.GzipCodec,\
            org.apache.hadoop.io.compress.DefaultCodec,\
            org.apache.hadoop.io.compress.BZip2Codec,\
            org.apache.hadoop.io.compress.SnappyCodec,\
            com.hadoop.compression.lzo.LzoCodec,\
            com.hadoop.compression.lzo.LzopCodec\
        </value>\
    </property>'

COMPRESSION_LZO_CONFIG='
    <property>\
        <name>io.compression.codec.lzo.class</name>\
        <value>com.hadoop.compression.lzo.LzoCodec</value>\
    </property>'

CORE_SITE_FILE=$HADOOP_HOME/etc/hadoop/core-site.xml
# determine whether the file core-site.xml is configured
if [ $(grep -c "fs.defaultFS" $CORE_SITE_FILE) -eq '0' ]; then
    sed -i -r '/<\/configuration>/i\'"$NAME_NODE_CONFIG" $CORE_SITE_FILE
    sed -i -r '/<\/configuration>/i\'"$DATA_DIR_CONFIG" $CORE_SITE_FILE
    sed -i -r '/<\/configuration>/i\'"$HDFS_USER_CONFIG" $CORE_SITE_FILE
    sed -i -r '/<\/configuration>/i\'"$USER_MARMOT_HOSTS" $CORE_SITE_FILE
    sed -i -r '/<\/configuration>/i\'"$USER_MARMOT_GROUPS" $CORE_SITE_FILE
    sed -i -r '/<\/configuration>/i\'"$COMPRESSION_CONFIG" $CORE_SITE_FILE
    sed -i -r '/<\/configuration>/i\'"$COMPRESSION_LZO_CONFIG" $CORE_SITE_FILE
    printf -- "${SUCCESS}Configure core-site.xml successful.${END}\n"
else
    printf -- "${SUCCESS}File core-site.xml configurtion is complete.${END}\n"
fi

#############################################################################################
# configure hdfs-site.xml
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure hadoop hdfs-site.xml.${END}\n"

WEB_CONFIG='
    <!-- namenode web address-->\
	<property>\
        <name>dfs.namenode.http-address</name>\
        <value>'${workers[0]}':9870</value>\
    </property>'

SECONDARY_WEB_CONFIG='
    <!-- secondary namemode web address-->\
    <property>\
        <name>dfs.namenode.secondary.http-address</name>\
        <value>'${workers[2]}':9868</value>\
    </property>'

HDFS_SITE_FILE=$HADOOP_HOME/etc/hadoop/hdfs-site.xml
# determine whether the file hdfs-site.xml is configured
if [ $(grep -c "dfs.namenode.http-address" $HDFS_SITE_FILE) -eq '0' ]; then
    sed -i -r '/<\/configuration>/i\'"$WEB_CONFIG" $HDFS_SITE_FILE
    sed -i -r '/<\/configuration>/i\'"$SECONDARY_WEB_CONFIG" $HDFS_SITE_FILE

    printf -- "${SUCCESS}Configure hdfs-site.xml successful.${END}\n"
else
    printf -- "${SUCCESS}File hdfs-site.xml configurtion is complete.${END}\n"
fi

#############################################################################################
# configure yarn-site.xml
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure hadoop yarn-site.xml.${END}\n"

MR_CONFIG='
    <!--  mapreduce mode -->\
    <property>\
        <name>yarn.nodemanager.aux-services</name>\
        <value>mapreduce_shuffle</value>\
    </property>'

RM_HOSTNAME='
    <!-- resource_manager address-->\
    <property>\
        <name>yarn.resourcemanager.hostname</name>\
        <value>'${workers[1]}'</value>\
    </property>'

ENV_CONFIG='
    <property>\
        <name>yarn.nodemanager.env-whitelist</name>\
        <value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_MAPRED_HOME</value>\
    </property>'

LOG_AGGREGATION_CONFIG='
    <property>\
        <name>yarn.log-aggregation-enable</name>\
        <value>true</value>\
    </property>'

LOG_SERVER_CONFIG='
    <property>\
        <name>yarn.log.server.url</name>\
        <value>'${workers[0]}':19888/jobhistory/logs</value>\
    </property>'

LOG_RETAIN_CONFIG='
    <property>\
        <name>yarn.log-aggregation.retain-seconds</name>\
        <value>604800</value>\
    </property>'

YARN_SITE_FILE=$HADOOP_HOME/etc/hadoop/yarn-site.xml
# determine whether the file yarn-site.xml is configured
if [ $(grep -c "yarn.nodemanager.aux-services" $YARN_SITE_FILE) -eq '0' ]; then
    sed -i -r '/<\/configuration>/i\'"$MR_CONFIG" $YARN_SITE_FILE
    sed -i -r '/<\/configuration>/i\'"$RM_HOSTNAME" $YARN_SITE_FILE
    sed -i -r '/<\/configuration>/i\'"$ENV_CONFIG" $YARN_SITE_FILE
    sed -i -r '/<\/configuration>/i\'"$LOG_AGGREGATION_CONFIG" $YARN_SITE_FILE
    sed -i -r '/<\/configuration>/i\'"$LOG_SERVER_CONFIG" $YARN_SITE_FILE
    sed -i -r '/<\/configuration>/i\'"$LOG_RETAIN_CONFIG" $YARN_SITE_FILE

    printf -- "${SUCCESS}Configure yarn-site.xml successful.${END}\n"
else
    printf -- "${SUCCESS}File yarn-site.xml configurtion is complete.${END}\n"
fi

#############################################################################################
# configure mapred-site.xml
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure hadoop mapred-site.xml.${END}\n"

MR_YARN_CONFIG='
    <!-- mapreduce work on yarn -->\
    <property>\
        <name>mapreduce.framework.name</name>\
        <value>yarn</value>\
    </property>'

HISTORY_ADDRESS_CONFIG='
    <!-- historyserver address -->\
    <property>\
        <name>mapreduce.jobhistory.address</name>\
        <value>'${workers[0]}':10020</value>\
    </property>'

HISTORY_WEB_CONFIG='
    <!-- historyserver web address -->\
    <property>\
        <name>mapreduce.jobhistory.webapp.address</name>\
        <value>'${workers[0]}':19888</value>\
    </property>'

MR_SITE_FILE=$HADOOP_HOME/etc/hadoop/mapred-site.xml
# determine whether the file mapred-site.xml is configured
if [ $(grep -c "mapreduce.framework.name" $MR_SITE_FILE) -eq '0' ]; then
    sed -in '/<\/configuration>/i\'"$MR_YARN_CONFIG" $MR_SITE_FILE
    sed -in '/<\/configuration>/i\'"$HISTORY_ADDRESS_CONFIG" $MR_SITE_FILE
    sed -in '/<\/configuration>/i\'"$HISTORY_WEB_CONFIG" $MR_SITE_FILE

    printf -- "${SUCCESS}Configure mapred-site.xml successful.${END}\n"
else
    printf -- "${SUCCESS}File mapred-site.xml configurtion is complete.${END}\n"
fi

#############################################################################################
# configure workers
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure hadoop workers.${END}\n"

cat /dev/null >$HADOOP_HOME/etc/hadoop/workers
for host in ${workers[@]}; do
    echo $host >>$HADOOP_HOME/etc/hadoop/workers
done

#############################################################################################
# distributing hadoop
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Distributing hadoop to all cluster nodes.${END}\n"
# modify permissions
chown $HADOOP_USER:$HADOOP_USER -R $HADOOP_HOME
# distributing hadoop
sh $SCRIPT_DIR/msync $HADOOP_WORKERS $HADOOP_HOME
printf -- "\n"
# distributing environment variables
sh $SCRIPT_DIR/msync $HADOOP_WORKERS /etc/profile.d/marmot_env.sh

#############################################################################################
# format namenode
#############################################################################################
if [ ! -d $HADOOP_HOME/data ]; then
    printf -- "${INFO}>>> Format namenode.${END}\n"
    ssh $HADOOP_USER@${workers[0]} "hdfs namenode -format 1>/dev/null 2>&1"
    if [ $? -eq 0 ]; then
        printf -- "${SUCCESS}Format namenode successful.${END}\n"
    else
        printf -- "${ERROR}Format namenode failed.${END}\n"
        exit 1
    fi
fi

printf -- "\n"
printf -- "${SUCCESS}========== HADOOP INSTALL SUCCESSFUL ==========${END}\n"
