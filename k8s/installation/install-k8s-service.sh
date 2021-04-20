#!/usr/bin/env bash

# This script is used for setup k8s+calico all configurations in only one node
#
# FileName     : install-k8s-service-single.sh
# Path         : ~/bin/
# Author       : ymliu
# Create Date  : 2021-04-20 10:31
# WorkFlow     : To clear installation information & setup k8s with calico.
#                per service install on each hosts & startup service.
#
# History      : 2021-04-20 copy from install-k8s-service.sh to be modified

# ------ function declaration ---------------------------------------
# Showing infomation prepared
function show_vars()
{
  echo "-------------------------------------------------------------"
  echo "Show declare environment variables"
  echo "-------------------------------------------------------------"

  echo "MASTERS_INFO=(${MASTERS_INFO[@]})"
  echo "WORKERS_INFO=(${WORKERS_INFO[@]})"
  echo "DEFAULT_VIP=${DEFAULT_VIP}"
  echo ""
  echo "MASTERS=(${MASTERS[@]})"
  echo "WORKERS=(${WORKERS[@]})"
  echo "EXEC_NODE=${EXEC_NODE}"
  echo ""
  echo "APP_DIR=${APP_DIR}"
  echo "SSL_DIR=${SSL_DIR}"
  echo "RPM_DIR=${RPM_DIR}"
  echo "SHELL_DIR=${SHELL_DIR}"
  echo "TEMPLATE_DIR=${TEMPLATE_DIR}"
  echo "TMP_DIR=${TMP_DIR}"
  echo ""
  echo "MASTER_SINGLE_FLAG=${MASTER_SINGLE_FLAG}"
  echo "VIP=${VIP}"
  echo "VIP_PORT=${VIP_PORT}"
  echo ""

  echo "CLUSTER_IP_SEGMENT=${CLUSTER_IP_SEGMENT}.0"
  echo "POD_IP_SEGMENT=${POD_IP_SEGMENT}.0"

  echo "SERVICE_DIR=${SERVICE_DIR}"
  echo "K8S_BASE_DIR=${K8S_BASE_DIR}"
  echo "K8S_BIN_DIR=${K8S_BIN_DIR}"
  echo "K8S_CONF_DIR=${K8S_CONF_DIR}"
  echo "K8S_YAML_DIR=${K8S_YAML_DIR}"
  echo "K8S_TOKEN_DIR=${K8S_TOKEN_DIR}"
  echo ""
  echo "KUBECTL=${KUBECTL}"
  echo "ETCD_VER=${ETCD_VER}"
  echo "DOCKER_HUB=${DOCKER_HUB}"
  echo "NETWORK_CARD=${NETWORK_CARD}"
  echo ""
  echo "ETCD_CLUSTER=${ETCD_CLUSTER}"
  echo "ETCD_ENDPOINTS=${ETCD_ENDPOINTS}"

  echo "------ Ending of show environment variables -----------------"
  echo ""
}

# Clearing all installation, remove services, files, images
function clear_all()
{
  echo "-------------------------------------------------------------"
  echo "Clear all configurations"
  echo "-------------------------------------------------------------"

  # for cleaning all, do not stop pods needed.

  # Stop service
  for SVC in "kube-proxy" "kubelet" "kube-scheduler" "kube-controller-manager" "kube-apiserver" "etcd" "keepalived" "haproxy"; do
    for host in ${WORKERS[@]}; do
      echo -n "Running on ${host}($(hostip ${host})): Removing service ${SVC}..."
      ssh ${USER}@${host} "[ -f ${SERVICE_DIR}/${SVC}.service ] &&
        (sudo systemctl stop ${SVC} >/dev/null 2>&1; \
        sudo systemctl disable ${SVC} >/dev/null 2>&1; \
        sudo rm -f ${SERVICE_DIR}/${SVC}.service;
        sudo rm -f ${K8S_CONF_DIR}/${SVC}.conf)"
      echo "ok"
    done
  done

  # Removing services, files in workers
  local -r BASHRC_FILE="${HOME}/.bashrc"
  for host in ${WORKERS[@]}; do
    echo -n "Running on ${host}($(hostip ${host})): Removing packages, files, declares & aliases ..."
    ssh ${USER}@${host} "sudo yum remove -y haproxy keepalived psmisc bash-completion ipvsadm bridge-utils conntrack \
        lm_sensors-libs net-snmp-agent-libs net-snmp-libs \
        libnetfilter_cthelper libnetfilter_cttimeout libnetfilter_queue >/dev/null 2>&1; \
      docker ps -a | awk 'NR>1{cmd=\"docker stop \"\$1; system(cmd)}' >/dev/null 2>&1; \
      docker ps -a | awk 'NR>1{cmd=\"docker rm -f \"\$1; system(cmd)}' >/dev/null 2>&1; \
      docker images | awk 'NR>1{cmd=\"docker rmi \"\$1\":\"\$2; system(cmd)}' >/dev/null 2>&1; \
      sudo rm -f /etc/sysctl.d/kubernetes.conf /etc/profile.d/{kubernetes.sh,etcd.sh,calico.sh} /etc/haproxy/haproxy.cfg.rpmsave /etc/keepalived/keepalived.conf.rpmsave; \
      sudo rm -fr ${APP_DIR}/{k8s,etcd,haproxy,calico} /opt/{ssl,k8s,cni,calico} /etc/cni; \
      sudo rm -fr /opt/{etcd,etcd-*} /opt/kubernetes /etc/haproxy /opt/keepalived; \
      sudo rm -fr /var/calico; \
      sudo rm -fr ${HOME}/.kube /root/.kube; \
      sed -i \"/^declare -a MASTERS.*$/d\" ${BASHRC_FILE}; \
      sed -i \"/^declare -a NODES.*$/d\" ${BASHRC_FILE}; \
      sed -i \"/^alias masterExec.*$/d\" ${BASHRC_FILE}; \
      sed -i \"/^alias nodeExec.*$/d\" ${BASHRC_FILE}; \
      sed -i \"/kubectl.*$/d\" ${BASHRC_FILE}; \
      sudo sed -i \"/swap / s/#//g\" /etc/fstab"
    echo "ok"
  done

  # if masters are cluster, remove local, not to do if not.
  if [ "${MASTER_SINGLE_FLAG}" == "cluster" ]; then
    echo -n "Running on localhost: Removing packages, files & directories..."
    sudo yum remove -y haproxy keepalived psmisc bash-completion ipvsadm bridge-utils conntrack \
      lm_sensors-libs net-snmp-agent-libs net-snmp-libs \
      libnetfilter_cthelper libnetfilter_cttimeout libnetfilter_queue >/dev/null 2>&1
    sudo rm -fr ${APP_DIR}/{k8s,etcd,haproxy,calico} /opt/{ssl,k8s,cni,calico} /etc/{cni,calico}
    sudo rm -fr /opt/{etcd,etcd-*} /opt/kubernetes
    sudo rm -fr /var/lib/calico
    sudo rm -fr ${HOME}/.kube /root/.kube
    sudo rm -f /etc/sysctl.d/kubernetes.conf /etc/profile.d/{kubernetes.sh,etcd.sh,calico.sh} /etc/haproxy/haproxy.cfg.rpmsave /etc/keepalived/keepalived.conf.rpmsave
    sudo rm -f /etc/systemd/system/{etcd,kube-apiserver,kube-controller-manager,kube-scheduler,kubelet,kube-proxy}.service
    echo "ok"

    echo -n "Running on localhost: Removing declare & alias..."
    sed -i "/^declare -a MASTERS.*$/d" ${BASHRC_FILE}
    sed -i "/^declare -a NODES.*$/d" ${BASHRC_FILE}
    sed -i "/^alias masterExec.*$/d" ${BASHRC_FILE}
    sed -i "/^alias nodeExec.*$/d" ${BASHRC_FILE}
    sed -i "/kubectl.*$/d" ${BASHRC_FILE}
    sudo sed -i "/swap / s/#//g" /etc/fstab
    echo "ok"
  fi

  echo "------ Ending of clear all installations --------------------"
  echo ""
}

