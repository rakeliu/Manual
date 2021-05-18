#!/usr/bin/env bash

function _INIT_SED_VAR()
{
  # docker-hub setting
  SED_VAR["DOCKER_HUB"]="docker-hub:5000"
  # nfs setting
  SED_VAR["NFS_SERVER"]="192.168.176.8"
  SED_VAR["NFS_PATH"]="/appdata/nfs"
  # docker setting
  SED_VAR["DOCKER_DATA_ROOT"]="/appdata/docker"
  # coredns setting
  SED_VAR["INNER_DNS"]="10.15.0.2"
  SED_VAR["OUTTER_DNS"]="172.18.0.4"
}

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
_INIT_SED_VAR

# -------- main -----------
_sed_in_map ${DIRS[@]}
