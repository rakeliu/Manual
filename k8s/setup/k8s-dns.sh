#!/usr/bin/env bash

# This script is used for setup k8s addiontals, such as CoreDNS, dashboard.

function clear_all()
{
  echo "============================================================="
  echo "Clearing all additionals"
  echo "-------------------------------------------------------------"

  echo ">> remove coredns service..."
  ssh ${USER}@${EXEC_NODE} "sudo ${KUBECTL} delete -f /opt/k8s/yaml/coredns.yaml"

  IP=34
  for host in ${NODES[@]}
  do
    IP=$(( IP + 1 ))
    echo " >> remove coredns configuration in host ${host}(192.168.176.${IP})..."
    ssh ${USER}@${host} "sudo rm -fv /opt/k8s/yaml/coredns.yaml; \
      sudo docker rmi -f ${REGISTRY}/coredns/coredns:1.7.0"

# DEPRECATED do not modify resolv.conf indeed
#      sudo sed -i '/^nameserver.*\$/d' /etc/resolv.conf ; \
#      sudo sed -i '\$a\\nameserver ${OUTTER_DNS}' /etc/resolv.conf
  done
}


function deploy_coredns()
{
  echo "============================================================="
  echo "Deploying coredns"
  echo "-------------------------------------------------------------"

  echo ">> create coredns.yaml file"
  cat > ~/coredns.yaml << EOF
# Deploy CoreDNS Service internal

apiVersion: v1
kind: ServiceAccount
metadata:
  name: coredns
  namespace: kube-system
  labels:
      kubernetes.io/cluster-service: "true"
      addonmanager.kubernetes.io/mode: Reconcile
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
    addonmanager.kubernetes.io/mode: Reconcile
  name: system:coredns
rules:
- apiGroups:
  - ""
  resources:
  - endpoints
  - services
  - pods
  - namespaces
  verbs:
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - get
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
    addonmanager.kubernetes.io/mode: EnsureExists
  name: system:coredns
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:coredns
subjects:
- kind: ServiceAccount
  name: coredns
  namespace: kube-system
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
  labels:
      addonmanager.kubernetes.io/mode: EnsureExists
data:
  Corefile: |
    .:53 {
        errors
        health {
            lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
            pods insecure
            fallthrough in-addr.arpa ip6.arpa
            ttl 30
        }
        prometheus :9153
        forward . ${OUTTER_DNS}
        cache 30
        loop
        reload
        loadbalance
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: coredns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
    kubernetes.io/name: "CoreDNS"
spec:
  # replicas: not specified here:
  # 1. In order to make Addon Manager do not reconcile this replicas parameter.
  # 2. Default is 1.
  # 3. Will be tuned in real time if DNS horizontal auto-scaling is turned on.
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  selector:
    matchLabels:
      k8s-app: kube-dns
  template:
    metadata:
      labels:
        k8s-app: kube-dns
      annotations:
        seccomp.security.alpha.kubernetes.io/pod: 'runtime/default'
    spec:
      priorityClassName: system-cluster-critical
      serviceAccountName: coredns
      tolerations:
        - key: "CriticalAddonsOnly"
          operator: "Exists"
      nodeSelector:
        kubernetes.io/os: linux
      containers:
      - name: coredns
        image: ${REGISTRY}/coredns/coredns:1.7.0
        imagePullPolicy: IfNotPresent
        resources:
          limits:
            memory: 170Mi
          requests:
            cpu: 100m
            memory: 70Mi
        args: [ "-conf", "/etc/coredns/Corefile" ]
        volumeMounts:
        - name: config-volume
          mountPath: /etc/coredns
          readOnly: true
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
        - containerPort: 9153
          name: metrics
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /ready
            port: 8181
            scheme: HTTP
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            add:
            - NET_BIND_SERVICE
            drop:
            - all
          readOnlyRootFilesystem: true
      dnsPolicy: Default
      volumes:
        - name: config-volume
          configMap:
            name: coredns
            items:
            - key: Corefile
              path: Corefile
---
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
  annotations:
    prometheus.io/port: "9153"
    prometheus.io/scrape: "true"
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
    kubernetes.io/name: "CoreDNS"
spec:
  selector:
    k8s-app: kube-dns
  clusterIP: ${INNER_DNS}
  ports:
  - name: dns
    port: 53
    protocol: UDP
  - name: dns-tcp
    port: 53
    protocol: TCP
  - name: metrics
    port: 9153
    protocol: TCP
EOF

  echo ">> distribute coredns.yaml to all nodes"
  IP=34
  for host in ${NODES[@]}
  do
    IP=$(( IP + 1 ))
    echo "  >> copy coredns.yaml in host ${host}(192.168.176.${IP})..."
    scp ~/coredns.yaml ${USER}@${host}:~/
    ssh ${USER}@${host} "sudo chown root:root ~/coredns.yaml; \
      sudo mv -fv ~/coredns.yaml /opt/k8s/yaml/"
  done

  echo ">> start coredns"
  ssh ${USER}@${EXEC_NODE} "sudo ${KUBECTL} create -f /opt/k8s/yaml/coredns.yaml"

  echo ">> wait 5s seconds"
  ssh ${USER}@${EXEC_NODE} "sudo ${KUBECTL} get pod --all-namespaces"

  return 0

# DEPRECATED (below) do not modify resolv.conf indeed
  echo ">> modify all host's resolv.conf after CoreDNS started successful."
  IP=34
  for host in ${NODES[@]}
  do
    echo "    modify resolv.conf on host ${host}(192.168.176.${IP})..."
    ssh ${USER}@${host} "sudo sed -i '1i\\nameserver ${INNER_DNS}' /etc/resolv.conf"
  done
}


function clear_tmpfiles()
{
  echo "============================================================="
  echo "Clear all temp files"
  echo "-------------------------------------------------------------"

  rm -fv ~/coredns.yaml
}

# ---- main --------------
declare -ra MASTERS=("k8s-master1" "k8s-master2" "k8s-master3")
#declare -ra NODES=(${MASTERS[@]} "k8s-node1" "k8s-node2" "k8s-node3")
declare -ra NODES=(${MASTERS[@]})
declare -a EXEC_NODE="k8s-master1"
declare -i IP=0
declare -r APP_DIR="/appdata"
declare -r SSL_DIR="/opt/ssl"
declare -r RPMDIR="/mnt/rw/rpm"
declare -r KUBECTL="/opt/k8s/bin/kubectl"
declare -r REGISTRY="docker-hub:5000"
declare -r INNER_DNS="10.15.0.2"
declare -r OUTTER_DNS="172.18.0.4"

clear_all
deploy_coredns

clear_tmpfiles
