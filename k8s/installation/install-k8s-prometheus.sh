#!/usr/bin/env bash

# This script is used for setup k8s prometheus configurations
# The prometheus has very more yamls.
#
# FileName     : install-k8s-prometheus.sh
# Path         : ~/bin/
# Author       : ymliu
# Create Date  : 2021-04-02 13:58
#
# History      : 2021-04-08 ok

# ------ function declaration ---------------------------------------
function undeploy_prometheus()
{
  echo "-------------------------------------------------------------"
  echo "Undeploy kubernetes addons : prometheus"

  declare -ra YAMLS=(
    "prometheus/80-grafana-deploy-all"
    "prometheus/70-blackbox-exporter-deploy-all"
    "prometheus/62-prometheusRule-operator"
    "prometheus/61-prometheusRule-k8s"
    "prometheus/60-prometheus-deploy-all"
    "prometheus/50-adapter-deploy-all"
    "prometheus/41-prometheusRule-alertmanager"
    "prometheus/40-alertmanager-deploy-all"
    "prometheus/31-prometheusRule-node-exporter"
    "prometheus/30-node-exporter-deploy-all"
    "prometheus/23-prometheusRule-kubernetes"
    "prometheus/22-prometheusRule-kube-prometheus"
    "prometheus/21-prometheusRule-kube-stat-metrics"
    "prometheus/20-kube-state-metrics-deploy-all"
    "prometheus/18-operator-customResourceDefinition-thanosruler"
    "prometheus/17-operator-customResourceDefinition-servicemonitor"
    "prometheus/16-operator-customResourceDefinition-prometheusrule"
    "prometheus/15-operator-customResourceDefinition-prometheus"
    "prometheus/14-operator-customResourceDefinition-probe"
    "prometheus/13-operator-customResourceDefinition-podmonitor"
    "prometheus/12-operator-customResourceDefinition-alertmanager"
    "prometheus/11-operator-customResourceDefinition-altermanagerConfig"
    "prometheus/10-operator-deploy-all"
    "prometheus/01-storageclass"
    "prometheus/00-namespace"  )

  undeploy_yaml ${YAMLS[@]}
  sudo rm -fr ${K8S_YAML_DIR}/prometheus

  echo ""
}

function check_pkgs_prometheus()
{
  echo "-------------------------------------------------------------"
  echo "Checking installation packages..."

  check_pkg "addons/prometheus/00-namespace.yaml"
  check_pkg "addons/prometheus/01-storageclass.yaml"
  check_pkg "addons/prometheus/10-operator-deploy-all.yaml"
  check_pkg "addons/prometheus/11-operator-customResourceDefinition-altermanagerConfig.yaml"
  check_pkg "addons/prometheus/12-operator-customResourceDefinition-alertmanager.yaml"
  check_pkg "addons/prometheus/13-operator-customResourceDefinition-podmonitor.yaml"
  check_pkg "addons/prometheus/14-operator-customResourceDefinition-probe.yaml"
  check_pkg "addons/prometheus/15-operator-customResourceDefinition-prometheus.yaml"
  check_pkg "addons/prometheus/16-operator-customResourceDefinition-prometheusrule.yaml"
  check_pkg "addons/prometheus/17-operator-customResourceDefinition-servicemonitor.yaml"
  check_pkg "addons/prometheus/18-operator-customResourceDefinition-thanosruler.yaml"
  check_pkg "addons/prometheus/20-kube-state-metrics-deploy-all.yaml"
  check_pkg "addons/prometheus/21-prometheusRule-kube-stat-metrics.yaml"
  check_pkg "addons/prometheus/22-prometheusRule-kube-prometheus.yaml"
  check_pkg "addons/prometheus/23-prometheusRule-kubernetes.yaml"
  check_pkg "addons/prometheus/30-node-exporter-deploy-all.yaml"
  check_pkg "addons/prometheus/31-prometheusRule-node-exporter.yaml"
  check_pkg "addons/prometheus/40-alertmanager-deploy-all.yaml"
  check_pkg "addons/prometheus/41-prometheusRule-alertmanager.yaml"
  check_pkg "addons/prometheus/50-adapter-deploy-all.yaml"
  check_pkg "addons/prometheus/60-prometheus-deploy-all.yaml"
  check_pkg "addons/prometheus/61-prometheusRule-k8s.yaml"
  check_pkg "addons/prometheus/62-prometheusRule-operator.yaml"
  check_pkg "addons/prometheus/70-blackbox-exporter-deploy-all.yaml"
  check_pkg "addons/prometheus/80-grafana-deploy-all.yaml"

  echo ""
}

