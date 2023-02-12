#!/bin/bash

#############################################################################################
#
# vsftp version "3.0.2"
#
# configure vsftp
#
#############################################################################################

# get script directory and home directory
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"
# loading config file
source $HOME_DIR/conf/config.conf
# loading printf file
source $HOME_DIR/conf/printf.conf

TAG=".*"
PKG="vsftpd"
package_name=$(rpm -qa | grep "^${PKG}${TAG}")

printf -- "${INFO}========== INSTALL VSFTP ==========${END}\n"
if [ $? -eq 0 ]; then
    printf -- "${SUCCESS}========== VSFTP INSTALLED ==========${END}\n"
    printf -- "\n"
    exit 0
fi

#############################################################################################
# install vsftp
#############################################################################################
printf -- "${INFO}>>> Install vsftp.${END}\n"

rpm -ivh $HOME_DIR/softwares/packages/vsftpd-3.0.2-28.el7.x86_64.rpm
systemctl enable vsftpd.service
systemctl start vsftpd.service

#############################################################################################
# configure vsftp
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure vsftp.${END}\n"

VSFTP_CONF=/etc/vsftpd/vsftpd.conf
USER_LIST=/etc/vsftpd/user_list
CHROOT_LIST=/etc/vsftpd/chroot_list

if [ $(grep -c "anonymous_enable=YES" $VSFTP_CONF) -ne '0' ]; then
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

    printf -- "${SUCCESS}Configure vsftp configure successful.${END}\n"
else
    printf -- "${SUCCESS}Vsftp configurtion is complete.${END}\n"
fi

printf -- "\n"
printf -- "${SUCCESS}========== VSFTP INSTALL SUCCESSFUL ==========${END}\n"


