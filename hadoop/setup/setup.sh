#!/usr/bin/env bash

# This script is used for setup hadoop all configurations
# all sets are same build in all nodes

. ~/bin/common_env.sh

# Function for choose node type
function Choose_NodeType() {
  local READ
  echo "Choose Node Type: ZKJN NN RM DN"
  echo "  1 - ZKJN (Zookeeper, JournalNode)"
  echo "  2 - NN (NameNode)"
  echo "  3 - RM (ResourceManager)"
  echo "  4 - DN (DataNode, NodeManager)"
  echo ""
  read -n1 -p "Type your choice for acturalType [1,2,3,4]:" READ
  echo ""

  case ${READ} in
    1 )
      NODE_TYPE="ZKJN"
      ;;
    2 )
      NODE_TYPE="NN"
      ;;
    3 )
      NODE_TYPE="RM"
      ;;
    4 )
      NODE_TYPE="DN"
      ;;
    * )
      echo "YOU CHOICE IS INVALID, RE-RUN SETUP.SH!"
      exit 1
  esac
}

# Function for clean all setup information, or uninstall
function Clear() {
  # uninstall hadoop
  local -r HADOOP_ALL_FILES=(
    "${HADOOP_HDFS_DN_ALLOWFILE}"
    "${HADOOP_HDFS_DN_DENYFILE}"
    "${HADOOP_YARN_NM_ALLOWFILE}"
    "${HADOOP_YARN_NM_DENYFILE}"
    "${HADOOP_CONF_DIR}/core-site.xml"
    "${HADOOP_CONF_DIR}/hdfs-site.xml"
    "${HADOOP_CONF_DIR}/mapred-site.xml"
    "${HADOOP_CONF_DIR}/yarn-site.xml"
  )
  echo "remove hadoop config files:"
  for file in "${HADOOP_ALL_FILES[@]}"; do
    echo -n "  ${file} "
    if [ -f ${file} ]; then
      sudo rm -f ${file}
      echo "was removed!"
    else
      echo "not exist!"lo
    fi
  done

  echo "remove hadoop symbolic & directory(s):"
  echo -n "  ${HADOOP_SYMBOLIC} "
  sudo rm -fr ${HADOOP_SYMBOLIC}
  echo "ok!"
  for directory in "${HADOOP_ALL_DIRS[@]}"; do
    echo -n "  ${directory} "
    if [ -f ${directory} ]; then
      sudo rm -fr ${directory}
      echo "ok!"
    else
      echo " not exist!"
    fi
  done

  # uninstall zookeeper
  echo -n "remove zookeeper config file zoo.cfg: "
  if [ -f "${ZK_CONF_DIR}/zoo.cfg" ]; then
    sudo rm -f "${ZK_CONF_DIR}/zoo.cfg"
    echo "ok!"
  else
    echo "not exist."
  fi
  echo "remove zookeeper symbolic & direcory(s):"
  echo "  ${ZK_SYMBOLIC}, ${ZK_DATA_DIR}, ${ZK_LOG_DIR}"
  sudo rm -fr ${ZK_SYMBOLIC} ${ZK_DATA_DIR} ${ZK_LOG_DIR}
  echo "  remove ok!"

  # remove mount LVM
  egrep "^/dev/mapper/${VG_NAME}-${LV_NAME} " /etc/fstab >& /dev/null
  if [ $? -eq 0 ]; then
    echo "remove LVM:/dev/mapper/${VG_NAME}-${LV_NAME}: "
    sudo umount ${STORAGE_DIR} >& /dev/null
    sudo sed -i "/^\/dev\/mapper\/${VG_NAME}-${LV_NAME} /d" /etc/fstab >& /dev/null

    sudo lvremove -fyq "/dev/mapper/${VG_NAME}-${LV_NAME}" >& /dev/null
    sudo vgremove -fyq "${VG_NAME}" >& /dev/null
    for disk in "${EXT_DISKS[@]}"; do
      sudo pvremove -fyq "/dev/${disk}" >& /dev/null
      echo -n "/dev/${disk} "
    done
    echo "removed!"
  fi

  # remove mount pure disk
  echo -n "remove pure disks mounted: "
  for disk in "${EXT_DISKS[@]}"; do
    egrep "^/dev/${disk}.*$" /etc/fstab >& /dev/null
    if [ $? -eq 0 ]; then
      echo -n "/dev/${disk} "
      if [ -d "${STORAGE_DIR}/${disk}" ]; then
        sudo umount "${STORAGE_DIR}/${disk}" >& /dev/null
        sudo rm -fr "${STORAGE_DIR}/${disk}"
      fi
      sudo sed -i "/^\/dev\/${disk}.*$/d" /etc/fstab
    fi
  done
  echo "removed!"

  # remove user privileges
  echo -n "remove privileges: "
  sudo egrep "^${USER_NAME}.*NOPASSWD:ALL$" /etc/sudoers >& /dev/null
  if [ $? -eq 0 ]; then
    sudo sed -i "/^${USER_NAME}.*NOPASSWD:ALL$/d" /etc/sudoers
    echo "ok!"
  else
    echo "not exist."
  fi

  # remove user
  echo -n "remove user ${USER_NAME}: "
  egrep "^${USER_NAME}:.*$" /etc/passwd >& /dev/null
  if [ $? -eq 0 ]; then
    sudo userdel -r ${USER_NAME}
    echo "ok!"
  else
    echo "not exist."
  fi

  # remove group
  echo -n "remove group ${GROUP_NAME}: "
  egrep "^${GROUP_NAME}:.*$" /etc/group >& /dev/null
  if [ $? -eq 0 ]; then
    sudo groupdel ${GROUP_NAME}
    echo "ok!"
  else
    echo "not exist."
  fi
}

