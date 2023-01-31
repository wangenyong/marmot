#!/bin/bash

# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh

#
# 配置 hadoop core-site.xml 文件
#
NAME_NODE_CONFIG='
    <!-- 指定 NameNode 的地址 -->\
    <property>\
        <name>fs.defaultFS</name>\
        <value>hdfs://'$(head -n 1 $HOME_DIR/conf/workers)':8020</value>\
    </property>'

DATA_DIR_CONFIG='
    <!-- 指定 hadoop 数据的存储目录 -->\
    <property>\
        <name>hadoop.tmp.dir</name>\
        <value>'$HADOOP_HOME'/data</value>\
    </property>'

HDFS_USER_CONFIG='
    <!-- 配置 HDFS 网页登录使用的静态用户为 marmot -->\
    <property>\
        <name>hadoop.http.staticuser.user</name>\
        <value>marmot</value>\
    </property>'

CORE_SITE_FILE=$HADOOP_HOME/etc/hadoop/core-site.xml
# 判断 core-site.xml 文件是否已经配置
if [ $(grep -c "fs.defaultFS" $CORE_SITE_FILE) -eq '0' ]; then
    sed -in '/<\/configuration>/i\'"$NAME_NODE_CONFIG" $CORE_SITE_FILE
    sed -in '/<\/configuration>/i\'"$DATA_DIR_CONFIG" $CORE_SITE_FILE
    sed -in '/<\/configuration>/i\'"$HDFS_USER_CONFIG" $CORE_SITE_FILE
    log_info "core-site.xml 文件配置完成！"
else
    log_warn "core-site.xml 文件已配置！"
fi

#
# 配置 hadoop hdfs-site.xml 文件
#
WEB_CONFIG='
    <!-- nn web端访问地址-->\
	<property>\
        <name>dfs.namenode.http-address</name>\
        <value>'$(head -n 1 $HOME_DIR/conf/workers)':9870</value>\
    </property>'

SECONDARY_WEB_CONFIG='
    <!-- 2nn web端访问地址-->\
    <property>\
        <name>dfs.namenode.secondary.http-address</name>\
        <value>'$(sed -n '3p' $HOME_DIR/conf/workers)':9868</value>\
    </property>'

HDFS_SITE_FILE=$HADOOP_HOME/etc/hadoop/hdfs-site.xml
# 判断 hdfs_site.xml 文件是否已经配置
if [ $(grep -c "dfs.namenode.http-address" $HDFS_SITE_FILE) -eq '0' ]; then
    sed -in '/<\/configuration>/i\'"$WEB_CONFIG" $HDFS_SITE_FILE
    sed -in '/<\/configuration>/i\'"$SECONDARY_WEB_CONFIG" $HDFS_SITE_FILE
    log_info "hdfs-site.xml 文件配置完成！"
else
    log_warn "hdfs-site.xml 文件已配置！"
fi
