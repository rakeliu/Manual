# 安装Worker节点

Worker节点上运行的组件较少，必要的有kube-proxy和kubelet，其它功能都是以容器插件的方式运行，不在本文说明。

Worker节点必须在Master节点部署完成后开始部署。

Master节点也可以复用为Worker节点，本文就采用Master\*3的方式复用为Worker\*3。

以下步骤在所有Worker节点依次执行。

## 安装ipvs

在所有节点安装ipvs工具。

```bash
# yum 在线安装
$ sudo yum install -y ipvsadm bridge-utils conntrack

# yum 离线安装
$ sudo yum install -y \
    ipvsadm-1.27-8.el7.x86_64.rpm \
    bridge-utils-1.5-9.el7.x86_64.rpm \
    conntrack-tools-1.4.4-7.el7.x86_64.rpm \
    libnetfilter_cthelper-1.0.0-11.el7.x86_64.rpm \
    libnetfilter_cttimeout-1.0.0-7.el7.x86_64.rpm \
    libnetfilter_queue-1.0.2-2.el7_2.x86_64.rpm
```

## 安装kubelet组件

## 安装kube-proxy组件

## 部署CNI插件Calico
