#!/usr/bin/env bash

# This script is used for setup k8s ingress configurations
#
# FileName     : install-k8s-dns.sh
# Path         : ~/bin/
# Author       : ymliu
# Create Date  : 2021-04-01 10:31
#
# History      : 2021-04-01 ok

# ------ function declaration ---------------------------------------
function undeploy_ingress()
{
  echo "-------------------------------------------------------------"
  echo "Undeploy kubernetes addons : ingress"

  undeploy_yaml "20-ingress-controller" "10-ingress-admission-webhook" "00-ingress-namespace"

  echo ""
}

function check_pkgs_ingress()
{
  echo "-------------------------------------------------------------"
  echo "Checking installation packages..."
  check_pkg "addons/ingress/00-ingress-namespace.yaml"
  check_pkg "addons/ingress/10-ingress-admission-webhook.yaml"
  check_pkg "addons/ingress/20-ingress-controller.yaml"
  echo ""
}

function deploy_ingress()
{
  echo "-------------------------------------------------------------"
  echo "Deploying kubernetes addons - ingress"

  echo -n "Building ingress - namespace,admission,controller yaml files..."
  cp -f ${TEMPLATE_DIR}/addons/ingress/??-ingress-*.yaml ${TMP_DIR}
  sed -i "s#\${DOCKER_HUB}#${DOCKER_HUB}#g" ${TMP_DIR}/20-ingress-controller.yaml
  sed -i "s#\${DOCKER_HUB}#${DOCKER_HUB}#g" ${TMP_DIR}/10-ingress-admission-webhook.yaml
  sudo cp ${TMP_DIR}/??-ingress-*.yaml ${K8S_YAML_DIR}
  sudo chown root:root ${K8S_YAML_DIR}/??-ingress-*.yaml
  echo "ok"

  # deploy yaml in sequence
  echo "Deploying ingress - namespace,admission,controller yaml files..."
  sudo ${KUBECTL} apply \
    -f ${K8S_YAML_DIR}/00-ingress-namespace.yaml \
    -f ${K8S_YAML_DIR}/10-ingress-admission-webhook.yaml \
    -f ${K8S_YAML_DIR}/20-ingress-controller.yaml
  echo ""

  # view pods in namespace ingress-nginx
  echo "Waiting for a moment for ingress-controller need some time to be ready, view pods..."
  sleep 30s
  ${KUBECTL} get deploy,svc,pods,job -n ingress-nginx -o wide

  echo "------ Ending of deploy ingress-nginx ----------------------"
}

# ----- main --------------------------------------------------------
declare -r SHELL_DIR="$(cd "$(dirname "${0}")" && pwd)"
. ${SHELL_DIR}/install-k8s-common.sh

undeploy_ingress

check_pkgs_ingress

deploy_ingress

clearTemporary

echo ""
echo "You should run install-k8s-dashboard.sh to deploy Kubernetes-Dashboard !"
echo ""
