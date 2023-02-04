#!/bin/bash

#################################
#
# mysql version "5.7.16"
#
# 配置 mysql
#
#################################

# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh
# 加载配置文件
source $HOME_DIR/conf/config.conf

log_info "========== 开始配置 MYSQL =========="

# 卸载自带的Mysql-libs（如果之前安装过mysql，要全都卸载掉）
rpm -qa | grep -i -E mysql\|mariadb | xargs -n1 sudo rpm -e --nodeps

DIR_MYSQL=/var/lib/mysql
LOG_MYSQL=/var/log/mysqld.log

# 清除卸载残留目录
if [ -d "$DIR_MYSQL" ]; then
    rm -rf $DIR_MYSQL
    rm -rf $LOG_MYSQL
fi

rpm -ivh $HOME_DIR/softwares/mysql/01_mysql-community-common-5.7.16-1.el7.x86_64.rpm
rpm -ivh $HOME_DIR/softwares/mysql/02_mysql-community-libs-5.7.16-1.el7.x86_64.rpm
rpm -ivh $HOME_DIR/softwares/mysql/03_mysql-community-libs-compat-5.7.16-1.el7.x86_64.rpm
rpm -ivh $HOME_DIR/softwares/mysql/04_mysql-community-client-5.7.16-1.el7.x86_64.rpm
rpm -ivh $HOME_DIR/softwares/mysql/05_mysql-community-server-5.7.16-1.el7.x86_64.rpm

systemctl enable mysqld
systemctl start mysqld

init_passwd=$(grep 'temporary password' $LOG_MYSQL | awk '{print $NF}')

mysqladmin -uroot -p$init_passwd password $MYSQL_ROOT_PASS


