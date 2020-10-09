#!/usr/bin/env bash

# This script file is used for start/stop zookeeper cluster.
#
# FileName     : zkCluster.sh
# Path         : ~/bin/
# Author       : ymliu
# Create Date  : 2017-10-27 15:18

function Print_Usage() {
  echo "Usage: zkCluster.sh start/stop"
  echo "  start     Start all node of cluster in sequence."
  echo "  stop      Stop all node cluster in sequence."
}

if [ $# -ne 1 ]
then
  Print_Usage
  exit 1
fi

METHODING=""
case $1 in
  start )
    METHODING="starting";;
  stop )
    METHODING="stopping";;
  *)
    Print_Usage
    exit 1;;
esac

. ~/bin/common_env.sh
CMDLINE="${ZK_SYMBOLIC}/bin/zkServer.sh ${1}"

for node in "${ZK_NODES[@]}"
do
  echo "-------------------------------------"
  echo "Host ${node} zookeeper ${METHODING}..."
  ssh ${LOGNAME}@${node} "$CMDLINE"
  echo ""
done
