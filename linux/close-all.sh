#/usr/bin/env bash

# This script file is used for shutdown all hosts of XX-Cluster
# No arguments because arguments in script is matter for me, add those later
#
# FileName     : close_all.sh
# Path         : ~/bin/
# Author       : ymliu
# Create Date  : 2021-03-03  9:34
# WorkFlow     : To set all hostname of cluster to variant HOSTS.
#                For each hostname, run shutdonw command by ssh skip localhost.
#                Shutdown localhost by local command.

# Step 1, set variants
# HOSTS contains all hostname of cluster, array

# declare -ra HOSTS=(`cat /etc/hosts | grep '192' | grep -v 'vip' | grep -v 'hub' | nl | sort -nr | awk '{print $3}'`)
#declare -ra HOSTS=("docker-tpl" "docker-single" "k8s-node3" "k8s-node2" "k8s-node1" "k8s-master3" "k8s-master2" "k8s-master1")
declare -ra HOSTS=("k8s-mini" "k8s-worker3" "k8s-worker2" "k8s-worker1" "k8s-master3" "k8s-master2" "k8s-master1" "docker-hub" "docker-tpl")

# LOCALHOST is short name of localhost
declare -r LOCALHOST=`hostname -s`

# COMMAND is shutdown remote host by ssh
# if cannot login by ssh, export timeout by ssh
declare -r COMMAND="sudo shutdown -h now"

# Delay interval between two hosts.
declare -r DELAY_SECOND=2s

echo "The script will shutdown all hosts."
echo "------------------------------------------------"
for host in "${HOSTS[@]}"
do
  if [ "${host}" != "${LOCALHOST}" ]
  then
    echo -n "  shutting down host: ${host}.   "
    ssh ${LOGNAME}@${host} "${COMMAND}"
    sleep ${DELAY_SECOND}
  fi
done

# Step3, to shutdown localhost
echo "  shutting down localhost."
sudo shutdown -h now
