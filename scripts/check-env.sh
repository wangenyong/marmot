#!/bin/bash

#################################
#
# check operation environment, software dependency
#
#################################

# get script current dir and project home dir
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"
# loading config file
source $HOME_DIR/conf/config.conf
# loading printf file
source $HOME_DIR/conf/printf.conf

printf -- "Check operation environment.\n"
if [ $ENVIRONMENT_STATUS -eq 0 ]; then
    printf -- "${SUCCESS}Operation has been config completed.${END}\n"
    exit 0
fi

#################################
# check necessary softwares
#################################
printf -- "Install necessary softwares.\n"
# package sshpass
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
# package psmisc
psmisc=$(rpm -qa | grep "^psmisc.*")
if [ $? -eq 0 ]; then
    printf -- "${SUCCESS}${psmisc} has been installed.${END}\n"
else
    printf -- "Install psmisc...\n"
    rpm -ivh "$HOME_DIR/softwares/packages/psmisc-22.20-17.el7.x86_64.rpm"
    if [ $? -eq 0 ]; then
        printf -- "${SUCCESS}psmisc install successfully.${END}\n"
    else
        printf -- "${ERROR}psmisc install failed.${END}\n"
        exit 1
    fi
fi
# package pv
pv=$(rpm -qa | grep "^pv.*")
if [ $? -eq 0 ]; then
    printf -- "${SUCCESS}${pv} has been installed.${END}\n"
else
    printf -- "Install pv...\n"
    rpm -ivh "$HOME_DIR/softwares/packages/pv-1.4.6-1.el7.x86_64.rpm"
    if [ $? -eq 0 ]; then
        printf -- "${SUCCESS}pv install successfully.${END}\n"
    else
        printf -- "${ERROR}pv install failed.${END}\n"
        exit 1
    fi
fi
# package unzip
unzip=$(rpm -qa | grep "^unzip.*")
if [ $? -eq 0 ]; then
    printf -- "${SUCCESS}${unzip} has been installed.${END}\n"
else
    printf -- "Install unzip...\n"
    rpm -ivh "$HOME_DIR/softwares/packages/unzip-6.0-21.el7.x86_64.rpm"
    if [ $? -eq 0 ]; then
        printf -- "${SUCCESS}unzip install successfully.${END}\n"
    else
        printf -- "${ERROR}unzip install failed.${END}\n"
        exit 1
    fi
fi