function check_pkgs()
{
  echo "-------------------------------------------------------------"
  echo "Checking installation packages..."
  echo "-------------------------------------------------------------"

  check_pkg "conf/kubernetes.conf"
  check_pkg "conf/kubernetes.sh"
  check_pkg "conf/etcd.sh"

  check_pkg "ca/ca-csr.json"
  check_pkg "ca/ca-config.json"

  check_pkg "etcd/etcd-csr.json"
  check_pkg "etcd/etcd.conf"
  check_pkg "etcd/etcd.service"

  check_pkg "haproxy/haproxy.cfg"
  check_pkg "keepalived/keepalived.conf"

  check_pkg "apiserver/kubernetes-csr.json"
  check_pkg "apiserver/admin-csr.json"
  check_pkg "apiserver/metrics-server-csr.json"
  check_pkg "apiserver/bootstrap-token.csv"
  check_pkg "apiserver/basic-auth.csv"
  check_pkg "apiserver/audit-policy-min.yaml"
  check_pkg "apiserver/kube-apiserver.service"
  check_pkg "apiserver/kube-apiserver.conf"

  check_pkg "controller/kube-controller-manager-csr.json"
  check_pkg "controller/kube-controller-manager.service"
  check_pkg "controller/kube-controller-manager.conf"

  check_pkg "scheduler/kube-scheduler-csr.json"
  check_pkg "scheduler/kube-scheduler.service"
  check_pkg "scheduler/kube-scheduler.conf"

  check_pkg "kubelet/kubelet.service"
  check_pkg "kubelet/kubelet.conf"
  check_pkg "kubelet/kubelet.yaml"

  check_pkg "proxy/kube-proxy-csr.json"
  check_pkg "proxy/kube-proxy.service"
  check_pkg "proxy/kube-proxy.conf"
  check_pkg "proxy/kube-proxy.yaml"

  check_pkg "calico/calico.sh"
  check_pkg "calico/10-calico.conf"
  check_pkg "calico/calicoctl.cfg"
  check_pkg "calico/calico.yaml"

  echo "------ Ending of check packages -----------------------------"
  sleep 2s
  echo ""
}

# Initializing environment for installing
function init_env_service()
{
  echo "-------------------------------------------------------------"
  echo "Initializing Environment"
  echo "-------------------------------------------------------------"

  # modify .bashrc
  local -r BASHRC_FILE="${HOME}/.bashrc"
  local SED_PARAM=""

  echo -n "Modifying ${BASHRC_FILE} to add declares, aliases, etc..."
  SED_PARAM="/^# export SYSTEMD_PAGER/adeclare -a MASTERS=(`echo ${MASTERS[@]}`)"
  #sed -i "/^# export SYSTEMD_PAGER/adeclare -a MASTERS=(${MASTERS[@]})" ${BASHRC_FILE}
  sed -i "${SED_PARAM}" ${BASHRC_FILE}

  SED_PARAM="/^declare -a MASTERS/adeclare -a NODES=(`echo ${WORKERS[@]}`)"
  #sed -i "/^declare -a MASTERS/adeclare -a NODES=(${NODES[@]})" ${BASHRC_FILE}
  sed -i "${SED_PARAM}" ${BASHRC_FILE}

  sed -i "/^alias log=.*$/aalias masterExec='_f() { for host in \"\${MASTERS[@]}\";do echo \"Executing in host: \${host}\"; ssh ${USER}@\${host} \"sudo \$@\"; echo ''; done; }; _f'" ${BASHRC_FILE}
  sed -i "/^alias masterExec=.*$/aalias nodeExec='_f() { for host in \"\${NODES[@]}\";do echo \"Executing in host: \${host}\"; ssh ${USER}@\${host} \"sudo \$@\"; echo ''; done; }; _f'" ${BASHRC_FILE}

  echo "ok"

  # create directory(s) on localhost
  echo -n "Running on localhost: Creating directories..."
  sudo mkdir -p ${SSL_DIR} ${K8S_BASE_DIR}/{bin,conf,token,yaml}
  sudo mkdir -p ${APP_DIR}/etcd ${APP_DIR}/k8s/{apiserver,controller,scheduler,kubelet,proxy}
  sudo mkdir -p /opt/cni/bin /opt/calico/{conf,yaml,bin} /etc/cni/net.d/ /etc/calico /var/lib/calico
  sudo chmod 700 ${APP_DIR}/etcd
  echo "ok"

  # distribute .bashrc kubernetes.conf
  echo -n "Building etcd.sh & kubernetes.sh..."
  cp -f ${TEMPLATE_DIR}/conf/{etcd,kubernetes}.sh ${TMP_DIR}
  local -r ETCD_CONN=$(build_etcd_clientConnectString)
  sed -i "s#\${ETCD_CONN}#\"${ETCD_CONN}\"#g" ${TMP_DIR}/etcd.sh
  sed -i "s#\${K8S_BASE_DIR}#${K8S_BASE_DIR}#g" ${TMP_DIR}/kubernetes.sh
  echo "ok"

  echo "Building kubernetes.conf, same as template/conf/kubernetes.conf."

  echo -n "Running on localhost: Copying profile files from template..."
  sudo cp -f ${TMP_DIR}/{kubernetes,etcd}.sh /etc/profile.d/
  sudo cp -f ${TEMPLATE_DIR}/conf/kubernetes.conf /etc/sysctl.d/
  sudo chown root:root /etc/profile.d/{kubernetes,etcd}.sh /etc/sysctl.d/kubernetes.conf
  sudo sysctl -p /etc/sysctl.d/kubernetes.conf >/dev/null 2>&1
  echo "ok"

  # if masters are cluster, distribute to all workers
  if [ ${MASTER_SINGLE_FLAG} == "cluster" ]; then
    for host in ${WORKERS[@]}; do
      echo -n "Running on ${host}($(hostip ${host})): Initializing environment..."
      ssh ${USER}@${host} "sudo mkdir -p ${SSL_DIR} ${K8S_BASE_DIR}/{bin,conf,token,yaml} >/dev/null 2>&1; \
        sudo mkdir -p ${APP_DIR}/etcd ${APP_DIR}/k8s/{apiserver,controller,scheduler,kubelet,proxy} >/dev/null 2>&1; \
        sudo mkdir -p /opt/cni/bin /opt/calico/{conf,yaml,bin} /etc/cni/net.d /etc/calico /var/lib/calico >/dev/null 2>&1; \
        sudo chmod 700 ${APP_DIR}/etcd"

      scp ${BASHRC_FILE} \
        ${TEMPLATE_DIR}/conf/kubernetes.conf \
        ${TMP_DIR}/{kubernetes,etcd}.sh \
        ${USER}@${host}:${TMP_DIR} >/dev/null 2>&1

      ssh ${USER}@${host} "cp -f ${TMP_DIR}/.bashrc ${BASHRC_FILE}; \
        sudo chown root:root ${TMP_DIR}/kubernetes.conf ${TMP_DIR}/kubernetes.sh ${TMP_DIR}/etcd.sh; \
        sudo cp -f ${TMP_DIR}/kubernetes.conf /etc/sysctl.d/; \
        sudo cp -f ${TMP_DIR}/kubernetes.sh ${TMP_DIR}/etcd.sh /etc/profile.d/; \
        sudo sed -i '/swap / s/^\(.*\)$/#\1/g' /etc/fstab; \
        sudo sysctl -p /etc/sysctl.d/kubernetes.conf >/dev/null 2>&1"
      echo "ok"
    done
  fi

  echo "------ Ending of initialize environment ---------------------"
  echo ""
}

function create_ca()
{
  # 1. copy cfssl
  echo "-------------------------------------------------------------"
  echo "Creating CA files..."
  echo "-------------------------------------------------------------"

  echo -n "Running on localhost: Copying cfssl packages..."
  local -r SOURCE_DIR="/mnt/rw/cfssl"
  local -ra CFSSL_FILES=("cfssl" "cfssl-certinfo" "cfssljson")
  for file in ${CFSSL_FILES[@]}; do
    sudo cp -f "${SOURCE_DIR}/${file}_linux-amd64" "${SSL_DIR}/${file}"
  done
  echo "ok"

  # ca
  echo -n "Creating CA cert & key files..."
  sudo cp -f "${TEMPLATE_DIR}/ca/ca-config.json" "${TEMPLATE_DIR}/ca/ca-csr.json" ${SSL_DIR}
  sudo chown root:root ${SSL_DIR}/ca-config.json ${SSL_DIR}/ca-csr.json
  pushd ${SSL_DIR} >/dev/null 2>&1
  (sudo ./cfssl gencert -initca ca-csr.json | sudo ./cfssljson -bare ca) >/dev/null 2>&1
  popd >/dev/null 2>&1
  echo "ok"

  if [ ${MASTER_SINGLE_FLAG} == "cluster" ]; then
    # distribute certification files
    sudo chmod 644 ${SSL_DIR}/ca-key.pem
    for host in ${WORKERS[@]}; do
      echo -n "Running on ${host}($(hostip ${host})): Copying ca files..."
      scp ${SSL_DIR}/ca*.pem ${USER}@${host}:${TMP_DIR} >/dev/null 2>&1
      ssh ${USER}@${host} "sudo chown root:root ${TMP_DIR}/ca*.pem; \
        sudo cp -f ${TMP_DIR}/ca*.pem ${SSL_DIR}; \
        sudo chmod 600 ${SSL_DIR}/ca-key.pem"
      echo "ok"
    done
    sudo chmod 600 ${SSL_DIR}/ca-key.pem
  fi

  echo "------ Ending of create ca ----------------------------------"
  echo ""
}

