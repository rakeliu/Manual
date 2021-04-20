#!/usr/bin/env bash

# This script is used for setup k8s metrics-server configurations
#
# FileName     : install-k8s-metrics-server.sh
# Path         : ~/bin/
# Author       : ymliu
# Create Date  : 2021-03-24 10:31
#
# History      : 2021-03-31 ok.

# ------ function declaration ---------------------------------------
function undeploy_metrics_server()
{
  echo "-------------------------------------------------------------"
  echo "Undeploy kubernetes addons : metrics-server"

  undeploy_yaml "metrics-server"

  echo ""
}

function deploy_metrics_server()
{
  echo "-------------------------------------------------------------"
  echo "Deploying kubernetes addons : metrics-server"

  # building metrics-server cert & key files, distribute to masters.
  # modifing kube-apiserver service & conf files to include metrics-server config,
  # that was modified when kube-apiserver deploying.
  echo "Commet:"
  echo "  Metrics-server needs build certification, injects user \"system:metrics-server\" to kube-apiserver."
  echo "  Those are build and deployed in phase of kube-apiserver, not needed to do here."
  echo ""
  # building metrics-server.yaml
  echo -n "Building metrics-server.yaml..."
  cp -f ${TEMPLATE_DIR}/addons/metrics-server/metrics-server.yaml ${TMP_DIR}
  sed -i "s#\${DOCKER_HUB}#${DOCKER_HUB}#g" ${TMP_DIR}/metrics-server.yaml
  echo "ok"

  # deploy metrics-server.yaml
  echo "Deploying metrics-server.yaml..."
  sudo chown root:root ${TMP_DIR}/metrics-server.yaml
  sudo cp -f ${TMP_DIR}/metrics-server.yaml ${K8S_YAML_DIR}
  sudo ${KUBECTL} apply -f ${K8S_YAML_DIR}/metrics-server.yaml
  echo ""

  # show pods, it can be show nodes/pods metrics after one minutes.
  echo ""
  echo "Waiting for a while until metrics-server pod(s) is/are ready, view service & pods status..."
  sleep 10s
  sudo ${KUBECTL} get deploy,svc,pods -n kube-system -o wide
  echo ""


  echo "Waiting for one minute for collecting metrics, view metrics..."
  sleep 55s
  sudo ${KUBECTL} top nodes
  echo ""
  sudo ${KUBECTL} top pods -A
  echo ""

  echo "------ Ending of deploy metrics-server ----------------------"
}

function check_metrics_pkgs()
{
  echo "-------------------------------------------------------------"
  echo "Checking installation packages..."
  check_pkg "addons/metrics-server/metrics-server.yaml"
  echo ""
}

# ------ main ---------------------------------------
declare -r SHELL_DIR="$(cd "$(dirname "${0}")" && pwd)"
. ${SHELL_DIR}/install-k8s-common.sh

undeploy_metrics_server

check_metrics_pkgs

deploy_metrics_server

clearTemporary

echo ""
echo "You should run install-k8s-ingress.sh to deploy Ingress !"
echo ""
