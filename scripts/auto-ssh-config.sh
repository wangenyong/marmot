#!/bin/bash

# 修改SSH配置文件
SSH_CONFIG_FILE="/etc/ssh/ssh_config"

if [ $(grep -c "StrictHostKeyChecking no" $SSH_CONFIG_FILE) -eq '0' ]; then
    sed -i '/StrictHostKeyChecking/s/^#//; /StrictHostKeyChecking/s/ask/no/' $SSH_CONFIG_FILE
fi

# 生成公钥
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa
fi

# 读取集群节点
IFS=$'\n' read -d '' -r -a lines <../conf/workers

for worker in ${lines[@]}; do
    echo root@$worker
    sshpass -f ../conf/ssh_passwd ssh-copy-id root@$worker
done
