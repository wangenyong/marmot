#!/bin/bash

# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh
# 加载配置文件
source $HOME_DIR/conf/config.conf

function check_process() {
    pid=$(ps -ef 2>/dev/null | grep -v grep | grep -i $1 | awk '{print$2}')
    ppid=$(netstat -nltp 2>/dev/null | grep $2 | awk '{print $7}' | cut -d '/' -f 1)
    echo $pid
    [[ "$pid" =~ "$ppid" ]] && [ "$ppid" ] && return 0 || return 1
}

function hive_start() {
    metapid=$(check_process HiveMetastore 9083)
    cmd="ssh marmot@hadoop101 nohup hive --service metastore >$HIVE_HOME/logs/metastore.log 2>&1 &"
    [ -z "$metapid" ] && eval $cmd || echo "Metastroe 服务已启动"
    server2pid=$(check_process HiveServer2 10000)
    cmd="ssh marmot@hadoop101 nohup hiveserver2 >$HIVE_HOME/logs/hiveServer2.log 2>&1 &"
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
    # 配置 SSH 免密登录，关闭防火墙
    sh $SCRIPT_DIR/hadoop-ssh.sh kettle go
    # 安装配置 JAVA SDK
    sh $SCRIPT_DIR/deploy-jdk.sh
    # 安装 Mysql
    sh $SCRIPT_DIR/deploy-mysql.sh
    # 安装配置 kettle
    sh $SCRIPT_DIR/deploy-kettle.sh
    # 集群分发 Java 和 kettle
    sh $SCRIPT_DIR/msync.sh /opt/marmot
    # 集群分发环境变量
    sh $SCRIPT_DIR/msync.sh /etc/profile.d/marmot_env.sh
    ;;
start)
    log_info "========== 启动 kettle 集群 =========="
    

    log_info "---------- 启动 Hdfs ----------"
    ssh marmot@hadoop101 "$HADOOP_HOME/sbin/start-dfs.sh"
    log_info "---------- 启动 Yarn ----------"
    ssh marmot@hadoop102 "$HADOOP_HOME/sbin/start-yarn.sh"
    log_info "---------- 启动 Hadoop Historyserver ----------"
    ssh marmot@hadoop101 "$HADOOP_HOME/bin/mapred --daemon start historyserver"
    log_info "---------- 启动 Hive ----------"
    hive_start

    if [ -d "$SPARK_HOME" ]; then
        log_info "---------- 启动 Spark Historyserver ----------"
        ssh marmot@hadoop101 "$SPARK_HOME/sbin/start-history-server.sh"
    fi
    ;;
stop)
    log_info "========== 关闭 Hadoop 集群 =========="
    if [ -d "$SPARK_HOME" ]; then
        log_info "---------- 关闭 Spark Historyserver ----------"
        ssh marmot@hadoop101 "$SPARK_HOME/sbin/stop-history-server.sh"
    fi
    log_info "---------- 关闭 Hive ----------"
    hive_stop
    log_info "---------- 关闭 Hadoop Historyserver ----------"
    ssh marmot@hadoop101 "$HADOOP_HOME/bin/mapred --daemon stop historyserver"
    log_info "---------- 关闭 Yarn ----------"
    ssh marmot@hadoop102 "$HADOOP_HOME/sbin/stop-yarn.sh"
    log_info "---------- 关闭 Hdfs ----------"
    ssh marmot@hadoop101 "$HADOOP_HOME/sbin/stop-dfs.sh"
    ;;
status)
    IFS=',' read -ra array <<<$HADOOP_WORKERS
    for host in ${array[@]}; do
        echo =============== $host ===============
        ssh $host jps
    done
    # 查看 Hive 运行状态
    check_process HiveMetastore 9083 >/dev/null && echo "Metastore 服务运行正常" || echo "Metastore 服务运行异常"
	check_process HiveServer2 10000 >/dev/null && echo "HiveServer2 服务运行正常" || echo "HiveServer2 服务运行异常"
    ;;
delete)
    IFS=',' read -ra array <<<$HADOOP_WORKERS
    for host in ${array[@]}; do
        ssh $host rm -rf /opt/marmot
    done
    ;;
*)
    echo "default (none of above)"
    ;;
esac
