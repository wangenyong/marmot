#!/bin/bash

#############################################################################################
#
# spark version "3.0.0"
#
# configure spark
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

printf -- "${INFO}========== INSTALL SPARK ==========${END}\n"
if [ -d $PROJECT_DIR/spark* ]; then
    printf -- "${SUCCESS}========== SPARK INSTALLED ==========${END}\n"
    printf -- "\n"
    exit 0
fi

#############################################################################################
# install spark
#############################################################################################
printf -- "${INFO}>>> Install spark.${END}\n"

pv $HOME_DIR/softwares/spark-3.0.0-bin-hadoop3.2.tgz | tar -zx -C $PROJECT_DIR/

#############################################################################################
# configure environment variables
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure spark environment variables.${END}\n"

if [ $(grep -c "SPARK_HOME" $MARMOT_PROFILE) -eq '0' ]; then
    cd $PROJECT_DIR/spark*
    SPARK_PATH="SPARK_HOME="$(pwd)
    cd - >/dev/null 2>&1

    echo -e >>$MARMOT_PROFILE
    echo '#***** SPARK_HOME *****' >>$MARMOT_PROFILE
    echo "export "$SPARK_PATH >>$MARMOT_PROFILE
    echo 'export PATH=$PATH:$SPARK_HOME/bin' >>$MARMOT_PROFILE

    source /etc/profile
    printf -- "${SUCCESS}SPARK_HOME configure successful: $SPARK_HOME${END}\n"
else
    source /etc/profile
    printf -- "${WARN}SPARK_HOME configurtion is complete.${END}\n"
fi

#############################################################################################
# configure yarn-site.xml
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure hadoop yarn-site.xml.${END}\n"

PMEM_CHECK_CONFIG='
    <property>\
        <name>yarn.nodemanager.pmem-check-enabled</name>\
        <value>false</value>\
    </property>'

VMEM_CHECK_CONFIG='
    <property>\
        <name>yarn.nodemanager.vmem-check-enabled</name>\
        <value>false</value>\
    </property>'

YARN_SITE_FILE=$HADOOP_HOME/etc/hadoop/yarn-site.xml
# determine whether the file yarn-site.xml is configured
if [ $(grep -c "yarn.nodemanager.pmem-check-enabled" $YARN_SITE_FILE) -eq '0' ]; then
    sed -i -r '/<\/configuration>/i\'"$PMEM_CHECK_CONFIG" $YARN_SITE_FILE
    sed -i -r '/<\/configuration>/i\'"$VMEM_CHECK_CONFIG" $YARN_SITE_FILE
    printf -- "${SUCCESS}Configure yarn-site.xml successful.${END}\n"
else
    printf -- "${SUCCESS}File yarn-site.xml configurtion is complete.${END}\n"
fi

#############################################################################################
# configure conf/spark-env.sh
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure spark spark-env.sh.${END}\n"

SPARK_ENV=$SPARK_HOME/conf/spark-env.sh

if [ ! -f $SPARK_ENV ]; then
    echo '#***** CUSTOM CONFIG *****' >>$SPARK_ENV
    echo 'export JAVA_HOME='$JAVA_HOME >>$SPARK_ENV
    echo 'YARN_CONF_DIR='$HADOOP_HOME'/etc/hadoop' >>$SPARK_ENV
    printf -- "${SUCCESS}Configure spark-env.sh successful.${END}\n"
else
    printf -- "${SUCCESS}File spark-env.sh configurtion is complete.${END}\n"
fi

#############################################################################################
# start hdfs
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Start hdfs.${END}\n"
ssh $HADOOP_USER@$HDFS_NAMENODE "$HADOOP_HOME/sbin/start-dfs.sh"

#############################################################################################
# configure spark historyserver
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure spark historyserver.${END}\n"

SPARK_DEFAULTS=$SPARK_HOME/conf/spark-defaults.conf
if [ ! -f $SPARK_DEFAULTS ]; then
    # create hdfs directory
    ssh $HADOOP_USER@$HDFS_NAMENODE "hadoop fs -mkdir /directory"

    echo '#***** CUSTOM CONFIG *****' >>$SPARK_DEFAULTS
    echo "spark.eventLog.enabled true" >>$SPARK_DEFAULTS
    echo "spark.eventLog.dir hdfs://$HDFS_NAMENODE:8020/directory" >>$SPARK_DEFAULTS
    echo "spark.yarn.historyServer.address=$HDFS_NAMENODE:18080" >>$SPARK_DEFAULTS
    echo "spark.history.ui.port=18080" >>$SPARK_DEFAULTS

    SPARK_HISTORY_OPTS='
