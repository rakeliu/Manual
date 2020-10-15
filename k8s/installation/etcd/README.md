# 安装ETCD服务

本章安装带鉴权的ETCD服务。

## 制作 ETCD 所需证书

既然是带鉴权的 ETCD 服务，证书是必不可少的前提条件。

### 创建 ETCD 证书签名请求文件（etcd-csr.json）

文件位于`/opt/ssl/etcd-csr.json`。

```json
{
  "CN": "etcd",
  "hosts": [
    "127.0.0.1",
    "192.168.176.35",
    "192.168.176.36",
    "192.168.176.37",
    "k8s-master1",
    "k8s-master2",
    "k8s-master3"
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

- hosts 字段制定授权该证书的etcd节点的ip或主机名列表。这里应将运行 etcd 集群和请求 etcd 的客户端节点都包含在其中。（Master节点的kube-apiserver**必须**访问etcd，而worker节点的kubelet和kube-proxy则不需要）
- names 字段最好与 ca-csr.json 的一致，未测试过不一致的情况。

### 生成证书和私钥

```bash
$ cd /opt/ssl
$ sudo ./cfssl gencert -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  etcd-csr.json | sudo ./cfssljson -bare etcd
```

- 参数 profile 指向**kubernetes**，即`ca-config.json`中策略名。
- 执行后有一个警告（WARNING），提示证书有效范围为制定的hosts，可忽略。

　　执行后得到证书**etcd.pem**和密钥**etcd-key.pem**。同样，密钥etcd-key.pem只有root用户拥有读权限。

### 分发证书

　　etcd证书是通过根证书ca.pem授权制作，因此在使用etcd证书时，需要根证书鉴权。

　　分发etcd证书时同样需要将根证书ca.pem一道分发。

```bash
$ cd /opt/ssl
$ sudo chmod +r etcd-key.pem
$ declare MASTERS=(master 节点)
$ for host in ${MASTERS[@]}; do
  scp ca.pem etcd.pem etcd-key.pem ${USER}@${host}:~/
  ssh ${USER}@${host} 'sudo chown root:root ca.pem etcd.pem etcd-key.pem; \
    sudo mv -f ca.pem etcd.pem etcd-key.pem /opt/ssl/; \
    sudo chmod 600 /opt/ssl/etcd-key.pem'
done
$ sudo chmod 600 etcd-key.pem
```

## 部署ETCD集群

　　在每一个etcd的节点（即master节点）上执行以下步骤。

### 下载程序文件

从 [github.com/etcd-io/etcd/releases](https://github.com/etcd-io/etcd/releases)下载最新的 etcd **稳定版**，目前是 v3.4.13。

下载后将程序包解压到`/opt/etcd`（或链接到），再将相关程序文件链接至 `/opt/k8s/bin` 下，可直接在PATH中使用。

```bash
# 下载程序包，解压
$ curl https://github.com/etcd-io/etcd/releases/download/v3.4.13/etcd-v3.4.13-linux-amd64.tar.gz
$ sudo tar -xvzf etcd-v3.4.13-linux-amd64.tar.gz -C /opt
$ sudo ln -s /opt/etcd-v3.4.13-linux-amd64 /opt/etcd
$ sudo ln -s /opt/etcd/{etcd,etcdctl} /opt/k8s/bin/
```

准备etcd的工作目录，将其权限设置为**700**。从v3.4.10开始，工作目录的权限**必须**为700。

```bash
# 创建工作目录，赋权
$ sudo mkdir -p /ext/etcd
$ sudo chmod 700 /ext/etcd
```

### 创建 etcd 服务的 system unit 文件

服务单元文件位于`/etc/systemd/system/etcd.service`。

```conf
[Unit]
Description= Etcd Service
After=network.service
After=network-online.service
Wants=network-online.service
Documentation=https://github.com/etcd-io/etcd

