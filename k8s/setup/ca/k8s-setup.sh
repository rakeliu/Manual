#!/usr/bin/env bash

# This script is use for setup k8s+calico & all configurations
# all sets are same build in all nodes

# clear all setup
function clear_all()
{
  echo "============================================================="
  echo "0. Clear all setup & configurations"

  echo ">> clear local files..."
  sudo systemctl stop calico kubelet kube-proxy kube-scheduler kube-controller-manager keepalived haproxy kube-apiserver etcd
  sudo systemctl disable calico kubelet kube-proxy kube-scheduler kube-controller-manager keepalived haproxy kube-apiserver etcd
  sudo rm -fv /etc/systemd/system/{etcd,kube-apiserver,kube-controller-manager,kube-scheduler,kubelet,kube-proxy}.service
  sudo yum remove -y haproxy keepalived psmisc bash-completion ipvsadm bridge-utils conntrack
  sudo docker ps -a | awk 'NR>1{print $1}' | xargs sudo docker stop
  sudo docker ps -a | awk 'NR>1{print $1}' | xargs sudo docker rm -f
  sudo docker images | awk 'NR>1{print $1":"$2}' | xargs sudo docker rmi
  sudo rm -fr /ext/{k8s,etcd,haproxy,calico} /opt/{ssl,k8s,cni,calico} /etc/{cni,calico}
  sudo rm -fr /opt/{etcd,etcd-v3.2.18-linux-amd64,kubernetes}
  sudo rm -fr /var/lib/calico /var/run/calico
  sudo rm -fr /etc/{haproxy,keepalived}
  sudo rm -fr ~/.kube
  sudo rm -fv /etc/profile.d/{kubernetes.sh,etcd.sh,calico.sh} /etc/haproxy/haproxy.cfg.rpmsave /etc/keepalived/keepalived.conf.rpmsave
  sed -i "/^declare -a MASTERS.*$/d;/^declare -a NODES.*$/d;/^declare ETCD_CONN.*$/d;/^export ETCD_CONN.*$/d;/^alias masterExec.*$/d;/^alias nodeExec.*$/d;/^# kubectl/d;/^source <(kubectl.*$/d" ~/.bashrc

  local -ra SERVICES=(calico kube-proxy kubelet kube-scheduler kube-controller-manager keepalived haproxy kube-apiserver etcd)
  echo ">> stop & disable all services"
  ssh ${USER}@${FIRSTMASTER} "sudo ${KUBECTL} delete -f /opt/calico/yaml/calico.yaml -nkube-system"
  for service in ${SERVICES[@]}
  do
    IP=${FIRSTIP}
    for host in ${ALLNODES[@]}
    do
      IP=$(( IP + 1 ))
      echo "  >> stop & disable service: ${service} in host ${host} (192.168.176.${IP})..."
      ssh ${USER}@${host} "sudo systemctl stop ${service}; \
        sudo systemctl disable ${service}; \
        sudo rm -fv /etc/systemd/system/${service}.service"
    done
  done

  echo ">> remove yum packages"
  IP=${FIRSTIP}
  for host in ${ALLNODES[@]}
  do
    IP=$(( IP + 1 ))
    echo "  >> remove yum packages in host ${host} (192.168.176.${IP})..."
    sudo ${USER}@${host} "sudo yum remove -y haproxy keepalived psmisc bash-completion ipvsadm bridge-utils conntrack"
  done


  echo ">> remove docker images"
  IP=${FIRSTIP}
  for host in ${ALLNODES[@]}
  do
    IP=$(( IP + 1 ))
    echo "  >> remove docker images in host ${host} (192.168.176.${IP})..."
    ssh ${USER}@${host} "sudo docker ps -a | awk 'NR>1{print \$1}' | xargs sudo docker stop; \
      sudo docker ps -a | awk 'NR>1{print \$1}' | xargs sudo docker rm -f; \
      sudo docker images | awk 'NR>1{print \$1\":\"\$2}' | xargs sudo docker rmi"
  done

  echo ">> remove directorys & files"
  IP=${FIRSTIP}
  for host in ${ALLNODES[@]}
  do
    IP=$(( IP + 1 ))
    echo "  >> remove directorys & files in host ${host} (192.168.176.${IP})..."
    ssh ${USER}@${host} "sudo rm -fr /ext/{k8s,etcd,haproxy,calico} /opt/{ssl,k8s,cni,calico} /etc/{cni,calico}; \
      sudo rm -fr /opt/{etcd,etcd-v3.2.18-linux-amd64,kubernetes}; \
      sudo rm -fr /var/lib/calico /var/run/calico; \
      sudo rm -fr /etc/{haproxy,keepalived}; \
      sudo rm -fr ~/.kube; \
      sudo rm -fv /etc/profile.d/{kubernetes.sh,etcd.sh,calico.sh}"
  done

  echo ">> remove declare & alias"
  IP=${FIRSTIP}
  for host in ${ALLNODES[@]}
  do
    IP=$(( IP + 1 ))
    echo "  >> remove declare & alias in host ${host} (192.168.176.${IP})..."
    ssh ${USER}@${host} "sed -i \"/^declare -a MASTERS.*$/d;/^declare -a NODES.*$/d;/^declare ETCD_CONN.*$/d;/^export ETCD_CONN.*$/d;/^alias masterExec.*$/d;/^alias nodeExec.*$/d;/^# kubectl/d;/^source <(kubectl.*$/d\" ~/.bashrc"
  done

  echo ">> Ending of clear all configurations"
}

