#!/bin/bash -xe

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

#format hdfs
${HADOOP_LOCAL_DIR}/bin/hdfs namenode -format
${HADOOP_LOCAL_DIR}/sbin/start-dfs.sh