# Function for check&create group&user
function Create_GroupUser(){
  # create group
  echo -n "create group ${GROUP_NAME}: "
  egrep "^${GROUP_NAME}" /etc/group >& /dev/null
  if [ $? -ne 0 ]; then
    sudo groupadd ${GROUP_NAME}
    echo "created!"
  else
    echo "exists."
  fi

  # create user
  echo -n "create user ${USER_NAME}: "
  sudo egrep "^${USER_NAME}" /etc/passwd >& /dev/null
  if [ $? -ne 0 ]; then
    sudo useradd -g ${GROUP_NAME} -s /bin/bash ${USER_NAME}
    echo -e "${PASSWD}\n${PASSWD}" | sudo passwd ${USER_NAME} >& /dev/null
    echo "created!"
  else
    echo -n "exists, change password "
    echo -e "${PASSWD}\n${PASSWD}" | sudo passwd ${USER_NAME} >& /dev/null
    echo "ok!"
  fi
  # create usr ssh-key
  echo -n "create user ${USER_NAME} ssh-keygen file: "
  if [ -f "/home/${USER_NAME}/.ssh/id_rsa" ]; then
    sudo rm -f "/home/${USER_NAME}/.ssh/id_rsa"
    echo -n "remove first for exists, "
  fi
  echo "${PASSWD}" | su - ${USER_NAME} -c "ssh-keygen -t rsa -P \"\" -f ~/.ssh/id_rsa" >& /dev/null
  echo " ok!"

  # add user to sudoers, modify visudo
  echo -n "add user ${USER_NAME} to sudoers: "
  sudo egrep "^${USER_NAME}.*NOPASSWD:ALL$" /etc/sudoers >& /dev/null
  if [ $? -ne 0 ]; then
    # add line after ymliu
    sudo sed -i "/^${USER}.*$/a\\${USER_NAME}  ALL=(ALL)  NOPASSWD:ALL" /etc/sudoers
    echo "ok!"
  else
    echo "exists."
  fi
  # modify .bashrc
  echo -n "modify ${USER_NAME}'s .bashrc :"
  local -r BASHRC_FILE="/home/${USER_NAME}/.bashrc"
  sudo egrep "^alias\ sudo=" ${BASHRC_FILE} >& /dev/null
  if [ $? -ne 0 ]; then
    # append end of file
    sudo sed -i "\$a\alias sudo='sudo env PATH=\$PATH'" ${BASHRC_FILE}
    echo "ok!"
  else
    echo "exists."
  fi
}

# Function for mounting pure disk
function Mount_Disk() {
  if [ "${MOUNT_FLAG}" = "RUN" ]; then
    echo "Mount Disk has run."
    return 0
  fi
  MOUNT_FLAG="RUN"

  echo -n "mount pure disks: "
  for disk in "${EXT_DISKS[@]}"; do
    echo -n "${disk} "
    sudo mkfs -t xfs -f -L ${disk} "/dev/${disk}" >& /dev/null
    sudo mkdir -p "${STORAGE_DIR}/${disk}"

    egrep "^\/dev\/${disk} " /etc/fstab >& /dev/null
    if [ $? -ne 0 ]; then
      sudo sed -i "\$a\\/dev\/${disk}                ${STORAGE_DIR}\/${disk}                      xfs     defaults        0 0" /etc/fstab
    fi
  done
  sudo mount -a

  sudo chown -R ${GROUP_NAME}:${USER_NAME} ${STORAGE_DIR}/sd*
  echo "mounted!"
}
# Function for mounting all disk to lvm
function Mount_LVM() {
  if [ "${MOUNT_FLAG}" = "RUN" ]; then
    echo "Mount LVM has run."
    return 0
  fi
  MOUNT_FLAG="RUN"

  echo -n "create PV & extend VG ${VG_NAME}: "
  local num=0
  for disk in "${EXT_DISKS[@]}"; do
    sudo pvcreate -fqy "/dev/${disk}" >& /dev/null
    if [ $num -eq 0 ]; then
      sudo vgcreate -fyq ${VG_NAME} "/dev/${disk}" >& /dev/null
    else
      sudo vgextend -fyq ${VG_NAME} "/dev/${disk}" >& /dev/null
    fi
    num=$[$num +1]
    echo -n "/dev/${disk} "
  done
  echo "created!"

  echo -n "create ${LV_NAME}: "
  sudo lvcreate --config allocation/raid_stripe_all_devices=1 --type raid5 -i ${STRIPE_NUM} -l 100%FREE -I 64 -y -n ${LV_NAME} ${VG_NAME} >& /dev/null
  sudo mkfs -t xfs -f -L ${LV_NAME} "/dev/mapper/${VG_NAME}-${LV_NAME}" >& /dev/null
  echo "created!"

  echo -n "mount ${LV_NAME}: "
  egrep "^/dev/mapper/${VG_NAME}-${LV_NAME} " /etc/fstab
  if [ $? -ne 0 ]; then
    sudo sed -i "\$a\/dev/mapper/${VG_NAME}-${LV_NAME}  ${STORAGE_DIR}                  xfs     defaults        0 0" /etc/fstab
  fi
  sudo mount -a
  sudo chown -R ${GROUP_NAME}:${USER_NAME} ${STORAGE_DIR}
  echo "ok!"
}

