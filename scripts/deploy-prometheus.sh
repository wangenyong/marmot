#!/bin/bash

#############################################################################################
#
# prometheus version "2.29.1"
#
# install prometheus
#
#############################################################################################

# get script directory and home directory
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$BASH_SOURCE")")
HOME_DIR="$(dirname $SCRIPT_DIR)"
# loading config file
source $HOME_DIR/conf/config.conf
# loading printf file
source $HOME_DIR/conf/printf.conf
# loading version file
source $HOME_DIR/conf/version.conf
# loading environment
source /etc/profile
# loading zookeeper nodes
IFS=',' read -ra prometheus_nodes <<<$PROMETHEUS_NODES

printf -- "${INFO}========== INSTALL PROMETHEUS ==========${END}\n"
if [ -d $PROJECT_DIR/prometheus* ]; then
    printf -- "${SUCCESS}========== PROMETHEUS INSTALLED ==========${END}\n"
    printf -- "\n"
    exit 0
fi

#############################################################################################
# install prometheus
#############################################################################################
printf -- "${INFO}>>> Install prometheus.${END}\n"
pv $HOME_DIR/softwares/prometheus/prometheus-${prometheus_version}.*.tar.gz | tar -zx -C $PROJECT_DIR/
# modify directory name
mv $PROJECT_DIR/prometheus* $PROJECT_DIR/prometheus-${prometheus_version}

#############################################################################################
# configure prometheus
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Configure prometheus prometheus.yml.${END}\n"

CONFIG_YML=$PROJECT_DIR/prometheus-${prometheus_version}/prometheus.yml

begin_line=$(sed -n '/^scrape_configs:/=' $CONFIG_YML)
end_line=$(sed -n '$=' $CONFIG_YML)
sed -i -r "${begin_line},${end_line}s|(targets).*|\1: [\""$PROMETHEUS_SERVER":9090\"]|" $CONFIG_YML

# -------------------------------------------------------------------------------------------
# configure pushgateway
# -------------------------------------------------------------------------------------------
printf -- "${INFO}--> Configure prometheus pushgateway.${END}\n"

sed -i -r '$G' $CONFIG_YML
sed -i -r '$a\  - job_name: "pushgateway"' $CONFIG_YML
sed -i -r '$a\    static_configs:' $CONFIG_YML
sed -i -r '$a\      - targets: ["'$PROMETHEUS_PUSH_GATEWAY':9091"]' $CONFIG_YML
sed -i -r '$a\        labels:' $CONFIG_YML
sed -i -r '$a\        instance: pushgateway' $CONFIG_YML

# -------------------------------------------------------------------------------------------
# configure node exporter
# -------------------------------------------------------------------------------------------
printf -- "${INFO}--> Configure prometheus node exporter.${END}\n"

i=1
connect=""
length=${#prometheus_nodes[@]}
for node in ${prometheus_nodes[@]}; do
    if [ $i -eq $length ]; then
        connect="$connect\"$node:9100\""
    else
        connect="$connect\"$node:9100\", "
    fi
    let i+=1
done

sed -i -r '$G' $CONFIG_YML
sed -i -r '$a\  - job_name: "node exporter"' $CONFIG_YML
sed -i -r '$a\    static_configs:' $CONFIG_YML
sed -i -r '$a\      - targets: ['"$connect"']' $CONFIG_YML

#############################################################################################
# install prometheus pushgateway
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Install prometheus pushgateway.${END}\n"
pv $HOME_DIR/softwares/prometheus/pushgateway-${pushgateway_version}.*.tar.gz | tar -zx -C $PROJECT_DIR/
# modify directory name
mv $PROJECT_DIR/pushgateway* $PROJECT_DIR/pushgateway-${pushgateway_version}

#############################################################################################
# install prometheus node exporter
#############################################################################################
printf -- "\n"
printf -- "${INFO}>>> Install prometheus node exporter.${END}\n"
pv $HOME_DIR/softwares/prometheus/node_exporter-${node_exporter_version}.*.tar.gz | tar -zx -C $PROJECT_DIR/
# modify directory name
mv $PROJECT_DIR/node_exporter* $PROJECT_DIR/node_exporter-${node_exporter_version}