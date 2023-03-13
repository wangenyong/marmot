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
# loading version file
source $HOME_DIR/conf/version.conf
# loading environment
source /etc/profile
# loading zookeeper nodes
IFS=',' read -ra zookeeper_nodes <<<$ZOOKEEPER_NODES
# loading kafka nodes
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
pv $HOME_DIR/softwares/atlas/apache-atlas-${atlas_version}-server.tar.gz | tar -zx -C $PROJECT_DIR/
# modify directory name
mv $PROJECT_DIR/apache-atlas* $PROJECT_DIR/atlas-${atlas_version}

chown $SOLR_USER:$SOLR_USER -R $PROJECT_DIR/atlas-${atlas_version}

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
        kafka_servers="$kafka_servers$node:9092"
    else
        kafka_servers="$kafka_servers$node:9092,"
    fi
    let i+=1
done

APPLICATION_PROPERTIES_FILE=$PROJECT_DIR/atlas-${atlas_version}/conf/atlas-application.properties

sed -i -r '/^atlas\.graph\.storage\.hostname=/s|.*|atlas\.graph\.storage\.hostname='$zookeeper_servers'|' $APPLICATION_PROPERTIES_FILE

echo "# hbase conf dir" >>$PROJECT_DIR/atlas-${atlas_version}/conf/atlas-env.sh
echo 'export HBASE_CONF_DIR='$HBASE_HOME/conf >>$PROJECT_DIR/atlas-${atlas_version}/conf/atlas-env.sh

# -------------------------------------------------------------------------------------------
# integrate solr
# -------------------------------------------------------------------------------------------
printf -- "\n"
printf -- "${INFO}--> Integrate solo.${END}\n"
sed -i -r '/^atlas\.graph\.index\.search\.solr\.zookeeper-url=/s|.*|atlas\.graph\.index\.search\.solr\.zookeeper-url='$zookeeper_servers'|' $APPLICATION_PROPERTIES_FILE

ssh $SOLR_USER@$ATLAS_SERVER "$PROJECT_DIR/solr-${solr_version}/bin/solr create -c vertex_index -d $PROJECT_DIR/atlas-${atlas_version}/conf/solr -shards 3 -replicationFactor 2"
ssh $SOLR_USER@$ATLAS_SERVER "$PROJECT_DIR/solr-${solr_version}/bin/solr create -c edge_index -d $PROJECT_DIR/atlas-${atlas_version}/conf/solr -shards 3 -replicationFactor 2"
ssh $SOLR_USER@$ATLAS_SERVER "$PROJECT_DIR/solr-${solr_version}/bin/solr create -c fulltext_index -d $PROJECT_DIR/atlas-${atlas_version}/conf/solr -shards 3 -replicationFactor 2"

# -------------------------------------------------------------------------------------------
# integrate kafka
# -------------------------------------------------------------------------------------------
printf -- "\n"
printf -- "${INFO}--> Integrate kafka.${END}\n"
sed -i -r '/^atlas\.notification\.embedded=/s|.*|atlas\.notification\.embedded=false|' $APPLICATION_PROPERTIES_FILE
sed -i -r '/^atlas\.kafka\.data=/s|.*|atlas\.kafka\.data='$KAFKA_HOME'/data|' $APPLICATION_PROPERTIES_FILE
sed -i -r '/^atlas\.kafka\.zookeeper\.connect=/s|.*|atlas\.kafka\.zookeeper\.connect='$zookeeper_servers'/kafka|' $APPLICATION_PROPERTIES_FILE
sed -i -r '/^atlas\.kafka\.bootstrap\.servers=/s|.*|atlas\.kafka\.bootstrap\.servers='$kafka_servers'|' $APPLICATION_PROPERTIES_FILE

# -------------------------------------------------------------------------------------------
# configure altas server
# -------------------------------------------------------------------------------------------
printf -- "\n"
printf -- "${INFO}--> Configure altas server.${END}\n"
sed -i -r '/^atlas\.rest\.address=/s|.*|atlas\.rest\.address=http://'$ATLAS_SERVER':21000|' $APPLICATION_PROPERTIES_FILE
sed -i -r '/^#atlas\.server\.run\.setup\.on\.start=/s|.*|atlas\.server\.run\.setup\.on\.start=false|' $APPLICATION_PROPERTIES_FILE
sed -i -r '/^atlas\.audit\.hbase\.zookeeper\.quorum=/s|.*|atlas\.audit\.hbase\.zookeeper\.quorum='$zookeeper_servers'|' $APPLICATION_PROPERTIES_FILE

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

