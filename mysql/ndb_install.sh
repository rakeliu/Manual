#!/usr/bin/env bash

# This script is used for install Mysql NDB-Cluster
# No arguments because script confirm nodetype automaticlly
# Usage: ndb_install.sh
#
# FileName     : ndb_install.sh
# Path         : ~/bin/
# Author       : ymliu
# Create Date  : 2017-11-20 10:40
# WorkFlow     :

# Load NDB-Cluster Environments
. ~/bin/ndb_env.sh

# Function for asking for clear first
function Ask_Clear() {
	read -n1 -p "1.Clear enviroments first [Y/n]?: " READ
	echo ""
	if [ "$READ" = "Y" -o "$READ" = "y" ]; then
		. ~/bin/ndb_clear.sh
	fi
}

# Function for check/create group&user
function Create_Group_User() {
	echo -n "2.Check group ${GROUP_NAME} ... "
	egrep "^${GROUP_NAME}" /etc/group >& /dev/null
	if [ $? -ne 0 ]
	then
		echo -n "creating ... "
		sudo groupadd ${GROUP_NAME}
		echo "created."
	else
		echo "exist!"
	fi

	echo -n "3.Check user ${USER_NAME} ... "
	egrep "^${USER_NAME}" /etc/passwd >& /dev/null
	if [ $? -ne 0 ]; then
		echo -n "creating ... "
		sudo useradd -g ${GROUP_NAME} -s /bin/false ${USER_NAME}
		echo "create!"
	else
		echo "exist!"
	fi
}

# Function for whether localhost was in nodes passed by arguments
function Check_Type() {
	local -r NODES=(`echo "$@"`)

	for node in "${NODES[@]}"; do
		if [ $LOCALHOST = $node ]; then
			return 0
		fi
	done

	return 1
}

# Function for consider which type in ndb-cluster
function Consider_Type() {
	# whether node type is management
	Check_Type "${MGM_NODES[@]}"
	if [ $? -eq 0 ]; then
		echo "MGM"
		return 0
	fi

	# whether node type is ndb
	Check_Type "${NDB_NODES[@]}"
	if [ $? -eq 0 ]; then
		echo "NDB"
		return 0
	fi

	# whether node type is sql
	Check_Type "${SQL_NODES[@]}"
	if [ $? -eq 0 ]; then
		echo "SQL"
		return 0
	fi

	echo "Unknown"
	return 1
}

# Function for building connect-string of my.cnf
function Build_ConnectString() {
	local index=0
	local RET

	for host in "${MGM_NODES[@]}"; do
		if [ $index -eq 0 ]; then
			RET="${host}"
		else
			RET="${RET},${host}"
		fi
		index=$[$index +1]
	done
	echo $RET
}

