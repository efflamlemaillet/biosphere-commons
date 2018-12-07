#!/bin/bash -xe


config_spark_env(){
	ss-set component_name $(ss-get nodename)

	listen_hostname=$(ss-get hostname)
	SPARK_MASTER_HOST=${listen_hostname}
	SPARK_MASTER_PORT=7077
	SPARK_MASTER_WEBUI_PORT=$(ss-get spark-web-port)


	cat >> ${SPARK_LOCAL_DIR}/conf/spark-env.sh <<EOF
export SPARK_MASTER_HOST="$SPARK_MASTER_HOST"
export SPARK_MASTER_PORT=${SPARK_MASTER_PORT}
export SPARK_MASTER_WEBUI_PORT=${SPARK_MASTER_WEBUI_PORT}
EOF
	

}



add_slaves_config(){

	slave_name=$(ss-get slave_cpnt_name)

	touch ${SPARK_LOCAL_DIR}/conf/slaves

	slaves_list=$(ss-get $slave_name:ids)

	IFS=',' read -ra slave_ids <<< "$slaves_list"

	for id in ${slave_ids[@]} ; do
	    echo $(ss-get $slave_name.$id:hostname) >> ${SPARK_LOCAL_DIR}/conf/slaves
	done
}


$SPARK_LOCAL_DIR/sbin/start-all.sh

# provide status information through web UI
ss-display "Webserver ready on ${link}!"


_run(){
	config_spark_env
	add_slaves_config
	#start master and slaves
	$SPARK_LOCAL_DIR/sbin/start-all.sh
}

_run

