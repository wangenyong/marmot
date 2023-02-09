#!/bin/bash

# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh
# 加载配置文件
source $HOME_DIR/conf/config.conf

IFS=',' read -ra workers <<<$HADOOP_WORKERS
IFS=',' read -ra azkaban_nodes <<<$AZKABAN_NODES
IFS=',' read -ra zookeeper_nodes <<<$ZOOKEEPER_NODES

function check_process() {
    pid=$(ps -ef 2>/dev/null | grep -v grep | grep -i $1 | awk '{print$2}')
    ppid=$(netstat -nltp 2>/dev/null | grep $2 | awk '{print $7}' | cut -d '/' -f 1)
    echo $pid
    [[ "$pid" =~ "$ppid" ]] && [ "$ppid" ] && return 0 || return 1
}

function hive_start() {
    metapid=$(check_process HiveMetastore 9083)
    cmd="ssh $HADOOP_USER@${workers[0]} nohup hive --service metastore >$HIVE_HOME/logs/metastore.log 2>&1 &"
    [ -z "$metapid" ] && eval $cmd || echo "Metastroe 服务已启动"
    server2pid=$(check_process HiveServer2 10000)
    cmd="ssh $HADOOP_USER@${workers[0]} nohup hiveserver2 >$HIVE_HOME/logs/hiveServer2.log 2>&1 &"
    [ -z "$server2pid" ] && eval $cmd || echo "HiveServer2 服务已启动"
}

function hive_stop() {
    metapid=$(check_process HiveMetastore 9083)
    [ "$metapid" ] && kill $metapid || echo "Metastore 服务未启动"
    server2pid=$(check_process HiveServer2 10000)
    [ "$server2pid" ] && kill $server2pid || echo "HiveServer2 服务未启动"
}

#1. 判断参数个数
if [ $# -lt 1 ]; then
    log_warn 请输入命令参数!
    exit
fi

case "$1" in
install)
    # 配置 ssh 免密登录，关闭防火墙
    sh $SCRIPT_DIR/hadoop-ssh.sh hadoop go
    # 安装配置 java sdk
    sh $SCRIPT_DIR/deploy-jdk.sh
    # 安装配置 hadoop
    sh $SCRIPT_DIR/deploy-hadoop.sh
    # 集群分发 java 和 hadoop
    sh $SCRIPT_DIR/msync.sh $HADOOP_WORKERS /opt/marmot
    # 集群分发环境变量
    sh $SCRIPT_DIR/msync.sh $HADOOP_WORKERS /etc/profile.d/marmot_env.sh
    # 安装 mysql
    sh $SCRIPT_DIR/deploy-mysql.sh
    # 安装配置 hive
    sh $SCRIPT_DIR/deploy-hive.sh
    # 安装配置 spark
    sh $SCRIPT_DIR/deploy-spark.sh
    ;;
start)
    source /etc/profile

    log_info "========== 启动 hadoop 集群 =========="
    log_info "---------- 启动 hdfs ----------"
    ssh $HADOOP_USER@${workers[0]} "$HADOOP_HOME/sbin/start-dfs.sh"
    log_info "---------- 启动 yarn ----------"
    ssh $HADOOP_USER@${workers[1]} "$HADOOP_HOME/sbin/start-yarn.sh"
    log_info "---------- 启动 hadoop historyserver ----------"
    ssh $HADOOP_USER@${workers[0]} "$HADOOP_HOME/bin/mapred --daemon start historyserver"
    log_info "---------- 启动 hive ----------"
    hive_start
    if [ -d "$SPARK_HOME" ]; then
        log_info "---------- 启动 spark historyserver ----------"
        ssh $HADOOP_USER@${workers[0]} "$SPARK_HOME/sbin/start-history-server.sh"
    fi
    log_info "---------- 启动 azkaban ----------"
    for host in ${azkaban_nodes[@]}; do
        echo =============== $host start azkaban-exec ===============
        ssh $HADOOP_USER@$host "cd $AZKABAN_HOME/azkaban-exec; bin/start-exec.sh"
        sleep 5s
		ssh $HADOOP_USER@$host "cd $AZKABAN_HOME/azkaban-exec; curl -G \"$host:\$(<./executor.port)/executor?action=activate\" && echo "
    done
    echo =============== start azkaban-web ===============
    ssh $HADOOP_USER@${azkaban_nodes[0]} "cd $AZKABAN_HOME/azkaban-web; bin/start-web.sh"
    log_info "---------- 启动 zookeeper ----------"
    for host in ${zookeeper_nodes[@]}; do
        echo =============== zookeeper $i 启动 ===============
        ssh $HADOOP_USER@$host "$ZOOKEEPER_HOME/bin/zkServer.sh start"
    done
    ;;
stop)
    source /etc/profile
    log_info "========== 关闭 hadoop 集群 =========="
    log_info "---------- 关闭 zookeeper ----------"
    for host in ${zookeeper_nodes[@]}; do
        echo =============== zookeeper $i 停止 ===============
        ssh $HADOOP_USER@$host "$ZOOKEEPER_HOME/bin/zkServer.sh stop"
    done
    log_info "---------- 关闭 azkaban ----------"
    echo =============== stop azkaban-web ===============
    ssh $HADOOP_USER@${azkaban_nodes[0]} "cd $AZKABAN_HOME/azkaban-web; bin/shutdown-web.sh"
    for host in ${azkaban_nodes[@]}; do
        echo =============== $host stop azkaban-exec ===============
        ssh $HADOOP_USER@$host "cd $AZKABAN_HOME/azkaban-exec; bin/shutdown-exec.sh"
    done
    if [ -d "$SPARK_HOME" ]; then
        log_info "---------- 关闭 spark historyserver ----------"
        ssh $HADOOP_USER@${workers[0]} "$SPARK_HOME/sbin/stop-history-server.sh"
    fi
    log_info "---------- 关闭 hive ----------"
    hive_stop
    log_info "---------- 关闭 hadoop historyserver ----------"
    ssh $HADOOP_USER@${workers[0]} "$HADOOP_HOME/bin/mapred --daemon stop historyserver"
    log_info "---------- 关闭 yarn ----------"
    ssh $HADOOP_USER@${workers[1]} "$HADOOP_HOME/sbin/stop-yarn.sh"
    log_info "---------- 关闭 hdfs ----------"
    ssh $HADOOP_USER@${workers[0]} "$HADOOP_HOME/sbin/stop-dfs.sh"
    ;;
status)
    IFS=',' read -ra array <<<$HADOOP_WORKERS
    for host in ${array[@]}; do
        echo =============== $host ===============
        ssh $host jps
    done
    # 查看 hive 运行状态
    echo =============== hive service status ===============
    check_process HiveMetastore 9083 >/dev/null && echo "Metastore 服务运行正常" || echo "Metastore 服务运行异常"
	check_process HiveServer2 10000 >/dev/null && echo "HiveServer2 服务运行正常" || echo "HiveServer2 服务运行异常"
    echo =============== zookeeper service status ===============
    for host in ${zookeeper_nodes[@]}; do
        echo =============== zookeeper $i 状态 ===============
        ssh $HADOOP_USER@$host "$ZOOKEEPER_HOME/bin/zkServer.sh status"
    done
    ;;
delete)
    IFS=',' read -ra array <<<$HADOOP_WORKERS
    for host in ${array[@]}; do
        echo =============== $host ===============
        ssh $host rm -rfv /opt/marmot
    done
    ;;
*)
    echo "default (none of above)"
    ;;
esac
