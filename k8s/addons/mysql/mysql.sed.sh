#!/usr/bin/env bash

declare -r SHELL_DIR="$(cd "$(dirname "${0}")" && pwd)"

declare -r DOCKER_HUB="docker-hub:5000"

declare -r NFS_SERVER="192.168.176.8"
declare -r NFS_PATH="/appdata/nfs"

echo "sed \${DOCKER_HUB} -- > ${DOCKER_HUB}"
sed -i "s#\${DOCKER_HUB}#${DOCKER_HUB}#g" ${SHELL_DIR}/*.yaml

echo "sed \${NFS_SERVER} -- > ${NFS_SERVER}"
sed -i "s#\${NFS_SERVER}#${NFS_SERVER}#g" ${SHELL_DIR}/*.yaml

echo "sed \${NFS_PATH} -- > ${NFS_PATH}"
sed -i "s#\${NFS_PATH}#${NFS_PATH}#g" ${SHELL_DIR}/*.yaml
