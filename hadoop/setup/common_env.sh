# Define all environments for hadoo runtime

LOCALHOST=`hostname -s`

ALL_HOSTS=("zkjn1" "zkjn2" "zkjn3" "nna" "nns" "rma" "rms" "dn1" "dn2" "dn3")
ALL_NODES=("zk1" "jn1" "zk2" "jn2" "zk3" "jn3" "nm1" "nm2" "nm3")
ALL_HOSTS_IP=(
  "192.168.176.67"
  "192.168.176.68"
  "192.168.176.69"
  "192.168.176.70"
  "192.168.176.71"
  "192.168.176.72"
  "192.168.176.73"
  "192.168.176.74"
  "192.168.176.75"
  "192.168.176.76"
)
HOSTS_FILE="/etc/hosts"

#NODE_TYPES=("ZKJN" "NN" "RM" "DN" "NM")
NODE_TYPE=""

GROUP_NAME="hadoop"
USER_NAME="hadoop"
PASSWD="ocab7e9a"

STORAGE_DIR="/ext"
EXT_DISKS=(`echo sd{b..i}`)
VG_NAME="VG_hadoop"
LV_NAME="LV_hadoop"
MOUNT_FLAG=""

# Zookeeper
ZK_NODES=("zk1" "zk2" "zk3")
ZK_HOSTS=("zkjn1" "zkjn2" "zkjn3")
ZK_HOME_DIR="/opt/zookeeper-3.5.3-beta"
ZK_SYMBOLIC="/opt/zookeeper"
ZK_BASE_DIR="${STORAGE_DIR}/zk"
ZK_DATA_DIR="${ZK_BASE_DIR}/data"
ZK_LOG_DIR="${ZK_BASE_DIR}/logs"
ZK_CONF_DIR="${ZK_HOME_DIR}/conf"
ZK_LEADER_PORT="2888"
ZK_ELECT_PORT="3888"
ZK_COMM_PORT="2181"

# Hadoop Common
HADOOP_INIT_FLAG=""
HADOOP_HOME_DIR="/opt/hadoop-3.0.0"
HADOOP_SYMBOLIC="/opt/hadoop"
HADOOP_BASE_DIR="${STORAGE_DIR}/hadoop"
HADOOP_TMP_DIR="${HADOOP_BASE_DIR}/tmp"
HADOOP_CONF_DIR="${HADOOP_SYMBOLIC}/etc/hadoop"
# Hadoop NameNode
HADOOP_NN_NODES=("nna" "nns")
HADOOP_DN_NODES=("dn1" "dn2" "dn3")
HADOOP_HDFS_LOG_DIR="${HADOOP_BASE_DIR}/hdfs/logs"
#HADOOP_HDFS_NN_DATA_DIR="${HADOOP_BASE_DIR}/hdfs/name"
HADOOP_HDFS_NN_CLUSTER_NAME="fs_cluster1"
HADOOP_HDFS_NN_RPC_PORT="9000"
HADOOP_HDFS_NN_HTTP_PORT="50070"
HADOOP_HDFS_DN_ALLOWFILE="${HADOOP_CONF_DIR}/dn_allow_list"
HADOOP_HDFS_DN_DENYFILE="${HADOOP_CONF_DIR}/dn_deny_list"
# Hadoop Journal Node
HADOOP_JN_NODES=("jn1" "jn2" "jn3")
HADOOP_HDFS_JN_RPC_PORT="8485"
HADOOP_HDFS_JN_HTTP_PORT="8480"
HADOOP_HDFS_JN_DIR="${HADOOP_BASE_DIR}/hdfs/journal"
# Hadoop Yarn
HADOOP_RM_NODES=("rma" "rms")
HADOOP_NM_NODES=("nm1" "nm2" "nm3")
HADOOP_YARN_CLUSTERID="yarn-cluster"
#HADOOP_YARN_DATA_DIR="${HADOOP_BASE_DIR}/yarn/local"
HADOOP_YARN_LOG_DIR="${HADOOP_BASE_DIR}/yarn/logs"
HADOOP_MR_PORT="10020"
HADOOP_MR_WEB_PORT="19888"
HADOOP_YARN_NM_ALLOWFILE="${HADOOP_CONF_DIR}/nm_allow_list"
HADOOP_YARN_NM_DENYFILE="${HADOOP_CONF_DIR}/nm_deny_list"
HADOOP_YARN_RM_PORT="8132"
HADOOP_YARN_RM_SCHEDULE_PORT="8130"
HADOOP_YARN_RM_WEB_PORT="8188"
HADOOP_YARN_RM_TRACKER_PORT="8131"
HADOOP_YARN_RM_ADMIN_PORT="8033"
HADOOP_YARN_RM_HAADMIN_PORT="23142"
HADOOP_MR_SHUFFLE_PORT="23080"

