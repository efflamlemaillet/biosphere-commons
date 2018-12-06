#!/bin/bash

#install hadoop

#install hadoop binaries
install_hadoop(){

	HADOOP_V="2.7.7"
	HADOOP_PKG="hadoop-$HADOOP_V.tar.gz"
	HADOOP_LOCAL_DIR="/usr/local/hadoop"


	wget http://mirrors.standaloneinstaller.com/apache/hadoop/common/hadoop-$HADOOP_V/$HADOOP_PKG

	sudo mkdir -p ${HADOOP_LOCAL_DIR}
	sudo tar -xzvf $HADOOP_PKG -C ${HADOOP_LOCAL_DIR}  --strip-components 1

	touch /etc/profile.d/hadoop-env.sh
	cat >>/etc/profile.d/hadoop-env.s <<EOF
export HADOOP_V=$HADOOP_V
export HADOOP_PKG=$HADOOP_PKG
export HADOOP_LOCAL_DIR=$HADOOP_LOCAL_DIR
export PATH="'$PATH'":${HADOOP_LOCAL_DIR}/bin
EOF

}



_run(){
	install_hadoop

}

_run