sed -i -r '/<\/log4j:configuration>/i\'"$PERF_APPENDER" $PROJECT_DIR/atlas-${atlas_version}/conf/atlas-log4j.xml
sed -i -r '/<\/log4j:configuration>/i\'"$LOGGER_CONFIG" $PROJECT_DIR/atlas-${atlas_version}/conf/atlas-log4j.xml

# -------------------------------------------------------------------------------------------
# integrate hive
# -------------------------------------------------------------------------------------------
printf -- "\n"
printf -- "${INFO}--> Integrate hive.${END}\n"
sed -i -r '$a\######### Hive Hook Configs #######' $APPLICATION_PROPERTIES_FILE
sed -i -r '$a\atlas.hook.hive.synchronous=false' $APPLICATION_PROPERTIES_FILE
sed -i -r '$a\atlas.hook.hive.numRetries=3' $APPLICATION_PROPERTIES_FILE
sed -i -r '$a\atlas.hook.hive.queueSize=10000' $APPLICATION_PROPERTIES_FILE
sed -i -r '$a\atlas.cluster.name=primary' $APPLICATION_PROPERTIES_FILE

if [ $(grep -c 'hive.exec.post.hooks' $HIVE_HOME/conf/hive-site.xml) -eq '0' ]; then
    HIVE_HOOKS_CONFIG='
    <property>\
        <name>hive.exec.post.hooks</name>\
        <value>org.apache.atlas.hive.hook.HiveHook</value>\
    </property>'

    sed -i -r '/<\/configuration>/i\'"$HIVE_HOOKS_CONFIG" $HIVE_HOME/conf/hive-site.xml
fi
# copy hive hook file
ATLAS_HOOKS_TMP_DIR=$HOME_DIR/softwares/atlas/hivehook
if [ -d $ATLAS_HOOKS_TMP_DIR ]; then
    rm -rf $ATLAS_HOOKS_TMP_DIR
fi
mkdir $ATLAS_HOOKS_TMP_DIR

pv $HOME_DIR/softwares/atlas/apache-atlas-2.1.0-hive-hook.tar.gz | tar -zx -C $ATLAS_HOOKS_TMP_DIR --strip-components 1

cp -r $ATLAS_HOOKS_TMP_DIR/* $PROJECT_DIR/atlas-${atlas_version}/

# configure hive env
HIVE_ENV_FILE=$HIVE_HOME/conf/hive-env.sh

if [ ! -f "$HIVE_ENV_FILE" ]; then
    cp $HIVE_HOME/conf/hive-env.sh.template $HIVE_ENV_FILE
    sed -i -r '$a\export HIVE_AUX_JARS_PATH='$PROJECT_DIR'\/atlas\/hook\/hive' $HIVE_ENV_FILE
elif [ $(grep -c 'export HIVE_AUX_JARS_PATH' $HIVE_ENV_FILE) -eq '0' ]; then
    sed -i -r '$a\export HIVE_AUX_JARS_PATH='$PROJECT_DIR'\/atlas\/hook\/hive' $HIVE_ENV_FILE
fi

printf -- "\n"
printf -- "${INFO}--> Force copy atlas-application.properties to hive conf.${END}\n"
/bin/cp $APPLICATION_PROPERTIES_FILE $HIVE_HOME/conf/
printf -- "\n"
printf -- "${INFO}--> Force copy atlas hook jar to hive lib.${END}\n"
/bin/cp -r $PROJECT_DIR/atlas-${atlas_version}/hook/hive/* $HIVE_HOME/lib/

#############################################################################################
# modify permissions
#############################################################################################
chown $HADOOP_USER:$HADOOP_USER -R $PROJECT_DIR/atlas-${atlas_version}
chown $HADOOP_USER:$HADOOP_USER -R $HIVE_HOME/conf

printf -- "\n"
printf -- "${SUCCESS}========== ATLAS INSTALL SUCCESSFUL ==========${END}\n"