export SPARK_HISTORY_OPTS="\
-Dspark.history.ui.port=18080\
-Dspark.history.fs.logDirectory=hdfs://'$HDFS_NAMENODE':8020/directory\
-Dspark.history.retainedApplications=30"'
    sed -i -r '$a\'"$SPARK_HISTORY_OPTS" $SPARK_ENV

    printf -- "${SUCCESS}Configure spark historyserver successful.${END}\n"
else
    printf -- "${SUCCESS}Spark historyserver configurtion is complete.${END}\n"
fi


#############################################################################################
# configure spark on hive
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure spark historyserver.${END}\n"

if [ ! -f "$SPARK_HOME/conf/hive-site.xml" ]; then
    cp $HIVE_HOME/conf/hive-site.xml $SPARK_HOME/conf/
    cp $HIVE_HOME/lib/mysql-connector-java-5.1.27-bin.jar $SPARK_HOME/jars/
    cp $HADOOP_HOME/etc/hadoop/core-site.xml $SPARK_HOME/conf/
    cp $HADOOP_HOME/etc/hadoop/hdfs-site.xml $SPARK_HOME/conf/

    printf -- "${SUCCESS}Configure spark on hive successful.${END}\n"
else
    printf -- "${SUCCESS}Spark on hive configurtion is complete.${END}\n"
fi

#############################################################################################
# configure hive on spark
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure hive on spark.${END}\n"

HIVE_SPARK_DEFAULT=$HIVE_HOME/conf/spark-defaults.conf
if [ ! -f $HIVE_SPARK_DEFAULT ]; then  
    echo '#***** CUSTOM CONFIG *****' >>$HIVE_SPARK_DEFAULT
    echo "spark.master yarn" >>$HIVE_SPARK_DEFAULT
    echo "spark.eventLog.enabled true" >>$HIVE_SPARK_DEFAULT
    echo "spark.eventLog.dir hdfs://$HDFS_NAMENODE:8020/directory" >>$HIVE_SPARK_DEFAULT
    echo "spark.executor.memory 1g" >>$HIVE_SPARK_DEFAULT
    echo "spark.driver.memory 1g" >>$HIVE_SPARK_DEFAULT

    # upload pure spark jars to hdfs
    pv $HOME_DIR/softwares/spark-3.0.0-bin-without-hadoop.tgz | tar -zx -C /home/$HADOOP_USER/
    chown $HADOOP_USER:$HADOOP_USER -R /home/$HADOOP_USER/
    ssh $HADOOP_USER@$HDFS_NAMENODE "hadoop fs -mkdir /spark-jars"
    ssh $HADOOP_USER@$HDFS_NAMENODE "hadoop fs -put ~/spark-3.0.0-bin-without-hadoop/jars/* /spark-jars 1>/dev/null 2>&1"

    SPARK_YAR_JARS='
    <!--spark dependency location-->\
    <property>\
        <name>spark.yarn.jars</name>\
        <value>hdfs://'$HDFS_NAMENODE':8020/spark-jars/*</value>\
    </property>'
    HIVE_ENGINE='
    <property>\
        <name>hive.execution.engine</name>\
        <value>spark</value>\
    </property>'
    HIVE_SPARK_TIMEOUT='
    <property>\
        <name>hive.spark.client.connect.timeout</name>\
        <value>10000ms</value>\
    </property>'

    HIVE_SITE_FILE=$HIVE_HOME/conf/hive-site.xml

    sed -i -r '/<\/configuration>/i\'"$SPARK_YAR_JARS" $HIVE_SITE_FILE
    sed -i -r '/<\/configuration>/i\'"$HIVE_ENGINE" $HIVE_SITE_FILE
    sed -i -r '/<\/configuration>/i\'"$HIVE_SPARK_TIMEOUT" $HIVE_SITE_FILE

    printf -- "${SUCCESS}Configure hive on spark successful.${END}\n"
else
    printf -- "${SUCCESS}Hive on spark configurtion is complete.${END}\n"
fi

#############################################################################################
# stop hdfs
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Stop hdfs.${END}\n"
ssh $HADOOP_USER@$HDFS_NAMENODE "$HADOOP_HOME/sbin/stop-dfs.sh"

#############################################################################################
# distributing spark
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Distributing spark to all cluster nodes.${END}\n"
# modify permissions
chown $HADOOP_USER:$HADOOP_USER -R $SPARK_HOME
chown $HADOOP_USER:$HADOOP_USER -R $HIVE_HOME/conf
# distributing hadoop
sh $SCRIPT_DIR/msync $HADOOP_WORKERS $SPARK_HOME
printf -- "\n"
# distributing hive conf
sh $SCRIPT_DIR/msync $HADOOP_WORKERS $HIVE_HOME/conf
printf -- "\n"
# distributing environment variables
sh $SCRIPT_DIR/msync $HADOOP_WORKERS /etc/profile.d/marmot_env.sh


printf -- "\n"
printf -- "${SUCCESS}========== SPARK INSTALL SUCCESSFUL ==========${END}\n"