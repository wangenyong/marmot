#!/bin/bash

# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh

#1. 判断参数个数
if [ $# -lt 1 ]; then
    log_warn Not Enough Arguement!
    exit
fi

case "$1" in
install)
    case "$2" in
    jdk)
        log_info "install jdk"
        exec ./deploy-jdk.sh
        ;;
    hadoop)
        log_info "install hadoop"
        exec ./deploy-hadoop.sh
        ;;
    *)
        echo "default install (none of above)"
        ;;
    esac
    ;;
config)
    case "$2" in
    ssh)
        log_info "config auto ssh"
        exec ./auto-ssh-config.sh
        ;;
    2 | 3)
        echo "item = 2 or item = 3"
        ;;
    *)
        echo "default (none of above)"
        ;;
    esac
    ;;
start)
    echo "start"
    ;;
*)
    echo "default (none of above)"
    ;;
esac
