#!/usr/bin/env bash

# This script is used for start/stop hadoop cluster
#
# Arguments comments
#  argument 1: action-<start/stop>, to do action for cluster, start/stop cluster
#  argument 2: clusterTypes-<zk/jn/nn/zkfc/rm/dn/nm>, action objects cluster
#
# Command Line
#  hadoop-cluster.sh <start/stop> <zk/jn/nn/zkfc/rm/dn/nm>...

# load Environments & set variants to use later
. ~/bin/common_env.sh
COMMAND=""
declare -a CLUSTERS
METHOD=""

# Function for printing Usages when call arguments wrong
function Print_Usage() {
  echo "Usage: ${0} action clusters..."
  echo "  action    start/stop"
  echo "            start      start all nodes of clusters specified below"
  echo "            stop       stop all nodes of clusters specified below"
  echo "  clusters  zk/jn/nn/zkfc/dn/rm/nm, one or more..."
  echo "            zk          zookeeper cluster"
  echo "            jn          journalnode cluster"
  echo "            nn          namenode cluster"
  echo "            zkfc        zkfc cluster (hdfs namenode zkfc)"
  echo "            dn          datanode cluster"
  echo "            rm          resourcemanager cluster"
  echo "            nm          nodemanager cluster"
  echo "            all         all of above up"
}

# Function for initializing variants by arguments
function Init_Arguments() {
  if [ $# -lt 2 ]; then
    Print_Usage;
    exit 1
  fi

  COMMAND=${1}
  case ${COMMAND} in
    start )
      METHOD="starting"
      ;;
    stop )
      METHOD="stoping"
      ;;
    * )
      echo "Error: nnknown parameter ACTION - ${COMMAND}"
      echo ""
      Print_Usage
      exit 1
      ;;
  esac
  shift

  local num=0
  local RET
  while [[ $# -gt 0 ]]; do
    case ${1} in
      zk | jn | nn | zkfc | dn | rm | nm )
        ;;
      all )
        CLUSTERS=("all")
        return
        ;;
      * )
        echo "Error: unknown parameter CLUSTERS - ${1}"
        echo ""
        Print_Usage
        exit 1
        ;;
    esac

    if [ $num -eq 0 ]; then
      RET="$1"
    else
      RET="${RET} $1"
    fi
    num=$[${num} +1]
    shift
  done
  CLUSTERS=(${RET})
}

##### Main Body
Init_Arguments $@

for arg in "${CLUSTERS[@]}"; do
  case ${arg} in
    zk )
      echo "======================Zookeeper======================"
      for node in "${ZK_NODES[@]}"; do
        echo "node ${node} zookeeper ${METHOD}..."
        ssh ${USER_NAME}@${node} "${ZK_SYMBOLIC}/bin/zkServer.sh ${COMMAND}"
      done
      ;;
    jn )
      echo "=====================JournalNode====================="
      for node in "${HADOOP_JN_NODES[@]}"; do
        echo "node ${node} journalnode ${METHOD}..."
        ssh ${USER_NAME}@${node} "${HADOOP_SYMBOLIC}/bin/hdfs --daemon ${COMMAND} journalnode"
      done
      ;;
    nn )
      echo "======================NameNode======================"
      for node in "${HADOOP_NN_NODES[@]}"; do
        echo "node ${node} namenode ${METHOD}..."
        ssh ${USER_NAME}@${node} "${HADOOP_SYMBOLIC}/bin/hdfs --daemon ${COMMAND} namenode"
      done
      ;;
    zkfc )
      echo "========================ZKFC========================"
      for node in "${HADOOP_NN_NODES[@]}"; do
        echo "node ${node} zkfc ${METHOD}..."
        ssh ${USER_NAME}@${node} "${HADOOP_SYMBOLIC}/bin/hdfs --daemon ${COMMAND} zkfc"
      done
      ;;
    dn )
      echo "======================DataNode======================"
      for node in "${HADOOP_DN_NODES[@]}"; do
        echo "node ${node} datanode ${METHOD}..."
        ssh ${USER_NAME}@${node} "${HADOOP_SYMBOLIC}/bin/hdfs --daemon ${COMMAND} datanode"
      done
      ;;
    rm )
      echo "==================ResourceManager==================="
      for node in "${HADOOP_RM_NODES[@]}"; do
        echo "node ${node} resourcemanager ${METHOD}..."
        ssh ${USER_NAME}@${node} "${HADOOP_SYMBOLIC}/bin/hdfs --daemon ${COMMAND} resourcemanager"
      done
      ;;
    nm )
      echo "====================NodeManager====================="
      for node in "${HADOOP_NM_NODES[@]}"; do
        echo "node ${node} nodemanager ${METHOD}..."
        ssh ${USER_NAME}@${node} "${HADOOP_SYMBOLIC}/bin/hdfs --daemon ${COMMAND} nodemanager"
      done
      ;;
    all )
      case ${COMMAND} in
        start )
          ${0} start zk jn nn zkfc dn rm nm
          ;;
        stop )
          ${0} stop nm rm dn nn zkfc jn zk
          ;;
      esac
  esac
done
