# 部署DashBoard

DashBoard是kubernetes的仪表盘，也可以在里面进行控制，包括发布、修改、删除各种配置，包括Secret, ConfigMap, Volume, Pod, Job等等。

DashBoard以容器化方式部署，在部署过程中有些坑。

## 准备

### 下载yaml配置模板

<https://raw.githubsercontent.com/kubernetes/dashboard/v2.0.3/aio/deploy/recommended.yaml>

需要翻墙下载，下载后文件更名为dashboard。

### 下载镜像文件

```bash
docker pull kubernetesui/dashboard:v2.0.4
docker pull kubernetesui/metrics-scraper:v1.0.5
```

## 编辑配置文件

本文将配置文件按功能用途拆分为多个文件，存放在同一个目录下`~/yaml/dashboard/`，以下逐一说明。

### 命名空间（[00-namespace.yaml](00-namespace.yaml)）

单独为dashboard创建一个命名空间`kubernetes-dashboard`，将所有资源放置在该命名空间内。

### 安全文件1（[11-secret-certs.yaml](11-secret-certs.yaml)）

网上配置模板是一个空置的安全配置，这里增加了一对认证文件**内容**，分别命名为认证文件`kubernetes-dashboard.crt`和密钥`kubernetes-dashboard.key`；与calico的secret配置一样，其实质内容是对应证书和密钥的base64编码。

#### 制作证书

这次的证书不是用`cfssl`创建，而是用linux自带的`openssl`创建，如下：

```bash
$ cd /opt/ssl

$ sudo openssl req -nodes -newkey rsa 2048 \
    -keyout kubernetes-dashboard.key \
    -out kubernetes-dashboards.csr \
    -subj "/C=CN/ST=Chongqing/L=Chongqing/O=k8s/OU=ymliu/CN=kubernetes-dashboard"

$ sudo openssl x509 -req -sha256 -days 3650 \
    -in kubernetes-dashboard.csr \
    -signkey kubernetes-dashboard.key \
    -out kubernetes-dashboard.crt
```

- 命令行中C/ST/L/O/OU字段与前面`cfssl`创建时一致。
- CN字段使用`kubernetes-dashboard`。

### 安全文件2（[12-secret-csrf.yaml](12-secret-csrf.yaml)）

一个空的安全文件，应该是在运行过程中实时修改。

### 配置文件（[21-configmap.yaml](21-configmap.yaml)）

同样，一个空的配置文件，应该是在运行过程中被修改。

### 权限文件组1

包括ServiceAccount, Role, ClusterRole及Binding一整套RBAC定义，创建ServiceAccount为`kubernetes-dashboard`。用于dashboard和metric-scraper使用。

文件包括：

- [31-rbac-serviceAccount.yaml](31-rbac-serviceAccount.yaml)
- [32-rbac-role.yaml](32-rbac-role.yaml)
- [33-rbac-roleBinding.yaml](33-rbac-roleBinding.yaml)
- [34-rbac-clusterRole.yaml](34-rbac-clusterRole.yaml)
- [35-rbac-clusterRoleBinding.yaml](35-rbac-clusterRoleBinding.yaml)

### 权限文件组2

包括admin-user的ServiceAccount, ClusterRoleBinding的RBAC定义，创建ServiceAccount为`admin-user`，用于在dashboard web中进行管理。

文件包括：

- [36-rbad-admin-serviceAccount.yaml](36-rbad-admin-serviceAccount.yaml)
- [37-rbac-adm-clusterRoleBinding.yaml](37-rbac-adm-clusterRoleBinding.yaml)

### DashBoard的Pod发布([41-dashboard-deployment.yaml](41-dashboard-deployment.yaml))

发布DashBoard Web UI。

相比默认模板，在镜像参数段增加了认证文件加载，目的是解决DashBoard的Ingress转发。DashBoard是采用https方式访问，token登录，而DashBoard的https认证证书原来是自动生成，这里采用指定证书。

**请注意**：参数`--tls-cert-file`, `--tls-key-file`直接指向证书/密钥的文件名，无需指定目录；目录默认为`/certs`，通过secret进行mount。

### Metric Scraper的Pod发布（[42-metric-scraper-deployment.yaml](2-metric-scraper-deployment.yaml)）

仅仅只有DashBoard UI是不够的，这只能看到各种apiresources定义并进行管理。但是节点、pod的性能是抓取不到的，需要通过metric-scraper收集。

> 实际上，metric-scraper仅仅是收集数据，而不是真正的抓取数据，抓取数据还需通过部署metric-server来解决。

Metric Scraper没有什么特殊要求，参照原始模板即可。

### 服务发布

文件包括：

- [51-dashboard-service.yaml](51-dashboard-service.yaml)
- [52-metric-scraper-service.yaml](52-metric-scraper-service.yaml)
- [53-dashboard-ingress.yaml](53-dashboard-ingress.yaml)

前面两个服务发布没有什么特殊情况，都采用默认服务发布即可。这种情况下，只有集群内部可访问服务，要让集群外可访问，对dashboard创建一个ingress（首先要配置Ingress服务，后续介绍）。

文件`53-dashboard-ingress.yaml`就是dashboard的ingress配置，学习该配置的过程较为艰难。

dashboard是https访问，因此：

- 在`annotations`中必须进行如下定义才能保证https的请求正确传递到ingress后端

```yaml
metadata:
  annotations:
    kubernetes.io/ingress.allow-http: "false"
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/secret-backends: "true"
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
```

- `spec`中增加`tls`段，用来标注哪些hosts需要哪个证书（secret配置）来加解密。这也是为什么要修改***安全文件1***，指定证书内容。

```yaml
spec:
  tls:
  - hosts: ["dashboard.k8s.vm"]
    secretName: kubernetes-dashboard-certs
```
