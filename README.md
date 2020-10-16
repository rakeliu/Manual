# Manual
For all installations and configurations and manual by self.

This manual only written in Simplified Chinese。

- [Install kubernetes cluster and AddOns.](k8s/installation/README.md)
  - Generate CA Certifications.
  - Install ETCD.
  - Install Docker.
  - Install kubernetes cluster.
    - Prepare to installing haproxy.
    - Prepare to installing keepalived.
    - Install kube-apiserver, kube-controller-manager, kube-scheduler.
    - Install CNI Calico.
  - [Deploy kubernetes addons](k8s/addons/README.md).
    - Deploy coreDNS.
    - Deploy dashboard.
    - Deploy dynamic volume.
    - Deploy metric service.
    - Deploy Prometheus.
    - Deploy Grafana.
    - Deploy EFK.
      - Deploy ElasticSearch.
      - Deploy Fluntd.
      - Deploy Kabina.
    - Deploy Ingress.
      - Modify service above outside.
