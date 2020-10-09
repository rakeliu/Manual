#!/usr/bin/env bash

# This script is used for setup k8s+calico all configurations
# all sets are same build in all nodes

function clear_all()
{
  echo "============================================================="
  echo "Clear all configurations"
  echo "-------------------------------------------------------------"

  echo ">> clear local configurations..."
  local -r BASHRC_FILE="${HOME}/.bashrc"
  echo ">> stop services..."
  sudo systemctl stop calico keepalived haproxy kube-proxy kubelet kube-scheduler kube-controller-manager kube-apiserver etcd
  echo ">> remove services..."
  sudo systemctl disable etcd kube-apiserver kube-controller-manager kube-scheduler kubelet kube-proxy haproxy keepalived calico
  echo ">> remove packages ..."
  sudo yum remove -y haproxy keepalived psmisc bash-completion ipvsadm bridge-utils conntrack lm_sensors-libs net-snmp-agent-libs net-snmp-libs libnetfilter_cthelper libnetfilter_cttimeout libnetfilter_queue
  echo ">> remove docker images"
  sudo docker ps -a | awk 'NR>1{print $1}' | xargs sudo docker stop
  sudo docker ps -a | awk 'NR>1{print $1}' | xargs sudo docker rm -f
  sudo docker images | awk 'NR>1{print $1":"$2}' | xargs sudo docker rmi
  echo ">> remove directoris ..."
  sudo rm -fr ${APP_DIR}/{k8s,etcd,haproxy,calico} /opt/{ssl,k8s,cni,calico} /etc/{cni,calico}
  sudo rm -fr /opt/{etcd,etcd-*} /opt/kubernetes
  sudo rm -fr /var/lib/calico
  sudo rm -fr ~/.kube
  sudo rm -fv /etc/sysctl.d/kubernetes.conf /etc/profile.d/{kubernetes.sh,etcd.sh,calico.sh} /etc/haproxy/haproxy.cfg.rpmsave /etc/keepalived/keepalived.conf.rpmsave
  sudo rm -fv /etc/systemd/system/{etcd,kube-apiserver,kube-controller-manager,kube-scheduler,kubelet,kube-proxy}.service
  echo ">> remove declare & alias ..."
  sed -i "/^declare -a MASTERS.*$/d" ${BASHRC_FILE}
  sed -i "/^declare -a NODES.*$/d" ${BASHRC_FILE}
  sed -i "/^declare ETCD_CONN.*$/d" ${BASHRC_FILE}
  sed -i "/^export ETCD_CONN.*$/d" ${BASHRC_FILE}
  sed -i "/^alias masterExec.*$/d" ${BASHRC_FILE}
  sed -i "/^alias nodeExec.*$/d" ${BASHRC_FILE}
  sed -i "/^# kubectl/d" ${BASHRC_FILE}
  sed -i "/^source <(kubectl.*$/d" ${BASHRC_FILE}

  # remote hosts
  # first hosts
  ssh ${USER}@k8s-master1 "sudo ${KUBECTL} delete -f /opt/calico/yaml/calico.yaml -n kube-system"

  IP=34
  for host in "${NODES[@]}"
  do
    IP=$(( IP + 1 ))
    echo -e "\n>> clear configurations in host ${host} (192.168.176.${IP})...\n"
    ssh ${USER}@${host} "sudo systemctl stop keepalived haproxy kube-proxy kubelet kube-scheduler kube-controller-manager kube-apiserver etcd; \
      sudo systemctl disable etcd kube-apiserver kube-controller-manager kube-scheduler kubelet kube-proxy haproxy keepalived; \
      sudo yum remove -y haproxy keepalived psmisc bash-completion ipvsadm bridge-utils conntrack \
        lm_sensors-libs net-snmp-agent-libs net-snmp-libs \
        libnetfilter_cthelper libnetfilter_cttimeout libnetfilter_queue; \
      sudo docker ps -a | awk 'NR>1{print \$1}' | xargs sudo docker stop; \
      sudo docker ps -a | awk 'NR>1{print \$1}' | xargs sudo docker rm -f; \
      sudo docker images | awk 'NR>1{print \$1\":\"\$2}' | xargs sudo docker rmi; \
      sudo rm -fr ${APP_DIR}/{k8s,etcd,haproxy,calico} /opt/{ssl,k8s,cni,calico} /etc/cni; \
      sudo rm -fr /opt/{etcd,etcd-*} /opt/kubernetes; \
      sudo rm -fr /var/calico; \
      sudo rm -fr ~/.kube; \
      sudo rm -fv /etc/sysctl.d/kubernetes.conf /etc/profile.d/{kubernetes.sh,etcd.sh,calico.sh} /etc/haproxy/haproxy.cfg.rpmsave /etc/keepalived/keepalived.conf.rpmsave; \
      sudo rm -fv /etc/systemd/system/{etcd,kube-apiserver,kube-controller-manager,kube-scheduler,kubelet,kube-proxy}.service; \
      sed -i \"/^declare -a MASTERS.*$/d\" ${BASHRC_FILE}; \
      sed -i \"/^declare -a NODES.*$/d\" ${BASHRC_FILE}; \
      sed -i \"/^declare ETCD_CONN.*$/d\" ${BASHRC_FILE}; \
      sed -i \"/^export ETCD_CONN.*$/d\" ${BASHRC_FILE}; \
      sed -i \"/^alias masterExec.*$/d\" ${BASHRC_FILE}; \
      sed -i \"/^alias nodeExec.*$/d\" ${BASHRC_FILE}; \
      sed -i \"/^# kubectl/d\" ${BASHRC_FILE}; \
      sed -i \"/^source <(kubectl.*$/d\" ${BASHRC_FILE}"
  done
  echo -e "\n>> Ending of clear all configurations\n\n"
}

function preinstall()
{
  echo "============================================================="
  echo "PreInstall - setting script environments"
  echo "-------------------------------------------------------------"

  echo -e ">> Ending preinstall \n\n"
}

function init_template()
{
  echo "============================================================="
  echo "1. Initialize Template"

  echo "-------------------------------------------------------------"
  echo ">> 1.1 Modify file  .bashrc"
  local -r BASHRC_FILE="/home/${USER}/.bashrc"

  echo "  >> 1.1.1 add declare MASTERS..."
  sed -i "/^# export SYSTEMD_PAGER/adeclare -a MASTERS=(k8s-master1 k8s-master2 k8s-master3)" ${BASHRC_FILE}

  echo "-------------------------------------------------------------"
  echo "  >> 1.1.2 add declare NODES..."
  sed -i "/^declare -a MASTERS/adeclare -a NODES=(k8s-master1 k8s-master2 k8s-master3 k8s-node1 k8s-node2 k8s-node3)" ${BASHRC_FILE}

  echo "-------------------------------------------------------------"
  echo "  >> 1.1.3 add alias masterExec..."
  sed -i "/^alias log=.*$/aalias masterExec='_f() { for host in \"\${MASTERS[@]}\";do ssh ${USER}@\${host} \"sudo \$1\"; done; }; _f'" ${BASHRC_FILE}

  echo "-------------------------------------------------------------"
  echo "  >> 1.1.4 add alias nodeExec..."
  sed -i "/^alias masterExec=.*$/aalias nodeExec='_f() { for host in \"\${NODES[@]}\";do ssh ${USER}@\${host} \"sudo \$1\"; done; }; _f'" ${BASHRC_FILE}

  echo "-------------------------------------------------------------"
  echo "  >> 1.1.5 add alias ETCD_CONN..."
  local -r ETCD_CONN="--cacert=/opt/ssl/ca.pem --cert=/opt/ssl/etcd.pem --key=/opt/ssl/etcd-key.pem --endpoints=https://192.168.176.35:2379,https://192.168.176.36:2379,https://192.168.176.37:2379"
  sed -i "/^declare -a NODES.$/adeclare ETCD_CONN=\"${ETCD_CONN}\"" ${HOME}/.bashrc

  echo "-------------------------------------------------------------"
  echo "  >> 1.1.6 copy .bashrc to all nodes..."
  IP=34
  for host in ${NODES[@]}
  do
    IP=$(( IP + 1 ))
    echo "    copy .bashrc to host ${host}(192.168.176.${IP})"
    scp ~/.bashrc ${USER}@${host}:~/
  done

  echo "-------------------------------------------------------------"
  echo ">> 1.2 Initializing system settings"

  echo "-------------------------------------------------------------"
  echo "  >> 1.2.1 create kubernetes.conf "
  cat > ~/kubernetes.conf << EOF
net.ipv4.ip_forward = 1
net.ipv4.tcp_tw_recycle=0
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
vm.swappiness=0
vm.overcommit_memory=1
vm.panic_on_oom=0
fs.inotify.max_user_watches=89100
fs.file-max=52706963
fs.nr_open=52706963
EOF

  echo "-------------------------------------------------------------"
  echo "  >> 1.2.2 disable swap & distribute kubernetes.sh"
  IP=34
  for host in ${NODES[@]}
  do
    IP=$(( IP + 1 ))
    echo "    disable swap and create kubernetes system settings in host: ${host}(192.168.176.${IP})..."
    scp ~/kubernetes.conf ${USER}@${host}:~/
    ssh ${USER}@${host} "sudo chown root:root ~/kubernetes.conf; \
      sudo mv -fv ~/kubernetes.conf /etc/sysctl.d/; \
      sudo sed -i '/swap / s/^\(.*\)$/#\1/g' /etc/fstab; \
      sudo sysctl -p /etc/sysctl.d/kubernetes.conf"
  done
  rm -fv ~/kubernetes.conf

  echo "-------------------------------------------------------------"
  echo ">> 1.3 Initializing directories in all VMs"
  sudo mkdir -pv /opt/ssl /opt/k8s/{bin,conf,token,yaml}
  sudo mkdir -pv ${APP_DIR}/etcd ${APP_DIR}/k8s/{apiserver,controller,scheduler,kubelet,proxy}
  sudo mkdir -pv /opt/cni/bin /opt/calico/{conf,yaml,bin} /etc/cni/net.d/ /var/lib/calico
  IP=34
  for node in "${NODES[@]}"
  do
    IP=$(( IP + 1 ))
    echo "  >> making directories in host ${node} (192.168.176.${IP})..."
    ssh ${USER}@${node} "sudo mkdir -pv /opt/ssl /opt/k8s/{bin,conf,token,yaml}; \
      sudo mkdir -pv ${APP_DIR}/etcd ${APP_DIR}/k8s/{apiserver,controller,scheduler,kubelet,proxy}; \
      sudo mkdir -pv /opt/cni/bin /opt/calico/{conf,yaml,bin} /etc/cni/net.d/ /etc/calico /var/lib/calico; \
      sudo chmod 700 ${APP_DIR}/etcd"
  done

  echo "-------------------------------------------------------------"
  echo ">> 1.4 Setting global environments for etcd & k8s"
  cat > ~/kubernetes.sh <<EOF
K8S_HOME=/opt/k8s
export PATH=\$PATH:\$K8S_HOME/bin
EOF

  cat > ~/etcd.sh <<EOF
export ETCDCTL_API=3
EOF

  sudo chown root:root ~/kubernetes.sh ~/etcd.sh
  sudo mv -f ~/kubernetes.sh ~/etcd.sh /etc/profile.d/

  IP=34
  for node in "${NODES[@]}"
  do
    IP=$(( IP + 1 ))
    echo "  >> coping file to host ${node}(192.168.176.${IP})..."
    scp /etc/profile.d/kubernetes.sh /etc/profile.d/etcd.sh ${USER}@${node}:~/
    ssh ${USER}@${node} "sudo chown root:root ~/kubernetes.sh ~/etcd.sh; \
      sudo mv -f ~/kubernetes.sh ~/etcd.sh /etc/profile.d/"
  done

  echo -e ">> Ending initialized template \n\n"
}