# install all files to all nodes
function install_files()
{
  echo "============================================================="
  echo "1. Install Files"

  echo "-------------------------------------------------------------"
  echo ">> 1.1 initializing local configuration"
  echo "  >> 1.1.1 add declare MASTERS..."
  sed -i "/^#\ export/adeclare -a MASTERS=(${MASTERS[@]})" ~/.bashrc

  echo "-------------------------------------------------------------"
  echo "  >> 1.1.2 add declare NODES..."
  sed -i "/^declare -a MASTERS/adeclare -a NODES=(${NODES[@]})" ~/.bashrc

  echo "-------------------------------------------------------------"
  echo "  >> 1.1.3 add alias masterExec..."
  sed -i "/^alias log=.*$/aalias masterExec='_f() { for host in \"\${MASTERS[@]}\";do ssh ${USER}@\${host} \"sudo \$1\"; done; }; _f'" ~/.bashrc

  echo "-------------------------------------------------------------"
  echo "  >> 1.1.4 add alias nodeExec..."
  sed -i "/^alias masterExec=.*$/aalias nodeExec='_f() { for host in \"\${NODES[@]}\";do ssh ${USER}@\${host} \"sudo \$1\"; done; }; _f'" ~/.bashrc

  echo "-------------------------------------------------------------"
  echo ">> 1.2 create directorys in remote host"
  IP=${FIRSTIP}
  for host in ${ALLNODES[@]}
  do
    IP=$(( IP + 1 ))
    echo "  >> create directorys in host ${host} (192.168.176.${IP})..."
    ssh ${USER}@${host} "mkdir -pv ~/.kube; \
      sudo mkdir -pv /opt/ssl /opt/k8s/{bin,conf,token,yaml}; \
      sudo mkdir -pv /ext/{etcd,haproxy} /ext/k8s/{apiserver,controller,scheduler,kubelet,proxy}; \
      sudo mkdir -pv /opt/cni/bin /opt/calico/{conf,yaml,bin} /etc/cni/net.d /etc/calico"
  done

  echo "-------------------------------------------------------------"
  echo ">> 1.3 install files to all hosts"
  local -r RPMDIR="/mnt/rw"
  IP=${FIRSTIP}
  local -i SEQ=0
  for host in ${ALLNODES[@]}
  do
    IP=$(( IP + 1 ))
    SEQ=$(( SEQ + 1 ))
    echo "  >> 1.3.${SEQ} install file to host ${host}(192.168.176.${IP})..."
    ssh ${USER}@${host} "sudo yum install -y ${RPMDIR}/conntrack-tools-1.4.4-7.el7.x86_64.rpm \
        ${RPMDIR}/haproxy-1.5.18-9.el7.x86_64.rpm \
        ${RPMDIR}/keepalived-1.3.5-16.el7.x86_64.rpm \
        ${RPMDIR}/bash-completion-2.1-8.el7.noarch.rpm \
        ${RPMDIR}/ipvsadm-1.27-8.el7.x86_64.rpm \
        ${RPMDIR}/bridge-utils-1.5-9.el7.x86_64.rpm; \
      sudo ln -sfv /mnt/ro/cfssl/cfssl_linux-amd64 /opt/ssl/cfssl; \
      sudo ln -sfv /mnt/ro/cfssl/cfssl-certinfo_linux-amd64 /opt/ssl/cfssl-certinfo; \
      sudo ln -sfv /mnt/ro/cfssl/cfssljson_linux-amd64 /opt/ssl/cfssljson; \
      sudo tar -xzf /mnt/rw/etcd-v3.2.18-linux-amd64.tar.gz -C /opt/; \
      sudo ln -sfv /opt/etcd-v3.2.18-linux-amd64 /opt/etcd; \
      sudo ln -sfv /opt/etcd/{etcd,etcdctl} /opt/k8s/bin/; \
      sudo tar -xzf /mnt/ro/kubernetes-server-linux-amd64.tar.gz -C /opt/; \
      sudo ln -sfv /opt/kubernetes/server/bin/{kube-apiserver,kube-controller-manager,kube-scheduler,kubelet,kubectl,kubeadm,kube-proxy,apiextensions-apiserver,mounter} /opt/k8s/bin/; \
      sudo tar -xzf /mnt/rw/calico-amd64.tar.gz -C /opt/calico/bin/;
      sudo chown root:root /opt/calico/bin/*; \
      sudo tar -xzf /mnt/rw/cni-plugins-linux-amd64-v0.8.6.tgz -C /opt/cni/; \
      sudo ln -sfv /opt/cni/{bandwidth,loopback,portmap,tuning} /opt/calico/bin/{calico,calico-ipam} /opt/cni/bin"
  done
}




# ------- main body ----------
declare -ra MASTER=("k8s-master1" "k8s-master2" "k8s-master3")
declare -ra WORKERS=("k8s-node1" "k8s-node2" "k8s-node3")
declare -ra ALLNODES=(${MASTER[@]} ${WORKERS[@]})
declare -ri FIRSTIP=34
declare -i IP=0
declare -ri VIP=34
declare -r FIRSTMASTER=${MASTER[0]}
declare -r KUBECTL="/opt/k8s/bin/kubectl"
declare -r CALICOCTL="/opt/calico/bin/calico"
