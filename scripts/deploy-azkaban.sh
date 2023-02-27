#!/bin/bash

#############################################################################################
#
# azkaban version "3.84.4"
#
# configure azkaban
#
#############################################################################################

# get script directory and home directory
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"
# loading config file
source $HOME_DIR/conf/config.conf
# loading printf file
source $HOME_DIR/conf/printf.conf
# loading azkaban nodes
IFS=',' read -ra azkaban_nodes <<<$AZKABAN_NODES

AZKABAN_HOME=$PROJECT_DIR/azkaban

printf -- "${INFO}========== INSTALL AZKABAN ==========${END}\n"
if [ -d $AZKABAN_HOME ]; then
    printf -- "${SUCCESS}========== AZKABAN INSTALLED ==========${END}\n"
    printf -- "\n"
    exit 0
fi

#############################################################################################
# install azkaban
#############################################################################################
printf -- "${INFO}>>> Install azkaban.${END}\n"
mkdir -p $AZKABAN_HOME
pv $HOME_DIR/softwares/azkaban/azkaban-db-3.84.4.tar.gz | tar -zx -C $AZKABAN_HOME
pv $HOME_DIR/softwares/azkaban/azkaban-exec-server-3.84.4.tar.gz | tar -zx -C $AZKABAN_HOME
pv $HOME_DIR/softwares/azkaban/azkaban-web-server-3.84.4.tar.gz | tar -zx -C $AZKABAN_HOME
mv $AZKABAN_HOME/azkaban-exec-server-3.84.4 $AZKABAN_HOME/azkaban-exec
mv $AZKABAN_HOME/azkaban-web-server-3.84.4 $AZKABAN_HOME/azkaban-web

#############################################################################################
# configure environment variables
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure azkaban environment variables.${END}\n"

if [ $(grep -c "AZKABAN_HOME" $MARMOT_PROFILE) -eq '0' ]; then
    echo -e >>$MARMOT_PROFILE
    echo '#***** AZKABAN_HOME *****' >>$MARMOT_PROFILE
    echo "export AZKABAN_HOME="$AZKABAN_HOME >>$MARMOT_PROFILE

    source /etc/profile
    printf -- "${SUCCESS}AZKABAN_HOME configure successful: $AZKABAN_HOME${END}\n"
else
    source /etc/profile
    printf -- "${WARN}AZKABAN_HOME configurtion is complete.${END}\n"
fi

#############################################################################################
# configure azkaban database
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure azkaban database.${END}\n"

mysql -uroot -p$MYSQL_ROOT_PASS -e "use azkaban"

if [[ $? -ne 0 ]]; then
    printf -- "${INFO}--> Create database azkaban.${END}\n"
    mysql -uroot -p$MYSQL_ROOT_PASS -e "CREATE DATABASE azkaban DEFAULT CHARSET utf8 COLLATE utf8_general_ci"

    mysql -uroot -p$MYSQL_ROOT_PASS -e "CREATE USER '$MYSQL_AZKABAN_USER'@'%' IDENTIFIED BY '$MYSQL_AZKABAN_PASS'"
    mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL ON azkaban.* TO '$MYSQL_AZKABAN_USER'@'%' IDENTIFIED BY '$MYSQL_AZKABAN_PASS'"
    mysql -uroot -p$MYSQL_ROOT_PASS -e 'flush privileges'

    mysql -u$MYSQL_AZKABAN_USER -p$MYSQL_AZKABAN_PASS azkaban -e "source $AZKABAN_HOME/azkaban-db-3.84.4/create-all-sql-3.84.4.sql"

    if [ $(grep -c "max_allowed_packet" /etc/my.cnf) -eq '0' ]; then
        echo "max_allowed_packet=1024M" >>/etc/my.cnf
        systemctl restart mysqld
    fi
    printf -- "${SUCCESS}Configure azkaban database successful.${END}\n"