function create_CA()
{
  echo "============================================================="
  echo "2. Create CA certification files"

  local -r SOURCE_DIR="/mnt/rw/cfssl"

  echo "-------------------------------------------------------------"
  echo ">> 2.1 copy cfssl"
  for file in "cfssl" "cfssl-certinfo" "cfssljson"
  do
    sudo cp -fv "${SOURCE_DIR}/${file}_linux-amd64" "${SSL_DIR}/${file}"
  done

  echo "-------------------------------------------------------------"
  echo ">> 2.2 generate ca certification"

  echo "-------------------------------------------------------------"
  echo "  >> 2.2.1 create ca-config"
  pushd "${HOME}" >& /dev/null
  local -r CA_CONFIG="ca-config.json"
  cat > "${CA_CONFIG}" << EOF
{
    "signing": {
        "default": {
            "expiry": "87600h"
        },
        "profiles": {
            "kubernetes": {
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ],
                "expiry": "87600h"
            }
        }
    }
}
EOF

  echo "-------------------------------------------------------------"
  echo "  >> 2.2.2 create ca-csr.json"
  local -r CA_CSR="ca-csr.json"
  cat > "${CA_CSR}" <<EOF
{
    "CN": "kubernetes",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "Chongqing",
            "L": "Chongqing",
            "O": "k8s",
            "OU": "ymliu"
        }
    ]
}
EOF

  sudo chown root:root "${CA_CONFIG}" "${CA_CSR}"
  sudo mv -fv "${CA_CONFIG}" "${CA_CSR}" "${SSL_DIR}"

  echo "-------------------------------------------------------------"
  echo "  >> 2.2.3 generate pem & key"
  pushd "${SSL_DIR}" >& /dev/null
  sudo ./cfssl gencert -initca "${CA_CSR}" | sudo ./cfssljson -bare ca

  echo "-------------------------------------------------------------"
  echo "  >> 2.2.4 distribute ca pem & key file"
  sudo chmod 644 ca-key.pem
  IP=34
  for host in "${NODES[@]}"
  do
    IP=$(( IP + 1 ))
    echo "    >> coping to host ${host}(192.168.176.${IP})"
    scp ca*.pem ${USER}@${host}:~/
    ssh ${USER}@${host} "sudo chown root:root ca*.pem; \
      sudo chmod 600 ca-key.pem; \
      sudo mv ca*.pem ${SSL_DIR}/"
  done
  sudo chmod 600 ca-key.pem

  echo -e ">> Ending create CA certification \n\n"
}

function deploy_etcd()
{
  echo "============================================================="
  echo "3. Deploy ETCD"

  echo "-------------------------------------------------------------"
  echo ">> 3.1 generate etcd certification files"
  echo "-------------------------------------------------------------"
  echo "  >> 3.1.1 create ca-config"
  pushd "${HOME}" >& /dev/null
  local -r ETCD_CSR="etcd-csr.json"
  cat > "${ETCD_CSR}" << EOF
{
    "CN" : "etcd" ,
    "hosts" : [
        "127.0.0.1" ,
        "192.168.176.35" ,
        "192.168.176.36" ,
        "192.168.176.37" ,
        "k8s-master1" ,
        "k8s-master2" ,
        "k8s-master3"
    ] ,
    "key" : {
        "algo" : "rsa" ,
        "size" : 2048
    } ,
    "names" : [
        {
            "C" : "CN" ,
            "ST" : "Chongqing" ,
            "L" : "Chongqing" ,
            "O" : "k8s" ,
            "OU" : "ymliu"
        }
    ]
}
EOF

  sudo chown root:root "${ETCD_CSR}"
  sudo mv -fv "${ETCD_CSR}" "${SSL_DIR}"

  echo "-------------------------------------------------------------"
  echo "  >> 3.1.2 generate pem & key"
  pushd "${SSL_DIR}" >& /dev/null
  sudo ./cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes ${ETCD_CSR} | sudo ./cfssljson -bare etcd

  echo "-------------------------------------------------------------"
  echo "  >> 3.1.3 distribute etcd pem & key file"
  sudo chmod 644 etcd-key.pem
  IP=34
  for host in "${NODES[@]}"
  do
    IP=$(( IP + 1 ))
    echo "    >> coping to host ${host}(192.168.176.${IP})"
    scp etcd*.pem ${USER}@${host}:~/
    ssh ${USER}@${host} "sudo chown root:root etcd*.pem; \
      sudo chmod 600 etcd-key.pem; \
      sudo mv -fv etcd*.pem ${SSL_DIR}/"
  done
  sudo chmod 600 etcd-key.pem

  echo "-------------------------------------------------------------"
  echo ">> 3.2 copy & extract etcd files"
  local -r ETCD_SRC_DIR="/mnt/rw/k8s"
  local -r ETCD_PKG="etcd-v${ETCD_VER}-linux-amd64"
  local -r ETCD_FULL="etcd-v${ETCD_VER}-linux-amd64.tar.gz"

  echo "  >> extract etcd files in local host..."
  sudo tar -xzf ${ETCD_SRC_DIR}/${ETCD_FULL} -C /opt/ >& /dev/null
  sudo ln -sf /opt/${ETCD_PKG} /opt/etcd
  sudo ln -sf /opt/etcd/etcd /opt/k8s/bin/
  sudo ln -sf /opt/etcd/etcdctl /opt/k8s/bin

  IP=34
  for host in "${MASTERS[@]}"
  do
    IP=$(( IP + 1 ))
    echo "  >> extract etcd files in host ${host} (192.168.176.${IP})..."
    ssh ${USER}@${host} "sudo tar -xzf ${ETCD_SRC_DIR}/${ETCD_FULL} -C /opt/ >& /dev/null; \
      sudo chown -R root:root /opt/${ETCD_PKG}; \
      sudo ln -sf /opt/${ETCD_PKG} /opt/etcd; \
      sudo ln -sf /opt/etcd/etcd /opt/k8s/bin/; \
      sudo ln -sf /opt/etcd/etcdctl /opt/k8s/bin"
  done

  echo "-------------------------------------------------------------"
  echo ">> 3.3 create service & environment file"
  local -r UNIT_FILE="etcd.service"
  local -r CONF_FILE="etcd.conf"
  pushd "${HOME}" >& /dev/null
  echo "  >> 3.3.1 create etcd service file"
  cat > "${UNIT_FILE}" << EOF
[Unit]
Description=Etcd Server
After=network.service
After=network-online.service
Wants=network-online.service
Documentation=https://github.com/etcd-io/etcd

[Service]
Type=notify
WorkingDirectory=${APP_DIR}/etcd
EnvironmentFile=/opt/k8s/conf/etcd.conf
# set GOMAXPROCS to number of processes
ExecStart=/bin/bash -c "GOMAXPROCS=1 /opt/k8s/bin/etcd"
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

  echo "  >> 3.3.2 create etcd environment file"
  cat > "${CONF_FILE}" << EOF
#[member]
ETCD_NAME="##hostname##"
ETCD_DATA_DIR="${APP_DIR}/etcd"
ETCD_LISTEN_PEER_URLS="https://##hostip##:2380"
ETCD_LISTEN_CLIENT_URLS="https://##hostip##:2379,https://127.0.0.1:2379"
ETCD_LOGO_LEVEL="info"
ETCD_LOGGER="zap"

#[cluster]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://##hostip##:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://##hostip##:2379"
ETCD_INITIAL_CLUSTER="k8s-master1=https://192.168.176.35:2380,k8s-master2=https://192.168.176.36:2380,k8s-master3=https://192.168.176.37:2380"
INITIAL_CLUSTER_TOKEN="etcd-cluster"
INITIAL_CLUSTER_STATE="new"

#[security]
ETCD_CERT_FILE="/opt/ssl/etcd.pem"
ETCD_KEY_FILE="/opt/ssl/etcd-key.pem"
ETCD_TRUSTED_CA_FILE="/opt/ssl/ca.pem"
ETCD_CLIENT_CERT_AUTH="true"
ETCD_PEER_CERT_FILE="/opt/ssl/etcd.pem"
ETCD_PEER_KEY_FILE="/opt/ssl/etcd-key.pem"
ETCD_PEER_TRUSTED_CA_FILE="/opt/ssl/ca.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"

#[fixed heart beat interval]
ETCD_HEARTBEAT_INTERVAL=1000
ETCD_ELECTION_TIMEOUT=5000
EOF

  echo "  >> 3.3.3 distribute etcd service & environment file"
  sudo chown root:root ${UNIT_FILE} ${CONF_FILE}
  sudo mv -fv ${UNIT_FILE} /etc/systemd/system/
  sudo mv -fv ${CONF_FILE} /opt/k8s/conf
  IP=34
  for host in "${MASTERS[@]}"
  do
    IP=$(( IP + 1 ))
    echo "    >> copy to host ${host} (192.168.176.${IP})..."
    scp /etc/systemd/system/${UNIT_FILE} /opt/k8s/conf/${CONF_FILE} ${USER}@${host}:~/
    ssh ${USER}@${host} "sed -i 's/\#\#hostip\#\#/192.168.176.${IP}/g; s/\#\#hostname\#\#/${host}/g' ~/${CONF_FILE}; \
      sudo chown root:root ~/${UNIT_FILE} ~/${CONF_FILE}; \
      sudo mv -fv ~/${UNIT_FILE} /etc/systemd/system/; \
      sudo mv -fv ~/${CONF_FILE} /opt/k8s/conf/; \
      sudo systemctl daemon-reload"
  done

  echo "-------------------------------------------------------------"
  echo ">> 3.5 start etcd service"
  IP=34
  for host in "${MASTERS[@]}"
  do
    IP=$(( IP + 1 ))
    echo "  >> starting etcd service in host ${host} (192.168.176.${IP})..."
    ssh ${USER}@${host} "nohup sudo systemctl start etcd >/dev/null 2>&1 &"
  done

  echo -e "\n >> Ending of deploy etcd.\n"
}

deploy_HA()
{
  echo "============================================================="
  echo "4. Deploy haproxy & keepalived"

  echo "-------------------------------------------------------------"
  echo ">> 4.1 install haproxy & keepalived & psmisc files"
  IP=34
  for host in "${MASTERS[@]}"
  do
    IP=$(( IP + 1 ))
    echo "  >> install files in host ${host} (192.168.176.${IP}...)"
    ssh ${USER}@${host} "sudo yum install -y ${RPMDIR}/haproxy-1.5.18-9.el7.x86_64.rpm \
        ${RPMDIR}/keepalived-1.3.5-16.el7.x86_64.rpm \
        ${RPMDIR}/psmisc-22.20-16.el7.x86_64.rpm \
        ${RPMDIR}/lm_sensors-libs-3.4.0-8.20160601gitf9185e5.el7.x86_64.rpm \
        ${RPMDIR}/net-snmp-agent-libs-5.7.2-48.el7_8.1.x86_64.rpm \
        ${RPMDIR}/net-snmp-libs-5.7.2-48.el7_8.1.x86_64.rpm; \
      sudo mkdir -p ${APP_DIR}/haproxy; \
      sudo chown -R haproxy:haproxy ${APP_DIR}/haproxy"
  done

  echo "-------------------------------------------------------------"
  echo ">> 4.2 create haproxy config and distribute"
  pushd ${HOME} >& /dev/null
  cat > haproxy.cfg << EOF
#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    log         /dev/log    local0
    log         /dev/log    local1 notice

    chroot      ${APP_DIR}/haproxy
    pidfile     ${APP_DIR}/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon

    # turn on stats unix socket
    stats socket ${APP_DIR}/haproxy/haproxy-admin.sock mode 660 level admin
    stats timeout 30s
    daemon
    nbproc      1

#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
    log                     global
    timeout connect         5000
    timeout client          1m
    timeout server          1m
    maxconn                 3000

#---------------------------------------------------------------------
# listen for admin_stats, use admin/123456 to login
#---------------------------------------------------------------------
listen    admin_stats
    bind    0.0.0.0:10080
    mode    http
    log     127.0.0.1  local0  err
    stats   refresh  30s
    stats   uri  /status
    stats   realm  welcome login\ Haproxy
    stats   auth   admin:123456
    stats   hide-version
    stats   admin if TRUE

#---------------------------------------------------------------------
# listen for kube-master
#---------------------------------------------------------------------
listen    kube-master
    bind    0.0.0.0:8443
    mode    tcp
    option  tcplog
    balance source
    server  192.168.176.35   192.168.176.35:6443  check  inter  2000  fall 2  rise 2 weight 1
    server  192.168.176.36   192.168.176.36:6443  check  inter  2000  fall 2  rise 2 weight 1
    server  192.168.176.37   192.168.176.37:6443  check  inter  2000  fall 2  rise 2 weight 1

EOF
  for host in "${MASTERS[@]}"
  do
    scp haproxy.cfg ${USER}@${host}:~/
    ssh ${USER}@${host} "sudo chown root:root ~/haproxy.cfg; \
      sudo mv -fv ~/haproxy.cfg /etc/haproxy/; \
      sudo systemctl daemon-reload; \
      sudo systemctl enable haproxy; \
      sudo systemctl restart haproxy"
  done
  rm -fv haproxy.cfg

  echo "-------------------------------------------------------------"
  echo ">> 4.3 create keepalived config and distribute"
  pushd ${HOME} >& /dev/null
  cat > keepalived.conf << EOF
global_defs {
  router_id  lb-master-105
}

vrrp_script check-haproxy {
  script "killall -0 haproxy"
  interval 5
  weight -30
}

vrrp_instance  VI-kube-master {
  state MASTER
  priority 120
  dont_track_primary
  interface enp0s8
  virtual_router_id 68
  advert_int 3
  track_script {
    check-haproxy
  }
  virtual_ipaddress {
    192.168.176.34
  }
}
EOF
  scp keepalived.conf ${USER}@k8s-master1:~/

  sed -i "s/state MASTER$/state BACKUP/g; s/priority 120$/priority 110/g" keepalived.conf
  scp keepalived.conf ${USER}@k8s-master2:~/
  scp keepalived.conf ${USER}@k8s-master3:~/
  for host in "${MASTERS[@]}"
  do
    ssh ${USER}@${host} "sudo chown root:root keepalived.conf;\
      sudo mv -fv keepalived.conf /etc/keepalived/; \
      sudo systemctl daemon-reload; \
      sudo systemctl enable keepalived; \
      sudo systemctl restart keepalived"
  done
  rm -fv keepalived.conf

  echo -e "\n>> Ending of deploing haproxy & keepalived\n\n"
}

