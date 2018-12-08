#!/bin/bash

install_scala(){

	SCALA_V="2.12.7"
	SCALA_PKG="scala-${SCALA_V}.rpm"
	SCALA_URL="https://downloads.lightbend.com/scala/${SCALA_V}/${SCALA_PKG}"

	#install scala
	wget $SCALA_URL
	sudo yum -y install ${SCALA_PKG}


		
}



install_spark(){

	SPARK_V="2.3.2"
	HADOOP_V="2.7"
	SPARK_LOCAL_DIR="/usr/local/spark/"
	JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))


	touch /etc/profile.d/spark-env.sh
	cat >> /etc/profile.d/spark-env.sh <<EOF
export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
export SPARK_V="$SPARK_V"
export SPARK_LOCAL_DIR="$SPARK_LOCAL_DIR"
export HADOOP_V="$HADOOP_V"
export PATH=\$PATH:${SPARK_LOCAL_DIR}/bin
EOF

	wget https://archive.apache.org/dist/spark/spark-${SPARK_V}/spark-${SPARK_V}-bin-hadoop2.7.tgz
	sudo mkdir -p ${SPARK_LOCAL_DIR}
	sudo tar -xzvf spark-${SPARK_V}-bin-hadoop2.7.tgz -C ${SPARK_LOCAL_DIR}  --strip-components 1

}

_run(){
	install_scala
	install_spark

}

_run
