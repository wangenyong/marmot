#!/bin/bash

#############################################################################################
#
# hive version "3.1.2"
#
# configure hive
#
#############################################################################################

# get script directory and home directory
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"
# loading config file
source $HOME_DIR/conf/config.conf
# loading printf file
source $HOME_DIR/conf/printf.conf
# loading cluster nodes
IFS=',' read -ra workers <<<$HADOOP_WORKERS

printf -- "${INFO}========== INSTALL HIVE ==========${END}\n"
if [ -d $PROJECT_DIR/apache-hive* ]; then
    printf -- "${SUCCESS}========== HIVE INSTALLED ==========${END}\n"
    printf -- "\n"
    exit 0
fi

#############################################################################################
# install hive
#############################################################################################
printf -- "${INFO}>>> Install hive.${END}\n"
pv $HOME_DIR/softwares/apache-hive-3.1.2-bin.tar.gz | tar -zx -C $PROJECT_DIR/

#############################################################################################
# configure environment variables
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure hive environment variables.${END}\n"

if [ $(grep -c "HIVE_HOME" $MARMOT_PROFILE) -eq '0' ]; then
    cd $PROJECT_DIR/apache-hive*
    HIVE_PATH="HIVE_HOME="$(pwd)
    cd - >/dev/null 2>&1

    echo -e >>$MARMOT_PROFILE
    echo '#***** HIVE_HOME *****' >>$MARMOT_PROFILE
    echo "export "$HIVE_PATH >>$MARMOT_PROFILE
    echo 'export PATH=$PATH:$HIVE_HOME/bin' >>$MARMOT_PROFILE

    source /etc/profile
    printf -- "${SUCCESS}HIVE_HOME configure successful: $HIVE_HOME${END}\n"
else
    source /etc/profile
    printf -- "${WARN}HIVE_HOME configurtion is complete.${END}\n"
fi

#############################################################################################
# configure hive-site.xml
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure hive hive-site.xml.${END}\n"

HIVE_SITE_FILE=$HIVE_HOME/conf/hive-site.xml
# copy xml template
cp $HOME_DIR/template/configuration.xml $HIVE_SITE_FILE
chmod 755 $HIVE_SITE_FILE
# copy mysql driver
cp $HOME_DIR/softwares/mysql/mysql-connector-java-5.1.27-bin.jar $HIVE_HOME/lib/
# resolve log conflicts
mv $HIVE_HOME/lib/log4j-slf4j-impl-2.10.0.jar $HIVE_HOME/lib/log4j-slf4j-impl-2.10.0.jar.bak

MYSQL_URL_CONFIG='
    <property>\
        <name>javax.jdo.option.ConnectionURL</name>\
        <value>jdbc:mysql://'${workers[0]}':3306/metastore?useSSL=false</value>\
    </property>'

MYSQL_DRIVER_NAME_CONFIG='
    <property>\
        <name>javax.jdo.option.ConnectionDriverName</name>\
        <value>com.mysql.jdbc.Driver</value>\
    </property>'

MYSQL_USERNAME_CONFIG='
    <property>\
        <name>javax.jdo.option.ConnectionUserName</name>\
        <value>marmot</value>\
    </property>'

MYSQL_PASSWD_CONFIG='
    <property>\
        <name>javax.jdo.option.ConnectionPassword</name>\
        <value>Phee]d1f</value>\
    </property>'

HIVE_WAREHOUSE_CONFIG='
    <property>\
        <name>hive.metastore.warehouse.dir</name>\
        <value>/user/hive/warehouse</value>\
    </property>'

HIVE_VERIFICATION_CONFIG='
    <property>\
        <name>hive.metastore.schema.verification</name>\
        <value>false</value>\
    </property>'

HIVE_THRIFT_PORT='
    <property>\
        <name>hive.server2.thrift.port</name>\
        <value>10000</value>\
    </property>'

HIVE_THRIFT_HOST='
    <property>\
        <name>hive.server2.thrift.bind.host</name>\
        <value>'${workers[0]}'</value>\
    </property>'

HIVE_API_AUTH='
    <property>\
        <name>hive.metastore.event.db.notification.api.auth</name>\
        <value>false</value>\
    </property>'

