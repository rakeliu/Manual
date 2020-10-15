# 安装Scheduler组件

## 制作证书

### 创建csr请求的json文件（kube-scheduler-csr.json）

同样，文件位于`/opt/ssl/kube-scheduler-csr.json`。

```json
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
```

- hosts 字段包含所有运行Scheduler组件的节点IP列表，也只包含这些节点，权限最小化。
- CN 为`system:kube-scheduler`，O为`system:kube-scheduler`，kubernetes内置的ClusterRoleBinding `system:kube-scheduler`将赋予`kube-scheduler`工作所需的权限。

### 生成证书（kube-scheduler.pem）和私钥

```bash
$ cd /opt/ssl
$ sudo ./cfssl gencert \
    -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json \
    -profile=kubernetes kube-scheduler-csr.json \
    | sudo ./cfssljson -bare kube-scheduler
```

在`/opt/ssl`目录下生成证书文件`kube-scheduler.pem`和私钥`kube-scheduler-key.pem`，将其分发至所有Master节点。

## 创建kube-scheduler的kubeconfig文件

kube-scheduler的kubeconfig文件位于`/opt/k8s/conf/kube-scheduler.kubeconfig`。

```bash
$ sudo kubectl config set-cluster kubernetes \
    --certificate-authority=/opt/ssl/ca.pem \
    --embed-certs=true \
    --server=https://192.168.176.34:8443 \
    --kubeconfig=/opt/k8s/conf/kube-scheduler.kubeconfig

$ sudo kubectl config set-credentials system:kube-scheduler \
    --client-certificate=/opt/ssl/kube-scheduler.pem \
    --client-key=/opt/ssl/kube-scheduler-key.pem \
    --embed-certs=true \
    --kubeconfig=/opt/k8s/conf/kube-scheduler.kubeconfig

$ sudo kubectl config set-context system:kube-scheduler \
    --cluster=kubernetes \
    --user=system:kube-scheduler \
    --kubeconfig=/opt/k8s/conf/kube-scheduler.kubeconfig

$ sudo kubectl config use-context system:kube-scheduler \
    --kubeconfig=/opt/k8s/conf/kube-scheduler.kubeconfig
```

将配置文件`/opt/k8s/conf/kube-scheduler.kubeconfig`分发至各个Master节点。

## 创建服务单元文件（kube-scheduler.service）

文件位于`/etc/systemd/system/kube-scheduler.service`。

```conf
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes
After=kube-apiserver.service
Wants=kube-apiserver.service

[Service]
EnvironmentFile=/opt/k8s/conf/kube-scheduler.conf
ExecStart=/opt/k8s/bin/kube-scheduler \
  --bind-address=127.0.0.1 \
  --kubeconfig=${KUBE_SCHEDULER_CONFIG} \
  --leader-elect=true \
  --alsologtostderr=true \
  --logtostderr=false \
  --log-dir=${KUBE_SCHEDULER_LOG_DIR} \
  --v=4
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

## 创建环境变量文件（kube-scheduler.conf）

文件位于`/opt/k8s/conf/kube-scheduler.conf`。

```conf
##
# The following values are used to configure the kubernetes scheduler
#
# defaults from config and apiserver should be adequate

## configuration file
KUBE_SCHEDULER_CONFIG=/opt/k8s/conf/kube-scheduler.kubeconfig

## log direcory
KUBE_SCHEDULER_LOG_DIR=/ext/k8s/scheduler
```

将服务单元文件`kube-scheduler.service`和环境变量文件`kube-scheduler.conf`分发至各个Master节点。

## 设置开机自启动并启动服务

```bash
# 刷新服务配置
$ sudo systemctl daemon-reload
# 设置开机自启动
$ sudo systemctl enable kube-scheduler
# 启动服务
$ sudo systemctl start kube-scheduler
# 查看服务状态、日志
$ sudo systemctl status kube-scheduler
$ sudo journalctl -f -n 1000 -u kube-scheduler
```