deploy_kubernetes_install()
{
  echo "-------------------------------------------------------------"
  echo ">> 5.1 Install kubernetes files"

  local -r K8S_SRC_DIR="/mnt/rw/k8s"

  sudo tar -xzf ${K8S_SRC_DIR}/kubernetes-server-linux-amd64.tar.gz -C /opt/
  sudo ln -sfv /opt/kubernetes/server/bin/{kube-apiserver,kube-controller-manager,kube-scheduler,kubelet,kubectl,kubeadm,kube-proxy,apiextensions-apiserver,mounter} /opt/k8s/bin/

  IP=34
  for host in "${NODES[@]}"
  do
    IP=$(( IP + 1 ))
    echo "  >> install files in host ${host} (192.168.176.${IP})..."
    ssh ${USER}@${host} "sudo tar -xzf ${K8S_SRC_DIR}/kubernetes-server-linux-amd64.tar.gz -C /opt/; \
      sudo ln -sfv /opt/kubernetes/server/bin/{kube-apiserver,kube-controller-manager,kube-scheduler,kubelet,kubectl,kubeadm,kube-proxy,apiextensions-apiserver,mounter} /opt/k8s/bin/"
  done

}

deploy_kubernetes_autoComplete()
{
  echo "-------------------------------------------------------------"
  echo ">> 5.2 Setting autoComplete"

  sudo yum install -y ${RPMDIR}/bash-completion-2.1-8.el7.noarch.rpm
  source /usr/share/bash-completion/bash_completion
  source <(kubectl completion bash)
  echo "# kubectl auto-compelete" >> ~/.bashrc
  echo "source <(kubectl completion bash)" >> ~/.bashrc

  IP=34
  for host in "${NODES[@]}"
  do
    IP=$(( IP + 1 ))
    echo "    >> install autoComplete in host ${host} (192.168.176.${IP})...."
    ssh ${USER}@${host} "  sudo yum install -y ${RPMDIR}/bash-completion-2.1-8.el7.noarch.rpm; \
      echo \"# kubectl auto-compelete\" >> ~/.bashrc; \
      echo \"source <(kubectl completion bash)\" >> ~/.bashrc"
  done
}

deploy_kubernetes_apiserver()
{
  echo "-------------------------------------------------------------"
  echo ">> 5.3 Deploy kubernetes ApiServer service"

  echo "  >> 5.3.1 create kubernetes csr file"
  pushd "${HOME}" >& /dev/null

  cat > kubernetes-csr.json << EOF
{
  "CN": "kubernetes",
  "hosts": [
    "127.0.0.1",
    "192.168.176.34",
    "192.168.176.35",
    "192.168.176.36",
    "192.168.176.37",
    "192.168.176.38",
    "192.168.176.39",
    "192.168.176.40",
    "192.168.176.41",
    "10.15.0.1",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "Chongqing",
      "L": "Chongqing",
      "O": "k8s",
      "OU": "ymliu"
    }
  ]
}
EOF

  echo "  >> 5.3.2 generate k8s certification & key files"
  sudo chown root:root kubernetes-csr.json
  sudo mv -fv kubernetes-csr.json /opt/ssl
  pushd /opt/ssl >& /dev/null
  sudo ./cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kubernetes-csr.json | sudo ./cfssljson -bare kubernetes


  echo "  >> 5.3.3 create admin csr file"
  pushd >& /dev/null
  cat > admin-csr.json << EOF
{
  "CN" : "admin",
  "hosts" : [ ],
  "key" : {
    "algo" : "rsa",
    "size" : 2048
  },
  "names" : [
    {
      "C" : "CN",
      "ST" : "Chongqing",
      "L" : "Chongqing",
      "O" : "system:masters",
      "OU" : "ymliu"
    }
  ]
}
EOF

  echo "  >> 5.3.4 generate admin certification & key files"
  sudo chown root:root admin-csr.json
  sudo mv -fv admin-csr.json /opt/ssl
  pushd >& /dev/null
  sudo ./cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | sudo ./cfssljson -bare admin

  echo "  >> 5.3.5 create apiServer token file to be used by client"
  pushd /opt/k8s/token >& /dev/null
  local -r TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
  echo "    >> generate toke : ${TOKEN}"
  echo "${TOKEN},kubelet-bootstrap,10001,\"system:kubelet-bootstrap\"" > ~/bootstrap-token.csv

  echo "   >> create basic user & passwd to certificate"
  echo "admin,admin,1" > ~/basic-auth.csv
  echo "readonly,readonly,2" >> ~/basic-auth.csv

  sudo chown root:root ~/bootstrap-token.csv ~/basic-auth.csv
  sudo mv -fv ~/bootstrap-token.csv ~/basic-auth.csv /opt/k8s/token/

  echo "  >> 5.3.6 distribute upon files & create user"
  sudo chmod 644  /opt/ssl/kubernetes-key.pem /opt/ssl/admin-key.pem
  IP=34
  for host in "${MASTERS[@]}"
  do
    IP=$(( IP + 34 ))
    echo "    copy files and create user in host ${host} (192.168.176.${IP})..."

    scp /opt/ssl/kubernetes*.pem /opt/ssl/admin*.pem /opt/k8s/token/bootstrap-token.csv /opt/k8s/token/basic-auth.csv ${USER}@${host}:~/
    ssh ${USER}@${host} "sudo chown root:root ~/kubernetes*.pem ~/admin*.pem ~/bootstrap-token.csv ~/basic-auth.csv; \
      sudo mv -fv ~/{kubernetes,admin}*.pem /opt/ssl/; \
      sudo chmod 600 /opt/ssl/kubernetes-key.pem /opt/ssl/admin-key.pem; \
      sudo mv -fv ~/{bootstrap-token,basic-auth}.csv /opt/k8s/token/; \
      sudo /opt/k8s/bin/kubectl config set-credentials admin --client-certificate=/opt/ssl/admin.pem --client-key=/opt/ssl/admin-key.pem --embed-certs=true"
  done
  sudo chmod 600 /opt/ssl/kubernetes-key.pem /opt/ssl/admin-key.pem

  echo "  >> 5.3.7 create kube-apiserver audit-policy file"
  cat > ~/audit-policy-min.yaml << EOF
# Log all requests at the Metadata level.
apiVersion: audit.k8s.io/v1beta1
kind: Policy
rules:
- level: Metadata
EOF

  echo "  >> 5.3.8 create kube-apiserver service unit file"
  cat > ~/kube-apiserver.service << EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes
After=etcd.service
Wants=etcd.service

[Service]
EnvironmentFile=/opt/k8s/conf/kube-apiserver.conf
ExecStart=/opt/k8s/bin/kube-apiserver \\
  --enable-admission-plugins=\${KUBE_ADMISSION_CONTROL} \\
  --anonymous-auth=false \\
  --advertise-address=\${KUBE_API_ADDRESS} \\
  --bind-address=\${KUBE_API_ADDRESS} \\
  --authorization-mode=Node,RBAC \\
  --runtime-config=api/all=true \\
  --enable-bootstrap-token-auth \\
  --token-auth-file=\${KUBE_TOKEN_AUTH_FILE} \\
  --service-cluster-ip-range=\${KUBE_SERVICE_CLUSTER_IP_RANGE} \\
  --service-node-port-range=\${KUBE_SERVICE_NODE_PORT} \\
  --tls-cert-file=\${KUBE_TLS_CERT_FILE} \\
  --tls-private-key-file=\${KUBE_TLS_KEY_FILE} \\
  --client-ca-file=\${KUBE_CA_FILE} \\
  --kubelet-client-certificate=\${KUBE_TLS_CERT_FILE} \\
  --kubelet-client-key=\${KUBE_TLS_KEY_FILE} \\
  --service-account-key-file=\${KUBE_CA_KEY_FILE} \\
  --etcd-servers=\${KUBE_ETCD_SERVERS} \\
  --etcd-cafile=\${KUBE_CA_FILE} \\
  --etcd-certfile=\${ETCD_CERT_FILE} \\
  --etcd-keyfile=\${ETCD_KEY_FILE} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-policy-file=\${KUBE_AUDIT_POLICY_CONF} \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=\${KUBE_AUDIT_POLICY_PATH} \\
  --logtostderr=true \\
  --log-dir=\${KUBE_LOG_DIR} \\
  --v=4
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  echo "  >> 5.3.8 create kube-apiserver environment configuration file"
  cat > ~/kube-apiserver.conf << EOF
## kubernetes apiserver system config

## The address on the local server to listen to.
KUBE_API_ADDRESS="##hostip##"

## The port on the local server to listen on.
KUBE_API_PORT="--port=8080"

## Port minion listen on.
KUBELET_PORT="--kubelet-port=10250"

## Comma separated list of nodes in etcd cluster
KUBE_ETCD_SERVERS="https://192.168.176.35:2379,https://192.168.176.36:2379,https://192.168.176.37:2379"

## Address range to user for services
KUBE_SERVICE_CLUSTER_IP_RANGE="10.15.0.0/16"

## default admission control policies
KUBE_APISERVER_ADMISSION_CONTROL="NamespaceLifecycle,NamespaceExists,LimitRanger,ServiceAccount,ResourceQuota,NodeRestriction,ValidatingAdmissionWebhook,MutatingAdmissionWebhook"

## Secuirty Port listen on.
KUBE_SECURE_PORT=6443

## Token file for authorication.
KUBE_TOKEN_AUTH_FILE="/opt/k8s/token/bootstrap-token.csv"

## Port for node connect listen on the server.
KUBE_SERVICE_NODE_PORT="30000-50000"

## Enable audit policy
KUBE_AUDIT_POLICY="/opt/k8s/yaml/audit-policy-min.yaml"

