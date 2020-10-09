#!/usr/bin/env bash

# This script file is create by Ymliu at 2017-6-19 14:57.
# This script is used for start all nodes&services of ndbcluster on ssh.
# No arguments because arguments in script is matter for me. It will be modified later.
# FileName     : start-ndb.sh
# Path         : ~/bin/
# Author       : ymliu
# Create Date  : 2017-10-27 13:47
# WorkFlow     : Start managemet nodes, data nodes, sql nodes on sequence.

. ~/bin/ndb_env.sh

# Step 1: start managemet nodes
echo "Now starting management node(s)..."
CMD="${TARGET_DIR}/ndb_mgmd"
for host in "${MGM_NODES[@]}"
do
  echo -n "mgm node=${host}   "
  ssh ${USER}@${host} "sudo ${CMD} --configdir=${MGM_DIR}"
done
sleep 2s

# Step 2: start data nodes
echo ""
echo "Now starting data nodes..."
CMD="${TARGET_DIR}/ndbmtd"
for host in "${NDB_NODES[@]}"
do
  echo -n "ndb node=${host}   "
  ssh ${USER}@${host} "sudo ${CMD}"
done
sleep 10s

# Step 3: start sql nodes
echo ""
echo "Now starting sql nodes..."
for host in "${SQL_NODES[@]}"
do
  echo -n "sql node=${host}   "
  ssh ${USER}@${host} "sudo service ${SQL_SERVICE} start"
done

echo ""
ndb_mgm -e show
