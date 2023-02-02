#!/bin/bash

# hive version "3.1.2"

# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh

log_info "========== 开始配置 HIVE =========="

# 判断 Spark 是否已经安装
if [ -d /opt/marmot/apache-hive-3.1.2-* ]; then
    log_warn "Hive 已经安装!"
else
    # 安装 Spark
    pv $HOME_DIR/softwares/apache-hive-3.1.2-bin.tar.gz | tar -zx -C /opt/marmot/

    # 创建环境变量文件
    MARMOT_PROFILE="/etc/profile.d/marmot_env.sh"
    if [ ! -f $MARMOT_PROFILE ]; then
        touch $MARMOT_PROFILE
    fi

    # 配置 Spark 环境变量
    if [ $(grep -c "HIVE_HOME" $MARMOT_PROFILE) -eq '0' ]; then
        cd /opt/marmot/apache-hive-3.1.2-*
        HIVE_PATH="HIVE_HOME="$(pwd)
        cd -

        echo -e >>$MARMOT_PROFILE
        echo '#***** HIVE_HOME *****' >>$MARMOT_PROFILE
        echo "export "$HIVE_PATH >>$MARMOT_PROFILE
        echo 'export PATH=$PATH:$HIVE_HOME/bin' >>$MARMOT_PROFILE

        source /etc/profile

        log_info "HIVE_HOME 环境变量设置完成: "$HIVE_HOME

    else
        log_warn "HIVE_HOME 环境变量已配置"
    fi

    # 修改 hive 项目权限为 marmot:marmot
    chown marmot:marmot -R $HIVE_HOME

    log_info "========== HIVE 配置完成 =========="

fi