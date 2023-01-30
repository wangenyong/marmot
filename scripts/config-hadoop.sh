#!/bin/bash


SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"


NAME_NODE_CONFIG='
    <!-- 指定NameNode的地址 -->\
    <property>\
        <name>fs.defaultFS</name>\
        <value>hdfs://'$(head -n 1 $HOME_DIR/conf/workers)':8020</value>\
    </property>'

sed -in '/<\/configuration>/i\'"$NAME_NODE_CONFIG" $HADOOP_HOME/etc/hadoop/core-site.xml


DATA_DIR_CONFIG='
    <!-- 指定hadoop数据的存储目录 -->\
    <property>\
        <name>hadoop.tmp.dir</name>\
        <value>'$HADOOP_HOME'/data</value>\
    </property>'

sed -in '/<\/configuration>/i\'"$DATA_DIR_CONFIG" $HADOOP_HOME/etc/hadoop/core-site.xml


HDFS_USER_CONFIG='
    <!-- 配置HDFS网页登录使用的静态用户为marmot -->\
    <property>\
        <name>hadoop.http.staticuser.user</name>\
        <value>marmot</value>\
    </property>'

sed -in '/<\/configuration>/i\'"$HDFS_USER_CONFIG" $HADOOP_HOME/etc/hadoop/core-site.xml