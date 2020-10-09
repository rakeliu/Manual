#!/usr/bin/env bash

# This script is used for clear Mysql NDB-Cluster installation
# No arguments because no useful
# Usage: ndb_clear.sh
#
# FileName     : ndb_clear.sh
# Path         : ~/bin/
# Author       : ymliu
# Create Date  : 2017-11-16 16:36
# WorkFlow     :

. ~/bin/ndb_env.sh

# Function for removing directory
# Parameter 1 - diretory to remove
# Parameter 2 - node type to show
function Remove_Dir() {
  echo -n " Removing $2 directory : $1, "
  if [ -d $1 ]; then
    sudo rm -fr $1
    echo "removed."
  else
    echo "not exist."
  fi
}

# Function for removing symbolic link
# Parameter 1..n - list of symbolic links
function Remove_Symbolic() {
  echo " Removing symbolic link :"
  local count=0
  for link in $@; do
    if [ -L ${link} ]; then
      sudo rm -fr ${link}
      echo "    ${link} removed."
      count=$[$count +1]
    fi
  done
  echo "    ${count} link(s) removed."
}

# Function for removing service
# Parameter 1 - service name to remove
function Remove_Service() {
  echo -n " Removing service: $1 "
  if [ -f /etc/rc.d/init.d/$1 ]; then
    sudo systemctl disable $1 >& /dev/null
    if [ $? -eq 0 ]; then
      sudo rm -f "/etc/rc.d/init.d/${SQL_SERVICE}"
      echo "removed."
    else
      echo "faild."
    fi
  else
    echo "not exist."
  fi
}

# Function for removing file
# Parameter 1 - file to remove
# Parameter 2 - file describe
function Remove_File() {
  echo -n " Removing $2 file - $1: "
  if [ -f $1 ]; then
    sudo rm -f $1
    echo "removed."
  else
    echo "not exist."
  fi
}

# Function for remove user
function Remove_User() {
  echo -n " Removing user - $1, "
  egrep "^$1" /etc/passwd >& /dev/null
  if [ $? -eq 0 ]; then
    sudo userdel -r $1
    echo "removed."
  else
    echo "not exist."
  fi
}

# Function for remove group
function Remove_Group() {
  echo -n " Removing group - $1, "
  egrep "^$1" /etc/group >& /dev/null
  if [ $? -eq 0 ]; then
    sudo groupdel $1
    echo "removed."
  else
    echo "not exist."
  fi
}

# remove management directory & config file
Remove_Dir "${MGM_DIR}" "management"
Remove_Dir "${NDB_DIR}" "ndb"
Remove_Dir "${SQL_DIR}" "sql"
# remove symbolic
Remove_Symbolic `echo ${MGM_EXEC_FILES[@]} ${NDB_EXEC_FILES[@]} ${SQL_SYMBOLIC_LINK}`
# remove service
Remove_Service "${SQL_SERVICE}"
# remove file
Remove_File ${CLIENT_CONFIG_FILE} "client config"
Remove_File ${CLIENT_CONFIG_TMPFILE} "client config temp"
Remove_File ${MGM_TMPFILE} "management config temp"
# remove user & group
Remove_User ${USER_NAME}
Remove_Group ${GROUP_NAME}
