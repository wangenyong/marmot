#!/bin/bash

#################################
#
# zookeeper version "3.5.7"
#
# 配置 zookeeper
#
#################################

# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh
# 加载配置文件
source $HOME_DIR/conf/config.conf

IFS=',' read -ra zookeeper_nodes <<<$ZOOKEEPER_NODES

log_info "========== 开始安装 ZOOKEEPER =========="

# 判断 zookeeper 是否已经安装
if [ -d /opt/marmot/apache-zookeeper-* ]; then
    log_warn "zookeeper 已经安装!"
else
    # 安装 zookeeper
    pv $HOME_DIR/softwares/apache-zookeeper-3.5.7-bin.tar.gz | tar -zx -C /opt/marmot/

    # 创建环境变量文件
    MARMOT_PROFILE="/etc/profile.d/marmot_env.sh"
    if [ ! -f $MARMOT_PROFILE ]; then
        touch $MARMOT_PROFILE
    fi

    # 配置 zookeeper 环境变量
    if [ $(grep -c "ZOOKEEPER_HOME" $MARMOT_PROFILE) -eq '0' ]; then
        cd /opt/marmot/apache-zookeeper-*
        ZOOKEEPER_HOME="ZOOKEEPER_HOME="$(pwd)
        cd -

        echo -e >>$MARMOT_PROFILE
        echo '#***** ZOOKEEPER_HOME *****' >>$MARMOT_PROFILE
        echo "export "$ZOOKEEPER_HOME >>$MARMOT_PROFILE

        source /etc/profile

        log_info "ZOOKEEPER_HOME 环境变量设置完成: "$ZOOKEEPER_HOME
    else
        log_warn "ZOOKEEPER_HOME 环境变量已配置"
    fi
    log_info "========== ZOOKEEPER 安装完成 =========="
fi

#################################
# 配置集群节点
#################################
source /etc/profile

if [ ! -d "$ZOOKEEPER_HOME/data" ]; then
    mkdir -p $ZOOKEEPER_HOME/data
    touch $ZOOKEEPER_HOME/data/myid

    mv $ZOOKEEPER_HOME/conf/zoo_sample.cfg $ZOOKEEPER_HOME/conf/zoo.cfg

    sed -i -r '/^dataDir/s|.*|dataDir='$ZOOKEEPER_HOME'/data|' $ZOOKEEPER_HOME/conf/zoo.cfg
    echo "########## cluster ###########" >>$ZOOKEEPER_HOME/conf/zoo.cfg

    # 修改 zookeeper 项目权限为 marmot:marmot
    chown marmot:marmot -R $ZOOKEEPER_HOME

    # 集群分发 zookeeper
    sh $SCRIPT_DIR/msync.sh $ZOOKEEPER_NODES $ZOOKEEPER_HOME
    # 集群分发环境变量
    sh $SCRIPT_DIR/msync.sh $ZOOKEEPER_NODES /etc/profile.d/marmot_env.sh

    i=1
    for node in ${zookeeper_nodes[@]}; do
        echo "server.$i=$node:2888:3888" >>$ZOOKEEPER_HOME/conf/zoo.cfg
        ssh $HADOOP_USER@$node "echo $i >>$ZOOKEEPER_HOME/data/myid"
        let i+=1
    done
    # 集群分发配置文件
    sh $SCRIPT_DIR/msync.sh $ZOOKEEPER_NODES $ZOOKEEPER_HOME/conf/zoo.cfg
fi

