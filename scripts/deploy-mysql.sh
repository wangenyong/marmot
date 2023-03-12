#!/bin/bash

#############################################################################################
#
# mysql version "5.7.16"
#
# install mysql
#
#############################################################################################

# get script directory and home directory
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"
# loading config file
source $HOME_DIR/conf/config.conf
# loading printf file
source $HOME_DIR/conf/printf.conf
# loading version file
source $HOME_DIR/conf/version.conf

printf -- "${INFO}========== INSTALL MYSQL ==========${END}\n"
if [ ! -z "$1" ] && [[ "$1" =~ ^(-f|-F)$ ]]; then
    printf -- "${INFO}>>> Force install mysql.${END}\n"
    # uninstall previously installed
    rpm -qa | grep -i -E mysql\|mariadb | xargs -n1 sudo rpm -e --nodeps

    DIR_MYSQL=/var/lib/mysql
    LOG_MYSQL=/var/log/mysqld.log
    # clear leftover directory
    if [ -d "$DIR_MYSQL" ]; then
        rm -rf $DIR_MYSQL
        rm -rf $LOG_MYSQL
    fi
else
    mysql=$(rpm -qa | grep "mysql.*")
    if [ $? -eq 0 ]; then
        #printf -- "${SUCCESS}$mysql${END}\n"
        printf -- "${SUCCESS}========== MYSQL INSTALLED ==========${END}\n"
        printf -- "\n"
        exit 0
    fi
fi

#############################################################################################
# install mysql
#############################################################################################
printf -- "${INFO}>>> Install mysql.${END}\n"

rpm -ivh $HOME_DIR/softwares/mysql/01_mysql-community-common-${mysql_version}-*.rpm
rpm -ivh $HOME_DIR/softwares/mysql/02_mysql-community-libs-${mysql_version}-*.rpm
rpm -ivh $HOME_DIR/softwares/mysql/03_mysql-community-libs-compat-${mysql_version}-*.rpm
rpm -ivh $HOME_DIR/softwares/mysql/04_mysql-community-client-${mysql_version}-*.rpm
rpm -ivh $HOME_DIR/softwares/mysql/05_mysql-community-server-${mysql_version}-*.rpm

#############################################################################################
# configure mysql
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure mysql.${END}\n"

if [ $(grep -c "character-set-server" /etc/my.cnf) -eq '0' ]; then
    echo -e >>$MARMOT_PROFILE
    echo '#***** CUSTOM_CONFIG *****' >>/etc/my.cnf
    echo 'character-set-server=utf8' >>/etc/my.cnf
    echo '[client]' >>/etc/my.cnf
    echo 'default-character-set=utf8' >>/etc/my.cnf
    echo '[mysql]' >>/etc/my.cnf
    echo 'default-character-set=utf8' >>/etc/my.cnf

    printf -- "${SUCCESS}/etc/my.cnf configure successful.${END}\n"
else
    printf -- "${WARN}/etc/my.cnf configurtion is complete.${END}\n"
fi

systemctl enable mysqld
systemctl start mysqld

init_passwd=$(grep 'temporary password' $LOG_MYSQL | awk '{print $NF}')

mysqladmin -uroot -p$init_passwd password $MYSQL_ROOT_PASS

printf -- "\n"
printf -- "${SUCCESS}========== MYSQL INSTALL SUCCESSFUL ==========${END}\n"
