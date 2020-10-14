# 安装ApiServer组件

ApiServer组件是kubernetes中最核心组件之一，优先于其它所有组件运行。

## 制作证书

至少要制作两套证书，一套为整个kubernetes集群内部认证证书，一套为ApiServer管理用证书。

### 制作kubernetes证书

#### 创建csr请求的json文件（kubernetes-csr.json）

文件位于`/opt/ssl/kubernetes-csr.json`。

```json
{
  "CN": "kubernetes",
  "hosts": [
    "127.0.0.1",
    "192.168.176.34",
    "192.168.176.35",
    "192.168.176.36",
    "192.168.176.37",
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
```

- hosts里面配置了所有kubernetes内部交互的地址，其中`10.15.0.1`是service cluster网段的第一个IP。

#### 生成kubernetes证书和私钥

```bash
$ cd /opt/ssl
$ sudo ./cfssl gencert \
  -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json \
  -profile=kubernetes kubernetes-csr.json \
  | sudo ./cfssljson -bare kubernetes
```

生成证书文件`kubernetes.pem`和私钥`kubernetes-key.pem`。

### 制作admin证书

#### 创建csr请求的json文件（admin-csr.json）

文件位于`/opt/ssl/admin-csr.json`。

```json
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
```

- O 为 `system:master`，kube-apiserver收到该证书后，将请求的Group设置为`system:master`。
- 预定义的`ClusterRoleBinding cluster-admin`将`Group system:master`与`Role cluster-admin`绑定，该Role授予所有的API权限。
- 该证书只会被kubelet当做client证书使用，所以hosts字段为空。

#### 生成admin证书和私钥

```bash
$ cd /opt/ssl
$ sudo ./cfssl gencert \
  -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json \
  -profile=kubernetes admin-csr.json \
  | sudo ./cfssljson -bare admin
  ```

### 分发证书

将两套证书和私钥分发至各个Master节点，如果有其他管理节点需要，还需向管理节点分发admin证书（不能分发私钥）。

```bash
$ cd /opt/ssl
# 私钥的可读权限
$ sudo chmod +r kubernetes-key.pem admin-key.pem
$ declare -a MASTERS=(所有Master节点)
$ declare CERTIFICATIONS="kubernetes.pem kubernetes-key.pem admin.pem admin-key.pem"
$ for host in ${MASTERS[@]}; do
    scp kubernetes.pem kubernetes-key.pem admin.pem admin-key.pem ${USER}@${host}:~/
    ssh ${USER}@${host} "sudo chown root:root ${CERTIFICATIONS}; \
      sudo mv -f ${CERTIFICATIONS} /opt/ssl; \
      sudo chmod 600 kubernetes-key.pem admin-key.pem"
  done

# 还原权限
$ sudo chmod 600 kubernetes-key.pem admin-key.pem
```

## 客户端需求配置

这里的客户端，是指kube-apiserver的客户端，即包括controller, scheduler以及kubelet（worker节点）等。

### 创建客户端需求的token文件

文件位于`/opt/k8s/token/bootstrap-token.csv`。

```bash
$ sudo mkdir -p /opt/k8s/token
$ head -c 16 /dev/urandom | od -An -t x | tr -d ''
3dc0f45a5cba1389ddc6c75cf94231c1 # 这是生成的token
$ sudo vi /opt/k8s/token/bootstrap-token.csv
3dc0f45a5cba1389ddc6c75cf94231c1,kubelet-bootstrap,10001,"system:kubelet-bootstrap"
# 文件中第一个字段就是上述生成的token
```

然后将token文件分发至各个节点，包括Master和Worker节点。

### 创建基础用户名/密码认证配置

这个有设么用处还不清楚。

在所有节点创建一个基础认证文件，`/opt/k8s/token/basic-auth.csv`。

```bash
$ sudo cat > /opt/k8s/token/basic-auth.csv <<EOF
admin,admin,1
readonly,readonly,2
EOF
```

将该文件分发至各个Master和Worker节点节点。

然后在每个节点（Master和Worker）创建默认配置。

```bash
$ sudo kubectl config set-credentials admin \
    --client-certificate=/opt/ssl/admin.pem \
    --client-key=/opt/ssl/admin-key.pem \
    --embed-certs=true
```

## 部署ApiServer

以下步骤在每一个Master节点执行。

### 创建审计日志配置文件

创建一个最小化审计日志配置文件[`audit-policy-min.yaml`](audit-policy-min.yaml)，全量配置文件参看[`audit-policy.yaml`](audit-policy.yaml)，文件存放于`/opt/k8s/yaml`。

