SERVICES=("etcd" "kube-apiserver" "kube-controller-manager" "kube-scheduler")
MASTERS=("k8s-master1" "k8s-master2" "k8s-master3")
NODES=("k8s-master1" "k8s-master2" "k8s-master3" "k8s-node1" "k8s-node2" "k8s-node3")

# all services in all hosts
for service in "${SERVICES[@]}"
do
  for host in "${MASTERS[@]}"
  do
    echo "Start ${service} in host ${host}..."
    ssh ymliu@${host} "sudo systemctl start ${service}" &
  donell
  echo -e "\n"
done

alias masterExec='_f() { for host in "${MASTERS[@]}";do ssh ymliu@${host} "sudo $1"; done; }; _f'
alias nodeExec='_f() { for host in "${NODES[@]}";do ssh ymliu@${host} "sudo $1"; done; }; _f'


init_template()
{
  echo "============================================================="
  echo "1. Initializing Template"
  echo "-------------------------------------------------------------"

  echo ">> 1.1 Modify file  .bashrc"
  BASHRC_FILE = "~/.bashrc"
  echo ">>>> 1.1.1 declare MASTERS"
  egrep "^declare -a MASTERS" ${BASHRC_FILE} >& /dev/null
  if [ $? -eq 0 ]; then
    echo "replace declare MASTERS..."
    sed -i "s/^# export SYSTEMD_PAGER=/declare -a MASTERS=(k8s-master1 k8s-master2 k8s-master3)" ${BASHRC_FILE}
  else
    echo "add declare MASTERS..."
    sed -i "/^# export SYSTEMD_PAGER=/adeclare -a MASTERS=(k8s-master1 k8s-master2 k8s-master3)" ${BASHRC_FILE}
  fi

  echo ">>>> 1.1.2 declare NODES"
  egrep "^declare -a NODES" ${BASHRC_FILE} >& /dev/null
  if [ $? -eq 0 ]; then
    echo "replace declare NODES..."
    sed -i "s/^declare -a NODES/declare -a NODES=(k8s-master1 k8s-master2 k8s-masster3 k8s-node1 k8s-node2 k8s-node3)" ${BASHRC_FILE}
  else
    echo "add declare NODES..."
    sed -i "/^declare -a NODES/adeclare -a NODES=(k8s-master1 k8s-master2 k8s-masster3 k8s-node1 k8s-node2 k8s-node3)" ${BASHRC_FILE}
  fi

  echo ">>>> 1.1.3 alias masterExec"
  egrep 'masterExec' ${BASHRC_FILE} >& /dev/null
  if [ $? -eq 0 ]; then
    echo "replace alias masterExec..."
    sed -i "s/^alias\ masterExec=.*$/alias masterExec='_f() { for host in \"\${MASTERS[@]}\";do ssh ymliu@\${host} \"sudo \$1\"; done; }; _f'" ${BASHRC_FILE}
  else
    echo "add alias masterExec..."
    sed -i "/^alias\ masterExec=.*$/aalias masterExec='_f() { for host in \"\${MASTERS[@]}\";do ssh ymliu@\${host} \"sudo \$1\"; done; }; _f'" ${BASHRC_FILE}
  fi

  echo ">>>> 1.1.4 alias nodeExec"
  egrep "nodeExec" ${BASHRC_FILE} >& /dev/null
  if [ $? -eq 0 ]; then
    echo "replace alias nodeExec..."
    sed -i "s/^alias\ nodeExec=.*$/alias nodeExec='_f() { for host in \"\${NODES[@]}\";do ssh ymliu@\${host} \"sudo \$1\"; done; }; _f'" ${BASHRC_FILE}
  else
    echo "add alias nodeExec..."
    sed -i "/^alias\ nodeExec=.*$/aalias nodeExec='_f() { for host in \"\${NODES[@]}\";do ssh ymliu@\${host} \"sudo \$1\"; done; }; _f'" ${BASHRC_FILE}
  fi
}

