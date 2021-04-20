#!/usr/bin/env bash

declare -r IMAGE=/mnt/rw/docker-image/registry.docker.tar
declare -r STORAGE=/appdata
declare -r SSL_DIR=/opt/ssl
declare -r DOCKER_HUB=docker-hub:5000
declare -r VERSION=2.7.1

echo "Checking registry running..."
docker ps -a | grep '\ registry$' > /dev/null
if [ $? -eq 0 ]
then
  echo "Stop & Remove previous registry..."
  docker stop registry > /dev/null
  docker rm registry > /dev/null
fi

echo "Checking registry image exists..."
declare -ri RET=$(docker images registry:${VERSION} | wc -l)
if [[ RET -eq 1 ]]
then
  echo "Loading registry image file..."
  sudo docker load -i ${IMAGE}
fi

echo "Checking directory exists..."
if [[ -d ${STORAGE} ]]
then
  echo "  directory exists!"
else
  sudo mkdir -pv ${STORAGE}
  echo ""
fi

echo "Starting private registry server on secure mode..."
docker run -d -p 5000:5000 --restart=always \
  --name=registry \
  -v ${STORAGE}:/var/lib/registry \
  -v ${SSL_DIR}:/certs \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
  registry:${VERSION}

echo -e "Started!\n"

docker container ps

# do not copy below
function cp_key()
{
  echo "configure local certificate"
  declare -r DOCKER_CERTS_DIR="/etc/docker/certs.d/${DOCKER_HUB}"
  sudo mkdir -pv ${DOCKER_CERTS_DIR}
  sudo cp -fv "${SSL_DIR}/registry.crt" "${DOCKER_CERTS_DIR}/ca.crt"
  sudo systemctl restart docker
}
function unused()
{
  sudo mkdir -p /opt/ssl
  sudo openssl req -newkey rsa:2048 -nodes -sha256 -keyout /opt/ssl/registry.key -x509 -days 3650 -out /opt/ssl/registry.crt
}
