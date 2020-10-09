#!/usr/bin/env bash

KUBE_APISERVER="https://192.168.176.34:8443"
CA_FILE="/opt/ssl/ca.pem"
KUBECTL_CMD="/opt/k8s/bin/kubectl"
BOOTSTRAP_TOKEN=$(sudo cat /opt/k8s/token/bootstrap-token.csv | awk -F ',' '{print $1}')
echo "BOOTSTRAP_TOKEN = ${BOOTSTRAP_TOKEN}"
echo -e "\n"

# Create bootstrap.kubeconfig
create_bootstrap()
{
  echo "Create bootstrap.kubeconfig"

  CONFIG_FILE="/opt/k8s/cert/bootstrap.kubeconfig"

  sudo rm -f ${CONFIG_FILE}

  sudo ${KUBECTL_CMD} config set-cluster kubernetes \
    --certificate-authority=${CA_FILE} \
    --embed-certs=true \
    --server=${KUBE_APISERVER} \
    --kubeconfig=${CONFIG_FILE}
  echo "step 1: $?"

  sudo ${KUBECTL_CMD} config set-credentials  kubelet-bootstrap \
    --token=${BOOTSTRAP_TOKEN} \
    --kubeconfig=${CONFIG_FILE}
  echo "step 2: $?"

  sudo ${KUBECTL_CMD} config set-context default \
    --cluster="kubernetes" \
    --user="kubelet-bootstrap" \
    --kubeconfig=${CONFIG_FILE}
  echo "step 3: $?"

  sudo ${KUBECTL_CMD} config use-context default \
    --kubeconfig=${CONFIG_FILE}
  echo "step 4: $?"

  echo -e "\n"
}

# Create kublet.kubeconfig
create_kubelet()
{
  echo "Create kubelet.kubeconfig"

  CONFIG_FILE="/opt/k8s/cert/kubelet.kubeconfig"

  sudo rm -f ${CONFIG_FILE}

  sudo ${KUBECTL_CMD} config set-cluster kubernetes \
    --certificate-authority=${CA_FILE} \
    --embed-certs=true \
    --server=${KUBE_APISERVER} \
    --kubeconfig=${CONFIG_FILE}
  echo "step 1: $?"

  sudo ${KUBECTL_CMD} config set-credentials kubelet \
    --token=${BOOTSTRAP_TOKEN} \
    --kubeconfig=${CONFIG_FILE}
  echo "step 2: $?"

  sudo ${KUBECTL_CMD} config set-context default \
    --cluster="kubernetes" \
    --user="kubelet" \
    --kubeconfig=${CONFIG_FILE}
  echo "step 3: $?"

  sudo ${KUBECTL_CMD} config use-context default \
    --kubeconfig=${CONFIG_FILE}
  echo "step 4: $?"

  echo -e "\n"
}

# Create kube-proxy.kubeconfig
create_proxy()
{
  echo "Create kube-proxy.kubeconfig"

  CONFIG_FILE="/opt/k8s/cert/kube-proxy.kubeconfig"

  sudo rm -f ${CONFIG_FILE}

  sudo ${KUBECTL_CMD} config set-cluster kubernetes \
    --certificate-authority=${CA_FILE} \
    --embed-certs=true \
    --server=${KUBE_APISERVER} \
    --kubeconfig=${CONFIG_FILE}
  echo "step 1: $?"

  sudo ${KUBECTL_CMD} config set-credentials kube-proxy \
    --client-certificate="/opt/ssl/kube-proxy.pem" \
    --client-key="/opt/ssl/kube-proxy-key.pem" \
    --embed-certs=true \
    --kubeconfig=${CONFIG_FILE}
  echo "step 2: $?"

  sudo ${KUBECTL_CMD} config set-context default \
    --cluster="kubernetes" \
    --user="kube-proxy" \
    --kubeconfig=${CONFIG_FILE}
  echo "step 3: $?"

  sudo ${KUBECTL_CMD} config use-context default \
    --kubeconfig=${CONFIG_FILE}
  echo "step 4: $?"

  echo -e "\n"
}

# Create kubelet rbac
create_rbac()
{
  echo "Create kubelet RBAC running in k8s-master..."
  CMD="sudo ${KUBECTL_CMD} create clusterrolebinding kubelet-bootstrap --clusterrole=system:node-bootstrapper --user=kubelet-bootstrap"
  ssh ymliu@k8s-master1 "${CMD}"
  echo "step 1: $?"
}

# ---------------------------------
create_bootstrap
create_kubelet
create_proxy
create_rbac