## Cert Files
#
## Kubernetes ca file
KUBE_TLS_CERT_FILE="/opt/ssl/kubernetes.pem"
KUBE_TLS_KEY_FILE="/opt/ssl/kubernetes-key.pem"
#
## CA File
KUBE_CA_FILE="/opt/ssl/ca.pem"
KUBE_CA_KEY_FILE="/opt/ssl/ca-key.pem"
#
## ETCD File
ETCD_CERT_FILE="/opt/ssl/etcd.pem"
ETCD_KEY_FILE="/opt/ssl/etcd-key.pem"

## Log directory
KUBE_LOG_DIR="${APP_DIR}/k8s/apiserver"

## Audit
#
## Audit policy configuration
KUBE_AUDIT_POLICY_CONF="/opt/k8s/yaml/audit-policy-min.yaml"
## Audit policy log files
KUBE_AUDIT_POLICY_PATH="${APP_DIR}/k8s/apiserver/api-audit.log"
EOF

  echo "  >> 5.3.9 distribute files ..."
  IP=34
  for host in "${MASTERS[@]}"
  do
    IP=$(( IP + 1 ))
    echo " copy files to host ${host} (192.168.176.${IP}) and enable service..."
    scp ~/audit-policy-min.yaml ~/kube-apiserver.service ~/kube-apiserver.conf ${USER}@${host}:~/
    ssh ${USER}@${host} "sed -i \"s/\#\#hostip\#\#/192.168.176.${IP}/g\" ~/kube-apiserver.conf; \
      sudo chown root:root ~/audit-policy-min.yaml ~/kube-apiserver.service ~/kube-apiserver.conf; \
      sudo mv -fv ~/audit-policy-min.yaml /opt/k8s/yaml/; \
      sudo mv -fv ~/kube-apiserver.service /etc/systemd/system/; \
      sudo mv -fv ~/kube-apiserver.conf /opt/k8s/conf/; \
      sudo systemctl daemon-reload; \
      sudo systemctl enable kube-apiserver; \
      sudo systemctl start kube-apiserver"
  done

  sudo rm -fv ~/kube-apiserver.service ~/kube-apiserver.conf ~/audit-policy-min.yaml
}

deploy_kubernetes_kubelet_config()
{
  echo "-------------------------------------------------------------"
  echo ">> 5.4 Create kubectl kubeconfig file"

  echo "  >> 5.4.1 create kubectl config local file..."
  mkdir ~/.kube
  pushd ~/.kube >& /dev/null
  local -r KUBECONFIG="${HOME}/.kube/config"
  sudo ${KUBECTL} config set-cluster kubernetes --certificate-authority=/opt/ssl/ca.pem --embed-certs=true --server=https://192.168.176.34:8443 --kubeconfig=${KUBECONFIG}
  sudo ${KUBECTL} config set-credentials admin --client-certificate=/opt/ssl/admin.pem --client-key=/opt/ssl/admin-key.pem --embed-certs=true --kubeconfig=${KUBECONFIG}
  sudo ${KUBECTL} config set-context kubernetes --cluster=kubernetes --user=admin --kubeconfig=${KUBECONFIG}
  sudo ${KUBECTL} config use-context kubernetes --kubeconfig=${KUBECONFIG}
  sudo chown ymliu:ymliu ${KUBECONFIG}
  sudo mkdir -pv /root/.kube
  sudo cp -fv ${KUBECONFIG} /root/.kube/

  echo "  >> 5.4.2 distribute kubectl config file ..."
  IP=34
  for host in "${NODES[@]}"
  do
    IP=$(( IP + 1 ))
    echo "    copy kubectl config file to host ${host} (192.168.176.${IP})..."
    ssh ${USER}@${host} "mkdir -p ~/.kube"
    scp ${KUBECONFIG} ${USER}@${host}:~/.kube/
    ssh ${USER}@${host} "sudo mkdir -pv /root/.kube; \
      sudo cp -fv ~/.kube/config /root/.kube/"
  done

  echo "  >> 5.4.3 grant to visit kubelet api"
  ssh ${USER}@"k8s-master1" "sudo ${KUBECTL} create clusterrolebinding kube-apiserver:kubelet-apis --clusterrole=system:kubelet-api-admin --user=kubernetes"
}

deploy_kubernetes_controller()
{
  echo "-------------------------------------------------------------"
  echo ">> 5.5 Deploy kubernetes kube-controller-manager"

  echo "  >> 5.5.1 create kube-controller-manager certificate file"
  local -r CSRFILE="kube-controller-manager-csr.json"
  cat > ${HOME}/${CSRFILE} << EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "hosts": [
    "127.0.0.1",
    "192.168.176.35",
    "192.168.176.36",
    "192.168.176.37"
  ],
  "names":[
    {
      "C" : "CN",
      "ST": "Chongqing",
      "L" : "Chongqing",
      "O" : "system:kube-controller-manager",
      "OU": "ymliu"
    }
  ]
}
EOF

  pushd "/opt/ssl" >& /dev/null
  sudo mv -fv ${HOME}/${CSRFILE} ${CSRFILE}
  sudo chown root:root ${CSRFILE}
  sudo ./cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-controller-manager-csr.json | sudo ./cfssljson -bare kube-controller-manager

  echo "  >> 5.5.2 create kube-controller-manager kubeconfig file"
  pushd "/opt/k8s/conf" >& /dev/null
  local -r KUBECONFIG="${PWD}/kube-controller-manager.kubeconfig"
  sudo ${KUBECTL} config set-cluster kubernetes --certificate-authority=/opt/ssl/ca.pem --embed-certs=true --server=https://192.168.176.34:8443 --kubeconfig=${KUBECONFIG}
  sudo ${KUBECTL} config set-credentials system:kube-controller-manager --client-certificate=/opt/ssl/kube-controller-manager.pem --client-key=/opt/ssl/kube-controller-manager-key.pem --embed-certs=true --kubeconfig=${KUBECONFIG}
  sudo ${KUBECTL} config set-context system:kube-controller-manager --cluster=kubernetes --user=system:kube-controller-manager --kubeconfig=${KUBECONFIG}
  sudo ${KUBECTL} config use-context system:kube-controller-manager --kubeconfig=${KUBECONFIG}

  echo "  >> 5.5.3 create kube-controller-manager service unit file"
  cat > ~/kube-controller-manager.service << EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes
After=kube-apiserver.service
Wants=kube-apiserver.service

[Service]
EnvironmentFile=/opt/k8s/conf/kube-controller-manager.conf
ExecStart=/opt/k8s/bin/kube-controller-manager \\
  --bind-address=127.0.0.1 \\
  --master=http://127.0.0.1:8080 \\
  --kubeconfig=\${KUBE_CONTROLLER_CONFIG_FILE} \\
  --service-cluster-ip-range=\${KUBE_SERVICE_CLUSTER_IP_RANGE} \\
  --cluster-cidr=\${KUBE_PODS_CLUSTER_CIDR} \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=\${CA_FILE} \\
  --cluster-signing-key-file=\${CA_KEY_FILE} \\
  --experimental-cluster-signing-duration=8760h \\
  --root-ca-file=\${CA_FILE} \\
  --client-ca-file=\${CA_FILE} \\
  --service-account-private-key-file=\${CA_KEY_FILE} \\
  --leader-elect=true \\
  --feature-gates=RotateKubeletServerCertificate=true \\
  --controllers=*,bootstrapsigner,tokencleaner \\
  --horizontal-pod-autoscaler-sync-period=10s \\
  --tls-cert-file=\${KUBE_CONTROLLER_MANAGER_CERT_FILE} \\
  --tls-private-key-file=\${KUBE_CONTROLLER_MANAGER_KEY_FILE} \\
  --use-service-account-credentials=true \\
  --alsologtostderr=true \\
  --logtostderr=false \\
  --log-dir=\${KUBE_CONTROLLER_MANAGER_LOG_DIR} \\
  --v=4

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  echo "  >> 5.5.4 create kube-controller-manager environment config file"
  cat > ~/kube-controller-manager.conf << EOF
###
# The following values are used to configure the kubernetes controller-Manager
#
# defaults from config and apiserver should be adequate

## configuration file
KUBE_CONTROLLER_CONFIG_FILE="${KUBECONFIG}"

## certificate files
CA_FILE="/opt/ssl/ca.pem"
CA_KEY_FILE="/opt/ssl/ca-key.pem"

## certificate files
KUBE_CONTROLLER_MANAGER_CERT_FILE="/opt/ssl/kube-controller-manager.pem"
KUBE_CONTROLLER_MANAGER_KEY_FILE="/opt/ssl/kube-controller-manager-key.pem"

## network configure
KUBE_SERVICE_CLUSTER_IP_RANGE="10.15.0.0/16"
KUBE_PODS_CLUSTER_CIDR="10.16.0.0/16"

## log directory
KUBE_CONTROLLER_MANAGER_LOG_DIR="${APP_DIR}/k8s/controller"

EOF

  echo "  >> 5.5.5 distribute files to every master host"
  IP=34
  sudo chmod 644 /opt/ssl/kube-controller-manager-key.pem ${KUBECONFIG}
  for host in "${MASTERS[@]}"
  do
    IP=$(( IP + 1 ))
    echo "    deploy kube-controller-manager in host ${host} (192.168.176.${IP})..."
    scp /opt/ssl/kube-controller-manager*.pem ${KUBECONFIG} ~/kube-controller-manager.service ~/kube-controller-manager.conf ${USER}@${host}:~/
    ssh ${USER}@${host} "sudo chown root:root ~/kube-controller-manager*.*; \
      sudo mv -fv ~/kube-controller-manager*.pem /opt/ssl/; \
      sudo chmod 600 /opt/ssl/kube-controller-manager-key.pem; \
      sudo mv -fv ~/kube-controller-manager.kubeconfig /opt/k8s/conf/; \
      sudo chmod 600 /opt/k8s/conf/kube-controller-manager.kubeconfig; \
      sudo mv -fv ~/kube-controller-manager.service /etc/systemd/system/; \
      sudo mv -fv ~/kube-controller-manager.conf /opt/k8s/conf; \
      sudo systemctl daemon-reload; \
      sudo systemctl enable kube-controller-manager; \
      sudo systemctl start kube-controller-manager"
  done

  sudo chmod 600 /opt/ssl/kube-controller-manager-key.pem ${KUBECONFIG}
  rm -fv ~/kube-controller-manager.service ~/kube-controller-manager.conf
}

