#!/bin/bash

# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh
# 加载配置文件
source $HOME_DIR/conf/config.conf

source /etc/profile

IFS=',' read -ra zookeeper_nodes <<<$ZOOKEEPER_NODES

case $1 in
"start") {
    for host in ${zookeeper_nodes[@]}; do
        echo =============== zookeeper $i 启动 ===============
        ssh $HADOOP_USER@$host "$ZOOKEEPER_HOME/bin/zkServer.sh start"
    done
} ;;
"stop") {
    for host in ${zookeeper_nodes[@]}; do
        echo =============== zookeeper $i 停止 ===============
        ssh $HADOOP_USER@$host "$ZOOKEEPER_HOME/bin/zkServer.sh stop"
    done
} ;;
"status") {
    for host in ${zookeeper_nodes[@]}; do
        echo =============== zookeeper $i 状态 ===============
        ssh $HADOOP_USER@$host "$ZOOKEEPER_HOME/bin/zkServer.sh status"
    done
} ;;
esac