# Function for optimizing /etc/hosts, add all nodes into it
function Optimiz_Hosts() {
  local num=0
  local LINESTR
  echo "optimize ${HOSTS_FILE}"
  for host in "${ALL_HOSTS[@]}"; do
    LINESTR="${ALL_HOSTS_IP[${num}]} ${host}"
    egrep "^${LINESTR}$" ${HOSTS_FILE} >& /dev/null
    if [ $? -ne 0 ]; then
      sudo sed -i "\$a\\${LINESTR}" ${HOSTS_FILE}
      echo "  add line: ${LINESTR}"
    fi
    num=$[${num} +1]
  done
}

##################################################
# Function for initializing zookeeper before installation
# create symbolic, directory(s)
function ZK_Init() {
  echo -n "create zookeeper symbolic:${ZK_HOME_DIR} -> ${ZK_SYMBOLIC} "
  sudo ln -sf ${ZK_HOME_DIR} ${ZK_SYMBOLIC}
  sudo chown -R ${GROUP_NAME}:${USER_NAME} ${ZK_SYMBOLIC}
  echo "ok!"

  echo -n "create zookeeper directory(s):${ZK_DATA_DIR},${ZK_LOG_DIR} "
  sudo mkdir -p ${ZK_DATA_DIR} ${ZK_LOG_DIR}
  sudo chown -R ${GROUP_NAME}:${USER_NAME} ${ZK_DATA_DIR} ${ZK_LOG_DIR}
  echo "ok!"

  echo -n "change owner: "
  sudo chown -R ${GROUP_NAME}:${USER_NAME} ${ZK_HOME_DIR}
  echo "ok!"
}
# Function for creating zookeeper configuration file, zoo.cfg
function ZK_Create_Config() {
  local -r ZK_CONF_FILE="${ZK_CONF_DIR}/zoo.cfg"
  local -r ZK_CONF_SAMPLEFILE="${ZK_CONF_DIR}/zoo_sample.cfg"

  # copy zoo.sample to zoo.cfg
  echo -n "copy sample config file:${ZK_CONF_SAMPLEFILE}->${ZK_CONF_FILE} "
  sudo cp -r ${ZK_CONF_SAMPLEFILE} ${ZK_CONF_FILE}
  echo "copied!"
  # replace line of start with "dataDir" to "dataDir=${ZK_DATA_DIR}"
  echo -n "replace dataDir:${ZK_DATA_DIR} "
  sudo sed -i "s:^\(dataDir\)=.*$:\1=${ZK_DATA_DIR}:" ${ZK_CONF_FILE}
  echo "replaced!"
  # add logDir after line of dataDir
  echo -n "add dataLogdir:${ZK_LOG_DIR} "
  sudo sed -i "/^dataDir=/a\dataLogDir=${ZK_LOG_DIR}" ${ZK_CONF_FILE}
  echo "added!"
  # modify autopurge=1
  echo -n "modify autopurge.purgeInterval=1 "
  sudo sed -i "s:^\#\(autopurge.purgeInterval=1\):\1:" ${ZK_CONF_FILE}
  echo "ok!"

  # add server list
  echo "add zookeeper server list : "
  sudo sed -i "\$a\#" ${ZK_CONF_FILE}
  local num=0
  for node in "${ZK_NODES[@]}"; do
    num=$[$num +1]
    sudo sed -i "\$a\server.${num}=${node}:${ZK_LEADER_PORT}:${ZK_ELECT_PORT}" ${ZK_CONF_FILE}
    echo " server.${num}=${node}"
  done
  echo " added!"

  # create myid file
  echo -n "create myid file, myid="
  local -r ZK_MYID=`Build_ZK_MyID`
  echo "${ZK_MYID}" >/tmp/myid
  sudo mv /tmp/myid ${ZK_DATA_DIR}/
  echo ${ZK_MYID}
}
# Function for optimizing logfile format & directory
function ZK_Optimized_Log() {
  echo -n "optimize log4j.properties: "
  local -r LOG4J_FILE="${ZK_CONF_DIR}/log4j.properties"
  sudo sed -i "s/^\(zookeeper.root.logger\).*$/\1=INFO, ROLLINGFILE/" ${LOG4J_FILE}
  sudo sed -i "s/^\(log4j.appender.ROLLINGFILE\)=.*$/\1=org.apache.log4j.DailyRollingFileAppender/" ${LOG4J_FILE}
  sudo sed -i "s/^log4j.appender.ROLLINGFILE.MaxFileSize=.*$/#&/" ${LOG4J_FILE}
  sudo sed -i "s/^log4j.appender.ROLLINGFILE.MaxBackupIndex=.*$/#&/" ${LOG4J_FILE}
  echo "ok!"

  echo -n "optimize zkEnv.sh: "
  local -r ENV_FILE="${ZK_HOME_DIR}/bin/zkEnv.sh"
  sudo sed -i "s:\(ZOO_LOG_DIR\)=.*$:\1=\"${ZK_LOG_DIR}\":" ${ENV_FILE}
  sudo sed -i "s:\(ZOO_LOG4J_PROP\)=.*$:\1=\"INFO,ROLLINGFILE\":" ${ENV_FILE}
  echo "ok!"
}