deploy_kubernetes_scheduler()
{
  echo "-------------------------------------------------------------"
  echo ">> 5.6 Deploy kubernetes kube-scheduler"

  echo "  >> 5.6.1 create kube-scheduler certificate file"
  local -r CSRFILE="kube-scheduler-csr.json"
  cat > ${HOME}/${CSRFILE} << EOF
{
  "CN" : "system:kube-scheduler",
  "hosts" : [
    "127.0.0.1",
    "192.168.176.35",
    "192.168.176.36",
    "192.168.176.37"
  ],
  "key" : {
    "algo" : "rsa",
    "size" : 2048
  },
  "names" : [
    {
      "C" : "CN",
      "ST" : "Chongqing",
      "L" : "Chongqing",
      "O" : "system:kube-scheduler",
      "OU" : "ymliu"
    }
  ]
}
EOF

  pushd "/opt/ssl" >& /dev/null
  sudo mv -fv ${HOME}/${CSRFILE} ${CSRFILE}
  sudo chown root:root ${CSRFILE}
  sudo ./cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-scheduler-csr.json | sudo ./cfssljson -bare kube-scheduler

  echo "  >> 5.6.2 create kube-controller-manager kubeconfig file"
  pushd "/opt/k8s/conf" >& /dev/null
  local -r KUBECONFIG="${PWD}/kube-scheduler.kubeconfig"
  sudo ${KUBECTL} config set-cluster kubernetes --certificate-authority=/opt/ssl/ca.pem --embed-certs=true --server=https://192.168.176.34:8443 --kubeconfig=${KUBECONFIG}
  sudo ${KUBECTL} config set-credentials system:kube-scheduler --client-certificate=/opt/ssl/kube-scheduler.pem --client-key=/opt/ssl/kube-scheduler-key.pem --embed-certs=true --kubeconfig=${KUBECONFIG}
  sudo ${KUBECTL} config set-context system:kube-scheduler --cluster=kubernetes --user=system:kube-scheduler --kubeconfig=${KUBECONFIG}
  sudo ${KUBECTL} config use-context system:kube-scheduler --kubeconfig=${KUBECONFIG}

  echo "  >> 5.6.3 create kube-scheduler service unit file"
  cat > ~/kube-scheduler.service << EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes
After=kube-apiserver.service
Wants=kube-apiserver.service

[Service]
EnvironmentFile=/opt/k8s/conf/kube-scheduler.conf
ExecStart=/opt/k8s/bin/kube-scheduler \\
  --bind-address=127.0.0.1 \\
  --kubeconfig=\${KUBE_SCHEDULER_CONFIG} \\
  --leader-elect=true \\
  --alsologtostderr=true \\
  --logtostderr=false \\
  --log-dir=\${KUBE_SCHEDULER_LOG_DIR} \\
  --v=4
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  echo "  >> 5.6.4 create kube-scheduler environment config file"
  cat > ~/kube-scheduler.conf << EOF
##
# The following values are used to configure the kubernetes scheduler
#
# defaults from config and apiserver should be adequate

## configuration file
KUBE_SCHEDULER_CONFIG=/opt/k8s/conf/kube-scheduler.kubeconfig

## log direcory
KUBE_SCHEDULER_LOG_DIR=${APP_DIR}/k8s/scheduler
EOF

  echo "  >> 5.6.5 distribute files to every master host"
  IP=34
  sudo chmod 644 /opt/ssl/kube-scheduler-key.pem ${KUBECONFIG}
  for host in "${MASTERS[@]}"
  do
    IP=$(( IP + 1 ))
    echo "    deploy kube-scheduler in host ${host} (192.168.176.${IP})..."
    scp /opt/ssl/kube-scheduler*.pem ${KUBECONFIG} ~/kube-scheduler.service ~/kube-scheduler.conf ${USER}@${host}:~/
    ssh ${USER}@${host} "sudo chown root:root ~/kube-scheduler*.pem ~/kube-scheduler.*; \
      sudo mv -fv ~/kube-scheduler*.pem /opt/ssl/; \
      sudo chmod 600 /opt/ssl/kube-scheduler-key.pem; \
      sudo mv -fv ~/kube-scheduler.kubeconfig /opt/k8s/conf/; \
      sudo chmod 600 /opt/k8s/conf/kube-scheduler.kubeconfig; \
      sudo mv -fv ~/kube-scheduler.service /etc/systemd/system/; \
      sudo mv -fv ~/kube-scheduler.conf /opt/k8s/conf/; \
      sudo systemctl daemon-reload; \
      sudo systemctl enable kube-scheduler; \
      sudo systemctl start kube-scheduler"
  done

  sudo chmod 600 /opt/ssl/kube-scheduler-key.pem ${KUBECONFIG}
  rm -fv ~/kube-scheduler.*
}

deploy_kubernetes_node_env()
{
  echo "-------------------------------------------------------------"
  echo ">> 5.7 Set kubernetes workNode environment"

  echo "  >> 5.7.1 create kube-proxy csr file"
  cat >~/kube-proxy-csr.json << EOF
{
    "CN": "system:kube-proxy",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "Chongqing",
            "L": "Chongqing",
            "O": "system:kube-proxy",
            "OU": "ymliu"
        }
    ]
}
EOF

  echo "  >> 5.7.2 create kube-proxy certificate files"
  pushd /opt/ssl >& /dev/null
  sudo mv -fv ~/kube-proxy-csr.json /opt/ssl/
  sudo ./cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-proxy-csr.json | sudo ./cfssljson -bare kube-proxy

  echo "  >> 5.7.3 create bootstrap.kubeconfig"
  local -r KUBE_APISERVER="https://192.168.176.34:8443"
  local -r CAFILE="/opt/ssl/ca.pem"
  local -r TOKEN=$(sudo cat /opt/k8s/token/bootstrap-token.csv | awk -F ',' '{print $1}')
  local KUBECONFIG="/opt/k8s/conf/bootstrap.kubeconfig"

  sudo ${KUBECTL} config set-cluster kubernetes --certificate-authority=${CAFILE} --embed-certs=true --server=${KUBE_APISERVER} --kubeconfig=${KUBECONFIG}
  sudo ${KUBECTL} config set-credentials kubelet-bootstrap --token=${TOKEN} --kubeconfig=${KUBECONFIG}
  sudo ${KUBECTL} config set-context default --cluster=kubernetes --user=kubelet-bootstrap --kubeconfig=${KUBECONFIG}
  sudo ${KUBECTL} config use-context default --kubeconfig=${KUBECONFIG}

  echo "  >> 5.7.4 create kubelet.kubeconfig"
  KUBECONFIG="/opt/k8s/conf/kubelet.kubeconfig"
  sudo ${KUBECTL} config set-cluster kubernetes --certificate-authority=${CAFILE} --embed-certs=true --server=${KUBE_APISERVER} --kubeconfig=${KUBECONFIG}
  sudo ${KUBECTL} config set-credentials kubelet --token=${TOKEN} --kubeconfig=${KUBECONFIG}
  sudo ${KUBECTL} config set-context default --cluster=kubernetes --user=kubelet --kubeconfig=${KUBECONFIG}
  sudo ${KUBECTL} config use-context default --kubeconfig=${KUBECONFIG}

  echo "  >> 5.7.5 create kube-proxy.kubeconfig"
  KUBECONFIG="/opt/k8s/conf/kube-proxy.kubeconfig"
  sudo ${KUBECTL} config set-cluster kubernetes --certificate-authority=${CAFILE} --embed-certs=true --server=${KUBE_APISERVER} --kubeconfig=${KUBECONFIG}
  sudo ${KUBECTL} config set-credentials kube-proxy --client-certificate=/opt/ssl/kube-proxy.pem --client-key=/opt/ssl/kube-proxy-key.pem --embed-certs=true --kubeconfig=${KUBECONFIG}
  sudo ${KUBECTL} config set-context default --cluster=kubernetes --user=kube-proxy --kubeconfig=${KUBECONFIG}
  sudo ${KUBECTL} config use-context default --kubeconfig=${KUBECONFIG}

  echo "  >> 5.7.6 distribute files"
  sudo chmod 644 /opt/ssl/kube-proxy-key.pem /opt/k8s/conf/bootstrap.kubeconfig /opt/k8s/conf/kubelet.kubeconfig /opt/k8s/conf/kube-proxy.kubeconfig
  IP=34
  for host in ${NODES[@]}
  do
    IP=$(( IP + 1 ))
    echo "    copy files to host ${host} (192.168.176.${IP})..."
    scp /opt/ssl/kube-proxy*.pem /opt/k8s/conf/bootstrap.kubeconfig /opt/k8s/conf/kubelet.kubeconfig /opt/k8s/conf/kube-proxy.kubeconfig ${USER}@${host}:~/
    ssh ${USER}@${host} "sudo chown root:root ~/kube-proxy*.pem ~/bootstrap.kubeconfig ~/kubelet.kubeconfig ~/kube-proxy.kubeconfig; \
      sudo chmod 600 ~/kube-proxy-key.pem ~/bootstrap.kubeconfig ~/kubelet.kubeconfig ~/kube-proxy.kubeconfig; \
      sudo mv -fv ~/kube-proxy*.pem /opt/ssl/; \
      sudo mv -fv ~/bootstrap.kubeconfig ~/kubelet.kubeconfig ~/kube-proxy.kubeconfig /opt/k8s/conf/"
  done
  sudo chmod 600 /opt/ssl/kube-proxy-key.pem /opt/k8s/conf/bootstrap.kubeconfig /opt/k8s/conf/kubelet.kubeconfig /opt/k8s/conf/kube-proxy.kubeconfig

  echo "  >> 5.7.7 binding clusterrole kubelet-bootstrap"
  ssh ${USER}@k8s-master1 "sudo ${KUBECTL} create clusterrolebinding kubelet-bootstrap --clusterrole=system:node-bootstrapper --user=kubelet-bootstrap"
}

deploy_kubernetes_kubelet()
{
  echo "-------------------------------------------------------------"
  echo ">> 5.8 Install kubernetes kubelet"

  echo "  >> 5.8.1 Install ipvsadm, bridge, conntrack."
  IP=34
  for host in "${NODES[@]}"
  do
    IP=$(( IP + 1 ))
    echo "  install ipvsadm etc. tools in host ${host} (192.168.176.${IP})..."
    ssh ${USER}@${host} "sudo yum install -y ${RPMDIR}/ipvsadm-1.27-8.el7.x86_64.rpm \
        ${RPMDIR}/bridge-utils-1.5-9.el7.x86_64.rpm \
        ${RPMDIR}/conntrack-tools-1.4.4-7.el7.x86_64.rpm \
        ${RPMDIR}/libnetfilter_cthelper-1.0.0-11.el7.x86_64.rpm \
        ${RPMDIR}/libnetfilter_cttimeout-1.0.0-7.el7.x86_64.rpm \
        ${RPMDIR}/libnetfilter_queue-1.0.2-2.el7_2.x86_64.rpm"
  done

  echo "  >> 5.8.2 create kubelet service file"
  cat > ~/kubelet.service << EOF
[Unit]
Description=Kubernetes Kubelet Server
Documentation=https://github.com/kubernetes/kubernetes
After=docker.service
Requires=docker.service

[Service]
WorkingDirectory=${APP_DIR}/k8s/kubelet
EnvironmentFile=/opt/k8s/conf/kubelet.conf
ExecStart=/opt/k8s/bin/kubelet \\
  --hostname-override=\${KUBELET_HOSTNAME_OVERRIDE} \\
  --network-plugin=\${KUBELET_NETWORK_PLUGIN} \\
  --cni-conf-dir=/etc/cni/net.d \\
  --cni-bin-dir=/opt/cni/bin \\
  --pod_infra_container_image=\${KUBELET_POD_INFRA_CONTAINER_IMAGE} \\
  --kubeconfig=\${KUBELET_KUBECONFIG} \\
  --bootstrap-kubeconfig=\${KUBELET_BOOTSTRAP_KUBECONFIG} \\
  --config=\${KUBELET_CONFIG} \\
  --cert-dir=\${KUBELET_CERT_DIR} \\
  --log-dir=\${KUBELET_LOG_DIR} \\
  --logtostderr=false \\
  --v=4
Restart=on-failure
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

  echo "  >> 5.8.3 create kubelet environment configuration file"
  cat > ~/kubelet.conf << EOF
## kubernetes kubelet(minion) config
#
##

## set ip of current minion
KUBELET_HOSTNAME_OVERRIDE="##hostip##"

## use private registry if available
KUBELET_POD_INFRA_CONTAINER_IMAGE="gcr.io/google_containers/pause-amd64:3.1"

## bootstrap config file
KUBELET_BOOTSTRAP_KUBECONFIG="/opt/k8s/conf/bootstrap.kubeconfig"

## kubelet config file
KUBELET_KUBECONFIG="/opt/k8s/conf/kubelet.kubeconfig"

## config yaml file
KUBELET_CONFIG="/opt/k8s/yaml/kubelet.yaml"

## directory of certification files
KUBELET_CERT_DIR="/opt/ssl"

## network cni plugins
KUBELET_NETWORK_PLUGIN="cni"

## directory of log files
KUBELET_LOG_DIR="${APP_DIR}/k8s/kubelet"
EOF

  echo "  >> 5.8.4 create kubelet yaml file"
  cat > ~/kubelet.yaml << EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: 0.0.0.0
port: 10250
readOnlyPort: 10255
cgroupDriver: cgroupfs
clusterDNS: ["10.15.0.2"]
clusterDomain: cluster.local
failSwapOn: false
authentication:
  anonymous:
    enabled: true
  x509:
    clientCAFile: /opt/ssl/ca.pem
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 5m0s
    cacheUnauthorizedTTL: 30s
evictionHard:
  imagefs.available: 15%
  memory.available: 100Mi
  nodefs.available: 10%
  nodefs.inodesFree: 5%
maxOpenFiles: 100000
maxPods: 110
EOF

  echo "  >> 5.8.5 distribute files and start kubelet service"
  IP=34
  for host in "${NODES[@]}"
  do
    IP=$(( IP + 1 ))
    echo "    copying files to host ${host} (192.168.176.${IP})..."
    scp ~/kubelet.service ~/kubelet.conf ~/kubelet.yaml ${USER}@${host}:~/
    ssh ${USER}@${host} "sed -i \"s/\#\#hostip\#\#/192.168.176.${IP}/g\" ~/kubelet.conf; \
      sudo chown root:root ~/kubelet.service ~/kubelet.conf ~/kubelet.yaml; \
      sudo mv -fv ~/kubelet.service /etc/systemd/system/; \
      sudo mv -fv ~/kubelet.conf /opt/k8s/conf/; \
      sudo mv -fv ~/kubelet.yaml /opt/k8s/yaml/; \
      sudo docker load -i /mnt/rw/docker-image/gcr.io/google_containers/pause-amd64.docker.tar; \
      sudo docker load -i /mnt/rw/docker-image/gcr.io/google_containers/kube-proxy-amd64.docker.tar; \
      sudo systemctl daemon-reload; \
      sudo systemctl enable kubelet; \
      sudo systemctl start kubelet"
  done
  rm -fv ~/kubelet.service ~/kubelet.conf ~/kubelet.yaml

  echo "  >> 5.8.6 view csr and approve TLS requests after 5 seconds"
  sleep 5s
  ssh ${USER}@k8s-master1 "sudo ${KUBECTL} get csr; \
    sudo ${KUBECTL} get csr | grep 'Pending' | awk 'NR>0{print \$1}' | xargs sudo ${KUBECTL} certificate approve"
}