# ------ Deploying etcd service -------------------------------------
function deploy_etcd()
{
  echo "-------------------------------------------------------------"
  echo "Deploying etcd service..."
  echo "-------------------------------------------------------------"

  # creating etcd cert & key files
  echo -n "Creating cert & key files..."
  local -r TMP_CSRFILE=${TMP_DIR}/etcd-csr.json
  sudo cp -f ${TEMPLATE_DIR}/etcd/etcd-csr.json ${TMP_CSRFILE}
  for host in ${MASTERS[@]}; do
    sudo sed -i "/\"\${ip list}\"/i \ \ \ \ \ \ \ \ \"$(hostip ${host})\" ," ${TMP_CSRFILE}
    sudo sed -i "/\"\${hostname list}\"/i \ \ \ \ \ \ \ \ \"${host}\" ," ${TMP_CSRFILE}
  done
  sudo sed -i "/\"\${ip list}\"/d;/\"\${hostname list}\"/d" ${TMP_CSRFILE}

  sudo cp -f ${TMP_CSRFILE} ${SSL_DIR}
  sudo chown root:root ${SSL_DIR}/etcd-csr.json
  pushd ${SSL_DIR} >/dev/null 2>&1
  (sudo ./cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes etcd-csr.json | sudo ./cfssljson -bare etcd) >/dev/null 2>&1
  popd >/dev/null 2>&1
  echo "ok"

  if [ ${MASTER_SINGLE_FLAG} == "cluster" ]; then
    # distribute cert & key files to all workers, because calico running on workers need them to connect
    sudo chmod 644 ${SSL_DIR}/etcd-key.pem
    for host in ${WORKERS[@]}; do
      echo -n "Running on ${host}($(hostip ${host})): Copying etcd cert & key files..."
      scp ${SSL_DIR}/etcd*.pem ${USER}@${host}:${TMP_DIR} >/dev/null 2>&1
      ssh ${USER}@${host} "sudo chown root:root ${TMP_DIR}/etcd*.pem; \
        sudo cp -f ${TMP_DIR}/etcd*.pem ${SSL_DIR}; \
        sudo chmod 600 ${SSL_DIR}/etcd-key.pem"
      echo "ok"
    done
    sudo chmod 600 ${SSL_DIR}/etcd-key.pem
  fi

  # buiding
  echo -n "Building etcd service & conf files..."
  cp -f ${TEMPLATE_DIR}/etcd/etcd.service ${TMP_DIR}
  sed -i "s#\${APP_DIR}#${APP_DIR}#g" ${TMP_DIR}/etcd.service
  sed -i "s#\${K8S_CONF_DIR}#${K8S_CONF_DIR}#g" ${TMP_DIR}/etcd.service
  sed -i "s#\${K8S_BIN_DIR}#${K8S_BIN_DIR}#g" ${TMP_DIR}/etcd.service

  cp -f ${TEMPLATE_DIR}/etcd/etcd.conf ${TMP_DIR}
  sed -i "s#\${APP_DIR}#${APP_DIR}\/etcd#g" ${TMP_DIR}/etcd.conf; \
  sed -i "s#\${ETCD_CLUSTER}#${ETCD_CLUSTER}#g" ${TMP_DIR}/etcd.conf; \
  sed -i "s#\${SSL_DIR}#${SSL_DIR}#g" ${TMP_DIR}/etcd.conf; \
  echo "ok"

  # copy etcd ssl & service files
  # and
  # extract etcd packages
  local -r ETCD_SRC_DIR="/mnt/rw/k8s"
  local -r ETCD_DEST_DIR="etcd-v${ETCD_VER}-linux-amd64"
  local -r ETCD_PKG="${ETCD_DEST_DIR}.tar.gz"

  for host in ${MASTERS[@]}; do
    echo -n "Running on ${host}($(hostip ${host})): Copying etcd ssl & service files, extracting etcd packages..."
    scp ${TMP_DIR}/etcd.{service,conf} ${USER}@${host}:${TMP_DIR} >/dev/null 2>&1
    ssh ${USER}@${host} "
      sed -i \"s#\\\${hostname}#${host}#g\" ${TMP_DIR}/etcd.conf; \
      sed -i \"s#\\\${ip}#$(hostip ${host})#g\" ${TMP_DIR}/etcd.conf; \

      sudo chown root:root ${TMP_DIR}/etcd.{conf,service}; \
      sudo cp -f ${TMP_DIR}/etcd.conf ${K8S_CONF_DIR}; \
      sudo cp -f ${TMP_DIR}/etcd.service ${SERVICE_DIR}; \

      sudo tar -xzf ${ETCD_SRC_DIR}/${ETCD_PKG} -C /opt/; \
      sudo chown root:root /opt/${ETCD_DEST_DIR}; \
      sudo ln -sf /opt/${ETCD_DEST_DIR} /opt/etcd; \
      sudo ln -sf /opt/etcd/etcd /opt/etcd/etcdctl ${K8S_BIN_DIR}"
    echo "ok"
  done

  # start etcd service
  for host in ${MASTERS[@]}; do
    echo -n "Running on ${host}($(hostip ${host})): Starting etcd service..."
    ssh ${USER}@${host} "sudo systemctl daemon-reload; \
      sudo systemctl enable etcd >/dev/null 2>&1; \
      nohup sudo systemctl start etcd >/dev/null 2>&1 &"
    echo "ok"
  done

  echo ""
  echo "------ Ending of deploy etcd --------------------------------"
  sleep 2s
  echo ""
}

# ------ deploy HA (haproxy + keepalived) ---------------------------
function deploy_ha()
{
  echo "-------------------------------------------------------------"
  echo "Deploying haproxy & keepalived..."
  echo "-------------------------------------------------------------"

  # modify haproxy.cfg
  echo -n "Building haproxy.cfg..."
  local -r HAPROXY_CFG="${TMP_DIR}/haproxy.cfg"
  cp -f ${TEMPLATE_DIR}/haproxy/haproxy.cfg ${HAPROXY_CFG}
  sed -i "s#\${APP_DIR}#${APP_DIR}\/haproxy#g" ${HAPROXY_CFG}
  for host in ${MASTERS[@]}; do
    sed -i "/\${server list}$/a \ \ \ \ server  ${host}  $(hostip ${host}):6443  check  inter  2000  fall 2  rise 2 weight 1" ${HAPROXY_CFG}
  done
  sed -i "/\${server list}$/d" ${HAPROXY_CFG}
  echo "ok"

  local -r KEEPALIVED_CONF="${TMP_DIR}/keepalived.conf"
  for host in ${MASTERS[@]}; do
    echo -n "Running on ${host}($(hostip ${host})): Install haproxy & keepalived packages, copying conf files..."
    scp ${HAPROXY_CFG} ${TEMPLATE_DIR}/keepalived/keepalived.conf ${USER}@${host}:${TMP_DIR} >/dev/null 2>&1
    ssh ${USER}@${host} "sudo yum install -y ${RPM_DIR}/haproxy-1.5.18-9.el7.x86_64.rpm \
        ${RPM_DIR}/keepalived-1.3.5-16.el7.x86_64.rpm \
        ${RPM_DIR}/psmisc-22.20-16.el7.x86_64.rpm \
        ${RPM_DIR}/lm_sensors-libs-3.4.0-8.20160601gitf9185e5.el7.x86_64.rpm \
        ${RPM_DIR}/net-snmp-agent-libs-5.7.2-48.el7_8.1.x86_64.rpm \
        ${RPM_DIR}/net-snmp-libs-5.7.2-48.el7_8.1.x86_64.rpm >/dev/null 2>&1; \
      sudo mkdir -p ${APP_DIR}/haproxy; \
      sudo chown -R haproxy:haproxy ${APP_DIR}/haproxy"

    # modify keepalived by master/backup
    if [ "${host}" == "${MASTERS[0]}" ]; then
      # master node
      ssh ${USER}@${host} "sed -i \"s#\\\${MASTER}#MASTER#g\" ${KEEPALIVED_CONF}; \
        sed -i \"s#\\\${priority}#120#g\" ${KEEPALIVED_CONF}; \
        sed -i \"s#\\\${VIP}#${VIP}#g\" ${KEEPALIVED_CONF}; \
        sed -i \"s#\\\${NETWORK_CARD}#${NETWORK_CARD}#g\" ${KEEPALIVED_CONF}"
    else
      # backup node
      ssh ${USER}@${host} "sed -i \"s#\\\${MASTER}#BACKUP#g\" ${KEEPALIVED_CONF}; \
        sed -i \"s#\\\${priority}#110#g\" ${KEEPALIVED_CONF}; \
        sed -i \"s#\\\${VIP}#${VIP}#g\" ${KEEPALIVED_CONF}; \
        sed -i \"s#\\\${NETWORK_CARD}#${NETWORK_CARD}#g\" ${KEEPALIVED_CONF}"
    fi
    echo "ok"
  done

  for host in ${MASTERS[@]}; do
    # move file, start haproxy & keepalived service
    echo -n "Running on ${host}($(hostip ${host})): Starting haproxy & keepalived service..."
    ssh ${USER}@${host} "sudo chown root:root ${HAPROXY_CFG} ${KEEPALIVED_CONF} >/dev/null 2>&1; \
      sudo cp -f ${HAPROXY_CFG} /etc/haproxy/; \
      sudo cp -f ${KEEPALIVED_CONF} /etc/keepalived/; \
      sudo systemctl daemon-reload; \
      sudo systemctl enable haproxy keepalived >/dev/null 2>&1; \
      sudo systemctl restart haproxy keepalived"
    echo "ok"
  done

  echo "------ Ending of deploy haproxy & keepalived ----------------"
  sleep 2s
  echo ""
}

