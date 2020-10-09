#!/usr/bin/env bash

# This script file is used for view zookeeper WAL log file contntx.
# Full command to view log
#   java -classpath .:{path}slf4j-api-xxx.jar:{path}zookeeper-xxx.jar org.apache.zookeeper.server.LogFormatter {path}log.xxxxxx
#
# FileName     : zkLogView.sh
# Path         : ~/bin/
# Author       : ymliu
# Create Date  : 2017-10-27 13:47
# WorkFlow     : To set all hostname of cluster to variant HOSTS.
#                For each hostname, run shutdonw command by ssh skip localhost.
#                Shutdown localhost by local command.


ZOOROOTDIR="${BASH_SOURCE-$0}"
ZOOROOTDIR="$(dirname "${ZOOROOTDIR}")"
ZOOROOTDIR="$(cd "${ZOOROOTDIR}"; cd ..; pwd)"

if [ $# -lt 1 ]
then
	echo "	Usage: zkLogView.sh logfile1 logfile2 ..."
	exit 1
fi

if [ -e "$ZOOROOTDIR/zookeeper-3.5.0-alpha.jar" ]
then
	ZOOJAR="${ZOOROOTDIR}/zookeeper-3.5.0-alpha.jar"
else
	echo "zookeeper-xxxx.jar file not found!"
	exit 1
fi

if [ -d "$ZOOROOTDIR/lib" ]
then
	ZOOLIBDIR="$(cd "${ZOOROOTDIR}"; cd lib; pwd)"
else
	echo "zookeeper support lib (*.jar) not found!"
	exit 1
fi

CLASSPATH=".:${ZOOJAR}"
for jarfile in `ls $ZOOLIBDIR/*.jar`
do
	if [ -f "$jarfile" ]
	then
	CLASSPATH="${CLASSPATH}:${jarfile}"
	fi
done

ZOOLOGDIR="${ZOOROOTDIR}/logs/version-2"

echo "zkLogView.sh Environment Setting"
echo "ZOOROOTDIR = ${ZOOROOTDIR}"
echo "ZOOLIBDIR = ${ZOOLIBDIR}"
echo "CLASSPATH = ${CLASSPATH}"
echo "ZOOLOGDIR = ${ZOOLOGDIR}"

for i in "$@"
do
	echo ""
	echo "-------------------------------------------"
	echo "Display LogFile ${i}"
	echo "-------------------------------------------"

	if [ -f $i ]
	then
	java -classpath "$CLASSPATH" org.apache.zookeeper.server.LogFormatter $i
	elif [ -f "${ZOOLOGDIR}/$i" ]
	then
	java -classpath "${CLASSPATH}" org.apache.zookeeper.server.LogFormatter $ZOOLOGDIR/$i
	else
	echo "The logfile ${i} does not exist!"
	fi
done
