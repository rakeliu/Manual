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
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kubernetes-csr.json | sudo ./cfssljson -bare kubernetes
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
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | sudo ./cfssljson -bare admin
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