# ------ deploy kubernetes components -------------------------------
function deploy_kubernetes()
{
  echo "-------------------------------------------------------------"
  echo "Deploying all kubernetes components."
  echo "-------------------------------------------------------------"
  echo ""

  install_k8s_files

  config_autoComplete

  deploy_k8s_apiServer

  build_default_kubeconfig

  deploy_k8s_controller

  deploy_k8s_scheduler

  config_k8s_workers

  deploy_k8s_kubelet

  deploy_k8s_proxy

  deploy_calico
}

function install_k8s_files()
{
  echo "-------------------------------------------------------------"
  echo "Installing kubernetes packages..."

  local -r K8S_SRC_DIR="/mnt/rw/k8s"

  # localhost is operator node for cluster, it needs packages. single master not need.
  if [ ${MASTER_SINGLE_FLAG} == "cluster" ]; then
    echo -n "Running on localhost: Installing kubernetes packages..."
    sudo tar -xzf ${K8S_SRC_DIR}/kubernetes-server-linux-amd64.tar.gz -C /opt/
    sudo ln -sf /opt/kubernetes/server/bin/{kube-apiserver,kube-controller-manager,kube-scheduler,kubelet,kubectl,kubeadm,kube-proxy,apiextensions-apiserver,mounter} ${K8S_BIN_DIR}
    echo "ok"
  fi

  for host in ${WORKERS[@]}; do
    echo -n "Running on ${host}($(hostip ${host})): Installing kubernetes packages..."
    ssh ${USER}@${host} "sudo tar -xzf ${K8S_SRC_DIR}/kubernetes-server-linux-amd64.tar.gz -C /opt/; \
      sudo ln -sf /opt/kubernetes/server/bin/{kube-apiserver,kube-controller-manager,kube-scheduler,kubelet,kubectl,kubeadm,kube-proxy,apiextensions-apiserver,mounter} ${K8S_BIN_DIR}"
    echo "ok"
  done

  echo "------ Ending of install kubernetes packages ----------------"
  echo ""
}

function config_autoComplete()
{
  echo "-------------------------------------------------------------"
  echo "Configuration autoCompletion..."

  # localhost is operator node for cluster.
  if [ ${MASTER_SINGLE_FLAG} == "cluster" ]; then
    echo -n "Running on localhost: Config autoCompletion..."
    sudo yum install -y ${RPM_DIR}/bash-completion-2.1-8.el7.noarch.rpm >/dev/null 2>&1
    source /usr/share/bash-completion/bash_completion
    source <(${KUBECTL} completion bash)
    echo "# kubectl auto-compelete" >> ${HOME}/.bashrc
    echo "source <(${KUBECTL} completion bash)" >> ${HOME}/.bashrc
    echo "ok"
  fi

  for host in ${WORKERS[@]}
  do
    echo -n "Running on ${host}($(hostip ${host})): Config autoCompletion...."
    ssh ${USER}@${host} "sudo yum install -y ${RPM_DIR}/bash-completion-2.1-8.el7.noarch.rpm >/dev/null 2>&1; \
      echo \"# kubectl auto-compelete\" >> ${HOME}/.bashrc; \
      echo \"source <(kubectl completion bash)\" >> ${HOME}/.bashrc"
    echo "ok"
  done

  echo "------ Ending of config autoCompletion ----------------------"
  echo ""
}

function deploy_k8s_apiServer()
{
  echo "-------------------------------------------------------------"
  echo "Deploying kubernetes apiServer..."
  #
  # Here, deploying kube-apiserver dose contain metrics-server configurations,
  # such as configuration in service & conf file. But not include metrics-server cert & key files.
  #

  pushd ${SSL_DIR} >/dev/null 2>&1
  # kubernetes key & cert files
  echo -n "Building kubernetes cert & key files..."
  local TMP_CSRFILE="${TMP_DIR}/kubernetes-csr.json"
  local CSR_FILE="${SSL_DIR}/kubernetes-csr.json"
  cp -f "${TEMPLATE_DIR}/apiserver/kubernetes-csr.json" ${TMP_CSRFILE}

  for host in ${WORKERS[@]}; do
    sed -i "/\${host ips}/i \ \ \ \ \"$(hostip ${host})\"," ${TMP_CSRFILE}
  done
  sed -i "/\${host ips}/d" ${TMP_CSRFILE}
  sed -i "s#\${host vip}#${VIP}#g" ${TMP_CSRFILE}
  sed -i "s#\${cluster ip}#${CLUSTER_IP_SEGMENT}.1#g" ${TMP_CSRFILE}

  sudo cp -f ${TMP_CSRFILE} ${SSL_DIR}
  sudo chown root:root ${CSR_FILE}
  (sudo ./cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kubernetes-csr.json | sudo ./cfssljson -bare kubernetes) >/dev/null 2>&1
  echo "ok"

  # admin cert & key files
  echo -n "Building admin key & cert files..."
  CSR_FILE="${SSL_DIR}/admin-csr.json"
  sudo cp -f "${TEMPLATE_DIR}/apiserver/admin-csr.json" ${CSR_FILE}
  sudo chown root:root ${CSR_FILE}
  (sudo ./cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | sudo ./cfssljson -bare admin) >/dev/null 2>&1
  echo "ok"

  # building metrics-server cert & key files
  echo -n "Building metrics-server cert & key files..."
  sudo cp -f ${TEMPLATE_DIR}/apiserver/metrics-server-csr.json ${SSL_DIR}
  sudo chown root:root ${SSL_DIR}/metrics-server-csr.json
  (sudo ./cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes metrics-server-csr.json | sudo ./cfssljson -bare metrics-server) >/dev/null 2>&1
  echo "ok"
  popd >/dev/null 2>&1

  # token
  echo -n "Building bootstrap-token.csv file..."
  cp -f ${TEMPLATE_DIR}/apiserver/bootstrap-token.csv ${TMP_DIR}
  local -r TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
  sed -i "s#\${TOKEN}#${TOKEN}#g" ${TMP_DIR}/bootstrap-token.csv ${TMP_DIR}/bootstrap-token.csv
  # need to save on local, used to build kubeconfig in the future.
  sudo cp -f ${TMP_DIR}/bootstrap-token.csv ${K8S_CONF_DIR}
  sudo chown root:root ${K8S_CONF_DIR}/bootstrap-token.csv
  echo "ok"

  # basic-auth.csv
  # copy from ${TEMPLATE_DIR}/apiserver/basic-auth.csv, not modify needed.
  echo "building basic-auth.csv, same as template/apiserver/basic-auth.csv ."

  # distribute upon files, only master nodes
  sudo chmod +r ${SSL_DIR}/{kubernetes,admin,metrics-server}-key.pem
  for host in ${MASTERS[@]}; do
    echo -n "Running on ${host}($(hostip ${host})): Copying kubernetes, admin and metrics-server's cert & key files, token & auth csv files..."
    scp ${SSL_DIR}/{kubernetes,admin,metrics-server}*.pem \
      ${TMP_DIR}/bootstrap-token.csv \
      ${TEMPLATE_DIR}/apiserver/basic-auth.csv \
      ${USER}@${host}:${TMP_DIR} >/dev/null 2>&1
    ssh ${USER}@${host} "sudo chown root:root ${TMP_DIR}/{kubernetes,admin,metrics-server}*.pem \
        ${TMP_DIR}/bootstrap-token.csv \
        ${TMP_DIR}/basic-auth.csv; \
      sudo cp -f ${TMP_DIR}/{kubernetes,admin,metrics-server}*.pem ${SSL_DIR}/; \
      sudo chmod 600 ${SSL_DIR}/{kubernetes,admin,metrics-server}-key.pem; \
      sudo cp -f ${TMP_DIR}/bootstrap-token.csv ${TMP_DIR}/basic-auth.csv ${K8S_TOKEN_DIR}"
    echo "ok"
  done
  sudo chmod 600 ${SSL_DIR}/{kubernetes,admin,metrics-server}-key.pem

  # audit-policy.yaml
  # copy from ${TEMPLATE_DIR}/apiserver/audit-policy-min.yaml, not modify needed.
  echo "Building audit-policy-min.yaml, same as template/apiserver/audit-policy-min.yaml ."

  # building kube-apiserver.service
  # some properties, such hostip, to be modified on each host.
  echo -n "Building kube-apiserver service conf & service files..."
  cp -f ${TEMPLATE_DIR}/apiserver/kube-apiserver.{service,conf} ${TMP_DIR}
  sed -i "s#\${K8S_CONF_DIR}#${K8S_CONF_DIR}#g" ${TMP_DIR}/kube-apiserver.service
  sed -i "s#\${K8S_BIN_DIR}#${K8S_BIN_DIR}#g" ${TMP_DIR}/kube-apiserver.service
  sed -i "s#\${ETCD_ENDPOINTS}#${ETCD_ENDPOINTS}#g" ${TMP_DIR}/kube-apiserver.conf
  sed -i "s#\${CLUSTER_IP_SEGMENT}#${CLUSTER_IP_SEGMENT}#g" ${TMP_DIR}/kube-apiserver.conf
  sed -i "s#\${SSL_DIR}#${SSL_DIR}#g" ${TMP_DIR}/kube-apiserver.conf
  sed -i "s#\${APP_DIR}#${APP_DIR}#g" ${TMP_DIR}/kube-apiserver.conf
  sed -i "s#\${K8S_YAML_DIR}#${K8S_YAML_DIR}#g" ${TMP_DIR}/kube-apiserver.conf
  sed -i "s#\${K8S_TOKEN_DIR}#${K8S_TOKEN_DIR}#g" ${TMP_DIR}/kube-apiserver.conf
  echo "ok"

  # apiserver conf & service file
  for host in ${MASTERS[@]}; do
    echo -n "Running on ${host}($(hostip ${host})): Copying kube-apiserver service & conf files..."
    scp ${TEMPLATE_DIR}/apiserver/audit-policy-min.yaml ${TMP_DIR}/kube-apiserver.{service,conf} ${USER}@${host}:${TMP_DIR} >/dev/null 2>&1
    ssh ${USER}@${host} "sed -i \"s#\\\${hostip}#$(hostip ${host})#g\" ${TMP_DIR}/kube-apiserver.conf; \
      sudo chown root:root ${TMP_DIR}/kube-apiserver.{service,conf} ${TMP_DIR}/audit-policy-min.yaml; \
      sudo cp -f ${TMP_DIR}/kube-apiserver.service ${SERVICE_DIR}; \
      sudo cp -f ${TMP_DIR}/kube-apiserver.conf ${K8S_CONF_DIR}; \
      sudo cp -f ${TMP_DIR}/audit-policy-min.yaml ${K8S_YAML_DIR}; \
      sudo systemctl daemon-reload; \
      sudo systemctl enable kube-apiserver >/dev/null 2>&1; \
      nohup sudo systemctl start kube-apiserver >/dev/null 2>&1 &"
    echo "ok"
  done

  echo ""
  echo "------ Ending of deploying kube-apiserver -------------------"
  sleep 2s
  echo ""
}

