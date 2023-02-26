#!/bin/bash

#############################################################################################
#
# dolphinscheduler version "2.0.5"
#
# configure dolphinscheduler
#
#############################################################################################

# get script directory and home directory
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"
# loading config file
source $HOME_DIR/conf/config.conf
# loading printf file
source $HOME_DIR/conf/printf.conf

#############################################################################################
# install dolphinscheduler
#############################################################################################
DOLPHINSCHEDULER_TMP_DIR=$HOME_DIR/softwares/dolphinscheduler
if [ -d $DOLPHINSCHEDULER_TMP_DIR ]; then
    rm -rf $DOLPHINSCHEDULER_TMP_DIR
else
    mkdir $DOLPHINSCHEDULER_TMP_DIR
    pv $HOME_DIR/softwares/apache-dolphinscheduler-2.0.5-bin.tar.gz | tar -zx -C $DOLPHINSCHEDULER_TMP_DIR --strip-components 1
fi


#############################################################################################
# configure dolphinscheduler
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure dolphinscheduler install config.${END}\n"

DOLPHINSCHEDULER_INSTALL_CONF=$DOLPHINSCHEDULER_TMP_DIR/conf/config/install_config.conf

