#!/usr/bin/env bash

function _GET_DIR()
{
  if [ $# -eq 0 ]; then
    local -r CURRENT_DIR=$(pwd)
    echo ${CURRENT_DIR}
  else
    echo $@
  fi
}

function _sed_in_map()
{
  local val;
  local sed_script;
  for dir in $@; do
    for key in ${!SED_VAR[*]}; do
      val=${SED_VAR[${key}]}
      sed_script="s#\\\${${key}}#${val}#g"

      echo "sed in directory ${dir}: \${${key}} --> ${val}"
      sed -i "${sed_script}" ${dir}/*.yaml
    done
  done
}

declare -r SHELL_DIR="$(cd "$(dirname "${0}")" && pwd)"
declare -ra DIRS=($(_GET_DIR $@))

# declare map
declare -A SED_VAR
SED_VAR["DOCKER_HUB"]="docker-hub:5000"

SED_VAR["NFS_SERVER"]="192.168.176.8"
SED_VAR["NFS_PATH"]="/appdata/nfs"

# -------- main -----------
_sed_in_map ${DIRS[@]}