deploy_kubernetes_proxy()
{
  echo "-------------------------------------------------------------"
  echo ">> 5.9 Deploy kubernetes kube-proxy"

  echo "  >> 5.9.1 create kube-proxy service file"
  cat > ~/kube-proxy.service << EOF
[Unit]
Description=Kubernetes Kube-Proxy Server
Documentation=https://github.com/kubernetes/kubernetes
After=network.target

[Service]
EnvironmentFile=/opt/k8s/conf/kube-proxy.conf
WorkingDirectory=${APP_DIR}/k8s/proxy
ExecStart=/opt/k8s/bin/kube-proxy \\
  --config=\${KUBE_PROXY_CONFIG} \\
  --cluster-cidr=\${KUBE_CLUSTER_CIDR} \\
  --log-dir=\${KUBE_PROXY_DIR} \\
  --logtostderr=true \\
  --alsologtostderr=true \\
  --v=4
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

  echo "  >> 5.9.2 create kube-proxy environment configuration file"
  cat > ~/kube-proxy.conf << EOF
## kubernetes kube-proxy system config

## Ip address of local machine, modify it
KUBE_PROXY_ADDRESS="##hostip##"

## Setting kubeconfig file.
KUBE_PROXY_KUBECONFIG="/opt/k8s/conf/kube-proxy.kubeconfig"
KUBE_PROXY_CONFIG="/opt/k8s/yaml/kube-proxy.yaml"

## Setting ip range for pods
KUBE_CLUSTER_CIDR="10.16.0.0/16"

## Setting log directory
KUBE_PROXY_DIR="${APP_DIR}/k8s/proxy"

KUBE_FEATURE_GATES="SupportIPVSProxyMode=true"
KUBE_PROXY_MODE="ipvs"
EOF

  echo "  >> 5.9.3 create kube-proxy yaml file"
  cat > ~/kube-proxy.yaml << EOF
apiVersion: kubeproxy.config.k8s.io/v1alpha1
bindAddress: ##hostip##
clientConnection:
  kubeconfig: /opt/k8s/conf/kube-proxy.kubeconfig
clusterCIDR: 10.16.0.0/16
healthzBindAddress: ##hostip##:10256
hostnameOverride: ##hostip##
ipvs:
  minSyncPeriod: 5s
  scheduler: rr
kind: KubeProxyConfiguration
metricsBindAddress: ##hostip##:10249
mode: ipvs
EOF

  echo "  >> 5.9.4 distribute files and start service"
  IP=34
  for host in "${NODES[@]}"
  do
    IP=$(( IP + 1 ))
    echo "    copy files to host to ${host} (192.168.176.${IP}) and enable & start service..."
    scp ~/kube-proxy.service ~/kube-proxy.conf ~/kube-proxy.yaml ${USER}@${host}:~/
    ssh ${USER}@${host} "sed -i \"s/\#\#hostip\#\#/192.168.176.${IP}/g\" ~/kube-proxy.conf; \
      sed -i \"s/\#\#hostip\#\#/192.168.176.${IP}/g\" ~/kube-proxy.yaml; \
      sudo chown root:root ~/kube-proxy.service ~/kube-proxy.conf ~/kube-proxy.yaml; \
      sudo mv -fv ~/kube-proxy.service /etc/systemd/system/; \
      sudo mv -fv ~/kube-proxy.conf /opt/k8s/conf/; \
      sudo mv -fv ~/kube-proxy.yaml /opt/k8s/yaml/; \
      sudo systemctl daemon-reload; \
      sudo systemctl enable kube-proxy; \
      sudo systemctl start kube-proxy"
  done

  rm -fv ~/kube-proxy.service ~/kube-proxy.conf ~/kube-proxy.yaml

  echo "  >> 5.9.5 view lvs status"
  ssh ${USER}@k8s-master1 "sudo ipvsadm -Ln"
}

deploy_kubernetes()
{
  echo "============================================================="
  echo "5. Deploy kubernetes"

  deploy_kubernetes_install
  echo "  ---- wait 5 seconds ----"
  sleep 5s

  deploy_kubernetes_autoComplete
  deploy_kubernetes_apiserver
  echo "  ---- wait 5 seconds ----"
  sleep 5s

  deploy_kubernetes_kubelet_config
  echo "  ---- wait 5 seconds ----"
  sleep 5s

  deploy_kubernetes_controller
  echo "  ---- wait 5 seconds ----"
  sleep 5s

  deploy_kubernetes_scheduler
  echo "  ---- wait 5 seconds ----"
  sleep 5s

  deploy_kubernetes_node_env
  deploy_kubernetes_kubelet
  echo "  ---- wait 5 seconds ----"
  sleep 5s

  deploy_kubernetes_proxy
  echo "  ---- wait 5 seconds ----"
  sleep 5s

  echo -e "\n>> Ending of deploying all kubernetes\n"
}

