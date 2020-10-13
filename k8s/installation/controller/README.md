# 安装Controller组件

## 制作证书

该证书仅供kube-controller-manager组件使用。

### 创建csr请求的json文件（kube-controller-manager-csr.json）

文件位于`/opt/ssl/kube-controller-manager-csr.json`。

```json
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
```

- hosts列表仅包含了kube-controller-manager的节点IP，确保授权最小化。
- CN配置为`system:kube-controller-manager`，O配置为`system:kube-controller-manager`，kubernetes内置的ClusterRoleBinding `system:kube-controller-manager`赋予`kube-controller-manager`工作所需的权限。

### 创建证书（kube-controller-manager.pem）和私钥

```bash
$ cd /opt/ssl
$ sudo ./cfssl gencert \
    -ca=ca.pem -ca-key.pem --config=ca-config.json \
    -profile=kuberntes kube-controller-manager-csr.json \
    | sudo ./cfssljson -bare kube-controller-manager
```

将生成的证书文件`kube-controller-manager.pem`和私钥`kube-controller-manager-key.pem`分发至各个Master节点。

## 创建kube-controller-manager的kubeconfig文件

文件`/opt/k8s/cert/kube-controller-manager.kubeconfig`的作用是：`kube-controller-manager`组件访问kube-apiserver时的默认配置。

```bash
$ sudo kubectl config set-cluster kuberntes \
    --certificate-authority=/opt/ssl/ca.pem \
    --embed-certs=true \
    --server=https://10.185.176.34:8443 \
    --kubeconfig=/opt/k8s/cert/kube-controller-manager.kubeconfig

$ sudo kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=/opt/ssl/kube-controller-manager.pem \
    --client-key=/opt/ssl/kube-controller-manager-key.pem \
    --embed-certs=true \
    --kubeconfig=/opt/k8s/cert/kube-controller-manager.kubeconfig

$ sudo kubectl config set-context system:kube-controller-manager \
    --cluster=kubernetes \
    --user=system:kube-controller-manager \
    --kubeconfig=/opt/k8s/cert/kube-controller-manager.kubeconfig

$ sudo kubectl config use-context system:kube-controller-manager \
    --kubeconfig=/opt/k8s/cert/kube-controller-manager.kubeconfig
```

将创建好的`kube-controller-manager.kubeconfig`文件分发至各个Master节点。

## 创建system unit文件（kube-controller-manager.service）

创建`kube-controller-manager`的服务单元文件`/etc/systemd/system/kube-controller-manager.service`。

```conf
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes
After=kube-apiserver.service
Wants=kube-apiserver.service

[Service]
EnvironmentFile=/opt/k8s/conf/kube-controller-manager.conf
ExecStart=/opt/k8s/bin/kube-controller-manager \
  --bind-address=127.0.0.1 \
  --master=http://127.0.0.1:8080 \
  --kubeconfig=${KUBE_CONTROLLER_CONFIG_FILE} \
  --service-cluster-ip-range=${KUBE_SERVICE_CLUSTER_IP_RANGE} \
  --cluster-cidr=${KUBE_PODS_CLUSTER_CIDR} \
  --cluster-name=kubernetes \
  --cluster-signing-cert-file=${CA_FILE} \
  --cluster-signing-key-file=${CA_KEY_FILE} \
  --experimental-cluster-signing-duration=8760h \
  --root-ca-file=${CA_FILE} \
  --client-ca-file=${CA_FILE} \
  --service-account-private-key-file=${CA_KEY_FILE} \
  --leader-elect=true \
  --feature-gates=RotateKubeletServerCertificate=true \
  --controllers=*,bootstrapsigner,tokencleaner \
  --horizontal-pod-autoscaler-sync-period=10s \
  --tls-cert-file=${KUBE_CONTROLLER_MANAGER_CERT_FILE} \
  --tls-private-key-file=${KUBE_CONTROLLER_MANAGER_KEY_FILE} \
  --use-service-account-credentials=true \
  --alsologtostderr=true \
  --logtostderr=false \
  --log-dir=${KUBE_CONTROLLER_MANAGER_LOG_DIR} \
  --v=4

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

- `--bind-address`：指定监听地址为本地环回地址。
- `--kubeconfig`：指定kubeconfig文件，`kube-controller-manager`使用该文件连接`kube-apiserver`。
- `--service-cluster-ip-range`：指定Service Cluster IP地址段，必须与`kube-apiserver`同名参数一致。
- `--pods-cluster-cidr`：指定PODs的IP地址段，必须与后续的kubelet,CNI等一致。
- `--cluster-signing-*-file`：签名TLS Bootstrap创建的证书，用CA证书对其签名。
- `--experimental-cluster-signing-duration`：指定TLS Bootstrap证书的有效期。
- `--root-ca-file`：放置到容器`ServiceAccount`中的CA证书，用来对`kube-apiserver`的证书进行校验。
- `--client-ca-file`：一旦指定，任何客户端的访问通过该CA证书进行验证。
- `--service-account-private-key-file`：签名`ServiceAccount`中Token的私钥文件，必须和`kube-apiserver`的`--service-account-key-file`指定的公钥文件配对使用。
- `--leader-elect=true`：集群运行模式，启用选举功能，被选为leader的节点负责处理工作，其余节点为阻塞状态。
- `--feature-gates=RotateKubeletServerCertificate=true`：开启kubelete server证书的自动更新。
- `--controller=*,bootstrapsigner,tokencleaner`：启用的控制器列表，`tokencleaner`用于自动清理过期的Bootstrap Token。
- `--horizontal-pod-autoscaler-*`：custom metrics相关参数，支持autoscaling/v2alpha1。
- `--tls-cert-file`, `--tls-private-key-file`：使用https输出metrics时使用的Server证书和密钥。
- `--user-service-account-credentials=true`：启用ServiceAccount认证。

## 创建环境变量文件（kube-controller-manager.conf）

环境变量文件位于`/opt/k8s/conf/kube-controller-manager.conf`。

```conf
###
# The following values are used to configure the kubernetes controller-Manager
#
# defaults from config and apiserver should be adequate

## configuration file
KUBE_CONTROLLER_CONFIG_FILE="/opt/k8s/conf/kube-controller-manager.kubeconfig"

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
KUBE_CONTROLLER_MANAGER_LOG_DIR="/ext/k8s/controller"
```