# Function for create files of management node
function Install_MGM() {
	echo "4.Localhost is management node, installing ..."

	local index

	# copy/link management & mysql file into execute direcory
	echo " 4.1 Creating symblic link:"
	for file in "${MGM_EXEC_FILES[@]}"; do
		echo "     ${TARGET_DIR}/${file} --> ${SOURCE_DIR}/${file} created."
		sudo ln -sf ${SOURCE_DIR}/${file} ${TARGET_DIR}/${file}
	done

	# create direcory & chown & chmod
	echo -n " 4.2 Creating management directory: ${MGM_DIR} "
	sudo mkdir -p ${MGM_DIR}
	sudo chown -R ${GROUP_NAME}:${USER_NAME} ${MGM_DIR}
	sudo chmod +r ${MGM_DIR}
	echo "created, change owner & privileges."

	# create configuration tmp-file, remove if it exist
	echo -n " 4.3 Createing management configuration file."
	touch ${MGM_TMPFILE}
	echo " Empty tempfile ${MGM_TMPFILE} created!"

	# fill file contents
	echo " 4.4 Filling configuration tempfile."
	echo "     section [tcp default] filled."
	cat >> ${MGM_TMPFILE} <<EOF
# Configure tcp default
[tcp default]

EOF
	# fill file contents - fill computers
	echo -n "     filling section [computer]: "
	cat >> ${MGM_TMPFILE} <<EOF
# Configure compute node, define id & hostname(ip)
# Define secion per node except for ExecuteOnMachine
EOF
	# fill file contents - fill computers - management node
	index=1
	for host in "${MGM_NODES[@]}"; do
		cat >> ${MGM_TMPFILE} <<EOF
[computer]
id=mgm-server-${index}
hostname=${host}

EOF
		echo -n "${host} "
		index=$[$index + 1]
	done
	# fill file contents - fill computers - ndb node
	index=1
	for host in "${NDB_NODES[@]}"; do
		cat >> ${MGM_TMPFILE} <<EOF
[computer]
id=ndb-server-${index}
hostname=${host}

EOF
		echo -n "${host} "
		index=$[$index +1]
	done
	# fill file contents - fill computers - sql node
	index=0
	for host in "${SQL_NODES[@]}"; do
		cat >> ${MGM_TMPFILE} <<EOF
[computer]
id=sql-server-${index}
hostname=${host}

EOF
		echo -n "${host} "
		index=$[$index +1]
	done
	echo "."
	# fill file contents - fill computers end.

	# fill file contents - fill ndb_mgmd
	echo "     section [ndb_mgmd default] filled."
	cat >> ${MGM_TMPFILE} <<EOF
[ndb_mgmd default]
datadir=${MGM_DIR}

EOF
	# fill file contents - fill ndb_mgmd
	echo -n "     filling section [ndb_mgmd]:"
	index=1
	for host in "${MGM_NODES[@]}"; do
		cat >> ${MGM_TMPFILE} <<EOF
[ndb_mgmd]
nodeid=${index}
hostname=${host}

EOF
		echo -n "${host} "
		index=$[$index + 1]
	done
	echo "."
	# fill file contents - fill ndb_mgmd end.

	# fill file contents - fill ndb default
	echo "     filling section [ndbd default]."
	cat >> ${MGM_TMPFILE} <<EOF
[ndbd default]
NoOfReplicas=2
DataMemory=80M
IndexMemory=18M
datadir=${NDB_DIR}

EOF
	# fill file contents - fill ndb node
	echo -n "     filling section [ndbd]:"
	cat >> ${MGM_TMPFILE} <<EOF
EOF
	# fill file contents - fill ndb node
	index=11
	for host in "${NDB_NODES[@]}"; do
		cat >> ${MGM_TMPFILE} <<EOF
[ndbd]
nodeid=${index}
hostname=${host}

EOF
		echo -n "${host} "
		index=$[$index + 1]
	done
	echo "."
	# fill file contents - fill ndb node end.

	# fill file contents - fill sql node
	echo -n "     filling section [mysqld]:"
	cat >> ${MGM_TMPFILE} <<EOF
EOF
	index=21
	for host in "${SQL_NODES[@]}"; do
		cat >> ${MGM_TMPFILE} <<EOF
[mysqld]
nodeid=${index}
hostname=${host}

EOF
		echo -n "${host} "
		index=$[$index + 1]
	done
	# fill file contents - fill sql node - for backup & restore
	cat >> ${MGM_TMPFILE} <<EOF
# Configure emtpy section at least for backup & recover, because empty section will be connected by any node not defined
[mysqld]
EOF
	echo "(empty)."
	# ---------------------------------------
	# fill file contents end.

	# move it to configuration directory, remove first if it exist
	echo -n "     move tempfile to sys directory: ${MGM_TMPFILE} --> ${MGM_CONFIG_FILE} "
	sudo mv ${MGM_TMPFILE} ${MGM_CONFIG_FILE}
	sudo chown ${GROUP_NAME}:${USER_NAME} ${MGM_CONFIG_FILE}
	echo "success."

	# create my.cnf
	local -r CONNECT_STRING=`Build_ConnectString`
	echo " 4.5 Create client configuration file, connect-string=${CONNECT_STRING}"
	touch ${CLIENT_CONFIG_TMPFILE}
	cat > ${CLIENT_CONFIG_TMPFILE} <<EOF
[ndb_mgm]
connect-string=$CONNECT_STRING
EOF

	sudo mv ${CLIENT_CONFIG_TMPFILE} ${CLIENT_CONFIG_FILE}
	sudo chown root:root ${CLIENT_CONFIG_FILE}
	sudo chmod +r ${CLIENT_CONFIG_FILE}

	echo "Install successfully!"
}

# Function for create files of ndb node
function Install_NDB() {
	echo "4.Localhost is ndb node, installing ... "

	# copy/link ndb & mysql file into execute directory

	echo " 4.1 Creating symblic link:"
	for file in "${NDB_EXEC_FILES[@]}"; do
		echo "     ${TARGET_DIR}/${file} --> ${SOURCE_DIR}/${file} created."
		sudo ln -sf ${SOURCE_DIR}/${file} ${TARGET_DIR}/${file}
	done

	# create directory & chown & chmod
	echo -n " 4.2 Create ndb directory: ${NDB_DIR} "
	sudo mkdir -p ${NDB_DIR}
	sudo chown -R ${GROUP_NAME}:${USER_NAME} ${NDB_DIR}
	sudo chmod +r ${NDB_DIR}
	echo "created."

	# create my.cnf
	local -r CONNECT_STRING=`Build_ConnectString`
	echo " 4.3 Create cleint configuration file, connect-string=${CONNECT_STRING}"
	touch ${CLIENT_CONFIG_TMPFILE}
	cat > ${CLIENT_CONFIG_TMPFILE} <<EOF
[ndbd]
connect-string=${CONNECT_STRING}
EOF

	sudo mv ${CLIENT_CONFIG_TMPFILE} ${CLIENT_CONFIG_FILE}
	sudo chown ${GROUP_NAME}:${USER_NAME} ${CLIENT_CONFIG_FILE}

	echo "Install ndb node successfully."
}

