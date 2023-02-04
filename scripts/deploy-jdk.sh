#!/bin/bash

#################################
#
# java version "1.8.0_212"
#
# 配置 java sdk
#
#################################

# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh

log_info "========== 开始配置 JAVA JDK =========="

# 判断数据项目根目录是否已经创建
if [ ! -d /opt/marmot ]; then
    mkdir /opt/marmot
    log_info "创建 marmot 项目目录完成!"
fi
# 判断 java sdk 是否已经安装
if [ -d /opt/marmot/jdk1.8.0_* ]; then
    log_warn "JAVA JDK 已经安装!"
else
    # 安装 java sdk
    pv $HOME_DIR/softwares/jdk-8u212-linux-x64.tar.gz | tar -zx -C /opt/marmot/

    # 创建环境变量文件
    MARMOT_PROFILE="/etc/profile.d/marmot_env.sh"
    if [ ! -f $MARMOT_PROFILE ]; then
        touch $MARMOT_PROFILE
    fi

    # 配置 java sdk 环境变量
    if [ $(grep -c "JAVA_HOME" $MARMOT_PROFILE) -eq '0' ]; then
        cd /opt/marmot/jdk1.8.0_*
        JDK_PATH="JAVA_HOME="$(pwd)
        cd -

        echo '#***** JAVA_HOME *****' >>$MARMOT_PROFILE
        echo "export "$JDK_PATH >>$MARMOT_PROFILE
        echo 'export PATH=$PATH:$JAVA_HOME/bin' >>$MARMOT_PROFILE

        source /etc/profile

        log_info "JAVA_HOME 环境变量设置完成: "$JAVA_HOME
    else
        log_warn "JAVA_HOME 环境变量已配置"
    fi
    
    log_info "========== JAVA JDK 配置完成 =========="

fi