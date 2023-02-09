#!/bin/bash

#################################
#
# vsftp version "3.0.2"
#
# 配置 vsftp
#
#################################

# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh
# 加载配置文件
source $HOME_DIR/conf/config.conf

TAG=".*"
PKG="vsftpd"

package_name=$(rpm -qa | grep "^${PKG}${TAG}")
if [ $? -eq 0 ]; then
    log_warn "${package_name} 已存在，无需安装"
else
    log_info "========== 开始安装配置 VSFTP =========="
    rpm -ivh $HOME_DIR/softwares/packages/vsftpd-3.0.2-28.el7.x86_64.rpm

    systemctl enable vsftpd.service
    systemctl start vsftpd.service
fi

VSFTP_CONF=/etc/vsftpd/vsftpd.conf
USER_LIST=/etc/vsftpd/user_list
CHROOT_LIST=/etc/vsftpd/chroot_list

if [ $(grep -c "anonymous_enable=YES" $VSFTP_CONF) -ne '0' ]; then
    log_info "修改 vsftp 配置文件"
    cp $VSFTP_CONF $VSFTP_CONF.bak
    sed -i -r '/^anonymous_enable/s/YES/NO/g' $VSFTP_CONF
    sed -i -r '/^#chown_uploads/s/^#//; /^chown_uploads/s/YES/NO/' $VSFTP_CONF
    sed -i -r '/^#nopriv_user/s/^#//; /^nopriv_user/s/ftpsecure/'$HADOOP_USER'/' $VSFTP_CONF
    sed -i -r '/^#ascii_upload_enable/s/^#//' $VSFTP_CONF
    sed -i -r '/^#ascii_download_enable/s/^#//' $VSFTP_CONF
    sed -i -r '/^#chroot_local_user/s/^#//' $VSFTP_CONF
    sed -i -r '/^#chroot_list_enable/s/^#//' $VSFTP_CONF
    sed -i -r '/^#chroot_list_file/s/^#//' $VSFTP_CONF
    echo "userlist_deny=NO" >>$VSFTP_CONF
    echo "allow_writeable_chroot=YES" >>$VSFTP_CONF
    echo $HADOOP_USER >>$USER_LIST

    if [ ! -f $CHROOT_LIST ]; then
        touch $CHROOT_LIST && echo $HADOOP_USER >>$CHROOT_LIST
    fi
    
    systemctl restart vsftpd.service
else
    log_info "vsftp 配置文件已修改"
fi



