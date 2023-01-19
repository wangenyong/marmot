#!/bin/bash

source ./log.sh

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
