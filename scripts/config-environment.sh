#!/bin/bash

#############################################################################################
#
# check the operating system environment
#
# check software dependencies
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

printf -- "${INFO}========== CHECK THE OPERATING SYSTEM ENVIRONMENT ==========${END}\n"
if [ $ENVIRONMENT_STATUS -eq 0 ]; then
    printf -- "${SUCCESS}========== ENVIRONMENT CONFIGURATION IS COMPLETE ==========${END}\n"
    exit 0
fi

# create project directory
if [ ! -d $PROJECT_DIR ]; then
    mkdir $PROJECT_DIR
fi
# create environment variables file
if [ ! -f $MARMOT_PROFILE ]; then
    touch $MARMOT_PROFILE
fi

#############################################################################################
# check software dependencies
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Install software dependencies.${END}\n"
# package sshpass
sshpass=$(rpm -qa | grep "^sshpass.*")
if [ $? -eq 0 ]; then
    printf -- "${SUCCESS}${sshpass} has been installed.${END}\n"
else
    printf -- "Install sshpass...\n"
    rpm -ivh "$HOME_DIR/softwares/packages/sshpass-${sshpass_version}-*.rpm"
    if [ $? -eq 0 ]; then
        printf -- "${SUCCESS}sshpass install successfully.${END}\n"
    else
        printf -- "${ERROR}sshpass install failed.${END}\n"
        exit 1
    fi
fi
# package psmisc
psmisc=$(rpm -qa | grep "^psmisc.*")
if [ $? -eq 0 ]; then
    printf -- "${SUCCESS}${psmisc} has been installed.${END}\n"
else
    printf -- "Install psmisc...\n"
    rpm -ivh "$HOME_DIR/softwares/packages/psmisc-${psmisc_version}-*.rpm"
    if [ $? -eq 0 ]; then
        printf -- "${SUCCESS}psmisc install successfully.${END}\n"
    else
        printf -- "${ERROR}psmisc install failed.${END}\n"
        exit 1
    fi
fi

# package unzip
unzip=$(rpm -qa | grep "^unzip.*")
if [ $? -eq 0 ]; then
    printf -- "${SUCCESS}${unzip} has been installed.${END}\n"
else
    printf -- "Install unzip...\n"
    rpm -ivh "$HOME_DIR/softwares/packages/unzip-${unzip_version}-*.rpm"
    if [ $? -eq 0 ]; then
        printf -- "${SUCCESS}unzip install successfully.${END}\n"
    else
        printf -- "${ERROR}unzip install failed.${END}\n"
        exit 1
    fi
fi

#############################################################################################
# select a deployment cluster
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> select cluster by argument.${END}\n"
# judge the first argument
if [[ $1 == "kettle" ]]; then
    IFS=',' read -ra nodes <<<$KETTLE_NODES
    NORMAL_USER=$KETTLE_USER
    NORMAL_PASS=$KETTLE_PASS
    printf -- "Current selection: ${SUCCESS}kettle.${END}\n"
else
    IFS=',' read -ra nodes <<<$HADOOP_WORKERS
    NORMAL_USER=$HADOOP_USER
    NORMAL_PASS=$HADOOP_PASS
    printf -- "Current selection: ${SUCCESS}hadoop.${END}\n"
fi

HOST_LIST=${nodes[@]}
LOCAL_HOST=$(hostname)

#############################################################################################
# list all cluster nodes
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> All cluster nodes list:${END}\n"
for host in $HOST_LIST; do
    printf -- "${SUCCESS}----- $host -----${END}\n"
done

#############################################################################################
# cluster installation software dependencies
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Install rsync on all cluster.${END}\n"
for host in $HOST_LIST; do
    printf -- "${INFO}----- $host -----${END}\n"
    sshpass -p $ADMIN_PASS scp $HOME_DIR/softwares/packages/rsync-${rsync_version}-*.rpm $ADMIN_USER@$host:~/
    sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host "rpm -ivh rsync-${rsync_version}-*.rpm"
done

printf -- "\n"
printf -- "${INFO}>>> Install pv on all cluster.${END}\n"
for host in $HOST_LIST; do
    printf -- "${INFO}----- $host -----${END}\n"
    sshpass -p $ADMIN_PASS scp $HOME_DIR/softwares/packages/pv-${pv_version}-*.rpm $ADMIN_USER@$host:~/
    sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host "rpm -ivh pv-${pv_version}-*.rpm"
done