else
    printf -- "${SUCCESS}Database azkaban is complete.${END}\n"
fi

#############################################################################################
# configure executor server
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure azkaban executor server.${END}\n"

EXECUTOER_CONF_FILE=$AZKABAN_HOME/azkaban-exec/conf/azkaban.properties
if [ $(grep -c "America/Los_Angeles" $EXECUTOER_CONF_FILE) -ne '0' ]; then
    sed -i -r '/^default\.timezone\.id/s/.*/default\.timezone\.id=Asia\/Shanghai/' $EXECUTOER_CONF_FILE
    sed -i -r '/^azkaban\.webserver\.url/s/.*/azkaban.webserver\.url=http:\/\/'${azkaban_nodes[0]}':8081/' $EXECUTOER_CONF_FILE
    sed -i -r '/^mysql\.host/s/.*/mysql\.host='${azkaban_nodes[0]}'/' $EXECUTOER_CONF_FILE
    sed -i -r '/^mysql\.password/s/.*/mysql\.password='$MYSQL_AZKABAN_PASS'/' $EXECUTOER_CONF_FILE
    echo "executor.port=12321" >>$EXECUTOER_CONF_FILE

    printf -- "${SUCCESS}Configure azkaban executor server successful.${END}\n"
else
    printf -- "${SUCCESS}Azkaban executor server configurtion is complete.${END}\n"
fi

#############################################################################################
# configure azkaban web server
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure azkaban web server.${END}\n"

WEB_CONF_FILE=$AZKABAN_HOME/azkaban-web/conf/azkaban.properties
if [ $(grep -c "America/Los_Angeles" $WEB_CONF_FILE) -ne '0' ]; then
    sed -i -r '/^default\.timezone\.id/s/.*/default\.timezone\.id=Asia\/Shanghai/' $WEB_CONF_FILE
    sed -i -r '/^azkaban\.executorselector\.filters/s/.*/azkaban\.executorselector\.filters=StaticRemainingFlowSize,CpuStatus/' $WEB_CONF_FILE
    sed -i -r '/^mysql\.host/s/.*/mysql\.host='${azkaban_nodes[0]}'/' $WEB_CONF_FILE
    sed -i -r '/^mysql\.password/s/.*/mysql\.password='$MYSQL_AZKABAN_PASS'/' $WEB_CONF_FILE
    printf -- "${SUCCESS}Configure azkaban web server successful.${END}\n"
else
    printf -- "${SUCCESS}Azkaban web server configurtion is complete.${END}\n"
fi

#############################################################################################
# configure azkaban user
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure azkaban user.${END}\n"

USER_CONF_FILE=$AZKABAN_HOME/azkaban-web/conf/azkaban-users.xml
if [ $(grep -c $AZKABAN_USER $WEB_CONF_FILE) -eq '0' ]; then
    USER_CONFIG='<user password="'$AZKABAN_PASS'" roles="admin" username="'$AZKABAN_USER'"/>'
    sed -in '/<\/azkaban-users>/i\'"$USER_CONFIG" $USER_CONF_FILE
    printf -- "${SUCCESS}Configure azkaban user successful.${END}\n"
else
    printf -- "${SUCCESS}Azkaban user configurtion is complete.${END}\n"
fi


#############################################################################################
# distributing azkaban
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Distributing azkaban to all cluster nodes.${END}\n"

# modify permissions
chown $HADOOP_USER:$HADOOP_USER -R $AZKABAN_HOME
# distributing azkaban-exec
sh $SCRIPT_DIR/msync $AZKABAN_NODES $AZKABAN_HOME/azkaban-exec
printf -- "\n"
# distributing environment variables
sh $SCRIPT_DIR/msync $AZKABAN_NODES /etc/profile.d/marmot_env.sh

printf -- "\n"
printf -- "${SUCCESS}========== AZKABAN INSTALL SUCCESSFUL ==========${END}\n"