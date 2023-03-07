#!/bin/bash

#############################################################################################
#
# dolphinscheduler version "2.0.5"
#
# configure dolphinscheduler
#
#############################################################################################

# get script directory and home directory
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"
# loading config file
source $HOME_DIR/conf/config.conf
# loading printf file
source $HOME_DIR/conf/printf.conf
# loading environment
source /etc/profile
# loading dolphinscheduler nodes
IFS=',' read -ra dolphinscheduler_nodes <<<$DOLPHINSCHEDULER_NODES
# loading zookeeper nodes
IFS=',' read -ra zookeeper_nodes <<<$ZOOKEEPER_NODES
# loading hadoop nodes
IFS=',' read -ra workers <<<$HADOOP_WORKERS

DOLPHINSCHEDULER_HOME=$PROJECT_DIR/dolphinscheduler

printf -- "${INFO}========== INSTALL DOLPHINSCHEDULER ==========${END}\n"
if [ -d $DOLPHINSCHEDULER_HOME ]; then
    printf -- "${SUCCESS}========== DOLPHINSCHEDULER INSTALLED ==========${END}\n"
    printf -- "\n"
    exit 0
fi

#############################################################################################
# install dolphinscheduler
#############################################################################################
DOLPHINSCHEDULER_TMP_DIR=$HOME_DIR/softwares/dolphinscheduler
if [ -d $DOLPHINSCHEDULER_TMP_DIR ]; then
    rm -rf $DOLPHINSCHEDULER_TMP_DIR
fi
mkdir $DOLPHINSCHEDULER_TMP_DIR
pv $HOME_DIR/softwares/apache-dolphinscheduler-2.0.8-bin.tar.gz | tar -zx -C $DOLPHINSCHEDULER_TMP_DIR --strip-components 1
# copy mysql driver
cp $HOME_DIR/softwares/mysql/mysql-connector-java-5.1.27-bin.jar $DOLPHINSCHEDULER_TMP_DIR/lib/

#############################################################################################
# configure environment variables
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure dolphinscheduler environment variables.${END}\n"

if [ $(grep -c "DOLPHINSCHEDULER_HOME" $MARMOT_PROFILE) -eq '0' ]; then
    echo -e >>$MARMOT_PROFILE
    echo '#***** DOLPHINSCHEDULER_HOME *****' >>$MARMOT_PROFILE
    echo "export DOLPHINSCHEDULER_HOME="$DOLPHINSCHEDULER_HOME >>$MARMOT_PROFILE

    source /etc/profile
    printf -- "${SUCCESS}DOLPHINSCHEDULER_HOME configure successful: $DOLPHINSCHEDULER_HOME${END}\n"
else
    source /etc/profile
    printf -- "${WARN}DOLPHINSCHEDULER_HOME configurtion is complete.${END}\n"
fi

#############################################################################################
# configure dolphinscheduler inftall conf file
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure dolphinscheduler install config.${END}\n"

DOLPHINSCHEDULER_INSTALL_CONF=$DOLPHINSCHEDULER_TMP_DIR/conf/config/install_config.conf

