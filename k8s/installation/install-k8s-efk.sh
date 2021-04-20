#!/usr/bin/env bash

# This script is used for setup k8s coreDNS configurations
#
# FileName     : install-k8s-efk.sh
# Path         : ~/bin/
# Author       : ymliu
# Create Date  : 2021-04-08 14:39
#
# History      : 2021-04-08 ok.

# ------ function declaration ---------------------------------------
function undeploy_efk()
{
  echo "-------------------------------------------------------------"
  echo "Undeploy kubernetes addons : efk"

  local -ra YAMLS=(
    "efk/30-kibana-deploy-all.yaml"
    "efk/20-fluentd-deploy-all.yaml"
    "efk/10-elasticsearch-deploy-all.yaml"
    "efk/01-storageclass.yaml"
  )

  undeploy_yaml ${YAMLS[@]}
  sudo rm -fr "${K8S_YAML_DIR}/efk"

  echo ""
}

function check_pkgs_efk()
{
  echo "-------------------------------------------------------------"
  echo "Checking installation packages..."
  check_pkg "addons/efk/01-storageclass.yaml"
  check_pkg "addons/efk/10-elasticsearch-deploy-all.yaml"
  check_pkg "addons/efk/20-fluentd-deploy-all.yaml"
  check_pkg "addons/efk/30-kibana-deploy-all.yaml"
  echo ""
}

function deploy_efk()
{
  echo "-------------------------------------------------------------"
  echo "Deploying kubernetes coreDNS"

  # building coredns.yaml
  echo -n "Building coredns.yaml..."

  cp -Rf ${TEMPLATE_DIR}/addons/efk ${TMP_DIR}
  # storageclass
  sed -i "s#\${DOCKER_HUB}#${DOCKER_HUB}#g" ${TMP_DIR}/efk/01-storageclass.yaml
  sed -i "s#\${NFS_SERVER}#${NFS_SERVER}#g" ${TMP_DIR}/efk/01-storageclass.yaml
  sed -i "s#\${NFS_PATH}#${NFS_PATH}#g" ${TMP_DIR}/efk/01-storageclass.yaml
  # elasticsearch
  sed -i "s#\${DOCKER_HUB}#${DOCKER_HUB}#g" ${TMP_DIR}/efk/10-elasticsearch-deploy-all.yaml
  # fluentd
  sed -i "s#\${DOCKER_HUB}#${DOCKER_HUB}#g" ${TMP_DIR}/efk/20-fluentd-deploy-all.yaml
  sed -i s"#\${DOCKER_DATA_ROOT}#${DOCKER_DATA_ROOT}#g" ${TMP_DIR}/efk/20-fluentd-deploy-all.yaml
  # kibana
  sed -i "s#\${DOCKER_HUB}#${DOCKER_HUB}#g" ${TMP_DIR}/efk/30-kibana-deploy-all.yaml
  echo "ok"

  # deploy coredns.yaml
  echo "Deploying efk yaml files..."
  sudo chown -R root:root ${TMP_DIR}/efk
  sudo cp -Rf ${TMP_DIR}/efk ${K8S_YAML_DIR}
  sudo ${KUBECTL} apply -f ${K8S_YAML_DIR}/efk/01-storageclass.yaml
  echo ""
  sudo ${KUBECTL} apply -f ${K8S_YAML_DIR}/efk/10-elasticsearch-deploy-all.yaml
  echo ""
  sudo ${KUBECTL} apply -f ${K8S_YAML_DIR}/efk/20-fluentd-deploy-all.yaml
  echo ""
  sudo ${KUBECTL} apply -f ${K8S_YAML_DIR}/efk/30-kibana-deploy-all.yaml
  echo ""

  echo ""

  echo "Waiting for a minute until efk pods ready, view service & pods status..."
  sleep 60s
  sudo ${KUBECTL} get -n kube-system -o wide deploy,sc,pods,svc,ingress
  echo ""

  echo "------ Ending of deploy efk -----------------------------"
}

# ----- main --------------------------------------------------------
declare -r SHELL_DIR="$(cd "$(dirname "${0}")" && pwd)"
. ${SHELL_DIR}/install-k8s-common.sh

declare -r DOCKER_DATA_ROOT="${APP_DIR}/docker"

undeploy_efk

check_pkgs_efk

deploy_efk

#clearTemporary

echo ""
