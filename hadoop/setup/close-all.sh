#/usr/bin/env bash

# This script file is used for shutdown all hosts of XX-Cluster
# No arguments because arguments in script is matter for me, add those later
#
# FileName     : close-all.sh
# Path         : ~/bin/
# Author       : ymliu
# Create Date  : 2017-10-27 13:47
# WorkFlow     : To set all hostname of cluster to variant HOSTS.
#                For each hostname, run shutdonw command by ssh skip localhost.
#                Shutdown localhost by local command.

# Step 1, set variants
. ~/bin/common_env.sh

# COMMAND is shutdown remote host by ssh
# if cannot login by ssh, export timeout by ssh
COMMAND="sudo shutdown -h now"

echo "The script will shutdown all hosts."
echo "------------------------------------------------"
for host in "${ALL_HOSTS[@]}"
do
  if [ "${host}" != "${LOCALHOST}" ]
  then
    echo -n "  shutting down ${host}: "
    ssh ${LOGNAME}@${host} "${COMMAND}"
  fi
done

# Step3, to shutdown localhost
echo "  shutting down localhost."
sudo shutdown -h now
