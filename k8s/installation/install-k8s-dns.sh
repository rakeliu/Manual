#!/usr/bin/env bash

# This script is used for setup k8s coreDNS configurations
#
# FileName     : install-k8s-dns.sh
# Path         : ~/bin/
# Author       : ymliu
# Create Date  : 2021-04-01 10:31
#
# History      : 2021-04-01 ok.

# ------ function declaration ---------------------------------------
function undeploy_coredns()
{
  echo "-------------------------------------------------------------"
  echo "Undeploy kubernetes addons : coreDNS"

  undeploy_yaml "coredns"

  echo ""
}

function check_pkgs_coredns()
{
  echo "-------------------------------------------------------------"
  echo "Checking installation packages..."
  check_pkg "addons/coredns/coredns.yaml"
  echo ""
}

function deploy_coredns()
{
  echo "-------------------------------------------------------------"
  echo "Deploying kubernetes coreDNS"

  # building coredns.yaml
  echo -n "Building coredns.yaml..."
  local -r INNER_DNS="${CLUSTER_IP_SEGMENT}.2"
  local -r OUTTER_DNS="192.168.176.8"
  cp -f ${TEMPLATE_DIR}/addons/coredns/coredns.yaml ${TMP_DIR}
  sed -i "s#\${DOCKER_HUB}#${DOCKER_HUB}#g" ${TMP_DIR}/coredns.yaml
  sed -i "s#\${INNER_DNS}#${INNER_DNS}#g" ${TMP_DIR}/coredns.yaml
  sed -i "s#\${OUTTER_DNS}#${OUTTER_DNS}#g" ${TMP_DIR}/coredns.yaml
  echo "ok"

  # deploy coredns.yaml
  echo "Deploying coredns.yaml..."
  sudo chown root:root ${TMP_DIR}/coredns.yaml
  sudo cp -f ${TMP_DIR}/coredns.yaml ${K8S_YAML_DIR}
  sudo ${KUBECTL} apply -f ${K8S_YAML_DIR}/coredns.yaml
  echo ""

  echo "Waiting for a while until coreDNS pod(s) is/are ready, view service & pods status..."
  sleep 15s
  sudo ${KUBECTL} get deploy,svc,pods -n kube-system -o wide
  echo ""

  echo "------ Ending of deploy coreDNS -----------------------------"
}

# ----- main --------------------------------------------------------
declare -r SHELL_DIR="$(cd "$(dirname "${0}")" && pwd)"
. ${SHELL_DIR}/install-k8s-common.sh

undeploy_coredns

check_pkgs_coredns

deploy_coredns

clearTemporary

echo ""
echo "You should run install-k8s-metrics-server.sh to deploy Metrics-Server !"
echo ""
