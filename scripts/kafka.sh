#!/bin/bash

#################################
#
# kafka version "3.0.0"
#
# kafka 启停脚本
#
#################################

# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh
# 加载配置文件
source $HOME_DIR/conf/config.conf

source /etc/profile

IFS=',' read -ra kafka_nodes <<<$KAFKA_NODES

case $1 in
"start")
    for host in ${kafka_nodes[@]}; do
        echo =============== kafka $i 启动 ===============
        ssh $HADOOP_USER@$host "$KAFKA_HOME/bin/kafka-server-start.sh -daemon $KAFKA_HOME/config/server.properties"
    done
    ;;
"stop")
    for host in ${kafka_nodes[@]}; do
        echo =============== kafka $i 停止 ===============
        ssh $HADOOP_USER@$host "$KAFKA_HOME/bin/kafka-server-stop.sh"
    done
    ;;
"status") ;;

esac
