# 制作 **CA** 证书

证书制作程序和证书文件都放在 /opt/ssl 目录下，使用 cfssl 来制作证书。

## 下载程序文件 cfssl

```bash
# 将程序文件下载到/opt/ssl目录中
$ cd /opt/ssl
$ sudo curl http://pkg.cfssl.org/R1.2/cfssl_linux-amd64 -o cfssl
$ sudo curl http://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 -o cfssljson
$ sudo curl http://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64 -o cfssl-certinfo
```

## 创建生成CA证书的json配置文件（ca-config.json）

该文件位于`/opt/ssl/ca-config.json`。

```json
{
  "signing": {
    "default": {
      "expire": "87600h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
          "signing",
          "key encipherment",
          "server auth",
          "client auth"
        ],
        "expiry": "87600h"
      }
    }
  }
```

- profiles下创建了一个名为**kubernetes**的配置策略，该策略名后续还要使用。
- usages段中，**server auth**表示client可用该ca对server提供的证书进行验证。
- usages段中，**client auth**表示server可用该ca对client提供的证书进行验证。

## 创建生成CA证书csr请求的json配置文件（ca-csr.json）

该文件位于`/opt/ssl/ca-csr.json`。

```json
{
  "CN": "kubernetes",
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

- **CN**：即**Common Name**。kube-apiserver从证书中提取该字段作为请求的用户名（**User Name**），浏览器使用该字段验证网站的合法性。
- **O**: 即 **Organization**。kube-apiserver从证书中提取该字段作为请求用户所属的组（**Group**）。
- kube-apiserver将提取的User Name和Group作为RBAC授权的用户标识。

## 生成 CA 证书和私钥

```bash
# 在/opt/ssl中创建CA证书和私钥
$ cd /opt/ssl
$ sudo ./cfssl gencert -initca ca-csr.json | sudo ./cfssljson -bare ca
```

将生成**ca.pem**和**ca-key.pem**两个文件，其中**ca.pem**是**CA**证书，**ca-key.pem**是**CA**的私钥。

## 分发 CA 证书和私钥

将证书和私钥分发至所有节点。注意：是所有节点，包括**Master**和**Worker**节点。

```bash
$cd /opt/ssl
$declare -a WORKERS=(所有节点)
$sudo chmod +r ca-key.pem  # 私钥只有 root 用户可读
$for host in ${WORKERS[@]}; do
  scp ca.pem ca-key.pem ${USER}@${host}:~/
  ssh ${USER}@${host} 'sudo chown root:root ~/ca.pem ~/ca-key.pem; \
    sudo mv -f ~/ca.pem ~/ca-key.pem /opt/ssl/; \
    sudo chmod 600 /opt/ssl/ca-key.pem'
done
$sudo chmod 600 ca-key.pem # 还原权限
```