audit-policy-min.yaml文件内容：

```yaml
# Log all requests at the Metadata level.
apiVersion: audit.k8s.io/v1beta1
kind: Policy
rules:
- level: Metadata
```

### 创建kube-apiserver的system unit文件（kube-apiserver.service）

文件位于`/etc/systemd/system/kube-apiserver.service`。

```conf
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes
After=etcd.service
Wants=etcd.service

[Service]
EnvironmentFile=/opt/k8s/conf/kube-apiserver.conf
ExecStart=/opt/k8s/bin/kube-apiserver \
  --enable-admission-plugins=${KUBE_ADMISSION_CONTROL} \
  --anonymous-auth=false \
  --advertise-address=${KUBE_API_ADDRESS} \
  --bind-address=${KUBE_API_ADDRESS} \
  --authorization-mode=Node,RBAC \
  --runtime-config=api/all=true \
  --enable-bootstrap-token-auth \
  --token-auth-file=${KUBE_TOKEN_AUTH_FILE} \
  --service-cluster-ip-range=${KUBE_SERVICE_CLUSTER_IP_RANGE} \
  --service-node-port-range=${KUBE_SERVICE_NODE_PORT} \
  --tls-cert-file=${KUBE_TLS_CERT_FILE} \
  --tls-private-key-file=${KUBE_TLS_KEY_FILE} \
  --client-ca-file=${KUBE_CA_FILE} \
  --kubelet-client-certificate=${KUBE_TLS_CERT_FILE} \
  --kubelet-client-key=${KUBE_TLS_KEY_FILE} \
  --service-account-key-file=${KUBE_CA_KEY_FILE} \
  --etcd-servers=${KUBE_ETCD_SERVERS} \
  --etcd-cafile=${KUBE_CA_FILE} \
  --etcd-certfile=${ETCD_CERT_FILE} \
  --etcd-keyfile=${ETCD_KEY_FILE} \
  --allow-privileged=true \
  --apiserver-count=3 \
  --requestheader-client-ca-file=${KUBE_CA_FILE} \
  --requestheader-allowed-names=${KUBE_REQUESTHEADER_ALLOWED_NAMES} \
  --requestheader-extra-headers-prefix=${KUBE_REQUESTHEADER_EXTRA_HEADERS_PREFIX} \
  --requestheader-group-headers=${KUBE_REQUESTHEADER_GROUP_HEADERS} \
  --requestheader-username-headers=${KUBE_REQUESTHEADER_USERNAME_HEADERS} \
  --proxy-client-cert-file=${KUBE_PROXY_CLIENT_CERT_FILE} \
  --proxy-client-key-file=${KUBE_PROXY_CLIENT_KEY_FILE} \
  --runtime-config=${KUBE_RUNTIME_CONFIG} \
  --audit-policy-file=${KUBE_AUDIT_POLICY_CONF} \
  --audit-log-maxage=30 \
  --audit-log-maxbackup=3 \
  --audit-log-maxsize=100 \
  --audit-log-path=${KUBE_AUDIT_POLICY_PATH} \
  --logtostderr=true \
  --log-dir=${KUBE_LOG_DIR} \
  --v=4
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 创建环境变量文件（kube-apiserver.conf）

文件位于`/opt/k8s/conf/kube-apiserver.conf`。

```conf
## kubernetes apiserver system config

## The address on the local server to listen to.
KUBE_API_ADDRESS="192.168.176.35"
## The port on the local server to listen on.
KUBE_API_PORT="--port=8080"
## Port worker listen on.
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
KUBE_LOG_DIR="/appdata/k8s/apiserver"

## Audit
#
## Audit policy configuration
KUBE_AUDIT_POLICY_CONF="/opt/k8s/yaml/audit-policy-min.yaml"
## Audit policy log files
KUBE_AUDIT_POLICY_PATH="/appdata/k8s/apiserver/api-audit.log"