[Service]
Type=notify
WorkingDirectory=/ext/etcd
EnvironmentFile=/opt/k8s/conf/etcd.conf
# Set GOMAXPROCS to number of processes
ExecStart=/bin/bash -C "GOMAXPROCS=1" /opt/k8s/bin/etcd
Restart=on-failure
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
```

### 创建 etcd 服务环境变量文件

环境变量文件位于`/opt/k8s/conf/etcd.conf`。

```conf
#[member]
ETCD_NAME="k8s-master1"
ETCD_DATA_DIR="/ext/etcd"
ETCD_LISTEN_PEER_URLS="https://192.168.176.35:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.176.35:2379,https://127.0.0.1:2379"
ETCD_LOGO_LEVEL="info"
ETCD_LOGGER="zap"

#[cluster]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.176.35:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.176.35:2379"
ETCD_INITIAL_CLUSTER="k8s-master1=https://192.168.176.35:2380,k8s-master2=https://192.168.176.36:2380,k8s-master3=https://192.168.176.37:2380"
INITIAL_CLUSTER_TOKEN="etcd-cluster"
INITIAL_CLUSTER_STATE="new"

#[security]
ETCD_CERT_FILE="/opt/ssl/etcd.pem"
ETCD_KEY_FILE="/opt/ssl/etcd-key.pem"
ETCD_TRUSTED_CA_FILE="/opt/ssl/ca.pem"
ETCD_CLIENT_CERT_AUTH="true"
ETCD_PEER_CERT_FILE="/opt/ssl/etcd.pem"
ETCD_PEER_KEY_FILE="/opt/ssl/etcd-key.pem"
ETCD_PEER_TRUSTED_CA_FILE="/opt/ssl/ca.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"

#[fix heart beat interval]
ETCD_HEARTBEAT_INTERVAL=1000
ETCD_ELECTION_TIMEOUT=5000
EOF
```

- ETCD_NAME: 每个etcd节点命名，集群中不能重复，可用主机名，也可用etcd-0, etcd-1等等。
- 各个URLS中，涉及IP地址，一定要用本机IP，且在集群中可相互访问。
- ETCD_INITIAL_CLUSTER：表示整个集群所有节点，形如“节点名=https://节点地址:端口”， 各节点间用逗号（,）分隔。端口2379为对外服务端口，2380为集群内部各节点交互端口。
- 认证部分：
  - 所有**ETCD_PEER**打头的都表示集群内节点认证，而只有**ETCD**打头的表示用户侧认证。
  - **CERT_FILE**表示证书，即etcd.pem。
  - **KEY_FILE**表示私钥，即etcd-key.pem。
  - **TRUSTED_CA_FILE**表示根证书，即ca.pem。
- 修补部分。在个人电脑安装的虚拟机学习环境中，因计算力、内存、IO等性能限制，etcd集群的各节点容易出现相互间心跳超时，将心跳间隔延长解决。

## 启动与验证

### 启动

在每一个etcd节点启动服务，并设置为开机自启动方式。

```bash
# 启动服务
$ sudo systemctl daemon-reload
$ sudo systemctl enable etcd
$ sudo systemctl start etcd
```

查看服务运行状态：`sudo systemctl status etcd`

查看日志：`sudo journalctl -f -n 1000 etcd`

如果没有报错信息，没有反复启动，则etcd服务启动成功。

### 验证

检查etcd集群环境健康状况，在任一etcd节点执行命令：

```bash
$ sudo etcdctl --cacert=/opt/ssl/ca.pem \
  --cert=/opt/ssl/etcd.pem \
  --key=/opt/ssl/etcd-key.pem
  --endpoints=https://192.168.176.35:2379,https://192.168.176.36:2379,https://192.168.176.37:2379 \
  endpoint health
```

上述命令指定了大量参数，包括认证证书和etcd的endpoint，可将其设为环境变量，简化命令键入，防止出错。

```bash
# 定义环境变量，简化命令键入。
$ export ETCD_ENDPOINTS="https://192.168.176.35:2379,https://192.168.176.36:2379,https://192.168.176.37:2379"
$ export ETCD_PARAMS="--cacert=/opt/ssl/ca.pem --cert=/opt/ssl/etcd.pem --key=/opt/ssl/etcd-key.pem --endpoints=${ETCD_ENDPOINTS}"
```

定义环境变量后，可简化命令长度：`$sudo etcdctl ${ETCD_PARAMS} member list`
