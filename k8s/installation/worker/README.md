# 安装Worker节点

Worker节点上运行的组件较少，必要的有kube-proxy和kubelet，其它功能都是以容器插件的方式运行，不在本文说明。

Worker节点必须在Master节点部署完成后开始部署。

Master节点也可以复用为Worker节点，本文就采用Master\*3的方式复用为Worker\*3。

以下步骤在所有Worker节点依次执行。

## 安装kube-proxy组件

## 安装kubelet组件

## 部署CNI插件Calico