HIVE_CLI_HEADER='
    <property>\
        <name>hive.cli.print.header</name>\
        <value>true</value>\
    </property>'

HIVE_CLI_DB='
    <property>\
        <name>hive.cli.print.current.db</name>\
        <value>true</value>\
    </property>'

HIVE_METASTORE_URIS='
    <property>\
        <name>hive.metastore.uris</name>\
        <value>thrift://'${workers[0]}':9083</value>\
    </property>'

sed -i -r '/<\/configuration>/i\'"$MYSQL_URL_CONFIG" $HIVE_SITE_FILE
sed -i -r '/<\/configuration>/i\'"$MYSQL_DRIVER_NAME_CONFIG" $HIVE_SITE_FILE
sed -i -r '/<\/configuration>/i\'"$MYSQL_USERNAME_CONFIG" $HIVE_SITE_FILE
sed -i -r '/<\/configuration>/i\'"$MYSQL_PASSWD_CONFIG" $HIVE_SITE_FILE
sed -i -r '/<\/configuration>/i\'"$HIVE_WAREHOUSE_CONFIG" $HIVE_SITE_FILE
sed -i -r '/<\/configuration>/i\'"$HIVE_VERIFICATION_CONFIG" $HIVE_SITE_FILE
sed -i -r '/<\/configuration>/i\'"$HIVE_THRIFT_PORT" $HIVE_SITE_FILE
sed -i -r '/<\/configuration>/i\'"$HIVE_THRIFT_HOST" $HIVE_SITE_FILE
sed -i -r '/<\/configuration>/i\'"$HIVE_API_AUTH" $HIVE_SITE_FILE
sed -i -r '/<\/configuration>/i\'"$HIVE_CLI_HEADER" $HIVE_SITE_FILE
sed -i -r '/<\/configuration>/i\'"$HIVE_CLI_DB" $HIVE_SITE_FILE
sed -i -r '/<\/configuration>/i\'"$HIVE_METASTORE_URIS" $HIVE_SITE_FILE

printf -- "${SUCCESS}Configure hive-site.xml successful.${END}\n"

#############################################################################################
# configure metastore
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure hive metastore.${END}\n"

mysql -uroot -p$MYSQL_ROOT_PASS -e "use metastore"

if [[ $? -ne 0 ]]; then
    printf -- "${INFO}--> Create database metastore.${END}\n"
    mysql -uroot -p$MYSQL_ROOT_PASS -e "CREATE DATABASE metastore DEFAULT CHARSET utf8 COLLATE utf8_general_ci"
    mysql -uroot -p$MYSQL_ROOT_PASS -e "CREATE USER '$MYSQL_NORMAL_USER'@'%' IDENTIFIED BY '$MYSQL_NORMAL_PASS'"
    mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL ON metastore.* TO '$MYSQL_NORMAL_USER'@'%' IDENTIFIED BY '$MYSQL_NORMAL_PASS'"
    mysql -uroot -p$MYSQL_ROOT_PASS -e 'flush privileges'
    
    printf -- "${INFO}--> Init database schema.${END}\n"
    schematool -initSchema -dbType mysql 1>/dev/null 2>&1

    printf -- "${SUCCESS}Configure metastore successful.${END}\n"
else
    printf -- "${SUCCESS}Database metastore is complete.${END}\n"
fi

#############################################################################################
# create logs directory
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Create logs directory.${END}\n"

HIVE_LOG_DIR=$HIVE_HOME/logs
if [ ! -d $HIVE_LOG_DIR ]; then
	mkdir -p $HIVE_LOG_DIR
    printf -- "${SUCCESS}Create logs directory successful.${END}\n"
else
    printf -- "${SUCCESS}Logs directory is complete.${END}\n"
fi

#############################################################################################
# distributing hive
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Distributing hive to all cluster nodes.${END}\n"

# modify permissions
chown $HADOOP_USER:$HADOOP_USER -R $HIVE_HOME
# distributing hive
sh $SCRIPT_DIR/msync $HADOOP_WORKERS $HIVE_HOME
printf -- "\n"
# distributing environment variables
sh $SCRIPT_DIR/msync $HADOOP_WORKERS /etc/profile.d/marmot_env.sh

printf -- "\n"
printf -- "${SUCCESS}========== HIVE INSTALL SUCCESSFUL ==========${END}\n"