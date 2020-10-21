# 动态存储卷StorageClass配置

Kubernetes使用PV和PVC存储持久化数据。使用方法是：

- 管理员先创建一系列各种大小的PV，形成集群中的存储资源池。
- 用户创建PVC时需要指定大小，这个时候会从PV池中寻找合适大小（人工），并将PV绑定到PVC使用。
- Pod将PVCmount到某个目录下进行使用。

但实际情况是，管理员并不清楚用户需要什么样大小的存储卷，没有办法预先创建各种大小的PV。

最好的效果是用户创建指定大小的PVC，然后自动创建同样大小的PV并关联到用户的PVC。

Kubernetes通过创建StorageClass来使用Dynamic Provisioning特性。StorageClass需要有一个Provisioner来决定使用什么样的插件来动态创建pvc，比如nfs, glusterfs存储，ceph存储等等。

Kubernetes中有很多内置的provisioner，参考如下：

<https://kubernetes.io/docs/concepts/storage/storage-classes/#provisioner>

使用StorageClass创建PVC就不需要再按部就班的创建endpoint -> service -> pv -> pvc了，直接创建pvc指定大小即可。

下面以nfs为例创建StorageClass及使用。

![流程](../../../resources/images/storageclass-flow.png)

- 创建ServiceAccount，并设置RBAC。
- 部署`nfs-client-provisioner` Pod。
- 创建StorageClass。
- 创建PVC。
- 使用。

## 创建ServiceAccount

首先要在命名空间下创建一个ServiceAccount。

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner-monitoring
  namespace: monitoring
```

创建了一个名为`nfs-client-provisioner-monitoring`的ServiceAccount。

## 设置RBAC

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: nfs-client-provisioner-runner-monitoring
rules:
- apiGroups: [""]
  resources: ["persistentvolumes"]
  verbs: ["get", "list", "watch", "create", "delete"]
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get", "list", "watch", "update"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["list", "watch", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["endpoints"]
  verbs: ["create", "delete", "get", "list", "watch", "patch", "update"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: run-nfs-client-provisioner-monitoring
subjects:
- kind: ServiceAccount
  name: nfs-client-provisioner-monitoring
  namespace: monitoring
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner-monitoring
  apiGroup: rbac.authorization.k8s.io
```

所需权限并不多，都是针对pv, storageclass的集群权限。

## 部署nfs-client-provisioner

在需要动态PVC的命名空间内部署一个StorageClass的Pod。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-provisioner-monitoring
  namespace: monitoring
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      k8s-app: nfs-provisioner-monitoring
  template:
    metadata:
      labels:
        k8s-app: nfs-provisioner-monitoring
    spec:
      serviceAccountName: nfs-client-provisioner-monitoring
      containers:
      - name: nfs-client-provisioner-monitoring
        image: quay.io/external_storage/nfs-client-provisioner:v3.1.0-k8s1.11
        imagePullPolicy: IfNotPresent
        env:
        - name: PROVISIONER_NAME
          # this value is provided to storageclass calling
          value: nfs-provisioner-monitoring
        - name: NFS_SERVER
          value: 192.168.176.8
        - name: NFS_PATH
          value: /appdata/nfs
        volumeMounts:
        - name: nfs-client-root
          mountPath: /persistentvolumes
      volumes:
      - name: nfs-client-root
        nfs:
          server: 192.168.176.8
          path: /appdata/nfs
```

- 镜像中的`nfs-client-root`的mountPath默认为`/persistentvolumes`，不能修改。
- 192.168.176.8 是nfs服务的监听地址，/appdata/nfs是nfs共享的目录。

## 创建StorageClass

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-dynamic-monitoring
  namespace: monitoring
  # set as default storageClass
  #annotations:
  #  storageclass.kubernetes.io/is-default-class: "true"
# same as PROVISIONER_NAME upon
provisioner: nfs-provisioner-monitoring
# allowVolumeExpansion: true
```

- provisioner：指定使用的存储卷类型，即上方的部署的pod，不同的存储卷提供者要修改成对应的值。
- reclaimPolicy：有两种策略，Delete和Ratain，默认是Delete。用户删除pvc释放对pv的占用后，系统根据PV的“reclaimPolicy”决定对pv执行何种回收操作。目前有三种方式：Ratained, Recycled, Deleted。
  - Ratained 保护被pvc释放的pv及其上数据，并将pv状态改成“released”，不再被其它pvc绑定。集群管理员手动通过如下步骤释放存储资源：
    - 手动删除PV，但预期相关的后端存储资源（如：AWS EBS, GCE PD, Azure Disk, Cinder volume）仍然存在。
    - 手动清空后端存储volume上的数据。
    - 手动删除后端存储volume，或者重复使用其后端volume，为其创建新的PV。
  - Deleted
    - 删除被pvc释放的pv机器后端存储volume，对于动态pv其"reclaim policy"继承自其"storage class"。
    - 默认是Deleted。管理员负责将"storage class"的"reclaim policy"设置成用户期望的形式，否则需要用户手动为创建后的动态pv编辑"reclaim policy"。
  - Recycled
    - 保留PV，但清空其上的数据，已废弃（Deprecated）。
- 如果将`metadata`段的`storageclass.kubernetes.io/is-default-class`设置为"true"，则表示该StorageClass为默认设置，可以不定义pvc在pod中直接使用。
  - 全局的默认StorageClass只能有一个，无论任何namespace。
- 很多时候需要对pvc进行扩容，需要定义`allowVolumeExpansion`为true，然后修改pvc扩容。

## 创建PersistentVolumeClain

在存储类被正确创建后，就可以创建pvc来请求StorageClass，而StorageClass将会为pvc自动创建一个可用的pv。pvc是对pv的声明，即pv为存储提供者，pvc为存储消费者。

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-claim
  namespace: monitoring
spec:
  storageClassName: nfs-dynamic-monitoring
  accessModes: ["ReadWriteMany"]
  resources:
    requests:
      storage: 5Gi
```

## 使用

在pod发布（Deployment, Daemon, Job等）时，直接使用pvc即可，与常规无异。

如果将StorageClass定义为默认，则无需定义pvc，直接在pod中使用，甚至不用指定StorageClass。
