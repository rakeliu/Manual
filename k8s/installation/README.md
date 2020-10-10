# 安装 **Kubernetes**

安装 Kubernetes，采用集群方式。

## 部署规划

### 主机规划

计划采用 3 台主机，既做 Master 节点，也做 Worker 节点，另配置一个VIP。

- 192.168.176.34 vip
- 192.168.176.35 k8s-master1
- 192.168.176.36 k8s-master2
- 192.168.176.37 k8s-master3

|序号|IP|主机名|用途|备注|
| -: | - | :-: | - | - |
|1|192.168.176.34|(none)|k8s-vip|kube-apiserver 的 vip地址，由 keepalived 管理|
|2|192.168.176.35|k8s-master1|管理节点集群|部署 etcd, apiserver, controller, scheduler 等管理服务；也部署 docker 运行业务 pod。|
|3|192.168.176.36|k8s-master2|(同上)|(同上)|
|4|192.168.176.37|k8s-master3|(同上)|(同上)|

### 网络规划

Kubernetes 的网络比较复杂，本身就需要容器和服务（业务）两张网络。加之又是在某宿主机（虚拟机或物理机）中运行，宿主机本身网络这里称为管理网。

#### 管理网

管理网指宿主机的物理网卡 IP 地址范围，此处取 192.168.176.0/24。

#### 服务网（业务网）

服务网指 k8s 中服务的地址范围，此处取 10.15.0.0/16。

#### 容器网络

容器网络指 k8s 中 pod 的地址范围，此处取 10.16.0.0/16。

#### CNI 插件

CNI 插件是 k8s 网络管理插件，此处采用 Calico，有些k8s集群也采用 FlannelNet，这是应用最为广泛的两种容器网络插件。

## 配置

### 基础配置

**以下配置对所有主机有效。**

主机配置：采用2C/4G, 2C/3G, 2C/2G 三台主机。4G内存主要是因为后续配置是，部分容器需要使用较大内存的配置。

所有主机安装 Docker 服务。

所有主机不再新增用户和组，直接将常用用户添加到 docker 组中，具备 sudo 权限。

修改所有主机的 hosts 文件或 dns 配置，将所有节点加入其中，包括3个 master 节点和 vip 地址。

升级所有组件至最新，禁用 firewalld、selinux、swap分区，保留 iptalbes。禁用 swap 分区可使用如下命令：

`$ sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab`

优化内核参数：

```bash
$ sudo cat > /etc/sysctl.d/kubernetes.conf << EOF
net.ipv4.ip_forward = 1
net.ipv4.tcp_tw_recycle=0
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.all.forwarding = 1
vm.swappiness=0
vm.overcommit_memory=1
vm.panic_on_oom=0
fs.inotify.max_user_watches=89100
fs.file-max=52706963
fs.nr_open=52706963
EOF

$ sysctl -p /etc/sysctl.d/kubernetes.conf
```

### 安装前的准备

- 配置各种目录

```bash
# 证书目录
$ sudo mkdir -p /opt/ssl

# k8s 程序、服务配置、应用配置等目录
$ sudo mkdir -p /opt/k8s/{bin,conf,yaml,token}

# calico 和 cni 目录
$ sudo mkdir -p /opt/calico/{bin,conf,yaml} /etc/calico
$ sudo mkdir -p /opt/cni/bin /etc/cni/net.d

# 各种工作、日志目录
$ sudo mkdir -p /ext/k8s/log/{apiserver,controller-manager,scheduler,kubelet} /ext/etcd /var/lib/calico
```

- 设置环境变量

```bash
$ sudo cat > /etc/profile.d/kubernetes.sh <<EOF
K8S_HOME=/opt/k8s
export PATH=$PATH:$K8S_HOME/bin
EOF

$ sudo cat > vi /etc/profile.d/etcd.sh <<EOF
export ETCDCTL_API=3
EOF

$ source /etc/profile.d/kubernetes.sh
$ source /etc/profile.d/etcd.sh
```

### [制作 **CA** 证书](ca/README.md)

证书制作程序和证书文件都放在 /opt/ssl 目录下，使用 cfssl 来制作证书。

### [安装 **ETCD** 服务](etcd/README.md)

**ETCD** 服务安装在3个 Master节点即可。

## 安装 Docker

参照单机安装Docker，在每个节点，包括Worker节点安装即可。

## [安装HAProxy、KeepAlived](HA.md)

规划的Master节点为3个，需要通过集群软件设置VIP节点，这里采用HAProxy + KeepAlived来配置HA。
