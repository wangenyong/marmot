#!/bin/bash

#################################
#
# 配置集群节点 SSH 免密登录
#
#################################

# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh
# 加载配置文件
source $HOME_DIR/conf/config.conf

# 脚本参数判断
case "$1" in
"hadoop")
    log_info "配置 Hadoop SSH 免密登录"
    NORMAL_USER=$HADOOP_USER
    NORMAL_PASS=$HADOOP_PASS
    IFS=',' read -ra array <<<$HADOOP_WORKERS
    ;;
"kettle")
    log_info "配置 Kettle SSH 免密登录"
    NORMAL_USER=$KETTLE_USER
    NORMAL_PASS=$KETTLE_PASS
    IFS=',' read -ra array <<<$KETTLE_NODES
    ;;
*)
    echo "无效参数!"
    echo "参数说明: $(basename $0) {hadoop|kettle} {go|test|info}"
    exit
    ;;
esac

HOST_LIST=${array[@]}

LOCAL_HOST=$(hostname)

#
# 打印集群节点信息
#
function host_list_print() {
    echo ">>> 集群节点列表:"
    for host in $HOST_LIST; do
        echo $host
    done
}

#
# 创建集群节点普通用户
#
function add_user() {
    cmd="useradd $NORMAL_USER; echo '$NORMAL_PASS' | passwd $NORMAL_USER --stdin"
    for host in $HOST_LIST; do
        #echo "at $host: $cmd"
        sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host $cmd
    done
}

#
# SSH 免密配置
#
function ssh_auth() {
    echo "" >$NORMAL_USER-authorized_keys
    log_info ">>> Generating SSH key at each host"
    cmd_rm='rm -f ~/.ssh/id_rsa* ~/.ssh/known_hosts'
    cmd_gen='ssh-keygen -q -N "" -t rsa -f ~/.ssh/id_rsa'
    cmd_cat='cat ~/.ssh/id_rsa.pub'
    for host in $HOST_LIST; do
        sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host $cmd_rm
        sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host $cmd_gen
        sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host $cmd_cat >>$NORMAL_USER-authorized_keys
        sshpass -p $NORMAL_PASS ssh $NORMAL_USER@$host $cmd_rm
        sshpass -p $NORMAL_PASS ssh $NORMAL_USER@$host $cmd_gen
        sshpass -p $NORMAL_PASS ssh $NORMAL_USER@$host $cmd_cat >>$NORMAL_USER-authorized_keys
    done
    log_info ">>> All public keys copied to localhost"
    log_info ">>> Distributing all public keys"
    cmd_chmod="chmod 600 /home/$NORMAL_USER/.ssh/authorized_keys"
    for host in $HOST_LIST; do
        sshpass -p $ADMIN_PASS scp $NORMAL_USER-authorized_keys $ADMIN_USER@$host:~/.ssh/authorized_keys
        sshpass -p $NORMAL_PASS scp $NORMAL_USER-authorized_keys $NORMAL_USER@$host:/home/$NORMAL_USER/.ssh/authorized_keys
        sshpass -p $NORMAL_PASS ssh $NORMAL_USER@$host $cmd_chmod
    done
}

#
# 关闭集群节点防火墙
#
function close_firewall() {
    log_info ">>> Close firewall"
    cmd_stop_firewall="systemctl stop firewalld.service"
    cmd_disable_firewall="systemctl disable firewalld.service"
    cmd_firewall_state="firewall-cmd --state"
    for host in $HOST_LIST; do
        sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host $cmd_stop_firewall
        sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host $cmd_disable_firewall
        sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host $cmd_firewall_state
    done
}

function ssh_subtest() {
    for host in $HOST_LIST; do
        ssh $NORMAL_USER@$host hostname
    done
}

function ssh_test() {
    echo ">>> Testing SSH authorization for $NORMAL_USER in all nodes"
    cmd="./$0 subtest"
    for host in $HOST_LIST; do
        echo ">>> Testing SSH authorization at $host"
        sshpass -p $NORMAL_PASS scp ./$0 $NORMAL_USER@$host:~
        sshpass -p $NORMAL_PASS ssh $NORMAL_USER@$host $cmd
    done

    return
}

# HOSTS_CONF="/etc/hosts"
SSH_CONF="/etc/ssh/ssh_config"
#
# SSH 配置文件修改并同步集群
#
function system_conf() {
    log_info ">>> Distributing system configurations"

    if [ $(grep -c "StrictHostKeyChecking no" $SSH_CONF) -eq '0' ]; then
        sed -i '/StrictHostKeyChecking/s/^#//; /StrictHostKeyChecking/s/ask/no/' $SSH_CONF
    fi

    for host in $HOST_LIST; do
        if [ "$host" == "$LOCAL_HOST" ]; then
            echo "Skipping localhost $LOCAL_HOST"
            continue
        fi

        echo "$SSH_CONF to $host"
        sshpass -p $ADMIN_PASS scp $SSH_CONF $ADMIN_USER@$host:$SSH_CONF
        # echo "$HOSTS_CONF to $host"
        # sshpass -p $ADMIN_PASS scp $HOSTS_CONF $ADMIN_USER@$host:$HOSTS_CONF
    done
}
function print_info() {
    echo "Version: 2023-2-4"
    return
}
case "$2" in
go)
    host_list_print
    close_firewall
    system_conf
    add_user
    ssh_auth
    RETVAL=0
    ;;
subtest)
    ssh_subtest
    RETVAL=0
    ;;
test)
    ssh_test
    RETVAL=0
    ;;
info)
    print_info
    RETVAL=0
    ;;
*)
    echo $"参数说明: $(basename $0) $1 {go|test|info}"
    RETVAL=2
    ;;
esac
exit $RETVAL
