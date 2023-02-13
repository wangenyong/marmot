#!/bin/bash

#############################################################################################
#
# kettle version "7.1.0"
#
# configure kettle
#
#############################################################################################

# get script directory and home directory
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"
# loading config file
source $HOME_DIR/conf/config.conf
# loading printf file
source $HOME_DIR/conf/printf.conf
# loading kettle nodes
IFS=',' read -ra nodes <<<$KETTLE_NODES

KETTLE_HOME=$PROJECT_DIR/data-integration

printf -- "${INFO}========== INSTALL KETTLE ==========${END}\n"
if [ -d $KETTLE_HOME ]; then
    printf -- "${SUCCESS}========== KETTLE INSTALLED ==========${END}\n"
    printf -- "\n"
    exit 0
fi

#############################################################################################
# install kettle
#############################################################################################
printf -- "${INFO}>>> Install kettle.${END}\n"
unzip -o $HOME_DIR/softwares/pdi-ce-7.1.0.0-12.zip -d /opt/marmot/ | pv -l >/dev/null

#############################################################################################
# configure kettle
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure kettle.${END}\n"
# copy mysql driver
cp $HOME_DIR/softwares/mysql/mysql-connector-java-5.1.27-bin.jar $KETTLE_HOME/lib/
# modify the configuration file
PLUGIN_PROPERTIES=$KETTLE_HOME/plugins/pentaho-big-data-plugin/plugin.properties
sed -i '/active.hadoop.configuration=/s/active.hadoop.configuration=/active.hadoop.configuration=hdp25/' $PLUGIN_PROPERTIES

i=0
for node in ${nodes[@]}; do
    if [ $i -eq 0 ]; then
        MASTER_CONFIG_FILE=$KETTLE_HOME/pwd/carte-config-master-8080.xml
        begin_line=$(sed -n '/<slaveserver/=' $MASTER_CONFIG_FILE)
        end_line=$(sed -n '/<\/slaveserver>/=' $MASTER_CONFIG_FILE)
        sed -i -r "${begin_line},${end_line}s/(<name.*>).*(<\/name>)/\1master\2/1" $MASTER_CONFIG_FILE
        sed -i -r "${begin_line},${end_line}s/(<hostname.*>).*(<\/hostname>)/\1$node\2/1" $MASTER_CONFIG_FILE
        sed -i -r "${end_line}i<password>$KETTLE_PASS<\/password>" $MASTER_CONFIG_FILE
        sed -i -r "${end_line}i<username>$KETTLE_USER<\/username>" $MASTER_CONFIG_FILE
    else
        SLAVE_CONFIG_FILE="$KETTLE_HOME/pwd/carte-config-808$i.xml"
        begin_line=$(sed -n '/<slaveserver/=' $SLAVE_CONFIG_FILE)
        end_line=$(sed -n '/<\/slaveserver>/=' $SLAVE_CONFIG_FILE)
        IFS=' ' read -ra begin_lines <<<${begin_line[@]}
        IFS=' ' read -ra end_lines <<<${end_line[@]}
        master_begin_line=${begin_lines[0]}
        master_end_line=${end_lines[0]}
        sed -i -r "${master_begin_line},${master_end_line}s/(<name.*>).*(<\/name>)/\1master\2/1" $SLAVE_CONFIG_FILE
        sed -i -r "${master_begin_line},${master_end_line}s/(<hostname.*>).*(<\/hostname>)/\1${nodes[0]}\2/1" $SLAVE_CONFIG_FILE
        sed -i -r "${master_begin_line},${master_end_line}s/(<username.*>).*(<\/username>)/\1$KETTLE_USER\2/1" $SLAVE_CONFIG_FILE
        sed -i -r "${master_begin_line},${master_end_line}s/(<password.*>).*(<\/password>)/\1$KETTLE_PASS\2/1" $SLAVE_CONFIG_FILE
        slave_begin_line=${begin_lines[1]}
        slave_end_line=${end_lines[1]}
        sed -i -r "${slave_begin_line},${slave_end_line}s/(<hostname.*>).*(<\/hostname>)/\1$node\2/1" $SLAVE_CONFIG_FILE
        sed -i -r "${slave_begin_line},${slave_end_line}s/(<username.*>).*(<\/username>)/\1$KETTLE_USER\2/1" $SLAVE_CONFIG_FILE
        sed -i -r "${slave_begin_line},${slave_end_line}s/(<password.*>).*(<\/password>)/\1$KETTLE_PASS\2/1" $SLAVE_CONFIG_FILE
    fi
    let i+=1
done

printf -- "${SUCCESS}Configure kettle successful.${END}\n"

#############################################################################################
# configure kettle database repository
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure kettle database repository.${END}\n"

mysql -uroot -p$MYSQL_ROOT_PASS -e "use kettle_repository"

if [[ $? -ne 0 ]]; then
    printf -- "${INFO}--> Create database kettle_repository.${END}\n"
    mysql -uroot -p$MYSQL_ROOT_PASS -e "create DATABASE kettle_repository DEFAULT CHARSET utf8 COLLATE utf8_general_ci"
    
    mysql -uroot -p$MYSQL_ROOT_PASS -e "CREATE USER '$MYSQL_NORMAL_USER'@'%' IDENTIFIED BY '$MYSQL_NORMAL_PASS'"
    mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL ON kettle_repository.* TO '$MYSQL_NORMAL_USER'@'%' IDENTIFIED BY '$MYSQL_NORMAL_PASS'"
    mysql -uroot -p$MYSQL_ROOT_PASS -e 'flush privileges'

    printf -- "${SUCCESS}Configure kettle_repository successful.${END}\n"
else
    printf -- "${SUCCESS}Database kettle_repository is complete.${END}\n"
fi

#############################################################################################
# create logs directory
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Create logs directory.${END}\n"

KETTLE_LOG_DIR=$KETTLE_HOME/logs
if [ ! -d $KETTLE_LOG_DIR ]; then
	mkdir -p $KETTLE_LOG_DIR
    printf -- "${SUCCESS}Create logs directory successful.${END}\n"
else
    printf -- "${SUCCESS}Logs directory is complete.${END}\n"
fi

#############################################################################################
# distributing kettle
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Distributing kettle to all cluster nodes.${END}\n"

# modify permissions
chown $KETTLE_USER:$KETTLE_USER -R $KETTLE_HOME
# distributing kettle
sh $SCRIPT_DIR/msync $KETTLE_NODES $KETTLE_HOME

printf -- "\n"
printf -- "${SUCCESS}========== KETTLE INSTALL SUCCESSFUL ==========${END}\n"