##################################################
# Function for initializing hadoop, symbolic & directorys
function Hadoop_Init() {
  if [ "${HADOOP_INIT_FLAG}" = "run" ]; then
    echo "Hadoop_Init has run."
    return 1
  fi
  HADOOP_INIT_FLAG="run"

  echo -n "create hadoop symbolic: ${HADOOP_HOME_DIR} -> ${HADOOP_SYMBOLIC} "
  sudo ln -sf ${HADOOP_HOME_DIR} ${HADOOP_SYMBOLIC}
  sudo chown -R ${GROUP_NAME}:${USER_NAME} ${HADOOP_SYMBOLIC}
  echo "ok!"

  echo "create hadoop all directory(s):"
  for directory in "${HADOOP_ALL_DIRS[@]}"; do
    echo -n "  ${directory} "
    sudo mkdir -p ${directory}
    sudo chown -R ${GROUP_NAME}:${USER_NAME} ${directory}
    echo "ok!"
  done

  echo -n "append environments for ${USER_NAME}'s .bashrc: "
  local -r BASHRC_FILE="/home/${USER_NAME}/.bashrc"
  echo -n "${BASHRC_FILE} "
  sudo egrep "^#Hadoop Variables Start" $BASHRC_FILE >& /dev/null
  if [ $? -ne 0 ]; then
    sudo sed -i "\$a\#Hadoop Variables Start" ${BASHRC_FILE}
    sudo sed -i "\$a\export HADOOP_INSTALL=${HADOOP_SYMBOLIC}" ${BASHRC_FILE}
    sudo sed -i "\$a\export PATH=\$PATH:\$HADOOP_INSTALL\/bin:\$HADOOP_INSTALL\/sbin" ${BASHRC_FILE}
    sudo sed -i "\$a\export HADOOP_MAPRED_HOME=\$HADOOP_INSTALL" ${BASHRC_FILE}
    sudo sed -i "\$a\export HADOOP_COMMON_HOME=\$HADOOP_INSTALL" ${BASHRC_FILE}
    sudo sed -i "\$a\export HADOOP_HDFS_HOME=\$HADOOP_INSTALL" ${BASHRC_FILE}
    sudo sed -i "\$a\export HADOOP_LOG_DIR=${HADOOP_HDFS_LOG_DIR}" ${BASHRC_FILE}
    sudo sed -i "\$a\export HADOOP_COMMON_LIB_NATIVE_DIR=\$HADOOP_INSTALL\/lib\/native" ${BASHRC_FILE}
    sudo sed -i "\$a\export HADOOP_OPTS=\"-Djava.library.path=\$HADOOP_COMMON_LIB_NATIVE_DIR\"" ${BASHRC_FILE}
    sudo sed -i "\$a\export YARN_HOME=\$HADOOP_INSTALL" ${BASHRC_FILE}
    sudo sed -i "\$a\export YARN_LOG_DIR=${HADOOP_YARN_LOG_DIR}" ${BASHRC_FILE}
    sudo sed -i "\$a\export YARN_OPTS=\"-Djava.library.path=\$HADOOP_COMMON_LIB_NATIVE_DIR\"" ${BASHRC_FILE}
    sudo sed -i "\$a\#Hadoop variables end" ${BASHRC_FILE}
    echo "ok!"
  else
    echo "exist."
  fi

  local -r ENV_FILES=("${HADOOP_CONF_DIR}/hadoop-env.sh" "${HADOOP_CONF_DIR}/yarn-env.sh")
  local -r JAVA_HOME_ENV=`echo ${JAVA_HOME}`
  echo "optimize JAVA environments settings"
  for file in "${ENV_FILES[@]}"; do
    echo -n "  modify ${file}: "
    sudo egrep "^export JAVA_HOME=" ${file} >& /dev/null
    if [ $? -eq 0 ]; then
      # exist, replace it
      sudo sed -i "s:^\(export JAVA_HOME\)=.*$:\1=${JAVA_HOME_ENV}:" ${file}
      echo "replaced ok!"
    else
      # not exist, append line
      sudo sed -i "\$a\# optimized for hadoop & java" ${file}
      sudo sed -i "\$a\export JAVA_HOME=${JAVA_HOME_ENV}" ${file}
      echo "appended  ok!"
    fi
  done
  echo -n "chown owner of hadoop: "
  sudo chown -R ${GROUP_NAME}:${USER_NAME} ${HADOOP_HOME_DIR}
  echo "ok!"
}
# Function for building hadoop core-site.xml
function Hadoop_Build_CoreSite() {
  cat >&1 << EOF
<configuration>
  <!-- fs cluster name -->
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://${HADOOP_HDFS_NN_CLUSTER_NAME}</value>
  </property>

  <property>
    <name>io.file.buffer.size</name>
    <value>131072</value>
  </property>

  <property>
    <name>hadoop.tmp.dir</name>
    <value>${HADOOP_TMP_DIR}</value>
  </property>

  <property>
    <name>hadoop.proxyuser.hadoop.hosts</name>
    <value>*</value>
  </property>

  <property>
    <name>hadoop.proxyuser.hadoop.groups</name>
    <value>*</value>
  </property>

  <!-- call zookeeper cluster options -->
  <property>
    <name>ha.zookeeper.quorum</name>
    <value>${ZK_CLIENT_CONNECTSTRING}</value>
  </property>
</configuration>
EOF
}
# Function for building hadoop hdfs-site.xml
function Hadoop_Build_HdfsSite() {
  cat >&1 << EOF
<configuration>
  <!-- NameNode Cluster Configurations -->
  <!-- It must be the same as core-site.xml -->
  <property>
    <name>dfs.nameservices</name>
    <value>${HADOOP_HDFS_NN_CLUSTER_NAME}</value>
  </property>

  <property>
    <name>dfs.ha.namenodes.${HADOOP_HDFS_NN_CLUSTER_NAME}</name>
    <value>${HADOOP_NN_STRING}</value>
  </property>

EOF

  for node in "${HADOOP_NN_NODES[@]}"; do
    cat >&1 <<EOF
  <property>
    <name>dfs.namenode.rpc-address.${HADOOP_HDFS_NN_CLUSTER_NAME}.${node}</name>
    <value>${node}:${HADOOP_HDFS_NN_RPC_PORT}</value>
  </property>

  <property>
    <name>dfs.namenode.http-address.${HADOOP_HDFS_NN_CLUSTER_NAME}.${node}</name>
    <value>${node}:${HADOOP_HDFS_NN_HTTP_PORT}</value>
  </property>

EOF
  done

  cat >&1 << EOF
  <!-- Access Controll Lists -->
  <property>
    <name>dfs.namenode.hosts</name>
    <value>${HADOOP_HDFS_DN_ALLOWFILE}</value>
  </property>
  <property>
    <name>dfs.namenode.hosts.exclude</name>
    <value>${HADOOP_HDFS_DN_DENYFILE}</value>
  </property>

  <property>
    <!-- JournalNode(DataNode) set -->
    <name>dfs.namenode.shared.edits.dir</name>
    <value>${HADOOP_HDFS_JN_CONNECTSTRING}</value>
  </property>

  <property>
    <!-- Failover -->
    <name>dfs.client.failover.proxy.provider.fs-cluster1</name>
    <value>org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider</value>
  </property>

  <!-- fence -->
  <property>
    <name>dfs.ha.fencing.methods</name>
    <value>sshfence</value>
  </property>
  <property>
    <name>dfs.ha.fencing.ssh.private-key-files</name>
    <value>/home/${USER_NAME}/.ssh/id_rsa</value>
  </property>

  <property>
    <name>dfs.journalnode.edits.dir</name>
    <value>${HADOOP_HDFS_JN_DIR}</value>
  </property>

  <property>
    <name>dfs.ha.automatic-failover.enabled</name>
    <value>true</value>
  </property>

  <!-- diretories of data&log -->
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>${HADOOP_HDFS_MULTIPATH}</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>${HADOOP_HDFS_MULTIPATH}</value>
  </property>
  <property>
    <name>dfs.replication</name>
    <value>3</value>
  </property>

  <property>
    <name>dfs.webhdfs.enabled</name>
    <value>true</value>
  </property>

  <property>
    <name>dfs.journalnode.http-address</name>
    <value>0.0.0.0:${HADOOP_HDFS_JN_HTTP_PORT}</value>
  </property>
  <property>
    <name>dfs.journalnode.rpc-address</name>
    <value>0.0.0.0:${HADOOP_HDFS_JN_RPC_PORT}</value>
  </property>

  <property>
    <name>ha.zookeeper.quorum</name>
    <value>${ZK_CLIENT_CONNECTSTRING}</value>
  </property>
</configuration>
EOF
}
# Function for building hadoop mapred-site.xml
function Hadoop_Build_MapredSite() {
  cat >&1 <<EOF
<configuration>
	<property>
		<name>mapreduce.framework.name</name>
		<value>yarn</value>
	</property>

	<property>
		<name>mapreduce.jobhistory.address</name>
		<value>0.0.0.0:${HADOOP_MR_PORT}</value>
	</property>

	<property>
		<name>mapreduce.jobhistory.webapp.address</name>
		<value>0.0.0.0:${HADOOP_MR_WEB_PORT}</value>
	</property>
</configuration>
EOF
}
# Function for building hadoop yarn-site.xml
function Hadoop_Build_YarnSite() {
  cat >&1 <<EOF
<configuration>
  <!-- Site specific YARN configuration properties -->
  <property>
    <name>yarn.resourcemanager.connect.retry-interval.ms</name>
    <value>2000</value>
  </property>
  <property>
    <name>yarn.resourcemanager.ha.enabled</name>
    <value>true</value>
  </property>
  <property>
    <name>yarn.resourcemanager.ha.rm-ids</name>
    <value>${HADOOP_RM_HASTRING}</value>
  </property>
  <property>
    <name>ha.zookeeper.quorum</name>
    <value>${ZK_CLIENT_CONNECTSTRING}</value>
  </property>

  <!-- Access Controll Lists-->
  <property>
    <name>yarn.resourcemanager.nodes.include-path</name>
    <value>${HADOOP_YARN_NM_ALLOWFILE}</value>
  </property>
  <property>
    <name>yarn.resourcemanager.nodes.exclude-path</name>
    <value>${HADOOP_YARN_NM_DENYFILE}</value>
  </property>

  <property>
    <name>yarn.resourcemanager.ha.automatic-failover.enabled</name>
    <value>true</value>
  </property>
EOF

  for node in "${HADOOP_RM_NODES[@]}"; do
    cat >&1 <<EOF
  <property>
    <name>yarn.resourcemanager.hostname.${node}</name>
    <value>${node}</value>
  </property>
EOF
  done

  cat >&1 << EOF

  <!--set rma on resoucemanager-active, rms on resourcemanager-standy -->
  <!--NOTICE: each machine's config are not same. YOU MUST MODIFY ON OTHER NODE -->
  <property>
    <name>yarn.resourcemanager.ha.id</name>
    <value>${LOCALHOST}</value>
  </property>

  <!-- Failover enabled -->
  <property>
    <name>yarn.resourcemanager.recovery.enabled</name>
    <value>true</value>
  </property>
  <!--config zookeeper rpc-address -->
  <property>
    <name>yarn.resourcemanager.zk-state-store.address</name>
    <value>${ZK_CLIENT_CONNECTSTRING}</value>
  </property>
  <property>
    <name>yarn.resourcemanager.store.class</name>
    <value>org.apache.hadoop.yarn.server.resourcemanager.recovery.ZKRMStateStore</value>
  </property>
  <property>
    <name>yarn.resourcemanager.zk-address</name>
    <value>${ZK_CLIENT_CONNECTSTRING}</value>
  </property>
  <property>
    <name>yarn.resourcemanager.cluster-id</name>
    <value>${HADOOP_YARN_CLUSTERID}</value>
  </property>

  <!--schelduler wait timeout -->
  <property>
    <name>yarn.app.mapreduce.am.scheduler.connection.wait.interval-ms</name>
    <value>5000</value>
  </property>

EOF

  for node in "${HADOOP_RM_NODES[@]}"; do
    cat >&1 <<EOF
  <!-- config ${node} -->
  <property>
    <name>yarn.resourcemanager.address.${node}</name>
    <value>${node}:${HADOOP_YARN_RM_PORT}</value>
  </property>
  <property>
    <name>yarn.resourcemanager.scheduler.address.${node}</name>
    <value>${node}:${HADOOP_YARN_RM_SCHEDULE_PORT}</value>
  </property>
  <property>
    <name>yarn.resourcemanager.webapp.address.${node}</name>
    <value>${node}:${HADOOP_YARN_RM_WEB_PORT}</value>
  </property>
  <property>
    <name>yarn.resourcemanager.resource-tracker.address.${node}</name>
    <value>${node}:${HADOOP_YARN_RM_TRACKER_PORT}</value>
  </property>
  <property>
    <name>yarn.resourcemanager.admin.address.${node}</name>
    <value>${node}:${HADOOP_YARN_RM_ADMIN_PORT}</value>
  </property>
  <property>
    <name>yarn.resourcemanager.ha.admin.address.${node}</name>
    <value>${node}:${HADOOP_YARN_RM_HAADMIN_PORT}</value>
  </property>

EOF
  done

  cat >&1 <<EOF
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
  <property>
    <name>yarn.nodemanager.aux-services.mapreduce.shuffle.class</name>
    <value>org.apache.hadoop.mapred.ShuffleHandler</value>
  </property>
  <property>
    <name>yarn.nodemanager.local-dirs</name>
    <value>${HADOOP_HDFS_MULTIPATH}</value>
  </property>
  <property>
    <name>yarn.nodemanager.log-dirs</name>
    <value>${HADOOP_YARN_LOG_DIR}</value>
  </property>
  <property>
    <name>mapreduce.shuffle.port</name>
    <value>${HADOOP_MR_SHUFFLE_PORT}</value>
  </property>

  <!-- failover provider -->
  <property>
    <name>yarn.client.failover-proxy-provider</name>
    <value>org.apache.hadoop.yarn.client.ConfiguredRMFailoverProxyProvider</value>
  </property>
  <property>
    <name>yarn.resourcemanager.ha.automatic-failover.zk-base-path</name>
    <value>/yarn-leader-election</value>
  </property>
</configuration>
EOF
}

