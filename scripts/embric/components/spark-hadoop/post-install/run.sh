#!/bin/bash

install_hadoop(){

	HADOOP_V="2.7.7"
	HADOOP_PKG="hadoop-$HADOOP_V.tar.gz"
	HADOOP_LOCAL_DIR="/usr/local/hadoop"

	wget http://mirrors.standaloneinstaller.com/apache/hadoop/common/hadoop-$HADOOP_V/$HADOOP_PKG

	mkdir -p ${HADOOP_LOCAL_DIR}
	tar -xzvf $HADOOP_PKG -C ${HADOOP_LOCAL_DIR}  --strip-components 1
	DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
	cp $DIR/../config/* /etc/profile.d/

}



_run(){
	install_hadoop

}

_run