## Metric-Server addon
#
#KUBE_REQUESTHEADER_CLIENT_CA_FILE=${KUBE_CA_FILE}
KUBE_REQUESTHEADER_ALLOWED_NAMES=""
KUBE_REQUESTHEADER_EXTRA_HEADERS_PREFIX="X-Remote-Extra-"
KUBE_REQUESTHEADER_GROUP_HEADERS="X-Remote-Group"
KUBE_REQUESTHEADER_USERNAME_HEADERS="X-Remote-User"
KUBE_PROXY_CLIENT_CERT_FILE="/opt/ssl/metrics-server.pem"
KUBE_PROXY_CLIENT_KEY_FILE="/opt/ssl/metrics-server-key.pem"
KUBE_RUNTIME_CONFIG="api/all=true"
```

- --authorization-mode=Node,RBAC：开启Node和RBAC授权模式，拒绝未授权的请求。
- --server-account-key-file：签名ServiceAccountToken的公钥文件，kube-controller-manager的--server-account-private-key-file指私钥文件，两者配对使用。
- --tls-*-file：指定apiserver使用的证书、私钥和CA文件，--client-ca-file用于验证client端（controller,scheduler,kubelet,kube-proxy等）请求所带的证书。
- --kubelet-client-certificate, --kubelet-client-key：如果有指定参数，则使用https访问kublet APIs需要为证书对应的用户（前面的kubernetes.pem证书用户为kubernetes）定义RBAC规则，否则方位kublet APIs时提示未授权。
- --kube-api-address：当前节点可访问的IP地址，该IP地址在集群环境中可被访问到，不能是127.0.0.1这种环回地址，否则外界不能访问它的安全端口（6443）。
- --insecure-port=0：关闭监听非安全端口（8080）。
- --service-cluster-ip-range：指定Service Cluster IP地址段。
- --service-node-port-range：指定NodePort的可用端口范围，后续在部署pod时有更深的体会。
- --runtime-config=api/all=true：启用所有版本的APIs，如`autoscaling/v2alpha1`。
- --enable-bootstrap-toke-auth：启用kubelet bootstrap的token认证。
- --apiserver-count=3：指定集群运行模式，这里表示运行了3个kube-apiserver服务；多个服务会通过选举产生一个leader节点，其它节点处于阻塞状态。
- **特别注意**：配置中有很多证书、密钥文件，不要用错。

### 配置自启动并启动服务

```bash
# 刷新服务单元配置
$ sudo systemctl daemon-realod
# 配置自启动
$ sudo systemctl enable kube-apiserver
# 启动服务
$ sudo systemctl start kube-apiserver
# 查看状态和日志
$ sudo systemctl status kube-apiserver
$ sudo journalctl -f -n 1000 -u kube-apiserver
```

查看启动日志，可看到服务各节点的启动进度和状态，有错误及时排查。

## 授权访问kube-apiserver

在ApiServer部署完成后，客户端并不是能轻易访问APIs，应当创建一个`${HOME}/~kube/*.kubeconfig`文件，其中包含登录地址、认证信息等。

### 创建默认的kubeconfig文件

```bash
# 创建目录
$ mkdir ~/.kube
$ cd ~/.kube

# 配置集群信息，集群名kubernetes，包括入口地址、证书信息
$ sudo kubectl config set-cluster kubernetes \
    --certificate-authority=/opt/ssl/ca.pem \
    --embed-certs=true \
    --server=https://192.168.176.34:6443
    --kubeconfig=config

# 添加用户admin及证书
$ sudo kubectl config set-credentials admin \
    --client-certificate=/opt/ssl/admin.pem \
    --client-key=/opt/ssl/admin-key.pem \
    --embed-certs=true \
    --kubeconfig=config

# 将用户admin添加到集群中
$ sudo kubectl config set-context kuberntes \
    --cluster=kubernetes \
    --user=admin \
    --kubeconfig=config

# 将集群kubernetes设置为默认使用
$ sudo kubectl config use-context kubernetes \
    --kubeconfig=config

# 由于使用sudo命令进行创建配置，配置文件config属于root用户，更改为当前用户
$ sudo chown ${USER}:${GROUP} config
```

- 使用`sudo`命令使因为使用的很多证书文件权限属于root用户。
- 执行上述命令时，需保证kube-apiserver以及HAProxy等正常运行。
- `--server=https://192.168.176.34:6443`： 指向VIP地址的HAProxy转发端口，由HAProxy负责转发至3个Master节点的kube-apiserver服务（8443端口）。
- `--embed-certs=true`：将证书信息编码后嵌入配置文件中。
- `--kubeconfig=config`：配置信息写入文件当前目录（`~/.kube`）的`config`文件中，kubelet默认读取该文件。

制作好的kubeconfig文件（`~/.kube/config`）分发至各个Master节点。

### 创建一个用户角色绑定

在任一活动节点上执行一次即可，将用户`kubernetes`与集群角色`system:kubelet-api-admin`绑定，命名为`kube-apiserver:kubelet-apis`。

```bash
$ kubectl create clusterrolebinding kube-apiserver:kubelet-apis \
    --clusterrole=system:kubelet-api-admin \
    --user kubernetes
```
