#!/bin/bash -xe


config_hadoop_slaves(){

	#create if not exist and 
	#add slave to hadoop config
	. ~/.bashrc
	touch ${HADOOP_LOCAL_DIR}/etc/hadoop/slaves

	slave_name=$(ss-get slave_cpnt_name)

	slaves_list=$(ss-get $slave_name:ids)

	IFS=',' read -ra slave_ids <<< "$slaves_list"
	truncate -s0 ${HADOOP_LOCAL_DIR}/etc/hadoop/slaves
	#wait for all slave scripts to set hostname
	for id in ${slave_ids[@]} ; do
	    echo $(ss-get $slave_name.$id:hostname) >> ${HADOOP_LOCAL_DIR}/etc/hadoop/slaves
	done
}

#$1 = input $2 output $3 = name  $4 = value
add_property(){
	xmlstarlet edit -s '//configuration' -t elem -n "property" \
		-s '//configuration/property[last()]' -t elem -n "name"  -v $3 \
		-s '//configuration/property[last()]' -t elem -n "value" -v $4 \
		$1 > $2
	
}
config_hadoop_xml(){
	add_property "${HADOOP_LOCAL_DIR}/share/hadoop/common/templates/core-site.xml" "${HADOOP_LOCAL_DIR}/etc/hadoop/core-site.xml" "fs.default.name" "hdfs://master.local:9000"
	add_property "${HADOOP_LOCAL_DIR}/share/hadoop/hdfs/templates/hdfs-site.xml" "${HADOOP_LOCAL_DIR}/etc/hadoop/hdfs-site.xml" "dfs.replication" "3"
	add_property "${HADOOP_LOCAL_DIR}/share/hadoop/hdfs/templates/hdfs-site.xml" "${HADOOP_LOCAL_DIR}/etc/hadoop/hdfs-site.xml" "dfs.data.dir" "/srv/hadoop/datanode" 
	add_property "${HADOOP_LOCAL_DIR}/share/hadoop/hdfs/templates/hdfs-site.xml" "${HADOOP_LOCAL_DIR}/etc/hadoop/hdfs-site.xml" "dfs.name.dir" "/srv/hadoop/namenode"
}



_run(){
	. /etc/profile.d/*hadoop*
	config_hadoop_slaves
	#format hdfs
	${HADOOP_LOCAL_DIR}/bin/hdfs namenode -format
	${HADOOP_LOCAL_DIR}/sbin/start-dfs.sh
}

_run
