#!/usr/bin/env bash

# This script is used for setup k8s dashboard configurations
#
# FileName     : install-k8s-dns.sh
# Path         : ~/bin/
# Author       : ymliu
# Create Date  : 2021-04-01 10:31
#
# History      : 2021-04-01 ok

# ------ function declaration ---------------------------------------
function undeploy_dashboard()
{
  echo "-------------------------------------------------------------"
  echo "Undeploy kubernetes addons : dashboard"

  undeploy_yaml "kubernetes-dashboard"

  echo -n "Running on localhost: removing kubernetes-dashboard cert & key files..."
  sudo rm -f ${SSL_DIR}/kubernetes-dashboard*.*
  echo "ok"

  echo ""
}

function check_pkgs_dashboard()
{
  echo "-------------------------------------------------------------"
  echo "Checking installation packages..."
  check_pkg "addons/dashboard/kubernetes-dashboard-csr.json"
  check_pkg "addons/dashboard/kubernetes-dashboard.yaml"
  echo ""
}

function deploy_dashboard()
{
  echo "-------------------------------------------------------------"
  echo "Deploying kubernetes addons - dashboard"

  echo -n "Building kubernetes-dashboard cert & key files..."
  sudo cp -f ${TEMPLATE_DIR}/addons/dashboard/kubernetes-dashboard-csr.json ${SSL_DIR}
  pushd ${SSL_DIR} >/dev/null 2>&1
  (sudo ./cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kubernetes-dashboard-csr.json | sudo ./cfssljson -bare kubernetes-dashboard) >/dev/null 2>&1
  popd >/dev/null 2>&1
  echo "ok"

  echo -n "Building kubernetes-dashboard.ymal..."
  local -r DASHBOARD_KEY=$(sudo base64 -w 0 ${SSL_DIR}/kubernetes-dashboard-key.pem )
  local -r DASHBOARD_CERT=$(sudo base64 -w 0 ${SSL_DIR}/kubernetes-dashboard.pem)
  cp -f ${TEMPLATE_DIR}/addons/dashboard/kubernetes-dashboard.yaml ${TMP_DIR}
  sed -i "s#\${DOCKER_HUB}#${DOCKER_HUB}#g" ${TMP_DIR}/kubernetes-dashboard.yaml
  sed -i "s#\${DASHBOARD_CERT}#${DASHBOARD_CERT}#g" ${TMP_DIR}/kubernetes-dashboard.yaml
  sed -i "s#\${DASHBOARD_KEY}#${DASHBOARD_KEY}#g" ${TMP_DIR}/kubernetes-dashboard.yaml
  sudo chown root:root ${TMP_DIR}/kubernetes-dashboard.yaml
  sudo cp ${TMP_DIR}/kubernetes-dashboard.yaml ${K8S_YAML_DIR}
  echo "ok"

  echo "Deploy dashboard.yaml..."
  sudo ${KUBECTL} apply -f ${K8S_YAML_DIR}/kubernetes-dashboard.yaml
  echo ""

  echo "Waiting for a few seconds until pods are ready, view deploy,svc,pods & ingress in kubernetes-dashboard namespace..."
  sleep 10s
  sudo ${KUBECTL} get deploy,svc,pods,ingress -n kubernetes-dashboard -o wide
  echo ""

  echo "To view kubernetes-dashborad, type url: https://dashboard.k8s.vm:31443/ in browser, use token to login."
  echo "The following command to show token:"
  echo "  kubectl -n kubernetes-dashboard describe secret \$(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print \$1}')"
  echo ""
  ${KUBECTL} -n kubernetes-dashboard describe secret $(${KUBECTL} -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')
  echo ""

  echo "------ Ending of deploy kubernetes-dashboard ----------------"
}

# ----- main --------------------------------------------------------
declare -r SHELL_DIR="$(cd "$(dirname "${0}")" && pwd)"
. ${SHELL_DIR}/install-k8s-common.sh

undeploy_dashboard

check_pkgs_dashboard

deploy_dashboard

clearTemporary
