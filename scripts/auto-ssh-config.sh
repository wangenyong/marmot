#!/bin/bash

# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh

# 修改SSH配置文件
SSH_CONFIG_FILE="/etc/ssh/ssh_config"

log_info "开始配置SSH免密登录"

if [ $(grep -c "StrictHostKeyChecking no" $SSH_CONFIG_FILE) -eq '0' ]; then
    sed -i '/StrictHostKeyChecking/s/^#//; /StrictHostKeyChecking/s/ask/no/' $SSH_CONFIG_FILE
fi

# 生成公钥
if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa
fi

# 读取集群节点
IFS=$'\n' read -d '' -r -a lines <$HOME_DIR/conf/workers

for worker in ${lines[@]}; do
    sshpass -f $HOME_DIR/conf/ssh_passwd ssh-copy-id root@$worker
    log_info "root@$worker SSH免密配置完成"
done