deploy_calico_install()
{
  echo "-------------------------------------------------------------"
  echo ">> 6.1 install calico files"

  echo "  >> 6.1.1 install calico files..."
  IP=34
  for host in "${NODES[@]}"
  do
    IP=$(( IP + 1 ))
    echo "    install calico files in host ${host} (192.168.176.${IP})..."
    ssh ${USER}@${host} "sudo tar -xzf /mnt/rw/calico/cni-plugins-linux-amd64-v0.8.6.tgz -C /opt/cni/; \
      sudo ln -sf /opt/cni/{bandwidth,loopback,portmap,tuning} /opt/cni/bin/; \
      sudo chmod +x /opt/cni/bin/*; \
      sudo cp -fv /mnt/rw/calico/calico-amd64 /opt/calico/bin/calico; \
      sudo cp -fv /mnt/rw/calico/calico-ipam-amd64 /opt/calico/bin/calico-ipam; \
      sudo cp -fv /mnt/rw/calico/calicoctl-linux-amd64 /opt/calico/bin/calicoctl; \
      sudo ln -sf /opt/calico/bin/calico-ipam /opt/calico/bin/calico /opt/cni/bin/"
  done

  echo "  >> 6.1.2 create calico profile file"
  cat > ~/calico.sh << EOF
CALICO_HOME="/opt/calico"
export PATH=\$PATH:\$CALICO_HOME/bin
EOF

  echo "  >> 6.1.3 crate cni network configuration file"
  cat > ~/10-calico.conf << EOF
{
  "name": "calico-k8s-network",
  "cniVersion": "0.3.1",
  "type": "calico",
  "etcd_endpoints": "https://192.168.176.35:2379,https://192.168.176.36:2379,https://192.168.176.37:2379",
  "etcd_key_file": "/opt/ssl/etcd-key.pem",
  "etcd_cert_file": "/opt/ssl/etcd.pem",
  "etcd_ca_cert_file": "/opt/ssl/ca.pem",
  "log_level": "info",
  "mtu": 1500,
  "ipam": {
    "type": "calico-ipam"
  },
  "policy": {
    "type": "k8s"
  },
  "kubernetes":{
    "kubeconfig": "/opt/k8s/conf/kubelet.kubeconfig"
  }
}
EOF

  echo "  >> 6.1.4 create interactive file between calico and etcd"
  cat > ~/calicoctl.cfg << EOF
apiVersion: projectcalico.org/v3
kind: CalicoAPIConfig
metadata:
spec:
  datastoreType: "etcdv3"
  etcdEndpoints: "https://192.168.176.35:2379,https://192.168.176.36:2379,https://192.168.176.37:2379"
  etcdKeyFile: "/opt/ssl/etcd-key.pem"
  etcdCertFile: "/opt/ssl/etcd.pem"
  etcdCACertFile: "/opt/ssl/ca.pem"
EOF

  echo ">> 6.1.5 create calico yaml file"
  local -r ETCD_CA=$(sudo cat /opt/ssl/ca.pem | base64 -w 0)
  local -r ETCD_KEY=$(sudo cat /opt/ssl/etcd-key.pem | base64 -w 0)
  local -r ETCD_CERT=$(sudo cat /opt/ssl/etcd.pem | base64 -w 0)
  cat > ~/calico.yaml << EOF
---
# Source: calico/templates/calico-etcd-secrets.yaml
# The following contains k8s Secrets for use with a TLS enabled etcd cluster.
# For information on populating Secrets, see http://kubernetes.io/docs/user-guide/secrets/
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: calico-etcd-secrets
  namespace: kube-system
data:
  # Populate the following with etcd TLS configuration if desired, but leave blank if
  # not using TLS for etcd.
  # The keys below should be uncommented and the values populated with the base64
  # encoded contents of each file that would be associated with the TLS data.
  # Example command for encoding a file contents: cat <file> | base64 -w 0
  etcd-key: "${ETCD_KEY}"
  etcd-cert: "${ETCD_CERT}"
  etcd-ca: "${ETCD_CA}"
---
# Source: calico/templates/calico-config.yaml
# This ConfigMap is used to configure a self-hosted Calico installation.
kind: ConfigMap
apiVersion: v1
metadata:
  name: calico-config
  namespace: kube-system
data:
  # Configure this with the location of your etcd cluster.
  etcd_endpoints: "https://192.168.176.35:2379,https://192.168.176.36:2379,https://192.168.176.37:2379"
  # If you're using TLS enabled etcd uncomment the following.
  # You must also populate the Secret below with these files.
  etcd_ca: "/calico-secrets/etcd-ca"   # "/calico-secrets/etcd-ca"
  etcd_cert: "/calico-secrets/etcd-cert" # "/calico-secrets/etcd-cert"
  etcd_key: "/calico-secrets/etcd-key"  # "/calico-secrets/etcd-key"
  # Typha is disabled.
  typha_service_name: "none"
  # Configure the backend to use.
  calico_backend: "bird"
  # Configure the MTU to use for workload interfaces and the
  # tunnels.  For IPIP, set to your network MTU - 20; for VXLAN
  # set to your network MTU - 50.
  veth_mtu: "1500"

  # The CNI network configuration to install on each node.  The special
  # values in this config will be automatically populated.
  cni_network_config: |-
    {
      "name": "k8s-pod-network",
      "cniVersion": "0.3.1",
      "plugins": [
        {
          "type": "calico",
          "log_level": "info",
          "etcd_endpoints": "__ETCD_ENDPOINTS__",
          "etcd_key_file": "__ETCD_KEY_FILE__",
          "etcd_cert_file": "__ETCD_CERT_FILE__",
          "etcd_ca_cert_file": "__ETCD_CA_CERT_FILE__",
          "mtu": __CNI_MTU__,
          "ipam": {
              "type": "calico-ipam"
          },
          "policy": {
              "type": "k8s"
          },
          "kubernetes": {
              "kubeconfig": "__KUBECONFIG_FILEPATH__"
          }
        },
        {
          "type": "portmap",
          "snat": true,
          "capabilities": {"portMappings": true}
        },
        {
          "type": "bandwidth",
          "capabilities": {"bandwidth": true}
        }
      ]
    }

---
# Source: calico/templates/rbac.yaml

# Include a clusterrole for the kube-controllers component,
# and bind it to the calico-kube-controllers serviceaccount.
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: calico-kube-controllers
rules:
  # Pods are monitored for changing labels.
  # The node controller monitors Kubernetes nodes.
  # Namespace and serviceaccount labels are used for policy.
  - apiGroups: [""]
    resources:
      - pods
      - nodes
      - namespaces
      - serviceaccounts
    verbs:
      - watch
      - list
      - get
  # Watch for changes to Kubernetes NetworkPolicies.
  - apiGroups: ["networking.k8s.io"]
    resources:
      - networkpolicies
    verbs:
      - watch
      - list
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: calico-kube-controllers
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: calico-kube-controllers
subjects:
- kind: ServiceAccount
  name: calico-kube-controllers
  namespace: kube-system
---
# Include a clusterrole for the calico-node DaemonSet,
# and bind it to the calico-node serviceaccount.
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: calico-node
rules:
  # The CNI plugin needs to get pods, nodes, and namespaces.
  - apiGroups: [""]
    resources:
      - pods
      - nodes
      - namespaces
    verbs:
      - get
  - apiGroups: [""]
    resources:
      - endpoints
      - services
    verbs:
      # Used to discover service IPs for advertisement.
      - watch
      - list
  # Pod CIDR auto-detection on kubeadm needs access to config maps.
  - apiGroups: [""]
    resources:
      - configmaps
    verbs:
      - get
  - apiGroups: [""]
    resources:
      - nodes/status
    verbs:
      # Needed for clearing NodeNetworkUnavailable flag.
      - patch

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: calico-node
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: calico-node
subjects:
- kind: ServiceAccount
  name: calico-node
  namespace: kube-system

---
# Source: calico/templates/calico-node.yaml
# This manifest installs the calico-node container, as well
# as the CNI plugins and network config on
# each master and worker node in a Kubernetes cluster.
kind: DaemonSet
apiVersion: apps/v1
metadata:
  name: calico-node
  namespace: kube-system
  labels:
    k8s-app: calico-node
spec:
  selector:
    matchLabels:
      k8s-app: calico-node
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  template:
    metadata:
      labels:
        k8s-app: calico-node
      annotations:
        # This, along with the CriticalAddonsOnly toleration below,
        # marks the pod as a critical add-on, ensuring it gets
        # priority scheduling and that its resources are reserved
        # if it ever gets evicted.
        scheduler.alpha.kubernetes.io/critical-pod: ''
    spec:
      nodeSelector:
        kubernetes.io/os: linux
      hostNetwork: true
      tolerations:
        # Make sure calico-node gets scheduled on all nodes.
        - effect: NoSchedule
          operator: Exists
        # Mark the pod as a critical add-on for rescheduling.
        - key: CriticalAddonsOnly
          operator: Exists
        - effect: NoExecute
          operator: Exists
      serviceAccountName: calico-node
      # Minimize downtime during a rolling upgrade or deletion; tell Kubernetes to do a "force
      # deletion": https://kubernetes.io/docs/concepts/workloads/pods/pod/#termination-of-pods.
      terminationGracePeriodSeconds: 0
      priorityClassName: system-node-critical
      initContainers:
        # This container installs the CNI binaries
        # and CNI network config file on each node.
        - name: install-cni
          image: calico/cni:v3.15.1
          command: ["/install-cni.sh"]
          env:
            # Name of the CNI config file to create.
            - name: CNI_CONF_NAME
              value: "10-calico.conflist"
            # The CNI network config to install on each node.
            - name: CNI_NETWORK_CONFIG
              valueFrom:
                configMapKeyRef:
                  name: calico-config
                  key: cni_network_config
            # The location of the etcd cluster.
            - name: ETCD_ENDPOINTS
              valueFrom:
                configMapKeyRef:
                  name: calico-config
                  key: etcd_endpoints
            # CNI MTU Config variable
            - name: CNI_MTU
              valueFrom:
                configMapKeyRef:
                  name: calico-config
                  key: veth_mtu
            # Prevents the container from sleeping forever.
            - name: SLEEP
              value: "false"
          volumeMounts:
            - mountPath: /host/opt/cni/bin
              name: cni-bin-dir
            - mountPath: /host/etc/cni/net.d
              name: cni-net-dir
            - mountPath: /calico-secrets
              name: etcd-certs
          securityContext:
            privileged: true
        # Adds a Flex Volume Driver that creates a per-pod Unix Domain Socket to allow Dikastes
        # to communicate with Felix over the Policy Sync API.
        - name: flexvol-driver
          image: calico/pod2daemon-flexvol:v3.15.1
          volumeMounts:
          - name: flexvol-driver-host
            mountPath: /host/driver
          securityContext:
            privileged: true
      containers:
        # Runs calico-node container on each Kubernetes node.  This
        # container programs network policy and routes on each
        # host.
        - name: calico-node
          image: calico/node:v3.15.1
          env:
            # Bind network card, it will be prompt network card error if not set
            - name: IP_AUTODETECTION_METHOD
              value: interface=enp0s8
            # The location of the etcd cluster.
            - name: ETCD_ENDPOINTS
              valueFrom:
                configMapKeyRef:
                  name: calico-config
                  key: etcd_endpoints
            # Location of the CA certificate for etcd.
            - name: ETCD_CA_CERT_FILE
              valueFrom:
                configMapKeyRef:
                  name: calico-config
                  key: etcd_ca
            # Location of the client key for etcd.
            - name: ETCD_KEY_FILE
              valueFrom:
                configMapKeyRef:
                  name: calico-config
                  key: etcd_key
            # Location of the client certificate for etcd.
            - name: ETCD_CERT_FILE
              valueFrom:
                configMapKeyRef:
                  name: calico-config
                  key: etcd_cert
            # Set noderef for node controller.
            - name: CALICO_K8S_NODE_REF
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            # Choose the backend to use.
            - name: CALICO_NETWORKING_BACKEND
              valueFrom:
                configMapKeyRef:
                  name: calico-config
                  key: calico_backend
            # Cluster type to identify the deployment type
            - name: CLUSTER_TYPE
              value: "k8s,bgp"
            # Auto-detect the BGP IP address.
            - name: IP
              value: "autodetect"
            # Enable IPIP
            - name: CALICO_IPV4POOL_IPIP
              value: "Always"
            # Enable or Disable VXLAN on the default IP pool.
            - name: CALICO_IPV4POOL_VXLAN
              value: "Never"
            # Set MTU for tunnel device used if ipip is enabled
            - name: FELIX_IPINIPMTU
              valueFrom:
                configMapKeyRef:
                  name: calico-config
                  key: veth_mtu
            # Set MTU for the VXLAN tunnel device.
            - name: FELIX_VXLANMTU
              valueFrom:
                configMapKeyRef:
                  name: calico-config
                  key: veth_mtu
            # The default IPv4 pool to create on startup if none exists. Pod IPs will be
            # chosen from this range. Changing this value after installation will have
            # no effect. This should fall within \`--cluster-cidr\`.
            - name: CALICO_IPV4POOL_CIDR
              value: "10.16.0.0/16"
            # Disable file logging so \`kubectl logs\` works.
            - name: CALICO_DISABLE_FILE_LOGGING
              value: "true"
            # Set Felix endpoint to host default action to ACCEPT.
            - name: FELIX_DEFAULTENDPOINTTOHOSTACTION
              value: "ACCEPT"
            # Disable IPv6 on Kubernetes.
            - name: FELIX_IPV6SUPPORT
              value: "false"
            # Set Felix logging to "info"
            - name: FELIX_LOGSEVERITYSCREEN
              value: "info"
            - name: FELIX_HEALTHENABLED
              value: "true"
            #  set calico node name
            - name: NODENAME
              valueFrom:
                fieldRef:
                  fieldPath: status.hostIP
          securityContext:
            privileged: true
          resources:
            requests:
              cpu: 250m
          livenessProbe:
            exec:
              command:
              - /bin/calico-node
              - -felix-live
              - -bird-live
            periodSeconds: 10
            initialDelaySeconds: 10
            failureThreshold: 6
          readinessProbe:
            exec:
              command:
              - /bin/calico-node
              - -felix-ready
              - -bird-ready
            periodSeconds: 10
          volumeMounts:
            - mountPath: /lib/modules
              name: lib-modules
              readOnly: true
            - mountPath: /run/xtables.lock
              name: xtables-lock
              readOnly: false
            - mountPath: /var/run/calico
              name: var-run-calico
              readOnly: false
            - mountPath: /var/lib/calico
              name: var-lib-calico
              readOnly: false
            - mountPath: /calico-secrets
              name: etcd-certs
            - name: policysync
              mountPath: /var/run/nodeagent
      volumes:
        # Used by calico-node.
        - name: lib-modules
          hostPath:
            path: /lib/modules
        - name: var-run-calico
          hostPath:
            path: /var/run/calico
        - name: var-lib-calico
          hostPath:
            path: /var/lib/calico
        - name: xtables-lock
          hostPath:
            path: /run/xtables.lock
            type: FileOrCreate
        # Used to install CNI.
        - name: cni-bin-dir
          hostPath:
            path: /opt/cni/bin
        - name: cni-net-dir
          hostPath:
            path: /etc/cni/net.d
        # Mount in the etcd TLS secrets with mode 400.
        # See https://kubernetes.io/docs/concepts/configuration/secret/
        - name: etcd-certs
          secret:
            secretName: calico-etcd-secrets
            defaultMode: 0400
        # Used to create per-pod Unix Domain Sockets
        - name: policysync
          hostPath:
            type: DirectoryOrCreate
            path: /var/run/nodeagent
        # Used to install Flex Volume Driver
        - name: flexvol-driver-host
          hostPath:
            type: DirectoryOrCreate
            path: /usr/libexec/kubernetes/kubelet-plugins/volume/exec/nodeagent~uds
---

apiVersion: v1
kind: ServiceAccount
metadata:
  name: calico-node
  namespace: kube-system

---
# Source: calico/templates/calico-kube-controllers.yaml
# See https://github.com/projectcalico/kube-controllers
apiVersion: apps/v1
kind: Deployment
metadata:
  name: calico-kube-controllers
  namespace: kube-system
  labels:
    k8s-app: calico-kube-controllers
spec:
  # The controllers can only have a single active instance.
  replicas: 1
  selector:
    matchLabels:
      k8s-app: calico-kube-controllers
  strategy:
    type: Recreate
  template:
    metadata:
      name: calico-kube-controllers
      namespace: kube-system
      labels:
        k8s-app: calico-kube-controllers
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: ''
    spec:
      nodeSelector:
        kubernetes.io/os: linux
      tolerations:
        # Mark the pod as a critical add-on for rescheduling.
        - key: CriticalAddonsOnly
          operator: Exists
        - key: node-role.kubernetes.io/master
          effect: NoSchedule
      serviceAccountName: calico-kube-controllers
      priorityClassName: system-cluster-critical
      # The controllers must run in the host network namespace so that
      # it isn't governed by policy that would prevent it from working.
      hostNetwork: true
      containers:
        - name: calico-kube-controllers
          image: calico/kube-controllers:v3.15.1
          env:
            # The location of the etcd cluster.
            - name: ETCD_ENDPOINTS
              valueFrom:
                configMapKeyRef:
                  name: calico-config
                  key: etcd_endpoints
            # Location of the CA certificate for etcd.
            - name: ETCD_CA_CERT_FILE
              valueFrom:
                configMapKeyRef:
                  name: calico-config
                  key: etcd_ca
            # Location of the client key for etcd.
            - name: ETCD_KEY_FILE
              valueFrom:
                configMapKeyRef:
                  name: calico-config
                  key: etcd_key
            # Location of the client certificate for etcd.
            - name: ETCD_CERT_FILE
              valueFrom:
                configMapKeyRef:
                  name: calico-config
                  key: etcd_cert
            # Choose which controllers to run.
            - name: ENABLED_CONTROLLERS
              value: policy,namespace,serviceaccount,workloadendpoint,node
          volumeMounts:
            # Mount in the etcd TLS secrets.
            - mountPath: /calico-secrets
              name: etcd-certs
          readinessProbe:
            exec:
              command:
              - /usr/bin/check-status
              - -r
      volumes:
        # Mount in the etcd TLS secrets with mode 400.
        # See https://kubernetes.io/docs/concepts/configuration/secret/
        - name: etcd-certs
          secret:
            secretName: calico-etcd-secrets
            defaultMode: 0400

---

apiVersion: v1
kind: ServiceAccount
metadata:
  name: calico-kube-controllers
  namespace: kube-system

---
# Source: calico/templates/calico-typha.yaml

---
# Source: calico/templates/configure-canal.yaml

---
# Source: calico/templates/kdd-crds.yaml


EOF

  echo "  >> 6.1.6 distribute calico files..."
  IP=34
  for host in "${NODES[@]}"
  do
    IP=$(( IP + 1 ))
    echo "  copy files to host ${host} (192.168.176.${IP})..."
    scp ~/calico.sh ~/10-calico.conf ~/calicoctl.cfg ~/calico.yaml ${USER}@${host}:~/
    ssh ${USER}@${host} "sudo chown root:root ~/calico.sh ~/10-calico.conf ~/calicoctl.cfg ~/calico.yaml; \
      sudo mv -fv ~/calico.sh /etc/profile.d/; \
      source /etc/profile.d/calico.sh; \
      sudo mv -fv ~/10-calico.conf /etc/cni/net.d/; \
      sudo mv -fv ~/calicoctl.cfg /etc/calico/; \
      sudo mv -fv ~/calico.yaml /opt/calico/yaml"
  done
  rm -fv ~/calico.sh ~/10-calico.conf ~/calicoctl.cfg ~/calico.yaml

  echo "  >> 6.1.7 import docker images"
  IP=34
  for host in "${NODES[@]}"
  do
    IP=$(( IP + 1 ))
    echo "  install files in host ${host} (192.168.176.${IP})..."
    ssh ${USER}@${host} "sudo docker load -i /mnt/rw/docker-image/calico/node.docker.tar; \
      sudo docker load -i /mnt/rw/docker-image/calico/cni.docker.tar; \
      sudo docker load -i /mnt/rw/docker-image/calico/kube-controllers.docker.tar; \
      sudo docker load -i /mnt/rw/docker-image/calico/pod2daemon-flexvol.docker.tar"
  done

  echo "  >> 6.1.8 run calico.yaml in one master node"
  ssh ${USER}@k8s-master1 "sudo ${KUBECTL} create -f /opt/calico/yaml/calico.yaml -n kube-system"

  echo "  >> wait 5s ..."
  sleep 5s

  echo "  >> 6.1.9 view pod/deployment in all namespace"
  ssh ${USER}@k8s-master1 "sudo ${KUBECTL} get deployment,pod -n kube-system"
}

