#!/bin/bash

# This script file is create by Ymliu at 2017-6-19 14:57.
# This script is used to stop all nodes&services of ndbcluster on ssh.
# No arguments because arguments in script is matter for me. It will be modified later.
# FileName     : stop-ndb.sh
# Path         : ~/bin/
# Author       : ymliu
# Create Date  : 2017-10-27 13:47
# WorkFlow     : Stop sql nodes by service XXX stop, stop other nodes by mgm command line.

. ~/bin/ndb_env.sh
# Step 1: stop sql nodes
echo "Now stoping sql nodes..."
for host in "${SQL_NODES[@]}"
do
  echo -n "sql node=${host}   "
  ssh ${USER}@${host} "sudo service ${SQL_SERVICE} stop"
done

echo ""
echo "Now waiting for console to shutdown cluster!"
sleep 10s

# Step 2: stop all nodes except for sql nodes on console
ndb_mgm -e shutdown
