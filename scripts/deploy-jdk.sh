#!/bin/bash


# 判断大数据项目根目录是否已经创建
if [ ! -d /opt/marmot ]; then
    mkdir /opt/marmot
    echo "marmot folder created!"
fi
# 判断 Java Jdk 是否已经安装
if [ -d /opt/marmot/jdk1.8.0_* ]; then
    echo "jdk has been installed!"
else
    # 安装 Java Jdk
    tar -zxvf ../softwares/jdk-8u212-linux-x64.tar.gz -C /opt/marmot/

    # 创建环境变量文件
    MARMOT_PROFILE="/etc/profile.d/marmot_env.sh"
    if [ ! -f $MARMOT_PROFILE ]; then
        touch $MARMOT_PROFILE
    fi

    # 配置 Java Jdk 环境变量
    if [ `grep -c "JAVA_HOME" $MARMOT_PROFILE` -eq '0' ]; then
        cd /opt/marmot/jdk1.8.0_*
        JDK_PATH="JAVA_HOME="`pwd`

        echo '#***** JAVA_HOME *****' >> $MARMOT_PROFILE
        echo "export "$JDK_PATH >> $MARMOT_PROFILE
        echo 'export PATH=$PATH:$JAVA_HOME/bin' >> $MARMOT_PROFILE

        echo "jdk profile setting success!"
    fi
    
    echo "jdk install success!"

fi