# Function for create files of sql node
function Install_SQL() {
	echo "4.Localhost is sql node, installing..."

	# create symbolic link of whole mysql
	sudo ln -sf ${MYSQL_BASE_DIR} ${SQL_SYMBOLIC_LINK}
	sudo chown -R ${GROUP_NAME}:${USER_NAME} ${SQL_SYMBOLIC_LINK}

	# create directory & chown & chmod
	echo -n " 4.1 Create sql directory : ${NDB_DIR} "
	sudo mkdir -p ${NDB_DIR}
	sudo chown -R ${GROUP_NAME}:${USER_NAME} ${NDB_DIR}
	sudo chmod -R +r ${NDB_DIR}
	echo "created."

	# create my.cnf
	echo -n " 4.2 Create client configuration file : ${CLIENT_CONFIG_TMPFILE} "
	local -r CONNECT_STRING=`Build_ConnectString`
	touch ${CLIENT_CONFIG_TMPFILE}
	cat >${CLIENT_CONFIG_TMPFILE} <<EOF
[mysqld]
# configurations for mysqld process
ndbcluster
binlog_format=row
log_bin=${SQL_LOG_BIN}
server-id=${SQL_SERVER_ID}
ndb_connectstring=${CONNECT_STRING}

user=${USER_NAME}
basedir=${SQL_SYMBOLIC_LINK}
datadir=${SQL_DATA_DIR}
port=${SQL_PORT}

socket=${SQL_SOCKET_FILE}

# Disabling symbolic-links is recommended to prevent assorted security risks
symbolic-links=0
# Settings user and group are ignored when systemd is used.
# If you need to run mysqld under a different user or group,
# customize your systemd unit file for mariadb according to the
# instructions in http://fedoraproject.org/wiki/Systemd

[client]
# configurations for mysql client
socket=${SQL_SOCKET_FILE}

[mysql-cluster]
# configurations for MySQL Cluster process
ndb-connectstring=${CONNECT_STRING}

[mysqld_safe]
log-error=${SQL_LOG_FILE}
pid-file=${SQL_PID_FILE}

[mysql]
socket=${SQL_SOCKET_FILE}
EOF
	echo -n "created, "

	sudo mv ${CLIENT_CONFIG_TMPFILE} ${CLIENT_CONFIG_FILE}
	sudo chown ${GROUP_NAME}:${USER_NAME} ${CLIENT_CONFIG_FILE}
	echo " move to ${CLIENT_CONFIG_FILE}."

	# install Service
	echo -n " 4.3 Install Service ... "
	sudo cp "${MYSQL_BASE_DIR}/support-files/${SQL_SERVICE}" "/etc/rc.d/init.d/"
	sudo chkconfig --add ${SQL_SERVICE}
	sudo chkconfig ${SQL_SERVICE} off
	echo "${SQL_SERVICE} installed."

	echo "Install sql node successfully."

	# add path to /etc/profile
	local -r EXPORT_STR="export PATH=\$PATH:${SQL_SYMBOLIC_LINK}/bin"
	echo "------------------------------------------------------------------"
	echo "NOTICE:"
	echo " Modify /etc/profile by yourself, add line below."
	echo "    ${EXPORT_STR}"
	echo " And RUN command below:"
	echo "    sudo mysqld --initialize-insecure --user=${USER_NAME} --server-id=${SQL_SERVER_ID}"
	echo " And FIX BUG, touch empty log file, run command below"
	echo "    sudo touch ${SQL_LOG_FILE}"
	echo "    sudo chown ${GROUP_NAME}:${USER_NAME} ${SQL_LOG_FILE}"
	echo " And Change Passwd for root of mysql, run sql below:."
	echo "    use mysql;"
	echo "    set password for 'root'@'localhost'=password('${SQL_PASSWD}');"
	echo "    flush Privileges;"
	echo "    update user set host='%' where user='root' and host='localhost';"
	echo " And Grant Distribute Privileges, run script on mysql commandline."
	echo "------------------------------------------------------------------"
}

# To be suer clear first
Ask_Clear

# To be sure user & group exist or create
Create_Group_User

TYPE=`Consider_Type`
case ${TYPE} in
	MGM )
		Install_MGM;;
	NDB )
		Install_NDB;;
	SQL )
		Install_SQL;;
	* )
		echo "Error !!!"
		echo "  Localhost is unknown node type, please check hostname or reconfig ndb_env.sh."
		exit 1;;
esac
