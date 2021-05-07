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

function _SED()
{
  for dir in ${DIRS[@]}; do
    echo "sed in directory ${dir}: \${DOCKER_HUB} -- > ${DOCKER_HUB}"
    sed -i "s#\${DOCKER_HUB}#${DOCKER_HUB}#g" ${dir}/*.yaml

    echo "sed in directory ${dir}: \${NFS_SERVER} -- > ${NFS_SERVER}"
    sed -i "s#\${NFS_SERVER}#${NFS_SERVER}#g" ${dir}/*.yaml

    echo "sed in directory ${dir}: \${NFS_PATH} -- > ${NFS_PATH}"
    sed -i "s#\${NFS_PATH}#${NFS_PATH}#g" ${dir}/*.yaml
  done
}

declare -r SHELL_DIR="$(cd "$(dirname "${0}")" && pwd)"

declare -r DOCKER_HUB="docker-hub:5000"

declare -r NFS_SERVER="192.168.176.8"
declare -r NFS_PATH="/appdata/nfs"

declare -ra DIRS=($(_GET_DIR $@))

# -------- main -----------
_SED
