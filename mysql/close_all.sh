#/usr/bin/env bash

# This script file is used for shutdown all hosts of XX-Cluster
# No arguments because arguments in script is matter for me, add those later
#
# FileName     : close_all.sh
# Path         : ~/bin/
# Author       : ymliu
# Create Date  : 2018-1-16 15:19
# WorkFlow     : To set all hostname of cluster to variant HOSTS.
#                For each hostname, run shutdonw command by ssh skip localhost.
#                Shutdown localhost by local command.

# Step 1, set variants
# HOSTS contains all hostname of cluster, array
HOSTS=("docker-template" "k8s-master1" "k8s-master2" "k8s-master3" "k8s-node1" "k8s-node2" "k8s-node3")
# LOCALHOST is short name of localhost
LOCALHOST=`hostname -s`
# COMMAND is shutdown remote host by ssh
# if cannot login by ssh, export timeout by ssh
COMMAND="sudo shutdown -h now"

echo "The script will shutdown all hosts."
echo "------------------------------------------------"
for host in "${HOSTS[@]}"
do
  if [ "${host}" != "${LOCALHOST}" ]
  then
    echo -n "  shutting down host: ${host}.   "
    ssh ${LOGNAME}@${host} "${COMMAND}"
  fi
done

# Step3, to shutdown localhost
echo "  shutting down localhost."
sudo shutdown -h now