i=1
dolphinscheduler_workers=""
length=${#dolphinscheduler_nodes[@]}
for node in ${dolphinscheduler_nodes[@]}; do
    if [ $i -eq $length ]; then
        dolphinscheduler_workers="$dolphinscheduler_workers$node:default"
    else
        dolphinscheduler_workers="$dolphinscheduler_workers$node:default,"
    fi
    let i+=1
done

i=1
zookeeper_servers=""
length=${#zookeeper_nodes[@]}
for node in ${zookeeper_nodes[@]}; do
    if [ $i -eq $length ]; then
        zookeeper_servers="$zookeeper_servers$node:2181"
    else
        zookeeper_servers="$zookeeper_servers$node:2181,"
    fi
    let i+=1
done

# -------------------------------------------------------------------------------------------
# install machine config
# -------------------------------------------------------------------------------------------
sed -i -r '/^ips/s|.*|ips='\"$DOLPHINSCHEDULER_NODES\"'|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^masters/s|.*|masters='\"${dolphinscheduler_nodes[3]}\"'|' $DOLPHINSCHEDULER_INSTALL_CONF

sed -i -r '/^workers/s|.*|workers='\"${dolphinscheduler_workers}\"'|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^alertServer/s|.*|alertServer='\"${dolphinscheduler_nodes[3]}\"'|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^apiServers/s|.*|apiServers='\"${dolphinscheduler_nodes[3]}\"'|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^pythonGatewayServers/s|(.*)|# \1|' $DOLPHINSCHEDULER_INSTALL_CONF

sed -i -r '/^installPath/s|.*|installPath='\"$DOLPHINSCHEDULER_HOME\"'|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^deployUser/s|.*|deployUser="root"|' $DOLPHINSCHEDULER_INSTALL_CONF

# -------------------------------------------------------------------------------------------
# dolphinscheduler env config
# -------------------------------------------------------------------------------------------
sed -i -r '/^javaHome/s|.*|javaHome='\"$JAVA_HOME\"'|' $DOLPHINSCHEDULER_INSTALL_CONF

# -------------------------------------------------------------------------------------------
# database config
# -------------------------------------------------------------------------------------------
sed -i -r '/^DATABASE_TYPE/s|.*|DATABASE_TYPE="mysql"|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^SPRING_DATASOURCE_URL/s|.*|SPRING_DATASOURCE_URL="jdbc:mysql://'${workers[0]}':3306/dolphinscheduler?useUnicode=true\&characterEncoding=UTF-8"|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^SPRING_DATASOURCE_USERNAME/s|.*|SPRING_DATASOURCE_USERNAME="'$MYSQL_DOLPHINSCHEDULER_USER'"|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^SPRING_DATASOURCE_PASSWORD/s|.*|SPRING_DATASOURCE_PASSWORD="'$MYSQL_DOLPHINSCHEDULER_PASS'"|' $DOLPHINSCHEDULER_INSTALL_CONF

# -------------------------------------------------------------------------------------------
# registry server config
# -------------------------------------------------------------------------------------------
sed -i -r '/^registryServers/s|.*|registryServers='\"${zookeeper_servers}\"'|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^registryNamespace/s|.*|registryNamespace="dolphinscheduler"|' $DOLPHINSCHEDULER_INSTALL_CONF

# -------------------------------------------------------------------------------------------
# dolphinscheduler_workers task server config
# -------------------------------------------------------------------------------------------
sed -i -r '/^resourceStorageType/s|.*|resourceStorageType="HDFS"|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^defaultFS/s|.*|defaultFS="hdfs://'${workers[0]}':8020"|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^yarnHaIps/s|.*|yarnHaIps=|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^singleYarnIp/s|.*|singleYarnIp="'${workers[1]}'"|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^hdfsRootUser/s|.*|hdfsRootUser="'$HADOOP_USER'"|' $DOLPHINSCHEDULER_INSTALL_CONF
sed -i -r '/^sudoEnable/s|.*|sudoEnable="false"|' $DOLPHINSCHEDULER_INSTALL_CONF

# -------------------------------------------------------------------------------------------
# set registry.block.until.connected.wait
# -------------------------------------------------------------------------------------------
sed -i -r '/^registry\.block\.until\.connected\.wait/s|.*|registry\.block\.until\.connected\.wait=6000|' $DOLPHINSCHEDULER_TMP_DIR/conf/registry.properties

# -------------------------------------------------------------------------------------------
# modify install.sh
# -------------------------------------------------------------------------------------------
begin_line=$(sed -n '/^echo \"6.startup\"$/=' $DOLPHINSCHEDULER_TMP_DIR/install.sh)
end_line=$(sed -n '$=' $DOLPHINSCHEDULER_TMP_DIR/install.sh)
sed -i -r "${begin_line},${end_line}s|(.*)|# \1|" $DOLPHINSCHEDULER_TMP_DIR/install.sh

#############################################################################################
# init dolphinscheduler database
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Init dolphinscheduler database.${END}\n"

mysql -uroot -p$MYSQL_ROOT_PASS -e "use dolphinscheduler"

if [[ $? -ne 0 ]]; then
    printf -- "${INFO}--> Create database dolphinscheduler.${END}\n"
    mysql -uroot -p$MYSQL_ROOT_PASS -e "CREATE DATABASE dolphinscheduler DEFAULT CHARSET utf8 COLLATE utf8_general_ci"

    mysql -uroot -p$MYSQL_ROOT_PASS -e "CREATE USER '$MYSQL_DOLPHINSCHEDULER_USER'@'%' IDENTIFIED BY '$MYSQL_DOLPHINSCHEDULER_PASS'"
    mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL ON dolphinscheduler.* TO '$MYSQL_DOLPHINSCHEDULER_USER'@'%' IDENTIFIED BY '$MYSQL_DOLPHINSCHEDULER_PASS'"
    mysql -uroot -p$MYSQL_ROOT_PASS -e 'flush privileges'

    # run init database script
    $DOLPHINSCHEDULER_TMP_DIR/script/create-dolphinscheduler.sh

    printf -- "${SUCCESS}Configure dolphinscheduler database successful.${END}\n"
else
    printf -- "${SUCCESS}Database dolphinscheduler is complete.${END}\n"
fi

#############################################################################################
# configure dolphinscheduler_env.sh
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure dolphinscheduler_env.sh.${END}\n"

DOLPHINSCHEDULER_ENV_FILE=$DOLPHINSCHEDULER_TMP_DIR/conf/env/dolphinscheduler_env.sh

cat /dev/null >$DOLPHINSCHEDULER_ENV_FILE

echo 'export HADOOP_HOME='$HADOOP_HOME >>$DOLPHINSCHEDULER_ENV_FILE
echo 'export HADOOP_CONF_DIR='$HADOOP_HOME'/etc/hadoop' >>$DOLPHINSCHEDULER_ENV_FILE
echo 'export SPARK_HOME='$SPARK_HOME >>$DOLPHINSCHEDULER_ENV_FILE
echo 'export JAVA_HOME='$JAVA_HOME >>$DOLPHINSCHEDULER_ENV_FILE
echo 'export HIVE_HOME='$HIVE_HOME >>$DOLPHINSCHEDULER_ENV_FILE
echo 'export FLINK_HOME='$FLINK_HOME >>$DOLPHINSCHEDULER_ENV_FILE
echo 'export SQOOP_HOME='$SQOOP_HOME >>$DOLPHINSCHEDULER_ENV_FILE
echo 'export PATH=$HADOOP_HOME/bin:$SPARK_HOME/bin:$JAVA_HOME/bin:$HIVE_HOME/bin:$FLINK_HOME/bin:$SQOOP_HOME/bin:$PATH' >>$DOLPHINSCHEDULER_ENV_FILE
    

#############################################################################################
# deploy dolphinscheduler
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Deploy dolphinscheduler.${END}\n"

cd $DOLPHINSCHEDULER_TMP_DIR
./install.sh

#############################################################################################
# modify dolphinscheduler permissions
#############################################################################################
for node in ${dolphinscheduler_nodes[@]}; do
    ssh $ADMIN_USER@$node "chown $HADOOP_USER:$HADOOP_USER -R $DOLPHINSCHEDULER_HOME"
done

printf -- "\n"
printf -- "${SUCCESS}========== DOLPHINSCHEDULER INSTALL SUCCESSFUL ==========${END}\n"
