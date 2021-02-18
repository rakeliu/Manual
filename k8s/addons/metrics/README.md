# 度量服务

度量服务即Metrics-Server，在计算机专业术语中，指“软件/系统性能数据，根据不同维度产生（如时间、对象、分组），收集到的这些数据通常被称为metrics”。

如果没有metrics-server，则kubernetes的一切监控（包括dashborad，prometheus, etc.）无从谈起。

下面创建一个metrics-server的deployment。

## 创建系统级角色并授权

metrics-server需要在整个kubernetes集群中创建系统级角色`system:metrics-server`。
系统级角色需要在kube-apiserver启动时导入。

### 创建证书

创建文件 `/opt/ssl/metrics-server-csr.json`

```json
{
  "CN": "system:metrics-server",
  "hosts": [],
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

```bash
$sudo cfssl -ca=/opt/ssl/ca.pem \
            -ca-key=/opt/ssl/ca-key.pem \
            -config=/opt/ssl/ca-config.json \
            -profile=kubernetes metrics-server-csr.json
      | sudo cfssljson -bare metrics-server
```

### 导入证书

通过kube-apiserver命令行参数，在启动时带入上述证书和用户。

```bash
ExecStart=/opt/k8s/bin/kube-apiserver \
...
  --requestheader-allowed-names=...,metrics-server \
  --proxy-client-cert-file=/opt/ssl/metrics-server.pem \
  --proxy-client-key-file=/opt/ssl/metrics-server-key.pem \
...
```

## 创建ServiceAccount

在系统命名空间`kube-system`里创建一个`ServiceAccount`：`metrics-server`。

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: metrics-server
  namespace: kube-system
```

## 设置RBAC

对`ServiceAccount` `metrics-server`设置RBAC。

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: system:aggregated-metrics-reader
  labels:
    rbac.authorization.k8s.io/aggregate-to-view: "true"
    rbac.authorization.k8s.io/aggregate-to-edit: "true"
    rbac.authorization.k8s.io/aggregate-to-admin: "true"
rules:
- apiGroups: ["metrics.k8s.io"]
  resources: ["pods", "nodes"]
  verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: metrics-server:system:auth-delegator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: metrics-server
  namespace: kube-system

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: metrics-server-auth-reader
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: extension-apiserver-authentication-reader
subjects:
- kind: ServiceAccount
  name: metrics-server
  namespace: kube-system
```

同时还要设置`system:metrics-server`用户的RBAC。

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: system:metrics-server
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - nodes
  - nodes/stats
  - namespaces
  - configmaps
  verbs:
  - get
  - list
  - watch

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:metrics-server
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:metrics-server
subjects:
- kind: ServiceAccount
  name: metrics-server
  namespace: kube-system
```

## 部署Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: metrics-server
  namespace: kube-system
  labels:
    k8s-app: metrics-server
spec:
  selector:
    matchLabels:
      k8s-app: metrics-server
  template:
    metadata:
      name: metrics-server
      labels:
        k8s-app: metrics-server
    spec:
      serviceAccountName: metrics-server
      volumes:
      # mount in tmp so we can safely use from-scratch images and/or read-only containers
      - name: tmp-dir
        emptyDir: {}
      containers:
      - name: metrics-server
        image: google_containers/metrics-server:v0.3.7
        imagePullPolicy: IfNotPresent
        args:
          - --cert-dir=/tmp
          - --secure-port=4443
          - --kubelet-preferred-address-types=InternalIP,Hostname,InternalDNS
          - --kubelet-insecure-tls
        ports:
        - name: main-port
          containerPort: 4443
          protocol: TCP
        securityContext:
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
        volumeMounts:
        - name: tmp-dir
          mountPath: /tmp
      nodeSelector:
        kubernetes.io/os: linux
```

从上述配置可以看出，采集到的数据存放在`emptyDir`中，也可另行指定存放地点。但为安全考虑，存放在`emptyDir`中可避免被篡改。

## 部署服务

```yaml
apiVersion: v1
kind: Service
metadata:
  name: metrics-server
  namespace: kube-system
  labels:
    kubernetes.io/name: "Metrics-server"
    kubernetes.io/cluster-service: "true"
spec:
  selector:
    k8s-app: metrics-server
  ports:
  - port: 443
    protocol: TCP
    targetPort: main-port
```

## 部署API接口服务

暴露metrics-server服务api接口，供其他服务调用，如dashboard, prometheus等。

```yaml
apiVersion: apiregistration.k8s.io/v1
kind: APIService
metadata:
  name: v1beta1.metrics.k8s.io
spec:
  service:
    name: metrics-server
    namespace: kube-system
  group: metrics.k8s.io
  version: v1beta1
  insecureSkipTLSVerify: true
  groupPriorityMinimum: 100
  versionPriority: 100
```
