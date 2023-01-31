#!/bin/bash

# 获取当前脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# 加载日志打印脚本
source $SCRIPT_DIR/log.sh

#1. 判断参数个数
if [ $# -lt 1 ]; then
    echo Not Enough Arguement!
    exit
fi

IFS=$'\n' read -d '' -r -a lines <$HOME_DIR/conf/workers

#2. 遍历集群所有机器
for host in ${lines[@]}; do
    echo ==================== $host ====================
    #3. 遍历所有目录，挨个发送

    for file in $@; do
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
            rsync -av $pdir/$fname $host:$pdir
        else
            echo $file does not exists!
        fi
    done
done
