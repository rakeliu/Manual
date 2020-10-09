#!/usr/bin/env bash


declare -r NAMESPACE="kubernetes-dashboard"
declare -r DOMAIN="dashboard.k8s.vm"
declare -r SECURET_NAME=""

sudo openssl req -nodes -newkey rsa:2048 \
  -keyout kubernetes-dashboard.key \
  -out kubernetes-dashboard.csr \
  -subj "/C=CN/ST=Chongqing/L=Chongqing/O=k8s/OU=ymliu/CN=kubernetes-dashboard"

sudo openssl x509 -req -sha256 -days 3650 \
  -in kubernetes-dashboard.csr \
  -signkey kubernetes-dashboard.key \
  -out kubernetes-dashboard.crt


kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')