#############################################################################################
# turn off firewall
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Disable all cluster node firewalls.${END}\n"
cmd_stop_firewall="systemctl stop firewalld.service"
cmd_disable_firewall="systemctl disable firewalld.service"
cmd_firewall_state="firewall-cmd --state"
# stop cluster firewall
for host in $HOST_LIST; do
    printf -- "${INFO}----- $host -----${END}\n"
    sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host $cmd_stop_firewall
    sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host $cmd_disable_firewall
    sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host $cmd_firewall_state
done

#############################################################################################
# create a cluster node operation user
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Create operation user.${END}\n"
cmd1="useradd $NORMAL_USER; echo '$NORMAL_PASS' | passwd $NORMAL_USER --stdin"
cmd2="useradd $SOLR_USER; echo '$SOLR_PASS' | passwd $SOLR_USER --stdin"
for host in $HOST_LIST; do
    printf -- "${INFO}----- $host -----${END}\n"
    sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host $cmd1
    sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host $cmd2
done

#############################################################################################
# distributing ssh configuration
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Distributing ssh configuration.${END}\n"
# ssh configuration file
SSH_CONF="/etc/ssh/ssh_config"
# cancel ssh login confirmation
if [ $(grep -c "StrictHostKeyChecking no" $SSH_CONF) -eq '0' ]; then
    sed -i -r '/StrictHostKeyChecking/s/^#//; /StrictHostKeyChecking/s/ask/no/' $SSH_CONF
fi

for host in $HOST_LIST; do
    if [ "$host" == "$LOCAL_HOST" ]; then
        printf -- "Skipping localhost $LOCAL_HOST.\n"
        continue
    fi

    printf -- "$SSH_CONF to $host.\n"
    sshpass -p $ADMIN_PASS scp $SSH_CONF $ADMIN_USER@$host:$SSH_CONF
done

#############################################################################################
# ssh password-free configuration
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Ssh password-free configuration.${END}\n"

echo "" >$NORMAL_USER-authorized_keys
printf -- "${INFO}>>> Generating SSH key at each host.${END}\n"
cmd_rm='rm -f ~/.ssh/id_rsa* ~/.ssh/known_hosts'
cmd_gen='ssh-keygen -q -N "" -t rsa -f ~/.ssh/id_rsa'
cmd_cat='cat ~/.ssh/id_rsa.pub'
for host in $HOST_LIST; do
    printf -- "${INFO}----- $host -----${END}\n"
    sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host $cmd_rm
    sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host $cmd_gen
    sshpass -p $ADMIN_PASS ssh $ADMIN_USER@$host $cmd_cat >>$NORMAL_USER-authorized_keys
    sshpass -p $NORMAL_PASS ssh $NORMAL_USER@$host $cmd_rm
    sshpass -p $NORMAL_PASS ssh $NORMAL_USER@$host $cmd_gen
    sshpass -p $NORMAL_PASS ssh $NORMAL_USER@$host $cmd_cat >>$NORMAL_USER-authorized_keys
    sshpass -p $SOLR_PASS ssh $SOLR_USER@$host $cmd_rm
    sshpass -p $SOLR_PASS ssh $SOLR_USER@$host $cmd_gen
    sshpass -p $SOLR_PASS ssh $SOLR_USER@$host $cmd_cat >>$NORMAL_USER-authorized_keys
done
printf -- "${SUCCESS}All public keys copied to localhost.${END}\n"
printf -- "\n"
printf -- "${INFO}>>> Distributing all public keys.${END}\n"
cmd_chmod1="chmod 600 /home/$NORMAL_USER/.ssh/authorized_keys"
cmd_chmod2="chmod 600 /home/$SOLR_USER/.ssh/authorized_keys"
for host in $HOST_LIST; do
    printf -- "${INFO}----- $host -----${END}\n"
    sshpass -p $ADMIN_PASS scp $NORMAL_USER-authorized_keys $ADMIN_USER@$host:~/.ssh/authorized_keys
    sshpass -p $NORMAL_PASS scp $NORMAL_USER-authorized_keys $NORMAL_USER@$host:/home/$NORMAL_USER/.ssh/authorized_keys
    sshpass -p $SOLR_PASS scp $NORMAL_USER-authorized_keys $SOLR_USER@$host:/home/$SOLR_USER/.ssh/authorized_keys
    sshpass -p $NORMAL_PASS ssh $NORMAL_USER@$host $cmd_chmod1
    sshpass -p $SOLR_PASS ssh $SOLR_USER@$host $cmd_chmod2
done
printf -- "${SUCCESS}All public keys copied to cluster.${END}\n"

sed -i -r '/^ENVIRONMENT_STATUS/s/.*/ENVIRONMENT_STATUS=0/' $HOME_DIR/conf/config.conf
printf -- "\n"
printf -- "${SUCCESS}========== ENVIRONMENT CONFIGURATION SUCCESSFULL ==========${END}\n"