# deprecated
deploy_calico_service()
{
  echo "-------------------------------------------------------------"
  echo ">> 6.2 deploy calico service"

  echo "  >> 6.2.1 create calico environment configure file"
  local -r ASN=$(( ${RANDOM} % 65536 ))
  cat > ~/calico.conf << EOF
## calico config
#
##

## etcd configuration
ETCD_ENDPOINTS="https://192.168.176.35:2379,https://192.168.176.36:2379,https://192.168.176.37:2379"
ETCD_CA_CERT_FILE="/opt/ssl/ca.pem"
ETCD_CERT_FILE="/opt/ssl/etcd.pem"
ETCD_KEY_FILE="/opt/ssl/etcd-key.pem"

## calico configuration
CALICO_NODENAME="##hostname##"
CALICO_IP="##hostip##"
CALICO_IP6=""
CALICO_AS="${ASN}"
#CALICO_AS=""
NO_DEFAULT_POOLS=""
CALICO_NETWORKING_BACKEND="bird"
FELIX_DEFAULTENDPOINTTOHOSTACTION="ACCEPT"
FELIX_LOGSEVERITYSCREEN="info"
EOF

  echo "  >> 6.2.2 create calico service unit file"
  cat > ~/calico.service << EOF
[Unit]
Description=Calico Docker Node
After=docker.service
Requires=docker.service

[Service]
User=root
PermissionsStartOnly=true
EnvironmentFile=/opt/calico/conf/calico.conf
ExecStart=/usr/bin/docker run --net=host --privileged --name=calico-node \\
  -e NODENAME=\${CALICO_NODENAME} \\
  -e ETCD_ENDPOINTS=\${ETCD_ENDPOINTS} \\
  -e ETCD_CA_CERT_FILE=\${ETCD_CA_CERT_FILE} \\
  -e ETCD_CERT_FILE=\${ETCD_CERT_FILE} \\
  -e ETCD_KEY_FILE=\${ETCD_KEY_FILE} \\
  -e IP=\${CALICO_IP} \\
  -e IP6=\${CALICO_IP6} \\
  -e AS=\${CALICO_AS} \\
  -e NO_DEFAULT_POOLS=\${NO_DEFAULT_POOLS} \\
  -e CALICO_NETWORKING_BACKEND=\${CALICO_NETWORKING_BACKEND} \\
  -e FELIX_DEFAULTENDPOINTTOHOSTACTION=\${FELIX_DEFAULTENDPOINTTOHOSTACTION} \\
  -e FELIX_LOGSEVERITYSCREEN=\${FELIX_LOGSEVERITYSCREEN} \\
  -v /opt/ssl/ca.pem:/opt/ssl/ca.pem \\
  -v /opt/ssl/etcd.pem:/opt/ssl/etcd.pem \\
  -v /opt/ssl/etcd-key.pem:/opt/ssl/etcd-key.pem \\
  -v /run/docker/plugins:/run/docker/plugins \\
  -v /lib/modules:/lib/modules \\
  -v /var/run/calico:/var/run/calico \\
  -v /var/log:/var/log \\
  -v /var/lib/calico:/var/lib/calico \\
  calico/node:v3.15.1
ExecStop=/usr/bin/docker rm -f calico-node
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

  echo "  >> 6.2.3 distribute calico service files and start service"
  IP=34
  for host in "${NODES[@]}"
  do
    IP=$(( IP + 1 ))
    echo "    copy calico service files to host ${host} (192.168.176.${IP}) and start service..."
    scp ~/calico.conf ~/calico.service ${USER}@${host}:~/
    ssh ${USER}@${host} "sed -i \"s/\#\#hostname\#\#/${host}/g; s/\#\#hostip\#\#/192.168.176.${IP}/g\" ~/calico.conf; \
      sudo chown root:root ~/calico.conf ~/calico.service; \
      sudo mv -fv ~/calico.conf /opt/calico/conf/; \
      sudo mv -fv ~/calico.service /etc/systemd/system/; \
      sudo systemctl daemon-reload"
  done
  rm -fv ~/calico.conf ~/calico.service

  echo "  >> waiting for 5 seconds ..."
  sleep 5s
}

deploy_calico_postinstall()
{
  echo "-------------------------------------------------------------"
  echo ">> 6.3 postInstall calico: fix ippool"

  echo "  >> 6.3.1 prepare calico-ippool.yaml"
  cat > ~/calico-ippool.yaml << EOF
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: cluster-ipv4-ippool
spec:
  cidr: 10.16.0.0/16
  ipipMode: CrossSubnet
  natOutgoing: true
EOF

  echo "  >> 6.3.2 recreate ippool"
  scp ~/calico-ippool.yaml ${USER}@k8s-master1:~/
  ssh ${USER}@k8s-master1 "sudo mv -fv ~/calico-ippool.yaml /opt/calico/yaml/; \
    sudo chown root:root /opt/calico/yaml/calico-ippool.yaml; \
    sudo ${CALICOCTL} get ippool -o wide; \
    sudo ${CALICOCTL} delete ippool default-ipv4-ippool; \
    sudo ${CALICOCTL} apply -f /opt/calico/yaml/calico-ippool.yaml; \
    sudo ${CALICOCTL} get ippool -o wide"

  rm -f ~/calico-ippool.yaml
}

deploy_calico()
{
  echo "============================================================="
  echo "6. Deploy calico"

  deploy_calico_install

  #deploy_calico_service

  echo "  >> 6.2.1 view calico node"
  local -r CALICOCTL="/opt/calico/bin/calicoctl"
  ssh ${USER}@k8s-master1 "sudo ${CALICOCTL} get node -o wide"

  echo "  >> 6.2.2 view current node status"
  IP=34
  for host in ${NODES[@]}
  do
    IP=$(( IP + 1 ))
    echo "    --- view node:${host}(192.168.176.${IP}) status ---"
    ssh ${USER}@${host} "sudo ${CALICOCTL} node status"
    echo -e "\n"
  done

  echo "  >> 6.2.3 view peer info"
  ssh ${USER}@k8s-master1 "sudo ${CALICOCTL} get wep --all-namespace"

  deploy_calico_postinstall

  echo -e "\n>> Ending of deploying all calico\n"
}


unused()
{
  local -r images_old=(etcd-amd64:3.0.17 pause-amd64:3.0 kube-proxy-amd64:v1.7.2 kube-scheduler-amd64:v1.7.2 kube-controller-manager-amd64:v1.7.2 kube-apiserver-amd64:v1.7.2 kubernetes-dashboard-amd64:v1.6.1 k8s-dns-sidecar-amd64:1.14.4 k8s-dns-kube-dns-amd64:1.14.4 k8s-dns-dnsmasq-nanny-amd64:1.14.4)
  local -r images=(etcd-amd64:3.4.2 pause-amd64:3.1 kube-proxy-amd64:v1.16.2 kube-scheduler-amd64:v1.16.2 kube-controller-manager-amd64:v1.16.2 kube-apiserver-amd64:v1.16.2 kubernetes-dashboard-amd64:v1.10.1 k8s-dns-sidecar-amd64:1.15.7 k8s-dns-kube-dns-amd64:1.15.7 k8s-dns-dnsmasq-nanny-amd64:1.15.7)
  for imageName in ${images[@]} ; do
    sudo docker pull mirrorgooglecontainers/$imageName
    sudo docker tag mirrorgooglecontainers/$imageName gcr.io/google_containers/$imageName
    sudo docker rmi mirrorgooglecontainers/$imageName
  done

  local -r images=($(sudo docker images | grep '^gcr\.io' |  awk '{print $1}' | sed "s:/: :g"|awk '{print $3}'))
  for imageName in ${images[@]}
  do
    tag=$(sudo docker images | grep "${imageName}" | awk '{print $1":"$2}')
    echo "tag = ${tag}"
    sudo docker save ${tag} -o "/mnt/rw/docker-image/gcr.io/google_containers/${imageName}.docker.tar"
  done
}

# ------- main body -------------
declare -ra MASTERS=("k8s-master1" "k8s-master2" "k8s-master3")
declare -ra NODES=(${MASTERS[@]} "k8s-node1" "k8s-node2" "k8s-node3")
#declare -ra NODES=(${MASTERS[@]} "k8s-node1")
declare -i IP=0
declare -i APP_DIR="/ext"
declare -r SSL_DIR="/opt/ssl"
declare -r RPMDIR="/mnt/rw/rpm"
declare -r KUBECTL="/opt/k8s/bin/kubectl"
declare -r ETCD_VER="3.4.10"

clear_all
preinstall
init_template
create_CA
deploy_etcd
deploy_HA
deploy_kubernetes
deploy_calico
