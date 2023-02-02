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

        # 解决日志冲突问题
        mv $HIVE_HOME/lib/log4j-slf4j-impl-2.10.0.jar $HIVE_HOME/lib/log4j-slf4j-impl-2.10.0.jar.bak

    else
        log_warn "HIVE_HOME 环境变量已配置"
    fi

    # 修改 hive 项目权限为 marmot:marmot
    chown marmot:marmot -R $HIVE_HOME

    log_info "========== HIVE 配置完成 =========="

fi


#
# hive 元数据配置到 mysql
#

HIVE_SITE_FILE=$HIVE_HOME/conf/hive-site.xml

if [ ! -f $HIVE_SITE_FILE ]; then
    # 拷贝 hive-site.xml 模板文件
    cp $HOME_DIR/template/configuration.xml $HIVE_SITE_FILE
    # 拷贝 mysql 驱动
    cp $HOME_DIR/softwares/mysql/mysql-connector-java-5.1.27-bin.jar $HIVE_HOME/lib/
    # 设置拷贝文件的权限
    chown marmot:marmot -R $HIVE_HOME


    MYSQL_URL_CONFIG='  
    <property>\
        <name>javax.jdo.option.ConnectionURL</name>\
        <value>jdbc:mysql://'$(head -n 1 $HOME_DIR/conf/workers)':3306/metastore?useSSL=false</value>\
    </property>'

    MYSQL_DRIVER_NAME_CONFIG='
    <property>\
        <name>javax.jdo.option.ConnectionDriverName</name>\
        <value>com.mysql.jdbc.Driver</value>\
    </property>'

    MYSQL_USERNAME_CONFIG='
    <property>\
        <name>javax.jdo.option.ConnectionUserName</name>\
        <value>root</value>\
    </property>'

    MYSQL_PASSWD_CONFIG='
    <property>\
        <name>javax.jdo.option.ConnectionPassword</name>\
        <value>Qs23=zs32</value>\
    </property>'


    
    sed -in '/<\/configuration>/i\'"$MYSQL_URL_CONFIG" $HIVE_SITE_FILE


fi