# CallBack Function for build hadoop config file by argument
# Argument: 1-filename of configuration, convert it to callback function
#           core-site.xml -> CoreSite -> Hadoop_Build_CoreSite
function Hadoop_Build_Config_CallBack() {
  if [ $# -eq 0 ]; then
    echo "No argument specialfied!" >&2
    exit 1
  fi

  local -r TMPFILE="/tmp/hadoop-config.xml"
  for arg in "$@"; do
    local -r XMLFILE="${HADOOP_CONF_DIR}/${arg}"
    local CALLBACK=`echo ${arg} | sed "s/\.xml$//;s/\b[a-z]/\u&/g;s/-//"`
    CALLBACK="Hadoop_Build_${CALLBACK}"

    echo "building config ${XMLFILE}."
    if [ -f ${XMLFILE} ]; then
      sudo rm -f ${XMLFILE}
      echo "  old file was removed!"
    fi
    sudo rm -f ${TMPFILE}

    echo -n "  callback function ${CALLBACK} to build tmpfile: "
    touch ${TMPFILE}
    (${CALLBACK}) >> ${TMPFILE}
    echo "ok!"

    echo -n "  move tmpfile to ${XMLFILE}: "
    sudo mv ${TMPFILE} ${XMLFILE}
    sudo chown ${GROUP_NAME}:${USER_NAME} ${XMLFILE}
    echo "ok!"
  done
}

# Function for building all hadoop config-file, by callback
function Hadoop_Optimize_NN() {
  echo -n "create empty access file: ${HADOOP_HDFS_DN_ALLOWFILE} ${HADOOP_HDFS_DN_DENYFILE} "
  sudo rm -f ${HADOOP_HDFS_DN_ALLOWFILE} ${HADOOP_HDFS_DN_DENYFILE}
  sudo touch ${HADOOP_HDFS_DN_ALLOWFILE}
  sudo touch ${HADOOP_HDFS_DN_DENYFILE}
  sudo chown ${GROUP_NAME}:${USER_NAME} ${HADOOP_HDFS_DN_ALLOWFILE} ${HADOOP_HDFS_DN_DENYFILE}
  echo "ok!"

  local -r SLAVES="${HADOOP_CONF_DIR}/slaves"
  local -r TMPFILE="/tmp/slaves"
  echo "build yarn slaves file ${SLAVES}"
  sudo rm -f ${TMPFILE}
  touch ${TMPFILE}
  for node in "${HADOOP_DN_NODES[@]}"; do
    cat >> ${TMPFILE} <<EOF
${node}
EOF
    echo "  ${node}"
  done
  sudo mv -f ${TMPFILE} ${SLAVES}
  sudo chown ${GROUP_NAME}:${USER_NAME} ${SLAVES}
}
# Function for optimizing ResourceManager access file & slaves
function Hadoop_Optimize_RM() {
  echo -n "create empty access file: ${HADOOP_YARN_NM_ALLOWFILE} ${HADOOP_YARN_NM_DENYFILE} "
  sudo rm -f ${HADOOP_YARN_NM_ALLOWFILE} ${HADOOP_YARN_NM_DENYFILE}
  sudo touch ${HADOOP_YARN_NM_ALLOWFILE}
  sudo touch ${HADOOP_YARN_NM_DENYFILE}
  sudo chown ${GROUP_NAME}:${USER_NAME} ${HADOOP_YARN_NM_ALLOWFILE} ${HADOOP_YARN_NM_DENYFILE}
  echo "ok!"

  local -r SLAVES="${HADOOP_CONF_DIR}/slaves"
  local -r TMPFILE="/tmp/slaves"
  echo "build yarn slaves file ${SLAVES}"
  sudo rm -f ${TMPFILE}
  touch ${TMPFILE}
  for node in "${HADOOP_NM_NODES[@]}"; do
    cat >> ${TMPFILE} <<EOF
${node}
EOF
    echo "  ${node}"
  done
  sudo mv -f ${TMPFILE} ${SLAVES}
  sudo chown ${GROUP_NAME}:${USER_NAME} ${SLAVES}
}
# Function for building view-log alias
# Argument for ZK JN NN RM DN NM
function Optimize_ViewLog_Alias() {
  echo "add view-log alias."
  if [ $# -eq 0 ]; then
    echo "  no arguments specified, skipped!"
    return
  fi

  local -r BASHRC_FILE="/home/${USER_NAME}/.bashrc"
  local -r LOCALHOST_FULLNAME=`hostname`
  local ALIAS_LINE
  for arg in "$@"; do
    case ${arg} in
      ZK )
        ALIAS_LINE="alias zklog='tail -f -n 1000 ${ZK_LOG_DIR}/zookeeper-${USER_NAME}-server-${LOCALHOST_FULLNAME}.log'"
        ;;
      JN )
        ALIAS_LINE="alias jnlog='tail -f -n 1000 ${HADOOP_HDFS_LOG_DIR}/${GROUP_NAME}-${USER_NAME}-journalnode-${LOCALHOST_FULLNAME}.log'"
        ;;
      NN )
        ALIAS_LINE="alias nnlog='tail -f -n 1000 ${HADOOP_HDFS_LOG_DIR}/${GROUP_NAME}-${USER_NAME}-namenode-${LOCALHOST_FULLNAME}.log'"
        ;;
      RM )
        ALIAS_LINE="alias rmlog='tail -f -n 1000 ${HADOOP_HDFS_LOG_DIR}/${GROUP_NAME}-${USER_NAME}-resourcemanager-${LOCALHOST_FULLNAME}.log'"
        ;;
      DN )
        ALIAS_LINE="alias jnlog='tail -f -n 1000 ${HADOOP_HDFS_LOG_DIR}/${GROUP_NAME}-${USER_NAME}-datanode-${LOCALHOST_FULLNAME}.log'"
        ;;
      NM )
        ALIAS_LINE="alias jnlog='tail -f -n 1000 ${HADOOP_HDFS_LOG_DIR}/${GROUP_NAME}-${USER_NAME}-nodemanager-${LOCALHOST_FULLNAME}.log'"
        ;;
      * )
        echo "  unkonwn type ${arg}, skipped!"
        continue
        ;;
    esac

    sudo egrep "^${ALIAS_LINE}$" ${BASHRC_FILE} >& /dev/null
    if [ $? -ne 0 ]; then
      sudo sed -i "\$a\\${ALIAS_LINE}" ${BASHRC_FILE}
      echo "  ${ALIAS_LINE}"
    else
      echo "  ${arg} view-log alias exists."
    fi
  done
}
# Function for Coping scripts
function Hadoop_Copy_Scripts() {
  USER_HOME_BIN="/home/${USER_NAME}/bin"

  sudo mkdir -f ${USER_HOME_BIN}
  sudo cp ~/bin/common_env.sh ${USER_HOME_BIN}
  sudo cp ~/bin/hadoop-cluster.sh ${USER_HOME_BIN}
  sudo chown -R ${GROUP_NAME}:${USER_NAME} ${USER_HOME_BIN}
  sudo chmod +x "${USER_HOME_BIN}/*.sh"
}

