#!/bin/bash

#################################
#
# kettle version "7.1.0"
#
# 配置 kettle
#
#################################

# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh
# 加载配置文件
source $HOME_DIR/conf/config.conf

IFS=',' read -ra nodes <<<$KETTLE_NODES

log_info "========== 开始配置 KETTLE =========="

# 判断数据项目根目录是否已经创建
if [ ! -d /opt/marmot ]; then
    mkdir /opt/marmot
    log_info "创建 marmot 项目目录完成!"
fi

KETTLE_HOME=/opt/marmot/data-integration

if [ -d $KETTLE_HOME ]; then
    log_warn "KETTLE 已经安装!"
else
    unzip -o $HOME_DIR/softwares/pdi-ce-7.1.0.0-12.zip -d /opt/marmot/ | pv -l >/dev/null

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
fi