function build_default_kubeconfig()
{
  echo "-------------------------------------------------------------"
  echo "Building kubectl default kubeconfig..."

  echo -n "Building kubectl default kubeconfig file..."
  local -r KUBECONFIG="${HOME}/.kube/config"
  mkdir -p ${HOME}/.kube
  sudo ${KUBECTL} config set-cluster kubernetes --certificate-authority=${SSL_DIR}/ca.pem --embed-certs=true --server=https://${VIP}:${VIP_PORT} --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  sudo ${KUBECTL} config set-credentials admin --client-certificate=${SSL_DIR}/admin.pem --client-key=${SSL_DIR}/admin-key.pem --embed-certs=true --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  sudo ${KUBECTL} config set-context kubernetes --cluster=kubernetes --user=admin --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  sudo ${KUBECTL} config use-context kubernetes --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  sudo chown ${USER}:${USER} ${KUBECONFIG}

  sudo mkdir -p /root/.kube
  sudo cp -f ${KUBECONFIG} /root/.kube/
  sudo chown root:root /root/.kube/config
  echo "ok"

  if [ ${MASTER_SINGLE_FLAG} == "cluster" ]; then
    for host in ${WORKERS[@]}; do
      echo -n "Running on ${host}($(hostip ${host})): Copying kubectl kubeconfig file..."
      scp ${KUBECONFIG} ${USER}@${host}:${TMP_DIR} >/dev/null 2>&1
      ssh ${USER}@${host} "mkdir -p ${HOME}/.kube; \
        cp -f ${TMP_DIR}/config ${HOME}/.kube/; \
        sudo mkdir -p /root/.kube; \
        sudo cp -f ${TMP_DIR}/config /root/.kube/; \
        sudo chown root:root /root/.kube/config"
      echo "ok"
    done
  fi

  echo ""
  echo -n "Grant to visit kubelet api..."
  sudo ${KUBECTL} create clusterrolebinding kube-apiserver:kubelet-apis --clusterrole=system:kubelet-api-admin --user=kubernetes

  echo ""
  echo "------ Ending of build kubectl default kubeconfig -----------"
  echo ""
}

function deploy_k8s_controller()
{
  echo "-------------------------------------------------------------"
  echo "Deploying kubernetes kube-controller-manager..."

  # kube-controller-manager key & cert files
  echo -n "Building controller-manager cert & key files..."
  local -r TMP_CSRFILE="${TMP_DIR}/kube-controller-manager-csr.json"
  local -r CSR_FILE="${SSL_DIR}/kube-controller-manager-csr.json"
  cp -f ${TEMPLATE_DIR}/controller/kube-controller-manager-csr.json ${TMP_CSRFILE}

  for host in ${MASTERS[@]}; do
    sed -i "/\${master ip list}/i \ \ \ \ \"$(hostip ${host})\"," ${TMP_CSRFILE}
  done
  sed -i "/\${master ip list}/d" ${TMP_CSRFILE}

  sudo cp -f ${TMP_CSRFILE} ${CSR_FILE}
  sudo chown root:root ${CSR_FILE}
  pushd ${SSL_DIR} >/dev/null 2>&1
  (sudo ./cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-controller-manager-csr.json | sudo ./cfssljson -bare kube-controller-manager) >/dev/null 2>&1
  popd >/dev/null 2>&1
  echo "ok"

  # building kube-controller-manager kubeconfig
  echo -n "Building kube-controller-manager kubeconfig..."
  local -r KUBECONFIG="${K8S_CONF_DIR}/kube-controller-manager.kubeconfig"
  sudo ${KUBECTL} config set-cluster kubernetes --certificate-authority=${SSL_DIR}/ca.pem --embed-certs=true --server=https://${VIP}:${VIP_PORT} --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  sudo ${KUBECTL} config set-credentials system:kube-controller-manager --client-certificate=${SSL_DIR}/kube-controller-manager.pem --client-key=${SSL_DIR}/kube-controller-manager-key.pem --embed-certs=true --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  sudo ${KUBECTL} config set-context system:kube-controller-manager --cluster=kubernetes --user=system:kube-controller-manager --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  sudo ${KUBECTL} config use-context system:kube-controller-manager --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  echo "ok"

  # building kube-controller-manager.service
  # same as template/controller/kube-controller-manager.service
  echo -n "Building kube-controller-manager conf & service files..."
  cp -f ${TEMPLATE_DIR}/controller/kube-controller-manager.{service,conf} ${TMP_DIR}
  sed -i "s#\${K8S_CONF_DIR}#${K8S_CONF_DIR}#g" ${TMP_DIR}/kube-controller-manager.service
  sed -i "s#\${K8S_BIN_DIR}#${K8S_BIN_DIR}#g" ${TMP_DIR}/kube-controller-manager.service
  sed -i "s#\${KUBECONFIG}#${KUBECONFIG}#g" ${TMP_DIR}/kube-controller-manager.conf
  sed -i "s#\${SSL_DIR}#${SSL_DIR}#g" ${TMP_DIR}/kube-controller-manager.conf
  sed -i "s#\${CLUSTER_IP_SEGMENT}#${CLUSTER_IP_SEGMENT}#g" ${TMP_DIR}/kube-controller-manager.conf
  sed -i "s#\${POD_IP_SEGMENT}#${POD_IP_SEGMENT}#g" ${TMP_DIR}/kube-controller-manager.conf
  sed -i "s#\${APP_DIR}#${APP_DIR}#g" ${TMP_DIR}/kube-controller-manager.conf
  echo "ok"

  # distribute files & start service
  sudo chmod +r ${KUBECONFIG} ${SSL_DIR}/kube-controller-manager-key.pem
  for host in ${MASTERS[@]}; do
    echo -n "Running on ${host}($(hostip ${host})): Copying kube-controller-manager files & starting service..."
    scp ${SSL_DIR}/kube-controller-manager*.pem \
      ${KUBECONFIG} \
      ${TMP_DIR}/kube-controller-manager.{service,conf} \
      ${USER}@${host}:${TMP_DIR} >/dev/null 2>&1

    ssh ${USER}@${host} "sudo chown root:root ${TMP_DIR}/kube-controller-manager*.pem ${TMP_DIR}/kube-controller-manager.{kubeconfig,conf,service}; \
      sudo cp -f ${TMP_DIR}/kube-controller-manager.{kubeconfig,conf} ${K8S_CONF_DIR}; \
      sudo cp -f ${TMP_DIR}/kube-controller-manager.service ${SERVICE_DIR}; \
      sudo cp -f ${TMP_DIR}/kube-controller-manager*.pem ${SSL_DIR}; \
      sudo chmod 600 ${SSL_DIR}/kube-controller-manager-key.pem ${K8S_CONF_DIR}/kube-controller-manager.kubeconfig; \
      sudo systemctl daemon-reload; \
      sudo systemctl enable kube-controller-manager >/dev/null 2>&1; \
      nohup sudo systemctl start kube-controller-manager >/dev/null 2>&1 &"
    echo "ok"
  done
  sudo chmod 600 ${KUBECONFIG} ${SSL_DIR}/kube-controller-manager-key.pem

  echo ""
  echo "------ Ending  of deploying kube-controller-manager ---------"
  echo ""
  sleep 2s
}