########## Main Body ############################
Choose_NodeType
Clear
Create_GroupUser
Optimiz_Hosts
case ${NODE_TYPE} in
  ZKJN )
    Mount_LVM
    ZK_Init
    ZK_Create_Config
    ZK_Optimized_Log
    Hadoop_Init
    Hadoop_Build_Config_CallBack "core-site.xml" "hdfs-site.xml"
    Optimize_ViewLog_Alias ZK JN
    ;;
  NN )
    Mount_Disk
    Hadoop_Init
    Hadoop_Build_Config_CallBack "core-site.xml" "hdfs-site.xml"
    Hadoop_Optimize_NN
    Optimize_ViewLog_Alias NN
    ;;
  RM )
    Mount_Disk
    Hadoop_Init
    Hadoop_Build_Config_CallBack "mapred-site.xml" "yarn-site.xml"
    Hadoop_Optimize_RM
    Optimize_ViewLog_Alias RM
    ;;
  DN)
    Mount_Disk
    Hadoop_Init
    Hadoop_Build_Config_CallBack "core-site.xml" "hdfs-site.xml" "mapred-site.xml" "yarn-site.xml"
    Optimize_ViewLog_Alias DN NM
    ;;
  * )
    echo "Unkonwn type of ${NODE_TYPE}!"
    exit 1
    ;;
esac
Hadoop_Copy_Scripts
