#!/bin/bash

# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh
# 加载环境变量
source /etc/profile

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
# 判断 hdfs-site.xml 文件是否已经配置
if [ $(grep -c "dfs.namenode.http-address" $HDFS_SITE_FILE) -eq '0' ]; then
    sed -in '/<\/configuration>/i\'"$WEB_CONFIG" $HDFS_SITE_FILE
    sed -in '/<\/configuration>/i\'"$SECONDARY_WEB_CONFIG" $HDFS_SITE_FILE
    log_info "hdfs-site.xml 文件配置完成！"
else
    log_warn "hdfs-site.xml 文件已配置！"
fi

#
# 配置 hadoop yarn yarn-site.xml 文件
#
MR_CONFIG='
    <!-- 指定MR走shuffle -->\
    <property>\
        <name>yarn.nodemanager.aux-services</name>\
        <value>mapreduce_shuffle</value>\
    </property>'

RM_HOSTNAME='
    <!-- 指定ResourceManager的地址-->\
    <property>\
        <name>yarn.resourcemanager.hostname</name>\
        <value>'$(sed -n '2p' $HOME_DIR/conf/workers)'</value>\
    </property>'

ENV_CONFIG='
    <!-- 环境变量的继承 -->\
    <property>\
        <name>yarn.nodemanager.env-whitelist</name>\
        <value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_MAPRED_HOME</value>\
    </property>'

LOG_AGGREGATION_CONFIG='
    <!-- 开启日志聚集功能 -->\
    <property>\
        <name>yarn.log-aggregation-enable</name>\
        <value>true</value>\
    </property>'

LOG_SERVER_CONFIG='
    <!-- 设置日志聚集服务器地址 -->\
    <property>\
        <name>yarn.log.server.url</name>\
        <value>'$(head -n 1 $HOME_DIR/conf/workers)':19888/jobhistory/logs</value>\
    </property>'

LOG_RETAIN_CONFIG='
    <!-- 设置日志保留时间为7天 -->\
    <property>\
        <name>yarn.log-aggregation.retain-seconds</name>\
        <value>604800</value>\
    </property>'

YARN_SITE_FILE=$HADOOP_HOME/etc/hadoop/yarn-site.xml
# 判断 yarn-site.xml 文件是否已经配置
if [ $(grep -c "yarn.nodemanager.aux-services" $YARN_SITE_FILE) -eq '0' ]; then
    sed -in '/<\/configuration>/i\'"$MR_CONFIG" $YARN_SITE_FILE
    sed -in '/<\/configuration>/i\'"$RM_HOSTNAME" $YARN_SITE_FILE
    sed -in '/<\/configuration>/i\'"$ENV_CONFIG" $YARN_SITE_FILE
    sed -in '/<\/configuration>/i\'"$LOG_AGGREGATION_CONFIG" $YARN_SITE_FILE
    sed -in '/<\/configuration>/i\'"$LOG_SERVER_CONFIG" $YARN_SITE_FILE
    sed -in '/<\/configuration>/i\'"$LOG_RETAIN_CONFIG" $YARN_SITE_FILE
    log_info "yarn-site.xml 文件配置完成！"
else
    log_warn "yarn-site.xml 文件已配置！"
fi

#
# 配置 hadoop mapReduce mapred-site.xml 文件
#
MR_YARN_CONFIG='
    <!-- 指定MapReduce程序运行在Yarn上 -->\
    <property>\
        <name>mapreduce.framework.name</name>\
        <value>yarn</value>\
    </property>'

HISTORY_ADDRESS_CONFIG='
    <!-- 历史服务器端地址 -->\
    <property>\
        <name>mapreduce.jobhistory.address</name>\
        <value>'$(head -n 1 $HOME_DIR/conf/workers)':10020</value>\
    </property>'

HISTORY_WEB_CONFIG='
    <!-- 历史服务器 Web 端地址 -->\
    <property>\
        <name>mapreduce.jobhistory.webapp.address</name>\
        <value>'$(head -n 1 $HOME_DIR/conf/workers)':19888</value>\
    </property>'

MR_SITE_FILE=$HADOOP_HOME/etc/hadoop/mapred-site.xml
# 判断 mapred-site.xml 文件是否已经配置
if [ $(grep -c "mapreduce.framework.name" $MR_SITE_FILE) -eq '0' ]; then
    sed -in '/<\/configuration>/i\'"$MR_YARN_CONFIG" $MR_SITE_FILE
    sed -in '/<\/configuration>/i\'"$HISTORY_ADDRESS_CONFIG" $MR_SITE_FILE
    sed -in '/<\/configuration>/i\'"$HISTORY_WEB_CONFIG" $MR_SITE_FILE
    log_info "mapred-site.xml 文件配置完成！"
else
    log_warn "mapred-site.xml 文件已配置！"
fi

#
# 配置 workers
#
cat $HOME_DIR/conf/workers >$HADOOP_HOME/etc/hadoop/workers
