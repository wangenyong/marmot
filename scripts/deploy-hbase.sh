#!/bin/bash

#############################################################################################
#
# hbase version "2.4.11"
#
# configure hbase
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
# loading cluster nodes
IFS=',' read -ra hbase_nodes <<<$HBASE_NODES

printf -- "${INFO}========== INSTALL HBASE ==========${END}\n"
if [ -d $PROJECT_DIR/hbase* ]; then
    printf -- "${SUCCESS}========== HBASE INSTALLED ==========${END}\n"
    printf -- "\n"
    exit 0
fi

#############################################################################################
# install hbase
#############################################################################################
printf -- "${INFO}>>> Install hbase.${END}\n"
pv $HOME_DIR/softwares/hbase/hbase-${hbase_version}-bin.tar.gz | tar -zx -C $PROJECT_DIR/

if [ ! -d "$PROJECT_DIR/hbase-${hbase_version}" ]; then
    mv $PROJECT_DIR/hbase* $PROJECT_DIR/hbase-${hbase_version}
fi

#############################################################################################
# configure environment variables
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure hbase environment variables.${END}\n"

if [ $(grep -c "HBASE_HOME" $MARMOT_PROFILE) -eq '0' ]; then
    HBASE_PATH="HBASE_HOME="$PROJECT_DIR/hbase-${hbase_version}

    echo -e >>$MARMOT_PROFILE
    echo '#***** HBASE_HOME *****' >>$MARMOT_PROFILE
    echo "export "$HBASE_PATH >>$MARMOT_PROFILE
    echo 'export PATH=$PATH:$HBASE_HOME/bin' >>$MARMOT_PROFILE

    source /etc/profile
    printf -- "${SUCCESS}HBASE_HOME configure successful: $HBASE_HOME${END}\n"
else
    source /etc/profile
    printf -- "${WARN}HBASE_HOME configurtion is complete.${END}\n"
fi

#############################################################################################
# configure hbase-env.sh
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure hbase hbase-env.sh.${END}\n"

# resolve log conflicts
mv $HBASE_HOME/lib/client-facing-thirdparty/slf4j-reload4j-1.7.33.jar $HBASE_HOME/lib/client-facing-thirdparty/slf4j-reload4j-1.7.33.jar.bak

HBASE_ENV_FILE=$HBASE_HOME/conf/hbase-env.sh

echo 'export HBASE_MANAGES_ZK=false' >>$HBASE_ENV_FILE

HBASE_SITE_FILE=$HBASE_HOME/conf/hbase-site.xml
mv $HBASE_SITE_FILE $HBASE_HOME/conf/hbase-site.xml.back
cp $HOME_DIR/template/configuration.xml $HBASE_SITE_FILE
chmod 755 $HBASE_SITE_FILE

ZK_NODES='
    <property>\
        <name>hbase.zookeeper.quorum</name>\
        <value>'$ZOOKEEPER_NODES'</value>\
        <description>The directory shared by RegionServers.</description>\
    </property>'

ROOT_DIR='
    <property>\
        <name>hbase.rootdir</name>\
        <value>hdfs://'$HDFS_NAMENODE':8020/hbase</value>\
        <description>The directory shared by RegionServers.</description>\
    </property>'

CLUSTER_DISTRIBUTED='
    <property>\
        <name>hbase.cluster.distributed</name>\
        <value>true</value>\
    </property>'

TMP_DIR='
    <property>\
        <name>hbase.tmp.dir</name>\
        <value>./tmp</value>\
    </property>'

CAPABILITY_ENFORCE='
    <property>\
        <name>hbase.unsafe.stream.capability.enforce</name>\
        <value>false</value>\
    </property>'

sed -i -r '/<\/configuration>/i\'"$ZK_NODES" $HBASE_SITE_FILE
sed -i -r '/<\/configuration>/i\'"$ROOT_DIR" $HBASE_SITE_FILE
sed -i -r '/<\/configuration>/i\'"$CLUSTER_DISTRIBUTED" $HBASE_SITE_FILE
sed -i -r '/<\/configuration>/i\'"$TMP_DIR" $HBASE_SITE_FILE
sed -i -r '/<\/configuration>/i\'"$CAPABILITY_ENFORCE" $HBASE_SITE_FILE

#############################################################################################
# configure regionservers
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure hbase regionservers.${END}\n"

cat /dev/null >$HBASE_HOME/conf/regionservers
for host in ${hbase_nodes[@]}; do
    echo $host >>$HBASE_HOME/conf/regionservers
done

#############################################################################################
# distributing hbase
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Distributing hbase to all cluster nodes.${END}\n"

# modify permissions
chown $HADOOP_USER:$HADOOP_USER -R $HBASE_HOME
# distributing hive
sh $SCRIPT_DIR/msync $HBASE_NODES $HBASE_HOME
printf -- "\n"
# distributing environment variables
sh $SCRIPT_DIR/msync $HBASE_NODES /etc/profile.d/marmot_env.sh

printf -- "\n"
printf -- "${SUCCESS}========== HBASE INSTALL SUCCESSFUL ==========${END}\n"