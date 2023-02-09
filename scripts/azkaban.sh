#!/bin/bash

# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh
# 加载配置文件
source $HOME_DIR/conf/config.conf

source /etc/profile

IFS=',' read -ra azkaban_nodes <<<$ZOOKEEPER_NODES

case $1 in
"start") {
    log_info "---------- 启动 azkaban ----------"
    for host in ${azkaban_nodes[@]}; do
        echo =============== $host start azkaban-exec ===============
        ssh $HADOOP_USER@$host "cd $AZKABAN_HOME/azkaban-exec; bin/start-exec.sh"
        sleep 5s
        ssh $HADOOP_USER@$host "cd $AZKABAN_HOME/azkaban-exec; curl -G \"$host:\$(<./executor.port)/executor?action=activate\" && echo "
    done
    echo =============== start azkaban-web ===============
    ssh $HADOOP_USER@${azkaban_nodes[0]} "cd $AZKABAN_HOME/azkaban-web; bin/start-web.sh"
} ;;
"stop") {
    log_info "---------- 关闭 azkaban ----------"
    echo =============== stop azkaban-web ===============
    ssh $HADOOP_USER@${azkaban_nodes[0]} "cd $AZKABAN_HOME/azkaban-web; bin/shutdown-web.sh"
    for host in ${azkaban_nodes[@]}; do
        echo =============== $host stop azkaban-exec ===============
        ssh $HADOOP_USER@$host "cd $AZKABAN_HOME/azkaban-exec; bin/shutdown-exec.sh"
    done
} ;;
"status") {
} ;;
esac
