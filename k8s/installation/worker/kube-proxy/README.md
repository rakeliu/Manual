# 安装kube-proxy组件

```bash
$ declare KUBE_APISERVER="https://192.168.176.34:8443"
$ declare CAFILE="/opt/ssl/ca.pem"
$ declare KUBECONFIG="/opt/k8s/conf/kube-proxy.kubeconfig"

$ sudo kubelet config set-cluster kubernetes \
    --certificate-authority=${CAFILE} \
    --embed-certs=true \
    --server=${KUBE_APISERVER} \
    --kubeconfig=${KUBECONFIG}
$ sudo kubelet config set-credentials kube-proxy \
    --client-certificate=/opt/ssl/kube-proxy.pem \
    --client-key=/opt/kube-proxy-key.pem \
    --embed-certs=true \
    --kubeconfig=${KUBECONFIG}
$ sudo kubelet config set-context default \
    --cluster=kubernetes \
    --user=kube-proxy
    --kubeconfig=${KUBECONFIG}
$ sudo kubelet config use-context default \
    --kubeconfig=${KUBECONFIG}
```