function deploy_k8s_scheduler()
{
  echo "-------------------------------------------------------------"
  echo "Deploying kubernetes kube-scheduler..."

  # cert & key file
  echo -n "Building kube-scheduler cert & key files..."
  local -r TMP_CSRFILE=${TMP_DIR}/kube-scheduler-csr.json
  local -r CSR_FILE=${SSL_DIR}/kube-scheduler-csr.json

  cp -f ${TEMPLATE_DIR}/scheduler/kube-scheduler-csr.json ${TMP_CSRFILE}
  for host in ${MASTERS[@]}; do
    sed -i "/\${master ip list}/i \ \ \ \ \"$(hostip ${host})\"," ${TMP_CSRFILE}
  done
  sed -i "/\${master ip list}/d" ${TMP_CSRFILE}

  sudo cp -f ${TMP_CSRFILE} ${CSR_FILE}
  sudo chown root:root ${CSR_FILE}
  pushd ${SSL_DIR} >/dev/null 2>&1
  (sudo ./cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-scheduler-csr.json | sudo ./cfssljson -bare kube-scheduler) >/dev/null 2>&1
  popd >/dev/null 2>&1
  echo "ok"

  # builder kubeconfig
  echo -n "Building kube-scheduler kubeconfig file..."
  local -r KUBECONFIG="${K8S_CONF_DIR}/kube-scheduler.kubeconfig"
  sudo ${KUBECTL} config set-cluster kubernetes --certificate-authority=${SSL_DIR}/ca.pem --embed-certs=true --server=https://${VIP}:${VIP_PORT} --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  sudo ${KUBECTL} config set-credentials system:kube-scheduler --client-certificate=${SSL_DIR}/kube-scheduler.pem --client-key=${SSL_DIR}/kube-scheduler-key.pem --embed-certs=true --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  sudo ${KUBECTL} config set-context system:kube-scheduler --cluster=kubernetes --user=system:kube-scheduler --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  sudo ${KUBECTL} config use-context system:kube-scheduler --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  echo "ok"

  # builder service & conf file

  echo -n "Building kube-scheduler service & conf file..."
  cp -f ${TEMPLATE_DIR}/scheduler/kube-scheduler.{service,conf} ${TMP_DIR}
  sed -i "s#\${K8S_CONF_DIR}#${K8S_CONF_DIR}#g" ${TMP_DIR}/kube-scheduler.service
  sed -i "s#\${K8S_BIN_DIR}#${K8S_BIN_DIR}#g" ${TMP_DIR}/kube-scheduler.service
  sed -i "s#\${K8S_CONF_DIR}#${K8S_CONF_DIR}#g" ${TMP_DIR}/kube-scheduler.conf
  sed -i "s#\${APP_DIR}#${APP_DIR}#g" ${TMP_DIR}/kube-scheduler.conf
  echo "ok"

  # distribute & start service
  sudo chmod +r ${SSL_DIR}/kube-scheduler-key.pem ${KUBECONFIG}
  for host in ${MASTERS[@]}; do
    echo -n "Running on ${host}($(hostip ${host})): Copying kube-scheduler cert, key, service files & Starting service..."
    scp ${SSL_DIR}/kube-scheduler*.pem \
      ${KUBECONFIG} \
      ${TMP_DIR}/kube-scheduler.{service,conf} \
      ${USER}@${host}:${TMP_DIR} >/dev/null 2>&1

    ssh ${USER}@${host} "sudo chown root:root ${TMP_DIR}/kube-scheduler*.pem ${TMP_DIR}/kube-scheduler.{kubeconfig,service,conf}; \
      sudo cp -f ${TMP_DIR}/kube-scheduler.{kubeconfig,conf} ${K8S_CONF_DIR}; \
      sudo cp -f ${TMP_DIR}/kube-scheduler.service ${SERVICE_DIR}; \
      sudo cp -f ${TMP_DIR}/kube-scheduler*.pem ${SSL_DIR}; \
      sudo chmod 600 ${SSL_DIR}/kube-scheduler-key.pem ${K8S_CONF_DIR}/kube-scheduler.kubeconfig; \
      sudo systemctl daemon-reload; \
      sudo systemctl enable kube-scheduler >/dev/null 2>&1; \
      nohup sudo systemctl start kube-scheduler >/dev/null 2>&1 &"
    echo "ok"
  done
  sudo chmod 600 ${SSL_DIR}/kube-scheduler-key.pem ${KUBECONFIG}

  echo ""
  echo "------ Ending of deploying kube-scheduler -------------------"
  echo ""
  sleep 2s
}

function config_k8s_workers()
{
  echo "-------------------------------------------------------------"
  echo "Config kubernetes workers ..."

  # generating kube-proxy cert & key file
  echo -n "Building kube-proxy cert & key files..."
  local -r CSR_FILE=${SSL_DIR}/kube-proxy-csr.json
  sudo cp -f ${TEMPLATE_DIR}/proxy/kube-proxy-csr.json ${CSR_FILE}
  sudo chown root:root ${CSR_FILE}
  pushd ${SSL_DIR} >/dev/null 2>&1
  (sudo ./cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-proxy-csr.json | sudo ./cfssljson -bare kube-proxy) >/dev/null 2>&1
  popd >/dev/null 2>&1
  echo "ok"

  # building a few kubeconfig files.
  local -r KUBE_APISERVER="https://${VIP}:${VIP_PORT}"
  local -r CAFILE="${SSL_DIR}/ca.pem"
  local -r TOKEN=$(sudo cat ${K8S_CONF_DIR}/bootstrap-token.csv | awk -F ',' '{print $1}')
  local KUBECONFIG=""

  # building bootstrap.kubeconfig
  echo -n "Building bootstrap.kubeconfig..."
  KUBECONFIG="${K8S_CONF_DIR}/bootstrap.kubeconfig"
  sudo ${KUBECTL} config set-cluster kubernetes --certificate-authority=${CAFILE} --embed-certs=true --server=${KUBE_APISERVER} --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  sudo ${KUBECTL} config set-credentials kubelet-bootstrap --token=${TOKEN} --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  sudo ${KUBECTL} config set-context default --cluster=kubernetes --user=kubelet-bootstrap --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  sudo ${KUBECTL} config use-context default --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  echo "ok"

  # building kubelet.kubeconfig
  echo -n "Building kubelet.kubeconfig..."
  KUBECONFIG="${K8S_CONF_DIR}/kubelet.kubeconfig"
  sudo ${KUBECTL} config set-cluster kubernetes --certificate-authority=${CAFILE} --embed-certs=true --server=${KUBE_APISERVER} --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  sudo ${KUBECTL} config set-credentials kubelet --token=${TOKEN} --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  sudo ${KUBECTL} config set-context default --cluster=kubernetes --user=kubelet --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  sudo ${KUBECTL} config use-context default --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  echo "ok"

  # building kube-proxy.kubeconfig
  echo -n "Building kube-proxy.kubeconfig..."
  KUBECONFIG="${K8S_CONF_DIR}/kube-proxy.kubeconfig"
  sudo ${KUBECTL} config set-cluster kubernetes --certificate-authority=${CAFILE} --embed-certs=true --server=${KUBE_APISERVER} --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  sudo ${KUBECTL} config set-credentials kube-proxy --client-certificate=${SSL_DIR}/kube-proxy.pem --client-key=${SSL_DIR}/kube-proxy-key.pem --embed-certs=true --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  sudo ${KUBECTL} config set-context default --cluster=kubernetes --user=kube-proxy --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  sudo ${KUBECTL} config use-context default --kubeconfig=${KUBECONFIG} >/dev/null 2>&1
  echo "ok"

  # distribute upon files to all workers
  sudo chmod +r ${SSL_DIR}/kube-proxy-key.pem ${K8S_CONF_DIR}/{bootstrap,kubelet,kube-proxy}.kubeconfig
  for host in ${WORKERS[@]}; do
    echo -n "Running on ${host}($(hostip ${host})): Copying kube-proxy cert & key, workers' kubeconfig files to..."
    scp ${SSL_DIR}/kube-proxy*.pem \
      ${K8S_CONF_DIR}/{bootstrap,kubelet,kube-proxy}.kubeconfig \
      ${USER}@${host}:${TMP_DIR} >/dev/null 2>&1

    ssh ${USER}@${host} "sudo chown root:root ${TMP_DIR}/kube-proxy*.pem ${TMP_DIR}/{bootstrap,kubelet,kube-proxy}.kubeconfig; \
      sudo cp -f ${TMP_DIR}/kube-proxy*.pem ${SSL_DIR}; \
      sudo cp -f ${TMP_DIR}/{bootstrap,kubelet,kube-proxy}.kubeconfig ${K8S_CONF_DIR}; \
      sudo chmod 600 ${SSL_DIR}/kube-proxy-key.pem ${K8S_CONF_DIR}/{bootstrap,kubelet,kube-proxy}.kubeconfig"
    echo "ok"
  done
  sudo chmod 600 ${SSL_DIR}/kube-proxy-key.pem ${K8S_CONF_DIR}/{bootstrap,kubelet,kube-proxy}.kubeconfig

  # binding clusterrole to kubelet-bootstrap
  echo ""
  echo -n "Binding clusterrole to kubelet-bootstrap..."
  sudo ${KUBECTL} create clusterrolebinding kubelet-bootstrap --clusterrole=system:node-bootstrapper --user=kubelet-bootstrap
  echo ""

  echo "------ Ending of config kubernetes workers ------------------"
  echo ""
}

