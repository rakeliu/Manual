#!/usr/bin/env bash

declare -r IMAGE=/mnt/rw/docker-image/registry.docker.tar
declare -r STORAGE=/appdata
declare -r SSL_DIR=/opt/ssl
declare -r DOCKER_HUB=docker-hub:5000
declare -r VERSION=2.7.1

function import_docker_image()
{
  if [[ $# -eq 0 ]]
  then
    return 0
  fi

  local IMAGE_PATH=${1}
  local -a FILES=`sudo ls ${IMAGE_PATH}`
  local tmpfile=""
  local imagefile=""
  for FILE in ${FILES[@]}
  do
    tmpfile=${IMAGE_PATH}/${FILE}
    if sudo test -f ${tmpfile}
    then
      # docker image
      echo "--------------------------------------------"
      echo ">> importing docker image file ${tmpfile}..."
      sudo docker load -i ${tmpfile}

      imagefile=`docker images | grep -v '^registry' | awk 'NR==2{print $1":"$2}'`

      docker tag ${imagefile} ${DOCKER_HUB}/${imagefile}
      docker push ${DOCKER_HUB}/${imagefile}
      docker rmi ${DOCKER_HUB}/${imagefile}
      docker rmi ${imagefile}
      echo ""
    else
      # directory
      echo "============================================================="
      echo "recursive loading directory ${tmpfile} images ..."
      import_docker_image ${tmpfile}
    fi
  done
}

echo "Clear images exists except for registry..."
docker images | grep -v '^registry\ ' | awk 'NR>1{cmd="docker rmi "$1":"$2; system(cmd)}'
echo ""

import_docker_image "/mnt/rw/docker-image"