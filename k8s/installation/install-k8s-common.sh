#!/usr/bin/env bash

# To declare environment variables and common functions.
#
# FileName     : install-k8s-common.sh
# Path         : ~/bin/
# Author       : ymliu
# Create Date  : 2021-03-30 14:03
# WorkFlow     : To declare environment variables and common functions.
#
# History      : 2021-03-30 initialized.
#                2021-03-31 renamed.
#                2021-04-06 function undeploy_yaml add processing direcotry.

# ------ function declaration ---------------------------------------
# init_env_common
function init_env_common()
{
  [ -d ${TMP_DIR} ] && sudo rm -fr ${TMP_DIR}
  mkdir -p ${TMP_DIR}

  for host in ${WORKERS[@]}; do
    ssh ${USER}@${host} "[ -d ${TMP_DIR} ] && sudo rm -fr ${TMP_DIR}; \
      mkdir -p ${TMP_DIR}"
  done
}

# ----- ip & host --------
function build_hosts_array()
{
  local -r ARGS=($@)
  local -ri LENGTH=$#

  local STR=""
  local -i i=0
  local -i j=0

  while [ ${i} -lt ${LENGTH} ]; do
    if [ $j -gt 0 ]; then
      STR="${STR} "
    fi
    STR="${STR}${ARGS[${i}]}"

    i=$(( i + 2))
    (( j++ ))
  done

  echo ${STR}
}
function hostip()
{
  local -r host=$1
  local -ri LENGTH=${#WORKERS_INFO[@]}
  local -i index=0
  local -i pos=-1

  while [ ${index} -lt ${LENGTH} ]; do
    if [ "${host}" == "${WORKERS_INFO[${index}]}" ]; then
      pos=${index}
      break
    fi
    index=$(( index + 2 ))
  done

  if [ ${pos} -ge 0 ]; then
    echo ${WORKERS_INFO[$(( pos + 1 ))]}
  fi
}

# ------ build etcd conn -------------
function build_etcd_initialCluster()
{
  # return https://ip1:2380,https://ip2:2380...

  local STR=""
  local -i count=0

  for host in ${MASTERS[@]}; do
    count=$(( count + 1 ))
    if [ ${count} -gt 1 ]; then
      STR="${STR},"
    fi
    STR="${STR}${host}=https://$(hostip ${host}):2380"
  done

  echo ${STR}
}
function build_etcd_endpoints()
{
  # return https://ip1:2379,https:ip2:2379...

  local STR=""
  local -i count=0

  for host in ${MASTERS[@]}; do
    count=$(( count + 1 ))

    if [ ${count} -gt 1 ]; then
      STR="${STR},"
    fi
    STR="${STR}https://$(hostip ${host}):2379"
  done

  echo ${STR}
}
function build_etcd_clientConnectString()
{
  local -r ENDPOINTS=$(build_etcd_endpoints)
  echo "--cacert=${SSL_DIR}/ca.pem --cert=${SSL_DIR}/etcd.pem --key=${SSL_DIR}/etcd-key.pem --endpoints=${ENDPOINTS}"
}

# checking packages of installation: all kinds of files
function check_pkg()
{
  if [ $# -ne 1 ]; then
    echo "Error calling check_pkg, only one parameter permitted!"
    echo "     parameters passed: $@"
    exit 11
  fi

  local -r FILE="${TEMPLATE_DIR}/${1}"
  echo -n "checking file ${FILE} ... "
  if [ -f ${FILE} ]; then
    echo "exists !"
  else
    echo "not exist, ERROR !"
    exit 12
  fi
}

# undeploy k8s yaml(s), such as pods, service, ingress, etc...
function undeploy_yaml()
{
  if [ -f ${KUBECTL} ]; then
    local -ra YAMLS=($@)
    for yaml in ${YAMLS[@]}; do
      if [ -d "${K8S_YAML_DIR}/${yaml}" ]; then
        echo -n "Removing from directory ${K8S_YAML_DIR}/${yaml} ..."
        sudo ${KUBECTL} delete -Rf "${K8S_YAML_DIR}/${yaml}" >/dev/null 2>&1
        sudo rm -fr "${K8S_YAML_DIR}/${yaml}"
        echo "ok"
      elif [ -f "${K8S_YAML_DIR}/${yaml}.yaml" ]; then
        echo -n "Removing from ${K8S_YAML_DIR}/${yaml}.yaml..."
        sudo ${KUBECTL} delete -f "${K8S_YAML_DIR}/${yaml}.yaml" >/dev/null 2>&1
        sudo rm -f "${K8S_YAML_DIR}/${yaml}.yaml"
        echo "ok"
      else
        echo "Removing from ${K8S_YAML_DIR}/${yaml}...not exist!"
      fi
    done
  else
    echo "WARNNING: KUBECTL undefined!"
  fi
}

# clean temporary after installing
function clearTemporary()
{
  echo "-------------------------------------------------------------"
  echo "Clearing temporary files after installing"
  echo "-------------------------------------------------------------"

  echo -n "Running on localhost: Clearing temporary files..."
  rm -fr ${TMP_DIR}
  echo ""

  for host in ${WORKERS[@]}; do
    echo -n "Running on ${host}($(hostip ${host})): Clearing temporary files..."
    ssh ${USER}@${host} "rm -fr ${TMP_DIR}"
    echo "ok"
  done

  echo "------ Ending of clearing -----------------------------------"
}

# cluster function
function master_single_flag()
{
  if [ ${#MASTERS[@]} -eq 1 ]; then
    # only one master node
    echo "single"
  else
    # more than one master node
    echo "cluster"
  fi
}
function get_vip()
{
  if [ "x${MASTER_SINGLE_FLAG}x" == "xsinglex" ]; then
    echo $(hostip ${MASTERS[0]})
  else
    echo ${DEFAULT_VIP}
  fi
}
function get_vip_port()
{
  if [ ${MASTER_SINGLE_FLAG} == "single" ]; then
    echo "6443"
  else
    echo "8443"
  fi
}
# ------ ending of function declaration -----------------------------

# ------ main -------------------------------------------------------
# run once
echo "Loading install-k8s-common.sh..."
if [ "${RUN_ONCE_FLAG}" == "LOADED" ]; then
  # already load
  exit 2
fi
declare -r RUN_ONCE_FLAG="LOADED"

# ------ environment variables declaration --------------------------
declare -ra MASTERS_INFO=(
  "k8s-mini" "192.168.176.41"
#  "k8s-master1" "192.168.176.35"
#  "k8s-master2" "192.168.176.36"
#  "k8s-master3" "192.168.176.37"
)

declare -ra WORKERS_INFO=(
  ${MASTERS_INFO[@]}
#  "k8s-worker1" "192.168.176.38"
#  "k8s-worker2" "192.168.176.39"
#  "k8s-worker3" "192.168.176.40"
)
declare -r DEFAULT_VIP="192.168.176.34"

declare -ra MASTERS=($(build_hosts_array ${MASTERS_INFO[@]}))
declare -ra WORKERS=($(build_hosts_array ${WORKERS_INFO[@]}))
declare -r EXEC_NODE=${MASTERS[0]} # first index of array, if not specify index range

declare -r APP_DIR="/appdata"
declare -r SSL_DIR="/opt/ssl"
declare -r RPM_DIR="/mnt/rw/rpm"
declare -r TEMPLATE_DIR="${SHELL_DIR}/template"
declare -r TMP_DIR="$(mktemp -du /tmp/k8s-setup.XXXXX)"

declare -r MASTER_SINGLE_FLAG=$(master_single_flag)
declare -r VIP=$(get_vip)
declare -r VIP_PORT=$(get_vip_port)

declare -r CLUSTER_IP_SEGMENT="10.15.0"
declare -r POD_IP_SEGMENT="10.16.0"

declare -r NFS_SERVER="192.168.176.8"
declare -r NFS_PATH="/appdata/nfs"

declare -r SERVICE_DIR="/etc/systemd/system"
declare -r K8S_BASE_DIR="/opt/k8s"
declare -r K8S_BIN_DIR="${K8S_BASE_DIR}/bin"
declare -r K8S_CONF_DIR="${K8S_BASE_DIR}/conf"
declare -r K8S_YAML_DIR="${K8S_BASE_DIR}/yaml"
declare -r K8S_TOKEN_DIR="${K8S_BASE_DIR}/token"

declare -r KUBECTL="${K8S_BIN_DIR}/kubectl"
declare -r ETCD_VER="3.4.10"
declare -r DOCKER_HUB="docker-hub:5000"

declare -r NETWORK_CARD="enp0s3"

declare -r ETCD_CLUSTER=$(build_etcd_initialCluster)
declare -r ETCD_ENDPOINTS=$(build_etcd_endpoints)

# echo color
declare -r COLOR_RED="\033[31m"
declare -r COLOR_GREEN="\033[32m"
declare -r COLOR_NORMAL="\033[0m"

init_env_common