function deploy_k8s_kubelet()
{
  echo "-------------------------------------------------------------"
  echo "Deploying kubernetes kubelet..."

  # install ipvsadm etc. pacakges to all workers
  for host in ${WORKERS[@]}; do
    echo -n "Running on ${host}($(hostip ${host})): Installing ipvsadm packages..."
    ssh ${USER}@${host} "sudo yum install -y ${RPM_DIR}/ipvsadm-1.27-8.el7.x86_64.rpm \
        ${RPM_DIR}/bridge-utils-1.5-9.el7.x86_64.rpm \
        ${RPM_DIR}/conntrack-tools-1.4.4-7.el7.x86_64.rpm \
        ${RPM_DIR}/libnetfilter_cthelper-1.0.0-11.el7.x86_64.rpm \
        ${RPM_DIR}/libnetfilter_cttimeout-1.0.0-7.el7.x86_64.rpm \
        ${RPM_DIR}/libnetfilter_queue-1.0.2-2.el7_2.x86_64.rpm >/dev/null 2>&1"
    echo "ok"
  done

  # building kubelet service ,conf and yaml files
  echo -n "Building kubelet service, conf & ymal files..."
  cp -f ${TEMPLATE_DIR}/kubelet/kubelet.{service,conf,yaml} ${TMP_DIR}
  sed -i "s#\${APP_DIR}#${APP_DIR}#g" ${TMP_DIR}/kubelet.service
  sed -i "s#\${K8S_CONF_DIR}#${K8S_CONF_DIR}#g" ${TMP_DIR}/kubelet.service
  sed -i "s#\${K8S_BIN_DIR}#${K8S_BIN_DIR}#g" ${TMP_DIR}/kubelet.service
  sed -i "s#\${DOCKER_HUB}#${DOCKER_HUB}#g" ${TMP_DIR}/kubelet.conf
  sed -i "s#\${K8S_CONF_DIR}#${K8S_CONF_DIR}#g" ${TMP_DIR}/kubelet.conf
  sed -i "s#\${K8S_YAML_DIR}#${K8S_YAML_DIR}#g" ${TMP_DIR}/kubelet.conf
  sed -i "s#\${SSL_DIR}#${SSL_DIR}#g" ${TMP_DIR}/kubelet.conf
  sed -i "s#\${APP_DIR}#${APP_DIR}#g" ${TMP_DIR}/kubelet.conf
  sed -i "s#\${CLUSTER_IP_SEGMENT}#${CLUSTER_IP_SEGMENT}#g" ${TMP_DIR}/kubelet.yaml
  sed -i "s#\${SSL_DIR}#${SSL_DIR}#g" ${TMP_DIR}/kubelet.yaml
  echo "ok"

  # distriubte & start service
  for host in ${WORKERS[@]}; do
    echo -n "Running on ${host}($(hostip ${host})): Building kubelet.conf, distribute kubelet files, and start kubelet service..."
    scp ${TMP_DIR}/kubelet.{service,conf,yaml} ${USER}@${host}:${TMP_DIR} >/dev/null 2>&1
    ssh ${USER}@${host} "sed -i \"s#\\\${hostname}#${host}#g\" ${TMP_DIR}/kubelet.conf; \
      sudo chown root:root ${TMP_DIR}/kubelet.{service,conf,yaml}; \
      sudo cp -f ${TMP_DIR}/kubelet.service ${SERVICE_DIR}; \
      sudo cp -f ${TMP_DIR}/kubelet.conf ${K8S_CONF_DIR}; \
      sudo cp -f ${TMP_DIR}/kubelet.yaml ${K8S_YAML_DIR}; \
      sudo systemctl daemon-reload; \
      sudo systemctl enable kubelet >/dev/null 2>&1; \
      nohup sudo systemctl start kubelet >/dev/null 2>&1 &"
    echo "ok"
  done

  # approve TLS request
  echo ""
  echo "Viewing csr and approving TLS requests after a few seconds when kubelet.service ready..."
  sleep 10s
  sudo ${KUBECTL} get csr
  sudo ${KUBECTL} get csr | grep 'Pending' | awk 'NR>0{print $1}' | xargs ${KUBECTL} certificate approve

  echo "------ Ending of deploying kubelet --------------------------"
  sleep 2s
  echo ""
}

function deploy_k8s_proxy()
{
  echo "-------------------------------------------------------------"
  echo "Deploy kubernetes kube-proxy..."

  # building kube-proxy service,conf,yaml files...
  echo -n "Building kube-proxy service, conf & yaml files..."
  cp -f ${TEMPLATE_DIR}/proxy/kube-proxy.{service,conf,yaml} ${TMP_DIR}
  sed -i "s#\${K8S_CONF_DIR}#${K8S_CONF_DIR}#g" ${TMP_DIR}/kube-proxy.service
  sed -i "s#\${K8S_BIN_DIR}#${K8S_BIN_DIR}#g" ${TMP_DIR}/kube-proxy.service
  sed -i "s#\${APP_DIR}#${APP_DIR}#g" ${TMP_DIR}/kube-proxy.service
  sed -i "s#\${K8S_CONF_DIR}#${K8S_CONF_DIR}#g" ${TMP_DIR}/kube-proxy.conf
  sed -i "s#\${K8S_YAML_DIR}#${K8S_YAML_DIR}#g" ${TMP_DIR}/kube-proxy.conf
  sed -i "s#\${POD_IP_SEGMENT}#${POD_IP_SEGMENT}#g" ${TMP_DIR}/kube-proxy.conf
  sed -i "s#\${APP_DIR}#${APP_DIR}#g" ${TMP_DIR}/kube-proxy.conf
  sed -i "s#\${K8S_CONF_DIR}#${K8S_CONF_DIR}#g" ${TMP_DIR}/kube-proxy.yaml
  sed -i "s#\${POD_IP_SEGMENT}#${POD_IP_SEGMENT}#g" ${TMP_DIR}/kube-proxy.yaml
  echo "ok"

  # distribute files and start service
  for host in ${WORKERS[@]}; do
    echo -n "Running on host ${host}($(hostip ${host})): Copying kube-proxy service files & start..."
    scp ${TMP_DIR}/kube-proxy.{service,conf,yaml} ${USER}@${host}:${TMP_DIR} >/dev/null 2>&1
    ssh ${USER}@${host} "sed -i \"s#\\\${ip}#$(hostip ${host})#g\" ${TMP_DIR}/kube-proxy.yaml; \
      sed -i \"s#\\\${hostname}#${host}#g\" ${TMP_DIR}/kube-proxy.yaml; \
      sed -i \"s#\\\${ip}#$(hostip ${host})#g\" ${TMP_DIR}/kube-proxy.conf; \

      sudo chown root:root ${TMP_DIR}/kube-proxy.{service,conf,yaml}; \
      sudo cp -f ${TMP_DIR}/kube-proxy.service ${SERVICE_DIR}; \
      sudo cp -f ${TMP_DIR}/kube-proxy.conf ${K8S_CONF_DIR}; \
      sudo cp -f ${TMP_DIR}/kube-proxy.yaml ${K8S_YAML_DIR}; \

      sudo systemctl daemon-reload; \
      sudo systemctl enable kube-proxy >/dev/null 2>&1; \
      sudo systemctl start kube-proxy >/dev/null 2>&1 &"
    echo "ok"
  done

  # view ipvs status
  echo ""
  echo "Running on ${EXEC_NODE}: Viewing ipvs status"
  ssh ${USER}@${EXEC_NODE} "sudo ipvsadm -Ln"

  echo "------ Ending of deploy kubernetes kube-proxy ---------------"
  sleep 2s
  echo ""
}

