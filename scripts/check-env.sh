#!/bin/bash

#################################
#
# check operation environment, software dependency
#
#################################

# get script current dir and project home dir
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"

# loading printf file
source $HOME_DIR/conf/printf.conf

printf -- "Check operation environment.\n"
if [ "$ENVIRONMENT_STATUS -eq 0" ]; then
    printf -- "Install necessary softwares.\n"
    sshpass=$(rpm -qa | grep "^sshpass.*")
    if [ $? -eq 0 ]; then
        printf -- "${SUCCESS}${sshpass} has been installed.${END}\n"
    else
        printf -- "Install sshpass...\n"
        rpm -ivh "$HOME_DIR/softwares/packages/sshpass-1.06-1.el7.x86_64.rpm"
        if [ $? -eq 0 ]; then
            printf -- "${SUCCESS}sshpass install successfully.${END}\n"
        else
            printf -- "${ERROR}sshpass install failed.${END}\n"
            exit 1
        fi
    fi
else
    printf -- "${SUCCESS}Operation has been config completed.${END}\n"
fi