for host in "${MASTERS[@]}"
do
  scp /opt/k8s/service/etcd.service /opt/k8s/conf/etcd.conf ymliu@${host}:~/
  ssh ymliu@${host} 'sudo mv ~/etcd.service /opt/k8s/service/; sudo chown root:root /opt/k8s/service/etcd.service; \
    sudo mv ~/etcd.conf /opt/k8s/conf/; sudo chown root:root /opt/k8s/conf/etcd.conf; \
    sudo ln -sf /opt/k8s/service/etcd.service /etc/systemd/system/; sudo systemctl daemon-reload'
done

# copy Certification & Key Files in masters
CAFILES=("ca" "etcd" "kubernetes" "admin" "kube-controller-manager" "kube-scheduler" "kube-proxy")
for host in "${NODES[@]}"
do
  for file in "${CAFILES[@]}"
  do
    sudo chmod 644 "/opt/ssl/${file}-key.pem"
  done

  scp /opt/ssl/*.pem ymliu@${host}:~/
  ssh ymliu@${host} "sudo rm -f /opt/ssl/*.pem; \
    sudo mv -f ~/*.pem /opt/ssl/; \
    sudo chown root:root /opt/ssl/*.pem"

  for file in "${CAFILES[@]}"
  do
    sudo chmod 600 "/opt/ssl/${file}-key.pem"
    ssh ymliu@${host} "sudo chmod 600 /opt/ssl/${file}-key.pem"
  done
done


# kube-apiserver client token file
MASTERS=("k8s-master1" "k8s-master2" "k8s-master3")
for host in "${MASTERS[@]}"
do
  scp /opt/k8s/token/bootstrap-token.csv /opt/k8s/token/basic-auth.csv ymliu@${host}:~/
  ssh ymliu@${host} "sudo mv -f ~/bootstrap-token.csv ~/basic-auth.csv /opt/k8s/token/; \
  sudo chown root:root /opt/k8s/token/bootstrap-token.csv /opt/k8s/token/basic-auth.csv"
done


# audit log
MASTERS=("k8s-master1" "k8s-master2" "k8s-master3")
for host in "${MASTERS[@]}"
do
  scp /opt/k8s/yaml/audit-policy*.yaml ymliu@${host}:~/
  ssh ymliu@${host} "sudo mv -f ~/audit-policy*.yaml /opt/k8s/yaml/; \
    sudo chown root:root /opt/k8s/yaml/audit-policy*.yaml"
done

# kube-apiserver service&conf files
MASTERS=("k8s-master1" "k8s-master2" "k8s-master3")
for host in "${MASTERS[@]}"
do
  scp /opt/k8s/service/kube-apiserver.service /opt/k8s/conf/apiserver.conf ymliu@${host}:~/
  ssh ymliu@${host} "sudo mv -f ~/kube-apiserver.service /opt/k8s/service/; \
    sudo chown root:root /opt/k8s/service/kube-apiserver.service; \
    sudo ln -sf /opt/k8s/service/kube-apiserver.service /etc/systemd/system/; \
    sudo mv -f ~/apiserver.conf /opt/k8s/conf/; \
    sudo chown root:root /opt/k8s/conf/apiserver.conf"
done

# kube-controller-manager config file
for host in "${MASTERS[@]}"
do
  sudo chmod 644 /opt/k8s/cert/*.kubeconfig
  scp /opt/k8s/cert/*.kubeconfig ymliu@${host}:~/
  ssh ymliu@${host} "sudo mkdir -p /opt/k8s/cert; \
    sudo mv -f ~/*.kubeconfig /opt/k8s/cert/; \
    sudo chown root:root /opt/k8s/cert/*.kubeconfig; \
    sudo chmod 600 /opt/k8s/cert/*.kubeconfig"
  sudo chmod 600 /opt/k8s/cert/*.kubeconfig
done

#kube-controller-manager service&config files
for host in "${MASTERS[@]}"
do
  scp /opt/k8s/service/kube-controller-manager.service /opt/k8s/conf/controller-manager.conf ymliu@${host}:~/
  ssh ymliu@${host} "sudo mv -f ~/kube-controller-manager.service /opt/k8s/service/; \
  sudo chown root:root /opt/k8s/service/kube-controller-manager.service; \
  sudo ln -sf /opt/k8s/service/kube-controller-manager.service /etc/systemd/system/; \
  sudo mv ~/controller-manager.conf /opt/k8s/conf/; \
  sudo chown root:root /opt/k8s/conf/controller-manager.conf; \
  sudo systemctl daemon-reload"
done


#kube-scheduler service&config files
for host in "${MASTERS[@]}"
do
  scp /opt/k8s/service/kube-scheduler.service /opt/k8s/conf/scheduler.conf ymliu@${host}:~/
  ssh ymliu@${host} "sudo mv -f ~/kube-scheduler.service /opt/k8s/service/; \
  sudo chown root:root /opt/k8s/service/kube-scheduler.service; \
  sudo ln -sf /opt/k8s/service/kube-scheduler.service /etc/systemd/system/; \
  sudo mv ~/scheduler.conf /opt/k8s/conf/; \
  sudo chown root:root /opt/k8s/conf/scheduler.conf; \
  sudo systemctl daemon-reload"
done

for host in "${MASTERS[@]}"
do
  scp /etc/haproxy/haproxy.cfg ymliu@${host}:~/
  ssh ymliu@${host} "sudo mv -f ~/haproxy.cfg /etc/haproxy/; \
  sudo chown root:root /etc/haproxy/haproxy.cfg; \
  sudo chown -R haproxy:haproxy /ext/haproxy"
done

for host in "${MASTERS[@]}"
do
  scp /etc/keepalived/keepalived* ymliu@${host}:~/
  ssh ymliu@${host} "sudo mv -f ~/keepalived* /etc/keepalived/; \
  sudo chown root:root /etc/keepalived/keepalived*"
done


scp_kubelet_kubeconfig()
{
  FILES=("bootstrap.kubeconfig" "kubelet.kubeconfig" "kube-proxy.kubeconfig")
  LOCAL_PATH="/opt/k8s/cert/"
  REMOTE_PATH="~/"

  LOCAL_FILES=""
  REMOTE_FILES=""
  for file in "${FILES[@]}"
  do
    LOCAL_FILES="${LOCAL_FILES} ${LOCAL_PATH}${file}"
    REMOTE_FILES="${REMOTE_FILES} ${REMOTE_PATH}${file}"
  done
  echo "FILES        : ${FILES[@]}"
  echo "LOCAL_FILES  : ${LOCAL_FILES}"
  echo "REMOTE_FILES : ${REMOTE_FILES}"
  echo -e "\n"

  CMD_MV="sudo mv -f ${REMOTE_FILES} ${LOCAL_PATH}"
  CMD_CHOWN="sudo chown root:root ${LOCAL_FILES}"
  CMD_CHMOD="sudo chmod 600 ${LOCAL_FILES}"
  echo -e "\n"

  echo "CMD_MV    : ${CMD_MV}"
  echo "CMD_CHOWN : ${CMD_CHOWN}"
  echo "CMD_CHMOD : ${CMD_CHMOD}"

  for node in "${NODES[@]}"
  do
    sudo chmod 644 ${LOCAL_FILES}
    scp ${LOCAL_FILES} ymliu@${node}:${REMOTE_PATH}
    ssh ymliu@${node} "sudo mv -f ${REMOTE_FILES} ${LOCAL_PATH}; \
      sudo chown root:root ${LOCAL_FILES}; \
      sudo chmod 600 ${LOCAL_FILES}"
    sudo chmod 600 ${LOCAL_FILES}
  done
}

scp_kubelet_service()
{
  ip=35
  for node in "${NODES[@]}"
  do
    echo "doing in host ${node}, ip: 192.168.176.${ip}"
    scp /etc/systemd/system/kubelet.service /opt/k8s/conf/kubelet.conf /opt/k8s/yaml/kubelet.yaml ymliu@${node}:~/
    ssh ymliu@${node} "sed -i 's/\.35/\.${ip}/g' ~/kubelet.conf; \
      sudo mv -f ~/kubelet.service /etc/systemd/system/; \
      sudo mv -f ~/kubelet.conf /opt/k8s/conf/; \
      sudo mv -f ~/kubelet.yaml /opt/k8s/yaml/; \
      sudo chown root:root /etc/systemd/system/kubelet.service /opt/k8s/conf/kubelet.conf /opt/k8s/yaml/kubelet.yaml; \
      sudo systemctl daemon-reload"
    ip=$(( ip + 1 ))
    echo -e "\n"
  done
}

deploy_kube_proxy()
{
  ip=35
  for node in "${NODES[@]}"
  do
    echo "deploying kube-proxy in host ${node} (192.168.176.${ip})"

    sudo chmod 644 /opt/ssl/kube-proxy*.pem /opt/k8s/cert/kube-proxy.kubeconfig
    scp /opt/ssl/kube-proxy*.pem \
      /etc/systemd/system/kube-proxy.service \
      /opt/k8s/conf/kube-proxy.conf \
      /opt/k8s/yaml/kube-proxy.yaml \
      /opt/k8s/cert/kube-proxy.kubeconfig \
      ymliu@${node}:~/
    ssh ymliu@${node} "sed -i 's/\.35/\.${ip}/g' ~/kube-proxy.yaml; \
      sed -i 's/\.35/\.${ip}/g' ~/kube-proxy.conf; \
      sudo mv -f ~/kube-proxy*.pem /opt/ssl/; \
      sudo mv -f ~/kube-proxy.service /etc/systemd/system/; \
      sudo mv -f ~/kube-proxy.conf /opt/k8s/conf/; \
      sudo mv -f ~/kube-proxy.yaml /opt/k8s/yaml/; \
      sudo mv -f ~/kube-proxy.kubeconfig /opt/k8s/cert/; \
      sudo chmod 600 /opt/ssl/kube-proxy*.pem /opt/k8s/cert/kube-proxy.kubeconfig; \
      sudo chown root:root /etc/systemd/system/kube-proxy.service /opt/k8s/conf/kube-proxy.conf /opt/k8s/yaml/kube-proxy.yaml /opt/ssl/kube-proxy*.pem; \
      sudo systemctl daemon-reload"
    sudo chmod 600 /opt/ssl/kube-proxy*.pem

    ip=$(( ip + 1 ))
    echo -e "\n"
  done
}

deploy_calico()
{
  cat > ~/calico.sh <<EOF
CALICO_HOME="/opt/calico"
export PATH=\$PATH:\$CALICO_HOME
EOF
  sudo mv -f ~/calico.sh /etc/profile.d/
  sudo chown root:root /etc/profile.d/calico.sh
  source /etc/profile.d/calico.sh

  sudo mkdir -p /opt/calico/{conf,yaml,bin} /opt/cni/bin /etc/cni/net.d
  sudo cp -f /mnt/rw/calico/calico-amd64 /opt/cni/bin/calico
  sudo cp -f /mnt/rw/calico/calico-ipam-amd64 /opt/cni/bin/calico-ipam
  sudo tar -xvzf /mnt/rw/calico/cni-plugins-linux-amd64-v0.8.6.tgz -C /opt/cni
  sudo cp -f /opt/cni/{bandwidth,loopback,portmap,tuning} /opt/cni/bin/
  sudo chmod +x /opt/cni/bin/*

  echo -e "\n"

  ip=34
  for node in "${NODES[@]}"
  do
    # install
    ip=$(( ip + 1 ))
    echo "Installing in host ${node} ($ip)"
    scp /etc/profile.d/calico.sh ymliu@${node}:~/
    ssh ymliu@${node} "sudo mv -f ~/calico.sh /etc/profile.d/; \
      sudo chown root:root /etc/profile.d/calico.sh; \
      source /etc/profile.d/calico.sh; \
      sudo mkdir -p /opt/calico/{conf,yaml,bin} /opt/cni/bin /etc/cni/net.d; \
      sudo cp -f /mnt/rw/calico/calico-amd64 /opt/cni/bin/calico; \
      sudo cp -f /mnt/rw/calico/calico-ipam-amd64 /opt/cni/bin/calico-ipam; \
      sudo tar -xvzf /mnt/rw/calico/cni-plugins-linux-amd64-v0.8.6.tgz -C /opt/cni; \
      sudo cp -f /opt/cni/{bandwidth,loopback,portmap,tuning} /opt/cni/bin/; \
      sudo chmod +x /opt/cni/bin/*; \
      sudo docker load -i /mnt/rw/calico/node.docker.tar; \
      sudo docker load -i /mnt/rw/calico/cni.docker.tar; \
      sudo docker load -i /mnt/rw/calico/kube-controllers.docker.tar; \
      sudo docker load -i /mnt/rw/calico/pod2daemon-flexvol.docker.tar"
    echo -e "\n"
  done
}

deploy_calico_conf()
{
  cat > ~/10-calico.conf <<EOF
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
    "kubeconfig": "/opt/k8s/cert/kubelet.config"
  }
}
EOF

  cat > ~/calicoctl.cfg <<EOF
apiVersion: projectcalico.org/v3
kind: CalicoAPIConfig
metadata:
spec:
  datastoreType: etcdv3
  etcdEndPoints: https://192.168.176.35:2379,https://192.168.176.36:2379,https://192.168.176.37:2379
  etcdKeyFile: /opt/ssl/etcd-key.pem
  etcdCertFile: /opt/ssl/etcd.pem
  etcdCACertFile: /opt/ssl/ca.pem
EOF

  sudo chown root:root ~/10-calico.conf ~/calicoctl.cfg
  sudo mv -f ~/10-calico.conf /etc/cni/net.d/
  sudo mv -f ~/calicoctl.cfg /opt/calico/calicoctl.cfg

  ip=34
  for node in "${NODES[@]}"
  do
    ip=$(( ip + 1 ))
    echo "deploying config file in host ${node} ($ip)"

    scp /etc/cni/net.d/10-calico.conf /opt/calico/calicoctl.cfg /opt/calico/yaml/calico.yaml ymliu@${node}:~/
    ssh ymliu@${node} "sudo chown root:root ~/10-calico.conf ~/calicoctl.cfg ~/calico.yaml; \
      sudo mv -f ~/10-calico.conf /etc/cni/net.d/; \
      sudo mv -f ~/calico.yaml /opt/calico/yaml/; \
      sudo mv -f ~/calicoctl.cfg /opt/calico/"

    echo -e "\n"
  done
}

sudo tar -xvzf /mnt/rw/etcd-v3.2.18-linux-amd64.tar.gz -C /opt
sudo ln -s /opt/etcd-v3.2.18-linux-amd64 /opt/etcd
sudo ln -s /opt/etcd/etcd /opt/k8s/bin/
sudo ln -s /opt/etcd/etcdctl /opt/k8s/bin


sudo tar -xvzf /mnt/ro/kubernetes-server-linux-amd64.tar.gz -C /opt
sudo ln -sf /opt/kubernetes/server/bin/{kube-apiserver,kube-controller-manager,kube-scheduler,kubelet,kubectl,kubeadm,kube-proxy,apiextensions-apiserver,mounter} /opt/k8s/bin/

sudo mkdir -p /opt/cni
sudo tar -xvzf /mnt/ro/cni-plugins-linux-amd64-v0.8.6.tgz -C /opt/cni

sudo yum install -y bash-completion
source /usr/share/bash-completion/bash_completion
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
