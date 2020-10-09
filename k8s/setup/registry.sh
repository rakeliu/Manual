#!/usr/bin/env bash

# This script is used for docker registry utils

# list one image include all tags, output format
function listOne()
{
  if [ $# -eq 0 ]; then
    return
  fi

  local -r image=${1}
  local RET=`curl --cacert ${CERT_FILE} -i -X GET -s ${REGISTRY_URI}/${image}/tags/list`
  RET=`echo ${RET#*[}`    # remove prefix
  RET=`echo "${RET%]\}}"` # remove suffix
  local -ra TAGS=(`echo ${RET} | sed 's/,/\n/g; s/"//g' | sort`) # convert to column sorted

  for tag in ${TAGS[@]};do
    echo "    ${image}:${tag}"
  done
}

# list images on parameters, non for all, call listOne
function doList()
{
  local RET
  local -a REPOS
  if [ $# -eq 0 ]; then
    # no images specified, list all
    RET=`curl --cacert ${CERT_FILE} -s ${REGISTRY_URI}/_catalog`
    RET=`echo ${RET#*[}`    # remove prefix
    RET=`echo "${RET%]\}}"` # remove suffix
    REPOS=(`echo ${RET} | sed 's/,/\n/g; s/"//g' | sort`) # convert to column sorted
  else
    # images specified, list them
    REPOS=(`echo $@ | sort`)
  fi

  echo "List Catalog:"
  for image in ${REPOS[@]};do
    listOne ${image}
  done
}

function deleteOne()
{
  local -r image=${1}
  local -r tag=${2}
  local -r HEADER="Accept: application/vnd.docker.distribution.manifest.v2+json"

  local RET=`curl --cacert ${CERT_FILE} -i -s -X GET -H "${HEADER}" ${REGISTRY_URI}/${image}/manifests/${tag}`
  local TMP=`echo ${RET:0:15}`
  echo ${TMP} | grep "HTTP/1.1 200 OK" > /dev/null
  if [ $? -ne 0 ]; then
    echo "${image}:${tag} NOT exists!"
    exit 1
  fi

  local -r SHA256=`echo ${RET:105:95} | sed 's/Docker-Content-Digest: //'`
  RET=`curl -i -s --cacert ${CERT_FILE} -X DELETE ${REGISTRY_URI}/${image}/manifests/${SHA256}`
  echo -e "3:deleted ${TMP}"
  local TMP=`echo ${RET:0:15}`
  if [ $? -ne 0 ]; then
    # delete failed
    echo "${image}:${tag} delete failed!"
    exit 2
  fi

  docker exec -it registry /bin/registry garbage-collect /etc/docker/registry/config.yml
  echo "${image}:${tag} delete succeed!"

}

function doDelete()
{
  local TMP
  for imageTag in $@; do
    # check image:tag exists
    TMP=(`echo ${imageTag} | sed 's/:/\n/g'`)
    if [ ${#TMP[@]} -eq 2 ]; then
      image=${TMP[0]}
      tag=${TMP[1]}

      deleteOne ${image} ${tag}
    fi
  done

  docker exec -it registry /bin/registry garbage-collect /etc/docker/registry/config.yml >& /dev/null
}

function showUsage()
{
  echo "Usage:"
  echo "  registry.sh -h"
  echo "  registry.sh -l [images...]"
  echo "  registry.sh -d <image>:<tag>..."
  echo ""
  echo "              -h show help."
  echo "              -l list images specified with tag, list all without images."
  echo "              -d delete image with tag specified, like \"hub_site/owner/image:tag\" or short, you can specify one or more images."
  echo ""
  echo "You can use only one option, more than one cause error to show this usage."
}

# -------- main body --------------------
OPT_ARGS=`getopt -o :hld --long help,list,delete -n 'registry.sh' -- "$@"`
if [ $? != 0 ]; then
  showUsage
  exit 1
fi

eval set -- "${OPT_ARGS}"
CMD=""
declare -i CMD_COUNT=0

while true; do
  case ${1} in
    -h|--help)
      showUsage
      exit
      ;;
    -l|--list)
      CMD_COUNT=CMD_COUNT+1
      CMD="l"
      shift
      ;;
    -d|--delete)
    CMD_COUNT=CMD_COUNT+1
    CMD="d"
    shift
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "error option ${OPT_ARGS[@]}"
      exit
      ;;
  esac
done

if [[ CMD_COUNT -ne 1 ]]; then
  echo "You can use one option only, no more!"
  showUsage
  exit 1
fi

declare -r CERT_FILE="/opt/ssl/registry.crt"
declare -r REGISTRY_URI="https://docker-hub:5000/v2"

case ${CMD} in
  l)
    doList ${@}
  ;;
  d)
    doDelete ${@}
    #echo "Function Delete undeveloped."
  ;;
esac
