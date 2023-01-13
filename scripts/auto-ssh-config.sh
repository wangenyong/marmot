#!/bin/bash

sed -i '/StrictHostKeyChecking/s/^#//; /StrictHostKeyChecking/s/ask/no/' /etc/ssh/ssh_config

# 生成公钥
ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa

# 读取集群节点
IFS=$'\n' read -d '' -r -a lines < ../conf/workers

for worker in ${lines[@]}
do
    echo root@$worker
    sshpass -f ../conf/ssh_passwd ssh-copy-id root@$worker
done