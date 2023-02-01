#!/bin/bash

# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh

#1. 判断参数个数
if [ $# -lt 1 ]; then
    log_warn 请输入命令参数!
    exit
fi

case "$1" in
install)
    # 配置 SSH 免密登录，关闭防火墙
    sh $SCRIPT_DIR/hadoop-ssh.sh go
    # 安装配置 JAVA SDK
    sh $SCRIPT_DIR/deploy-jdk.sh
    # 安装 Hadoop
    sh $SCRIPT_DIR/deploy-hadoop.sh
    # 配置 Hadoop
    sh $SCRIPT_DIR/config-hadoop.sh
    # 修改项目权限
    chown marmot:marmot -R /opt/marmot
    # 集群分发
    sh $SCRIPT_DIR/msync.sh /opt/marmot
    sh $SCRIPT_DIR/msync.sh /etc/profile.d/marmot_env.sh
    ;;
start)
    source /etc/profile

    if [ ! -d $HADOOP_HOME/data ]; then
        log_info "格式化 NameNode"
        ssh marmot@hadoop101 "hdfs namenode -format"
    fi

    log_info "========== 启动 Hadoop 集群 =========="
    log_info "---------- 启动 Hdfs ----------"
    ssh marmot@hadoop101 "$HADOOP_HOME/sbin/start-dfs.sh"
    log_info "---------- 启动 Yarn ----------"
    ssh marmot@hadoop102 "$HADOOP_HOME/sbin/start-yarn.sh"
    log_info "---------- 启动 Historyserver ----------"
    ssh marmot@hadoop101 "$HADOOP_HOME/bin/mapred --daemon start historyserver"
    ;;
stop)
    log_info "========== 关闭 Hadoop 集群 =========="
    log_info "---------- 关闭 Historyserver ----------"
    ssh marmot@hadoop101 "$HADOOP_HOME/bin/mapred --daemon stop historyserver"
    log_info "---------- 关闭 Yarn ----------"
    ssh marmot@hadoop102 "$HADOOP_HOME/sbin/stop-yarn.sh"
    log_info "---------- 关闭 Hdfs ----------"
    ssh marmot@hadoop101 "$HADOOP_HOME/sbin/stop-dfs.sh"
    ;;
show)
    IFS=$'\n' read -d '' -r -a lines <$HOME_DIR/conf/workers
    for host in ${lines[@]}; do
    echo =============== $host ===============
        ssh $host jps
    done
    ;;
delete)
    IFS=$'\n' read -d '' -r -a lines <$HOME_DIR/conf/workers
    for host in ${lines[@]}; do
        ssh $host rm -rf /opt/marmot
    done
    ;;
*)
    echo "default (none of above)"
    ;;
esac
