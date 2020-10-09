# To define all variants for install
# Modifiy by yourself to correct enviroments

LOCALHOST=`hostname -s`

# group & user
GROUP_NAME="mysql"
USER_NAME="mysql"

# nodes & hostname
MGM_NODES=("mgm1" "mgm2")
NDB_NODES=("ndb1" "ndb2")
SQL_NODES=("sql1" "sql2")

# Build SQL node's ServerID
function Build_ServerID() {
  local index=20
  for host in "${SQL_NODES[@]}"; do
    index=$[$index +1]
    if [ $LOCALHOST = $host ]; then
      echo $index;
      break;
    fi
  done
}

# common configurations
STORAGE_DIR="/ext"

MYSQL_BASE_DIR="/opt/mysql-cluster-gpl-7.5.8-linux-glibc2.12-x86_64"
SOURCE_DIR="${MYSQL_BASE_DIR}/bin"
TARGET_DIR="/usr/local/bin"

# management
MGM_EXEC_FILES=("ndb_mgmd" "ndb_mgm" "mysql")
MGM_DIR="${STORAGE_DIR}/mysql-cluster"
MGM_CONFIG_FILE="${MGM_DIR}/config.ini"
MGM_TMPFILE="/tmp/config.ini"

# ndb
NDB_EXEC_FILES=("ndbd" "ndbmtd" "mysql")
NDB_DIR="${STORAGE_DIR}/mysql"

# sql
SQL_SYMBOLIC_LINK="/usr/local/mysql"
SQL_DIR="${STORAGE_DIR}/mysql"
SQL_DATA_DIR="${SQL_DIR}/data"
SQL_LOG_BIN="${LOCALHOST}-bin"
SQL_PORT="3306"
SQL_SOCKET_FILE="${SQL_DIR}/mysql.sock"
SQL_LOG_FILE="${SQL_DIR}/mysqld-${LOCALHOST}.log"
SQL_PID_FILE="${SQL_DIR}/mysqld-${LOCALHOST}.pid"
SQL_PASSWD="ocab7e9a"
SQL_SERVICE="mysql.server"
SQL_SERVER_ID=`Build_ServerID`

# all client
CLIENT_CONFIG_FILE="/etc/my.cnf"
CLIENT_CONFIG_TMPFILE="/tmp/my.cnf"
