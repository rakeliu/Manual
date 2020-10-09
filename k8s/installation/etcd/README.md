# 安装 **ETCD** 服务
本章安装带鉴权的 **ETCD** 服务。
## 制作 ETCD 所需证书
既然是带鉴权的 ETCD 服务，证书是必不可少的前提条件。
### 创建 ETCD 证书签名请求文件etcd-csr.json
```
$ cd /opt/ssl
$ sudo cat > etcd-csr.json << EOF
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
EOF
```
- hosts 字段制定授权该证书的 etcd 节点的 ip 或主机名列表。这里应将运行 etcd 集群和请求 etcd 的客户端节点都包含在其中。
- names 字段最好与 ca-csr.json 的一致，未测试过不一致的情况。
### 生成证书和私钥
