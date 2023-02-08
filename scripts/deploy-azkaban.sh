#!/bin/bash

#################################
#
# azkaban version "3.84.4"
#
# 配置 azkaban
#
#################################

# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh
# 加载配置文件
source $HOME_DIR/conf/config.conf

IFS=',' read -ra azkaban_nodes <<<$AZKABAN_NODES

log_info "========== 开始配置 AZKABAN =========="

AZKABAN_HOME=/opt/marmot/azkaban
# 判断 hadoop 是否已经安装
if [ -d $AZKABAN_HOME ]; then
    log_warn "azkaban 已经安装!"
else
    mkdir -p $AZKABAN_HOME
    # 安装 azkaban
    pv $HOME_DIR/softwares/azkaban/azkaban-db-3.84.4.tar.gz | tar -zx -C $AZKABAN_HOME
    pv $HOME_DIR/softwares/azkaban/azkaban-exec-server-3.84.4.tar.gz | tar -zx -C $AZKABAN_HOME
    pv $HOME_DIR/softwares/azkaban/azkaban-web-server-3.84.4.tar.gz | tar -zx -C $AZKABAN_HOME
    mv $AZKABAN_HOME/azkaban-exec-server-3.84.4 $AZKABAN_HOME/azkaban-exec
    mv $AZKABAN_HOME/azkaban-web-server-3.84.4 $AZKABAN_HOME/azkaban-web

    # 创建环境变量文件
    MARMOT_PROFILE="/etc/profile.d/marmot_env.sh"
    if [ ! -f $MARMOT_PROFILE ]; then
        touch $MARMOT_PROFILE
    fi

    # 配置 azkaban 环境变量
    if [ $(grep -c "AZKABAN_HOME" $MARMOT_PROFILE) -eq '0' ]; then
        echo -e >>$MARMOT_PROFILE
        echo '#***** AZKABAN_HOME *****' >>$MARMOT_PROFILE
        echo "export AZKABAN_HOME="$AZKABAN_HOME >>$MARMOT_PROFILE

        source /etc/profile

        log_info "AZKABAN_HOME 环境变量设置完成: "$AZKABAN_HOME
    else
        log_warn "AZKABAN_HOME 环境变量已配置"
    fi

    chown marmot:marmot -R $AZKABAN_HOME
fi

#################################
# 配置 mysql
#################################
mysql -uroot -p$MYSQL_ROOT_PASS -e "use azkaban"

if [[ $? -ne 0 ]]; then
    log_info "创建元数据库 azkaban"
    mysql -uroot -p$MYSQL_ROOT_PASS -e "CREATE DATABASE azkaban DEFAULT CHARSET utf8 COLLATE utf8_general_ci"

    mysql -uroot -p$MYSQL_ROOT_PASS -e "CREATE USER '$MYSQL_AZKABAN_USER'@'%' IDENTIFIED BY '$MYSQL_AZKABAN_PASS'"
    mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL ON azkaban.* TO '$MYSQL_AZKABAN_USER'@'%' IDENTIFIED BY '$MYSQL_AZKABAN_PASS'"
    mysql -uroot -p$MYSQL_ROOT_PASS -e 'flush privileges'

    mysql -u$MYSQL_AZKABAN_USER -p$MYSQL_AZKABAN_PASS azkaban -e "source $AZKABAN_HOME/azkaban-db-3.84.4/create-all-sql-3.84.4.sql"

    if [ $(grep -c "max_allowed_packet" /etc/my.cnf) -eq '0' ]; then
        echo "max_allowed_packet=1024M" >>/etc/my.cnf
        systemctl restart mysqld
    fi
else
    log_warn "数据库 azkaban 已创建"
fi

#################################
# 配置 executor server
#################################
EXECUTOER_CONF_FILE=$AZKABAN_HOME/azkaban-exec/conf/azkaban.properties
if [ $(grep -c "America/Los_Angeles" $EXECUTOER_CONF_FILE) -ne '0' ]; then
    sed -i -r '/^default\.timezone\.id/s/.*/default\.timezone\.id=Asia\/Shanghai/' $EXECUTOER_CONF_FILE
    sed -i -r '/^azkaban\.webserver\.url/s/.*/azkaban.webserver\.url=http:\/\/'${azkaban_nodes[0]}':8081/' $EXECUTOER_CONF_FILE
    sed -i -r '/^mysql\.host/s/.*/mysql\.host='${azkaban_nodes[0]}'/' $EXECUTOER_CONF_FILE
    sed -i -r '/^mysql\.password/s/.*/mysql\.password='$MYSQL_AZKABAN_PASS'/' $EXECUTOER_CONF_FILE
    echo "executor.port=12321" >>$EXECUTOER_CONF_FILE
fi

#################################
# 配置 web server
#################################
WEB_CONF_FILE=$AZKABAN_HOME/azkaban-web/conf/azkaban.properties
if [ $(grep -c "America/Los_Angeles" $WEB_CONF_FILE) -ne '0' ]; then
    sed -i -r '/^default\.timezone\.id/s/.*/default\.timezone\.id=Asia\/Shanghai/' $WEB_CONF_FILE
    sed -i -r '/^azkaban\.executorselector\.filters/s/.*/azkaban\.executorselector\.filters=StaticRemainingFlowSize,CpuStatus/' $WEB_CONF_FILE
    sed -i -r '/^mysql\.host/s/.*/mysql\.host='${azkaban_nodes[0]}'/' $WEB_CONF_FILE
    sed -i -r '/^mysql\.password/s/.*/mysql\.password='$MYSQL_AZKABAN_PASS'/' $WEB_CONF_FILE
fi

USER_CONF_FILE=$AZKABAN_HOME/azkaban-web/conf/azkaban-users.xml
if [ $(grep -c "marmot" $WEB_CONF_FILE) -eq '0' ]; then
    USER_CONFIG='<user password="'$AZKABAN_PASS'" roles="admin" username="'$AZKABAN_USER'"/>'
    sed -in '/<\/azkaban-users>/i\'"$USER_CONFIG" $USER_CONF_FILE
fi


#################################
# 同步分发集群
#################################

# 集群分发 azkaban-exec
sh $SCRIPT_DIR/msync.sh $AZKABAN_NODES $AZKABAN_HOME/azkaban-exec
# 集群分发环境变量
sh $SCRIPT_DIR/msync.sh $AZKABAN_NODES /etc/profile.d/marmot_env.sh