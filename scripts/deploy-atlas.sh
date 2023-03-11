#!/bin/bash

#############################################################################################
#
# atlas version "2.1.0"
#
# install atlas
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

IFS=',' read -ra kafka_nodes <<<$KAFKA_NODES

printf -- "${INFO}========== INSTALL ATLAS ==========${END}\n"
if [ -d $PROJECT_DIR/atlas* ]; then
    printf -- "${SUCCESS}========== ATLAS INSTALLED ==========${END}\n"
    printf -- "\n"
    exit 0
fi

#############################################################################################
# install atlas
#############################################################################################
printf -- "${INFO}>>> Install atlas.${END}\n"
pv $HOME_DIR/softwares/atlas/apache-atlas-2.1.0-server.tar.gz | tar -zx -C $PROJECT_DIR/
# modify directory name
mv $PROJECT_DIR/apache-atlas* $PROJECT_DIR/atlas

#############################################################################################
# configure atlas
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure atlas.${END}\n"

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

i=1
kafka_servers=""
length=${#kafka_nodes[@]}
for node in ${kafka_nodes[@]}; do
    if [ $i -eq $length ]; then
        kafka_servers="$kafka_nodes$node:9092"
    else
        kafka_servers="$kafka_nodes$node:9092,"
    fi
    let i+=1
done

APPLICATION_PROPERTIES_FILE=$PROJECT_DIR/atlas/conf/atlas-application.properties

sed -i -r '/^atlas\.graph\.storage\.hostname/s|.*|atlas\.graph\.storage\.hostname='$zookeeper_servers'|' $APPLICATION_PROPERTIES_FILE

echo "# hbase conf dir" >>$PROJECT_DIR/atlas/conf/atlas-env.sh
echo 'export HBASE_CONF_DIR='$HBASE_HOME/conf >>$PROJECT_DIR/atlas/conf/atlas-env.sh

# -------------------------------------------------------------------------------------------
# integrate solr
# -------------------------------------------------------------------------------------------
sed -i -r '/^atlas\.graph\.index\.search\.solr\.zookeeper-url/s|.*|atlas\.graph\.index\.search\.solr\.zookeeper-url='$zookeeper_servers'|' $APPLICATION_PROPERTIES_FILE

ssh $SOLR_USER@$HDFS_NAMENODE "$PROJECT_DIR/solr/bin/solr create -c vertex_index -d $PROJECT_DIR/solr/conf/solr -shards 3 -replicationFactor 2"
ssh $SOLR_USER@$HDFS_NAMENODE "$PROJECT_DIR/solr/bin/solr create -c edge_index -d $PROJECT_DIR/solr/conf/solr -shards 3 -replicationFactor 2"
ssh $SOLR_USER@$HDFS_NAMENODE "$PROJECT_DIR/solr/bin/solr create -c fulltext_index -d $PROJECT_DIR/solr/conf/solr -shards 3 -replicationFactor 2"

# -------------------------------------------------------------------------------------------
# integrate kafka
# -------------------------------------------------------------------------------------------
sed -i -r '/^atlas\.notification\.embedded/s|.*|atlas\.notification\.embedded=false|' $APPLICATION_PROPERTIES_FILE
sed -i -r '/^atlas\.kafka\.data/s|.*|atlas\.kafka\.data='$KAFKA_HOME'/data|' $APPLICATION_PROPERTIES_FILE
sed -i -r '/^atlas\.kafka\.zookeeper\.connect/s|.*|atlas\.kafka\.zookeeper\.connect='$zookeeper_servers'/kafka|' $APPLICATION_PROPERTIES_FILE
sed -i -r '/^atlas\.kafka\.bootstrap\.servers/s|.*|atlas\.kafka\.bootstrap\.servers='$kafka_servers'|' $APPLICATION_PROPERTIES_FILE
# -------------------------------------------------------------------------------------------
# configure altas server
# -------------------------------------------------------------------------------------------
sed -i -r '/^atlas\.rest\.address/s|.*|atlas\.rest\.address=http://'$HDFS_NAMENODE':21000|' $APPLICATION_PROPERTIES_FILE
sed -i -r '/^atlas\.server\.run\.setup\.on\.start/s|.*|atlas\.server\.run\.setup\.on\.start=false|' $APPLICATION_PROPERTIES_FILE
sed -i -r '/^atlas\.audit\.hbase\.zookeeper\.quorum/s|.*|atlas\.audit\.hbase\.zookeeper\.quorum='$zookeeper_servers'|' $APPLICATION_PROPERTIES_FILE

PERF_APPENDER='
    <appender name="perf_appender" class="org.apache.log4j.DailyRollingFileAppender">\       
        <param name="file" value="${atlas.log.dir}/atlas_perf.log" />\
        <param name="datePattern" value="'.'yyyy-MM-dd" />\
        <param name="append" value="true" />\
        <layout class="org.apache.log4j.PatternLayout">\
            <param name="ConversionPattern" value="%d|%t|%m%n" />\
        </layout>\
    </appender>'

LOGGER_CONFIG='
    <logger name="org.apache.atlas.perf" additivity="false">\
        <level value="debug" />\
        <appender-ref ref="perf_appender" />\
    </logger>'

sed -i -r '/<\/log4j:configuration>/i\'"$PERF_APPENDER" $PROJECT_DIR/atlas/conf/atlas-log4j.xml
sed -i -r '/<\/log4j:configuration>/i\'"$LOGGER_CONFIG" $PROJECT_DIR/atlas/conf/atlas-log4j.xml

# -------------------------------------------------------------------------------------------
# integrate hive
# -------------------------------------------------------------------------------------------
