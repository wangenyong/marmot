#!/bin/bash

# hadoop version "3.1.3"

# 判断大数据项目根目录是否已经创建
if [ ! -d /opt/marmot ]; then
    mkdir /opt/marmot
    echo "marmot folder created!"
fi

# 判断 Java Jdk 是否已经安装
if [ -d /opt/marmot/hadoop-* ]; then
    echo "hadoop has been installed!"
else
    # 安装 Java Jdk
    tar -zxvf ../softwares/hadoop-3.1.3.tar.gz -C /opt/marmot/

    # 创建环境变量文件
    MARMOT_PROFILE="/etc/profile.d/marmot_env.sh"
    if [ ! -f $MARMOT_PROFILE ]; then
        touch $MARMOT_PROFILE
    fi

    # 配置 Hadoop Jdk 环境变量
    if [ $(grep -c "HADOOP_HOME" $MARMOT_PROFILE) -eq '0' ]; then
        cd /opt/marmot/hadoop-*
        HADOOP_PATH="HADOOP_HOME="$(pwd)
        cd -

        echo -e >>$MARMOT_PROFILE
        echo '#***** HADOOP_HOME *****' >>$MARMOT_PROFILE
        echo "export "$HADOOP_PATH >>$MARMOT_PROFILE
        echo 'export PATH=$PATH:$HADOOP_HOME/bin' >>$MARMOT_PROFILE
        echo 'export PATH=$PATH:$HADOOP_HOME/sbin' >>$MARMOT_PROFILE

        echo "hadoop profile setting success!"
    fi

    echo "hadoop install success!"

fi
