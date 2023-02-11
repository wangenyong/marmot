#!/bin/bash

#################################
#
# 集群分发脚本
#
#################################

# get script directory and home directory
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"
# loading config file
source $HOME_DIR/conf/config.conf
# loading printf file
source $HOME_DIR/conf/printf.conf

if [ $# -lt 2 ]; then
    echo Not Enough Arguement!
    exit
fi

IFS=',' read -ra lines <<<$1

#2. 遍历集群所有机器
for host in ${lines[@]}; do
    echo ==================== $host $2 ====================
    #3. 遍历所有目录，挨个发送

    for file in $2; do
        #4. 判断文件是否存在
        if [ -e $file ]; then
            #5. 获取父目录
            pdir=$(
                cd -P $(dirname $file)
                pwd
            )

            #6. 获取当前文件的名称
            fname=$(basename $file)
            ssh $host "mkdir -p $pdir"
            rsync -a --info=progress2 $pdir/$fname $host:$pdir
        else
            echo $file does not exists!
        fi
    done
done
