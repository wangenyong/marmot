#!/bin/bash

#################################
#
# kafka version "3.0.0"
#
# 配置 kafka
#
#################################

# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh
# 加载配置文件
source $HOME_DIR/conf/config.conf

IFS=',' read -ra kafka_nodes <<<$KAFKA_NODES

log_info "========== 开始安装 KAFKA =========="

# 判断 kafka 是否已经安装
if [ -d /opt/marmot/kafka_* ]; then
    log_warn "kafka 已经安装!"
else
    # 安装 kafka
    pv $HOME_DIR/softwares/kafka_2.12-3.0.0.tgz | tar -zx -C /opt/marmot/

    # 创建环境变量文件
    MARMOT_PROFILE="/etc/profile.d/marmot_env.sh"
    if [ ! -f $MARMOT_PROFILE ]; then
        touch $MARMOT_PROFILE
    fi

    # 配置 kafka 环境变量
    if [ $(grep -c "KAFKA_HOME" $MARMOT_PROFILE) -eq '0' ]; then
        cd /opt/marmot/kafka_*
        KAFKA_HOME="KAFKA_HOME="$(pwd)
        cd -

        echo -e >>$MARMOT_PROFILE
        echo '#***** KAFKA_HOME *****' >>$MARMOT_PROFILE
        echo "export "$KAFKA_HOME >>$MARMOT_PROFILE
        echo 'export PATH=$PATH:$KAFKA_HOME/bin' >>$MARMOT_PROFILE

        source /etc/profile

        log_info "KAFKA_HOME 环境变量设置完成: "$KAFKA_HOME
    else
        log_warn "KAFKA_HOME 环境变量已配置"
    fi
    log_info "========== KAFKA 安装完成 =========="
fi

#################################
# 配置集群节点
#################################
source /etc/profile

if [ ! -d "$KAFKA_HOME/logs" ]; then
    mkdir -p $KAFKA_HOME/logs

    i=1
    connect=""
    length=${#kafka_nodes[@]}
    for node in ${kafka_nodes[@]}; do
        if [ $i -eq $length ]; then
            connect="$connect$node:2181/kafka"
        else
            connect="$connect$node:2181,"
        fi
        let i+=1
    done
    cp $KAFKA_HOME/config/server.properties $KAFKA_HOME/config/server.properties.bak
    sed -i -r '/^log.dirs/s|.*|log.dirs='$KAFKA_HOME'/logs|' $KAFKA_HOME/config/server.properties
    sed -i -r '/^zookeeper.connect=/s|.*|zookeeper.connect='$connect'|' $KAFKA_HOME/config/server.properties

    # 修改 kafka 项目权限为 marmot:marmot
    chown marmot:marmot -R $KAFKA_HOME

    # 集群分发 kafka
    sh $SCRIPT_DIR/msync.sh $ZOOKEEPER_NODES $KAFKA_HOME
    # 集群分发环境变量
    sh $SCRIPT_DIR/msync.sh $KAFKA_NODES /etc/profile.d/marmot_env.sh

    i=1
    for node in ${kafka_nodes[@]}; do
        cmd="sed -i -r '/^broker.id=/s|.*|broker.id='$i'|' $KAFKA_HOME/config/server.properties"
        ssh $HADOOP_USER@$node $cmd
        let i+=1
    done
fi