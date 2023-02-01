#!/bin/sh

# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh

# 读取集群节点
IFS=$'\n' read -d '' -r -a lines <$HOME_DIR/conf/workers

HOSTNAME_LIST=${lines[@]}

ADMIN_USER="root"
ADMIN_PASS="660011"
HADOOP_USER="marmot"
HADOOP_PASS="hadoop"

LOCAL_HOST=$(hostname)
OTHER_HOSTS="slave1 slave2 slave3"

function hostname_list_gen() {
    if [ -n "$OTHER_HOSTS" ]; then
        HOSTNAME_LIST="$LOCAL_HOST $OTHER_HOSTS"
        return
    fi

    HOSTNAME_LIST=""
    for i in {1..4}; do
        for j in {1..8}; do
            HOSTNAME_LIST="${HOSTNAME_LIST} gd1$i$j"
        done
    done
}
function hostname_list_print() {
    echo ">>> All hostnames:"
    for host in $HOSTNAME_LIST; do
        echo $host
    done
}

function add_user() {
    cmd="useradd $HADOOP_USER; echo '$HADOOP_PASS' | passwd $HADOOP_USER --stdin"
    for host in $HOSTNAME_LIST; do
        #echo "at $host: $cmd"
        sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host $cmd
    done
}

function ssh_auth() {
    echo "" >$HADOOP_USER-authorized_keys
    log_info ">>> Generating SSH key at each host"
    cmd_rm='rm -f ~/.ssh/id_rsa* ~/.ssh/known_hosts'
    cmd_gen='ssh-keygen -q -N "" -t rsa -f ~/.ssh/id_rsa'
    cmd_cat='cat ~/.ssh/id_rsa.pub'
    for host in $HOSTNAME_LIST; do
        sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host $cmd_rm
        sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host $cmd_gen
        sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host $cmd_cat >>$HADOOP_USER-authorized_keys
        sshpass -p $HADOOP_PASS ssh $HADOOP_USER@$host $cmd_rm
        sshpass -p $HADOOP_PASS ssh $HADOOP_USER@$host $cmd_gen
        sshpass -p $HADOOP_PASS ssh $HADOOP_USER@$host $cmd_cat >>$HADOOP_USER-authorized_keys
    done

    log_info ">>> All public keys copied to localhost"
    #ls -l /home/$HADOOP_USER/.ssh/authorized_keys
    cat $HADOOP_USER-authorized_keys

    log_info ">>> Distributing all public keys"
    cmd_chmod="chmod 600 /home/$HADOOP_USER/.ssh/authorized_keys"
    for host in $HOSTNAME_LIST; do
        sshpass -p $ADMIN_PASS scp $HADOOP_USER-authorized_keys $ADMIN_USER@$host:~/.ssh/authorized_keys
        sshpass -p $HADOOP_PASS scp $HADOOP_USER-authorized_keys $HADOOP_USER@$host:/home/$HADOOP_USER/.ssh/authorized_keys
        sshpass -p $HADOOP_PASS ssh $HADOOP_USER@$host $cmd_chmod
    done
}

function close_firewall() {
    log_info ">>> Close firewall"
    cmd_stop_firewall="systemctl stop firewalld.service"
    cmd_disable_firewall="systemctl disable firewalld.service"
    cmd_firewall_state="firewall-cmd --state"
    for host in $HOSTNAME_LIST; do
        sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host $cmd_stop_firewall
        sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host $cmd_disable_firewall
        sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host $cmd_firewall_state
    done
}

function ssh_subtest() {
    for host in $HOSTNAME_LIST; do
        ssh $HADOOP_USER@$host hostname
    done
}

function ssh_test() {
    echo ">>> Testing SSH authorization for $HADOOP_USER in all nodes"
    cmd="./$0 subtest"
    for host in $HOSTNAME_LIST; do
        echo ">>> Testing SSH authorization at $host"
        sshpass -p $HADOOP_PASS scp ./$0 $HADOOP_USER@$host:~
        sshpass -p $HADOOP_PASS ssh $HADOOP_USER@$host $cmd
    done

    return
}

# HOSTS_CONF="/etc/hosts"
SSH_CONF="/etc/ssh/ssh_config"

function system_conf() {
    log_info ">>> Distributing system configurations"

    if [ $(grep -c "StrictHostKeyChecking no" $SSH_CONF) -eq '0' ]; then
        sed -i '/StrictHostKeyChecking/s/^#//; /StrictHostKeyChecking/s/ask/no/' $SSH_CONF
    fi

    for host in $HOSTNAME_LIST; do
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
    echo "Version: 2011-12-20"
    return
}
case "$1" in
go)
    hostname_list_print
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
    echo $"Usage: $0 {go|test|info}"
    RETVAL=2
    ;;
esac
exit $RETVAL
