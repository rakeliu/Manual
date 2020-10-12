# 安装k8s-master节点

本文采用全手工配置，从github、官网等下载相关程序包、配置包，不采用yum进行自动安装。

## 准备阶段

### 下载程序包

在<https://github/kubernetes/kubernetes>中找到CHANGELOG，找到下载文件进行下载。共三个程序包，分别是server, client, node程序包，分别对应服务端、客户端、节点段（即master, client, worker），其中服务端包含了其余两个，仅下载服务端程序包足以。

原始下载地址为：

- [https://dl.k8s.io/v1.19.0/kuberentes-server-linux-amd64.tar.gz](https://dl.k8s.io/v1.19.0/kuberentes-server-linux-amd64.tar.gz) 服务端

- [https://dl.k8s.io/v1.19.0/kuberentes-client-linux-amd64.tar.gz](https://dl.k8s.io/v1.19.0/kuberentes-client-linux-amd64.tar.gz) 客户端

- [https://dl.k8s.io/v1.19.0/kuberentes-node-linux-amd64.tar.gz](https://dl.k8s.io/v1.19.0/kuberentes-node-linux-amd64.tar.gz) 节点端

### 解压程序包

在所有master节点解压程序包，并将其链接到指定目录上。

```bash
# 解压程序包，解压目录为/opt/kubernetes
$ sudo tar -xvzf kubernetes-server-linux-amd64.tar.gz -C /opt
# 链接至指定目录/opt/k8s/bin
$ sudo ln -sf /opt/kubernetes/server/bin/{kube-apiserver,\
kube-controller-manager,\
kube-scheduler,\
kubelte,\
kubeadm,\
kube-proxy,\
apiextensions-apiserver,\
mounter} \
/opt/k8s/bin/
```

### 命令自动补齐（可选）

Kubernetes 的管理主命令程序是 kubelet，支持导出命令参数补齐，可安装一个附加程序包，使得kubelet命令参数自动补齐。

命令自动补齐程序包名为`bash-completion`。

```bash
# yum 安装
$ sudo yum install -y bash-completion
# 或离线程序包安装
$ sudo yum install -y bash-completion-2.1-8.el7.noarch.rpm
# 配置自动补齐
$ source <(kubectl completion bash)
# 添加到用户脚本中
$ echo "source <(kubectl completion bash)" >> ~/.bashrc
```

## 安装Master节点各个组件

至少安装ApiServer, Controller和Schedulre组件。后续还需安装CNI插件（Calico）等。

以下逐一简述安装步骤。

### [安装kube-apiserver组件](apiserver/README.md)

### 安装kube-controller-manager组件

### 安装kube-scheduler组件