# cni-plugin calico
function deploy_calico()
{
  echo "-------------------------------------------------------------"
  echo "Deploy kubernetes cni-plugin calico..."

  # building calico profile, conf, cfg
  echo "Building calico.sh, same as template/calico/calico.sh ."

  echo -n "Building 10-calico.conf..."
  cp -f ${TEMPLATE_DIR}/calico/10-calico.conf ${TMP_DIR}
  sed -i "s#\${ETCD_ENDPOINTS}#${ETCD_ENDPOINTS}#g" ${TMP_DIR}/10-calico.conf
  sed -i "s#\${SSL_DIR}#${SSL_DIR}#g" ${TMP_DIR}/10-calico.conf
  sed -i "s#\${K8S_CONF_DIR}#${K8S_CONF_DIR}#g" ${TMP_DIR}/10-calico.conf
  echo "ok"

  # building calicoctl.cfg. here it shows that calicoctl need etcd cert & key files to connect to etcd.
  echo -n "Building calicoctl.cfg..."
  cp -f ${TEMPLATE_DIR}/calico/calicoctl.cfg ${TMP_DIR}
  sed -i "s#\${ETCD_ENDPOINTS}#${ETCD_ENDPOINTS}#g" ${TMP_DIR}/calicoctl.cfg
  sed -i "s#\${SSL_DIR}#${SSL_DIR}#g" ${TMP_DIR}/calicoctl.cfg
  echo "ok"

  # distribute & install calico packages
  for host in ${WORKERS[@]}; do
    echo -n "Running on ${host}($(hostip ${host})): Installing calico packages and copy config files..."
    scp ${TEMPLATE_DIR}/calico/calico.sh ${TMP_DIR}/10-calico.conf ${TMP_DIR}/calicoctl.cfg ${USER}@${host}:${TMP_DIR} >/dev/null 2>&1
    ssh ${USER}@${host} "sudo tar -xzf /mnt/rw/calico/cni-plugins-linux-amd64-v0.8.6.tgz -C /opt/cni/; \
      sudo ln -sf /opt/cni/{bandwidth,loopback,portmap,tuning} /opt/cni/bin/; \
      sudo chmod +x /opt/cni/bin/*; \
      sudo cp -f /mnt/rw/calico/calico-amd64 /opt/calico/bin/calico; \
      sudo cp -f /mnt/rw/calico/calico-ipam-amd64 /opt/calico/bin/calico-ipam; \
      sudo cp -f /mnt/rw/calico/calicoctl-linux-amd64 /opt/calico/bin/calicoctl; \
      sudo ln -sf /opt/calico/bin/calico-ipam /opt/calico/bin/calico /opt/cni/bin/; \

      sudo chown root:root ${TMP_DIR}/calico.sh ${TMP_DIR}/10-calico.conf ${TMP_DIR}/calicoctl.cfg; \
      sudo cp -f ${TMP_DIR}/calico.sh /etc/profile.d/; \
      sudo cp -f ${TMP_DIR}/10-calico.conf /etc/cni/net.d/; \
      sudo cp -f ${TMP_DIR}/calicoctl.cfg /etc/calico/"
    echo "ok"
  done

  # building calico.yaml and apply it on EXEC_NODE
  echo -n "Building calico deploy file calico.yaml..."
  cp -f ${TEMPLATE_DIR}/calico/calico.yaml ${TMP_DIR}
  local -r ETCD_CA=$(sudo base64 -w 0 ${SSL_DIR}/ca.pem)
  local -r ETCD_KEY=$(sudo base64 -w 0 ${SSL_DIR}/etcd-key.pem)
  local -r ETCD_CERT=$(sudo base64 -w 0 ${SSL_DIR}/etcd.pem)
  sed -i "s#\${ETCD_KEY}#${ETCD_KEY}#g" ${TMP_DIR}/calico.yaml
  sed -i "s#\${ETCD_CERT}#${ETCD_CERT}#g" ${TMP_DIR}/calico.yaml
  sed -i "s#\${ETCD_CA}#${ETCD_CA}#g" ${TMP_DIR}/calico.yaml
  sed -i "s#\${ETCD_ENDPOINTS}#${ETCD_ENDPOINTS}#g" ${TMP_DIR}/calico.yaml
  sed -i "s#\${DOCKER_HUB}#${DOCKER_HUB}#g" ${TMP_DIR}/calico.yaml
  sed -i "s#\${NETWORK_CARD}#${NETWORK_CARD}#g" ${TMP_DIR}/calico.yaml
  sed -i "s#\${POD_IP_SEGMENT}#${POD_IP_SEGMENT}#g" ${TMP_DIR}/calico.yaml
  echo "ok"

  echo -n "Deploying calico pods..."
  sudo chown root:root ${TMP_DIR}/calico.yaml
  sudo cp -f ${TMP_DIR}/calico.yaml ${K8S_YAML_DIR}
  sudo ${KUBECTL} apply -f ${K8S_YAML_DIR}/calico.yaml >/dev/null 2>&1
  echo "ok"

  # view pod/deployment in all namespace
  local -r CALICOCTL="/opt/calico/bin/calicoctl"
  echo ""
  echo "Waiting for a few minutes until calico pods are ready, view deployment/pods in k8s, view calico node..."
  sleep 90s
  echo "-------------------------------------------------------------"
  sudo ${KUBECTL} get deployment,pods -n kube-system -o wide
  echo "-------------------------------------------------------------"
  ssh ${USER}@${EXEC_NODE} "sudo ${CALICOCTL} get node -o wide"

  # fix ippool
  echo "Running on ${EXEC_NODE}: Recreate ippool to fix ippool config..."
  echo "-------------------------------------------------------------"
  cp -f ${TEMPLATE_DIR}/calico/calico-ippool.yaml ${TMP_DIR}
  sed -i "s#\${POD_IP_SEGMENT}#${POD_IP_SEGMENT}#g" ${TMP_DIR}/calico-ippool.yaml
  scp ${TMP_DIR}/calico-ippool.yaml ${USER}@${EXEC_NODE}:${TMP_DIR} >/dev/null 2>&1
  ssh ${USER}@${EXEC_NODE} "sudo chown root:root ${TMP_DIR}/calico-ippool.yaml; \
    sudo cp -f ${TMP_DIR}/calico-ippool.yaml /opt/calico/yaml/; \
    sudo ${CALICOCTL} get ippool -o wide; \
    sudo ${CALICOCTL} delete ippool default-ipv4-ippool; \
    sudo ${CALICOCTL} apply -f /opt/calico/yaml/calico-ippool.yaml; \
    sudo ${CALICOCTL} get ippool -o wide"
  echo ""

  # view current node status and peers info
  for host in ${WORKERS[@]}; do
    echo "Running on ${host}($(hostip ${host})): View calico node status..."
    echo "-----------------------------"
    ssh ${USER}@${host} "sudo ${CALICOCTL} node status"
  done

  # view peer info
  echo "Running on ${EXEC_NODE}: View peer info..."
  echo "-------------------------------------------------------------"
  ssh ${USER}@${EXEC_NODE} "sudo ${CALICOCTL} get wep -a"

  echo "------ Ending of deploy calico ------------------------------"
  sleep 2s
  echo ""
}

# ------ main -------------------------------------------------------

# ------ check parameters
declare -a OPT_ARGS=`getopt -o :rc --long restore,clean -n 'install-k8s-service.sh' -- "$@"`
if [ $? != 0 ]; then
  echo "Usage: install-k8s-service.sh [options]"
  echo "       -r, --restore   : clear environment before installed."
  echo "       -c, --clean     : same to -r, --restore"
#  echo "           --etcd      : only install etcd"
#  echo "           --ha        : only install haproxy & keepalived"
#  echo "           --apiserver : only install kube-apiserver"
#  echo "           --scheduler : only install kube-scheduler-manager"
  echo ""
  echo "  No parameter indicates run all scripts, including clean & all installations."
  exit 1
fi

eval set -- "${OPT_ARGS}"
declare CMD=""
while true; do
  case ${1} in
    -r|-c|--restore|--clean)
      CMD="R"
      break
      ;;
    *)
    CMD=""
    break
    ;;
  esac
done
# ------ end of check parameters

declare -r SHELL_DIR="$(cd "$(dirname "${0}")" && pwd)"
. ${SHELL_DIR}/install-k8s-common.sh

show_vars

clear_all
if [ "${CMD}" == "R" ]; then
  exit
fi

check_pkgs
if [ $? -ne 0 ]; then
  exit $?
fi

init_env_service

create_ca

deploy_etcd

if [ ${MASTER_SINGLE_FLAG} == "cluster" ]; then
  # only master cluster needs ha
  deploy_ha
fi

deploy_kubernetes

clearTemporary

echo ""
echo "You should run install-k8s-dns.sh to deploy coreDNS!"
echo ""