function deploy_prometheus()
{
  echo "-------------------------------------------------------------"
  echo "Deploying kubernetes addons : prometheus"

  echo -n "Building all yaml files..."
  # copy all *.yaml(s) to temporary diretory to modify
  cp -fR ${TEMPLATE_DIR}/addons/prometheus ${TMP_DIR}/
  local -i REPLICAS=1
  # namespace
  # storageclass
  sed -i "s#\${DOCKER_HUB}#${DOCKER_HUB}#g" ${TMP_DIR}/prometheus/01-storageclass.yaml
  sed -i "s#\${NFS_SERVER}#${NFS_SERVER}#g" ${TMP_DIR}/prometheus/01-storageclass.yaml
  sed -i "s#\${NFS_PATH}#${NFS_PATH}#g" ${TMP_DIR}/prometheus/01-storageclass.yaml
  # operator
  sed -i "s#\${DOCKER_HUB}#${DOCKER_HUB}#g" ${TMP_DIR}/prometheus/10-operator-deploy-all.yaml
  # kube-state-metrics
  sed -i "s#\${DOCKER_HUB}#${DOCKER_HUB}#g" ${TMP_DIR}/prometheus/20-kube-state-metrics-deploy-all.yaml
  # node-exporter
  sed -i "s#\${DOCKER_HUB}#${DOCKER_HUB}#g" ${TMP_DIR}/prometheus/30-node-exporter-deploy-all.yaml
  # alertmanager
  [ ${MASTER_SINGLE_FLAG} == "single" ] && REPLICAS=1 || REPLICAS=3
  sed -i "s#\${DOCKER_HUB}#${DOCKER_HUB}#g" ${TMP_DIR}/prometheus/40-alertmanager-deploy-all.yaml
  sed -i "s#\${REPLICAS}#${REPLICAS}#g" ${TMP_DIR}/prometheus/40-alertmanager-deploy-all.yaml
  # adapter
  sed -i "s#\${DOCKER_HUB}#${DOCKER_HUB}#g" ${TMP_DIR}/prometheus/50-adapter-deploy-all.yaml
  # prometheus
  [ ${MASTER_SINGLE_FLAG} == "single" ] && REPLICAS=1 || REPLICAS=2
  sed -i "s#\${DOCKER_HUB}#${DOCKER_HUB}#g" ${TMP_DIR}/prometheus/60-prometheus-deploy-all.yaml
  sed -i "s#\${REPLICAS}#${REPLICAS}#g" ${TMP_DIR}/prometheus/60-prometheus-deploy-all.yaml
  # blackbox-exporter
  sed -i "s#\${DOCKER_HUB}#${DOCKER_HUB}#g" ${TMP_DIR}/prometheus/70-blackbox-exporter-deploy-all.yaml
  # grafana
  sed -i "s#\${DOCKER_HUB}#${DOCKER_HUB}#g" ${TMP_DIR}/prometheus/80-grafana-deploy-all.yaml

  sudo mkdir -p ${K8S_YAML_DIR}/prometheus
  sudo cp -f ${TMP_DIR}/prometheus/*.yaml ${K8S_YAML_DIR}/prometheus
  sudo chown -R root:root ${K8S_YAML_DIR}/prometheus
  echo ""

  pushd ${K8S_YAML_DIR}/prometheus >/dev/null 2>&1
  echo "Deploying namespace, storageclass..."
  sudo ${KUBECTL} apply -f 00-namespace.yaml
  sudo ${KUBECTL} apply -f 01-storageclass.yaml
  sleep 2s
  echo ""

  echo "Deploying prometheus-operator..."
  sudo ${KUBECTL} apply -f 10-operator-deploy-all.yaml
  sudo ${KUBECTL} apply -f 11-operator-customResourceDefinition-altermanagerConfig.yaml
  sudo ${KUBECTL} apply -f 12-operator-customResourceDefinition-alertmanager.yaml
  sudo ${KUBECTL} apply -f 13-operator-customResourceDefinition-podmonitor.yaml
  sudo ${KUBECTL} apply -f 14-operator-customResourceDefinition-probe.yaml
  sudo ${KUBECTL} apply -f 15-operator-customResourceDefinition-prometheus.yaml
  sudo ${KUBECTL} apply -f 16-operator-customResourceDefinition-prometheusrule.yaml
  sudo ${KUBECTL} apply -f 17-operator-customResourceDefinition-servicemonitor.yaml
  sudo ${KUBECTL} apply -f 18-operator-customResourceDefinition-thanosruler.yaml
  # waiting for crds ready
  sleep 5s
  echo ""

  echo "Deploying kube-state-metrics..."
  sudo ${KUBECTL} apply -f 20-kube-state-metrics-deploy-all.yaml
  sudo ${KUBECTL} apply -f 21-prometheusRule-kube-stat-metrics.yaml
  sudo ${KUBECTL} apply -f 22-prometheusRule-kube-prometheus.yaml
  sudo ${KUBECTL} apply -f 23-prometheusRule-kubernetes.yaml
  sleep 2s
  echo ""

  echo "Deploying node-exporter..."
  sudo ${KUBECTL} apply -f 30-node-exporter-deploy-all.yaml
  sudo ${KUBECTL} apply -f 31-prometheusRule-node-exporter.yaml
  sleep 2s
  echo ""

  echo "Deploying alertmanager..."
  sudo ${KUBECTL} apply -f 40-alertmanager-deploy-all.yaml
  sudo ${KUBECTL} apply -f 41-prometheusRule-alertmanager.yaml
  sleep 2s
  echo ""

  echo "Deploying prometheus-adapter..."
  sudo ${KUBECTL} apply -f 50-adapter-deploy-all.yaml
  sleep 2s
  echo ""

  echo "Deploying prometheus self-body..."
  sudo ${KUBECTL} apply -f 60-prometheus-deploy-all.yaml
  sudo ${KUBECTL} apply -f 61-prometheusRule-k8s.yaml
  sudo ${KUBECTL} apply -f 62-prometheusRule-operator.yaml
  sleep 2s
  echo ""

  echo "Deploying blackbox-exporter..."
  sudo ${KUBECTL} apply -f 70-blackbox-exporter-deploy-all.yaml
  sleep 2s
  echo ""

  echo "Deploying grafana..."
  sudo ${KUBECTL} apply -f 80-grafana-deploy-all.yaml
  echo ""
  popd >/dev/null 2>&1

  echo "Waiting for one minute when prometheus components are ready, view services and pods..."
  sleep 60s
  sudo ${KUBECTL} get -n monitoring sc,svc,ingress
  echo ""
  sudo ${KUBECTL} get -n monitoring -o wide pods,crds,servicemonitors,prometheusrules
  echo ""

  echo "------ Ending of deploy prometheus ----------------------"
}

# ------ main ---------------------------------------
declare -r SHELL_DIR="$(cd "$(dirname "${0}")" && pwd)"
. ${SHELL_DIR}/install-k8s-common.sh

undeploy_prometheus

check_pkgs_prometheus

deploy_prometheus

clearTemporary

echo ""