HADOOP_ALL_DIRS=(
  "${HADOOP_TMP_DIR}"
  "${HADOOP_HDFS_LOG_DIR}"
#  "${HADOOP_HDFS_NN_DATA_DIR}"
  "${HADOOP_HDFS_JN_DIR}"
#  "${HADOOP_YARN_DATA_DIR}"
  "${HADOOP_YARN_LOG_DIR}"
)

# Function for calculating LVM-Raid5 Stripe Number
function Calc_StripeNum() {
  local num=-1
  for disk in "${EXT_DISKS[@]}"; do
    num=$[${num} +1]
  done
  echo ${num}
}
STRIPE_NUM=`Calc_StripeNum`
# Function for building zookeeper(current host) myid
function Build_ZK_MyID() {
  local num=0
  for host in "${ZK_HOSTS[@]}"; do
    num=$[${num} +1]
    if [ ${LOCALHOST} = ${host} ]; then
      echo ${num}
      return 0
    fi
  done
  exit 1
}
# Function for building zookeeper client connect-string
function Build_ZK_ClientConnectString() {
  local num=0
  local RET
  for node in "${ZK_NODES[@]}"; do
    if [ ${num} -eq 0 ]; then
      RET="${node}:${ZK_COMM_PORT}"
    else
      RET="${RET},${node}:${ZK_COMM_PORT}"
    fi
    num=$[${num} +1]
  done
  echo ${RET}
}
ZK_CLIENT_CONNECTSTRING=`Build_ZK_ClientConnectString`
# Function for building namenode string
function Build_Hadoop_NN_String() {
  local num=0
  local RET
  for node in "${HADOOP_NN_NODES[@]}"; do
    if [ ${num} -eq 0 ]; then
      RET="${node}"
    else
      RET="${RET},${node}"
    fi
    num=$[${num} +1]
  done
  echo ${RET}
}
HADOOP_NN_STRING=`Build_Hadoop_NN_String`
# Function for building journalnode connect-string
function Build_Hadoop_JN_String() {
  local num=0
  local RET
  for node in "${HADOOP_JN_NODES[@]}"; do
    if [ ${num} -eq 0 ]; then
      RET="${node}:${HADOOP_HDFS_JN_RPC_PORT}"
    else
      RET="${RET};${node}:${HADOOP_HDFS_JN_RPC_PORT}"
    fi
    num=$[${num} +1]
  done
  RET="qjournal://${RET}/${HADOOP_HDFS_NN_CLUSTER_NAME}"

  echo ${RET}
}
HADOOP_HDFS_JN_CONNECTSTRING=`Build_Hadoop_JN_String`
# Function for building ResourceManager HA String
function Build_Hadoop_RM_HAString() {
  local num=0
  local RET
  for node in "${HADOOP_RM_NODES[@]}"; do
    if [ ${num} -eq 0 ]; then
      RET="${node}"
    else
      RET="${RET},${node}"
    fi
    num=$[${num} +1]
  done
  echo ${RET}
}
HADOOP_RM_HASTRING=`Build_Hadoop_RM_HAString`
# Function for building multi-path for name&data dir
function Build_Hadoop_MultiPath() {
  local num=0
  local RET
  for disk in "${EXT_DISKS[@]}"; do
    if [ ${num} -eq 0 ]; then
      RET="${STORAGE_DIR}/${disk}"
    else
      RET="${RET},${STORAGE_DIR}/${disk}"
    fi
    num=$[${num} +1]
  done
  echo ${RET}
}
HADOOP_HDFS_MULTIPATH=`Build_Hadoop_MultiPath`
