# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh

log_info "========== 开始配置 SPARK =========="

# 判断 Spark 是否已经安装
if [ -d /opt/marmot/spark-3.0.0-* ]; then
    log_warn "Spark 已经安装!"
else
    # 安装 Spark
    pv $HOME_DIR/softwares/spark-3.0.0-bin-hadoop3.2.tgz | tar -zx -C /opt/marmot/

    # 创建环境变量文件
    MARMOT_PROFILE="/etc/profile.d/marmot_env.sh"
    if [ ! -f $MARMOT_PROFILE ]; then
        touch $MARMOT_PROFILE
    fi

    # 配置 Spark 环境变量
    if [ $(grep -c "SPARK_HOME" $MARMOT_PROFILE) -eq '0' ]; then
        cd /opt/marmot/spark-3.0.0-*
        SPARK_PATH="SPARK_HOME="$(pwd)
        cd -

        echo -e >>$MARMOT_PROFILE
        echo '#***** SPARK_HOME *****' >>$MARMOT_PROFILE
        echo "export "$SPARK_PATH >>$MARMOT_PROFILE
        echo 'export PATH=$PATH:$SPARK_HOME/bin' >>$MARMOT_PROFILE

        source /etc/profile

        log_info "SPARK_PATH 环境变量设置完成: "$SPARK_HOME

    else
        log_warn "SPARK_PATH 环境变量已配置"
    fi

    # 修改 Spark 项目权限为 marmot:marmot
    chown marmot:marmot -R $SPARK_HOME

    log_info "========== SPARK 配置完成 =========="

fi

#
# 修改 yarn-site.xml 配置文件
#
PMEM_CHECK_CONFIG='
    <!--是否启动一个线程检查每个任务正使用的物理内存量，如果任务超出分配值，则直接将其杀掉，默认是 true -->\
    <property>\
        <name>yarn.nodemanager.pmem-check-enabled</name>\
        <value>false</value>\
    </property>'

VMEM_CHECK_CONFIG='
    <!--是否启动一个线程检查每个任务正使用的物理内存量，如果任务超出分配值，则直接将其杀掉，默认是 true -->\
    <property>\
        <name>yarn.nodemanager.vmem-check-enabled</name>\
        <value>false</value>\
    </property>'

YARN_SITE_FILE=$HADOOP_HOME/etc/hadoop/yarn-site.xml
# 判断 yarn-site.xml 文件是否已经配置
if [ $(grep -c "yarn.nodemanager.pmem-check-enabled" $YARN_SITE_FILE) -eq '0' ]; then
    sed -in '/<\/configuration>/i\'"$PMEM_CHECK_CONFIG" $YARN_SITE_FILE
    sed -in '/<\/configuration>/i\'"$VMEM_CHECK_CONFIG" $YARN_SITE_FILE
    log_info "Spark yarn-site.xml 文件配置完成！"
else
    log_warn "Saprk yarn-site.xml 文件已配置！"
fi

#
# 修改 conf/spark-env.sh
#
SPARK_ENV=$SPARK_HOME/conf/spark-env.sh

if [ ! -f $SPARK_ENV ]; then
    ssh marmot@hadoop101 "touch $SPARK_ENV"
    echo '#***** CUSTOM CONFIG *****' >>$SPARK_ENV
    echo 'export JAVA_HOME='$JAVA_HOME >>$SPARK_ENV
    echo 'YARN_CONF_DIR='$HADOOP_HOME'/etc/hadoop' >>$SPARK_ENV
    log_info "Spark spark-env.xml 文件配置完成！"
else
    log_warn "Saprk spark-env.xml 文件已配置！"
fi

#
# 配置 Spark 历史服务器
#
SPARK_DEFAULTS=$SPARK_HOME/conf/spark-defaults.conf
if [ ! -f $SPARK_DEFAULTS ]; then
    ssh marmot@hadoop101 "touch $SPARK_DEFAULTS"
    # 启动 HDFS 创建 directory 目录
    ssh marmot@hadoop101 "$HADOOP_HOME/sbin/start-dfs.sh"
    ssh marmot@hadoop101 "hadoop fs -mkdir /directory"
    ssh marmot@hadoop101 "$HADOOP_HOME/sbin/stop-dfs.sh"

    echo '#***** CUSTOM CONFIG *****' >>$SPARK_DEFAULTS
    echo "spark.eventLog.enabled true" >>$SPARK_DEFAULTS
    echo "spark.eventLog.dir hdfs://$(head -n 1 $HOME_DIR/conf/workers):8020/directory" >>$SPARK_DEFAULTS
    echo "spark.yarn.historyServer.address=$(head -n 1 $HOME_DIR/conf/workers):18080" >>$SPARK_DEFAULTS
    echo "spark.history.ui.port=18080" >>$SPARK_DEFAULTS

    SPARK_HISTORY_OPTS='
export SPARK_HISTORY_OPTS="\
-Dspark.history.ui.port=18080\
-Dspark.history.fs.logDirectory=hdfs://'$(head -n 1 $HOME_DIR/conf/workers)':8020/directory\
-Dspark.history.retainedApplications=30"'
    sed -in '$a\'"$SPARK_HISTORY_OPTS" $SPARK_ENV

    log_info "Spark 历史服务器配置完成！"
else
    log_warn "Saprk 历史服务器已配置！"
fi