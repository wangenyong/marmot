#!/bin/bash

# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh
# 加载配置文件
source $HOME_DIR/conf/config.conf

IFS=',' read -ra nodes <<<$KETTLE_NODES

#1. 判断参数个数
if [ $# -lt 1 ]; then
    log_warn 请输入命令参数!
    exit
fi

case "$1" in
install)
    # 配置 ssh 免密登录，关闭防火墙
    sh $SCRIPT_DIR/hadoop-ssh.sh kettle go
    # 安装配置 java sdk
    sh $SCRIPT_DIR/deploy-jdk.sh
    # 安装 mysql
    sh $SCRIPT_DIR/deploy-mysql.sh
    # 安装配置 kettle
    sh $SCRIPT_DIR/deploy-kettle.sh
    # 集群分发 java 和 kettle
    sh $SCRIPT_DIR/msync.sh $KETTLE_NODES /opt/marmot
    # 集群分发环境变量
    sh $SCRIPT_DIR/msync.sh $KETTLE_NODES /etc/profile.d/marmot_env.sh
    ;;
start)
    log_info "========== 启动 kettle 集群 =========="

    KETTLE_HOME=/opt/marmot/data-integration

    i=0
    for node in ${nodes[@]}; do
        ssh $KETTLE_USER@$node "nohup $KETTLE_HOME/carte.sh $node 808$i >$KETTLE_HOME/logs/kettle.log 2>&1 &"
        let i+=1
    done
    ;;
stop)
    log_info "========== 关闭 kettle 集群 =========="
    
    i=0
    for host in ${nodes[@]}; do
        echo =============== $host ===============
        cmd="fuser -k 808$i/tcp"
        ssh $host $cmd
        let i+=1
    done
    ;;
status)
    i=0
    for host in ${nodes[@]}; do
        echo =============== $host ===============
        cmd="netstat -nlp | grep 808$i"
        ssh $host $cmd
        let i+=1
    done
    ;;
delete)
    for host in ${nodes[@]}; do
        ssh $host rm -rf /opt/marmot
    done
    ;;
*)
    echo "default (none of above)"
    ;;
esac
