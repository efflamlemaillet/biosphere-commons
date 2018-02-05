source /scripts/cluster/cluster_install.sh

SPARK_DIR=/opt
SPARK_ROOT_DIR=$SPARK_DIR/spark

Install_SPARK_master()
{
    cd $SPARK_DIR
    wget http://wwwftp.ciril.fr/pub/apache/spark/spark-2.2.0/spark-2.2.0-bin-hadoop2.7.tgz
    tar xzvf spark-2.2.0-bin-hadoop2.7.tgz
    mv spark-2.2.0-bin-hadoop2.7/ spark
    rm -rf spark-2.2.0-bin-hadoop2.7.tgz
    
    if isubuntu; then
        #install sbt
        echo "deb https://dl.bintray.com/sbt/debian /" | sudo tee -a /etc/apt/sources.list.d/sbt.list
        apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 2EE0EA64E40A89B84B2DF73499E82A75642AC823 -y
        apt-get update -y
        apt-get install -y sbt
        
        #install java8
        apt-get install -y software-properties-common
        apt-add-repository ppa:webupd8team/java -y
        apt-get update -y
        
        echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | debconf-set-selections
        echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 seen true" | debconf-set-selections
        
        apt-get install -y oracle-java8-installer
    
    
        cd $SPARK_ROOT_DIR/conf/
    
        #spark-env
        cp spark-env.sh.template spark-env.sh
        echo "JAVA_HOME=/usr/lib/jvm/java-8-oracle" >> spark-env.sh
        echo "SPARK_WORKER_MEMORY=4g" >> spark-env.sh
    
        #disable ipv6
        if isubuntu 16; then
            echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
            echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
            echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
        fi
    
        echo "export JAVA_HOME=/usr/lib/jvm/java-8-oracle" > /etc/profile.d/spark.sh
        echo "export SBT_HOME=/usr/share/sbt-launcher-packaging/bin/sbt-launch.jar" >> /etc/profile.d/spark.sh
        echo "export SPARK_HOME=$SPARK_ROOT_DIR" >> /etc/profile.d/spark.sh
        echo "export PATH=\$PATH:\$JAVA_HOME/bin" >> /etc/profile.d/spark.sh
        echo "export PATH=\$PATH:\$SBT_HOME/bin:\$SPARK_HOME/bin:\$SPARK_HOME/sbin" >> /etc/profile.d/spark.sh
    elif iscentos; then
        echo "export SPARK_HOME=\$HOME/spark-1.6.0-bin-hadoop2.6" > /etc/profile.d/spark.sh
        echo "export PATH=\$PATH:\$SPARK_HOME/bin" >> /etc/profile.d/spark.sh
        echo "export PATH=\$PATH:/usr/lib/scala/bin:\$SPARK_HOME/bin" >> /etc/profile.d/spark.sh
        echo "export SPARK_HOME=\$HOME/spark-1.6.0-bin-hadoop2.6" >> /etc/profile.d/spark.sh
        echo "export PATH=\$PATH:\$SPARK_HOME/bin" >> /etc/profile.d/spark.sh
    fi
}

Install_SPARK_slave()
{    
    if isubuntu; then
        #install sbt
        echo "deb https://dl.bintray.com/sbt/debian /" | sudo tee -a /etc/apt/sources.list.d/sbt.list
        apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 2EE0EA64E40A89B84B2DF73499E82A75642AC823 -y
        apt-get update -y
        apt-get install -y sbt
        
        #install java8
        apt-get install -y software-properties-common
        apt-add-repository ppa:webupd8team/java -y
        apt-get update -y
        
        echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | debconf-set-selections
        echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 seen true" | debconf-set-selections
        
        apt-get install -y oracle-java8-installer
    
        #disable ipv6
        if isubuntu 16; then
            echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
            echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
            echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
        fi
    
        echo "export JAVA_HOME=/usr/lib/jvm/java-8-oracle" > /etc/profile.d/spark.sh
        echo "export SBT_HOME=/usr/share/sbt-launcher-packaging/bin/sbt-launch.jar" >> /etc/profile.d/spark.sh
        echo "export SPARK_HOME=$SPARK_ROOT_DIR" >> /etc/profile.d/spark.sh
        echo "export PATH=\$PATH:\$JAVA_HOME/bin" >> /etc/profile.d/spark.sh
        echo "export PATH=\$PATH:\$SBT_HOME/bin:\$SPARK_HOME/bin:\$SPARK_HOME/sbin" >> /etc/profile.d/spark.sh
    elif iscentos; then
        echo "export SPARK_HOME=\$HOME/spark-1.6.0-bin-hadoop2.6" > /etc/profile.d/spark.sh
        echo "export PATH=\$PATH:\$SPARK_HOME/bin" >> /etc/profile.d/spark.sh
        echo "export PATH=\$PATH:/usr/lib/scala/bin:\$SPARK_HOME/bin" >> /etc/profile.d/spark.sh
        echo "export SPARK_HOME=\$HOME/spark-1.6.0-bin-hadoop2.6" >> /etc/profile.d/spark.sh
        echo "export PATH=\$PATH:\$SPARK_HOME/bin" >> /etc/profile.d/spark.sh
    fi
}

Config_iptables_spark()
{
	msg_info "Configuring iptables..."
    if isubuntu 16; then
        systemctl restart iptables.service
    elif isubuntu 14; then
		service iptables restart
	fi
    
    if isubuntu; then
	    iptables -N IFB_CLSTR_SPARK &&  iptables -I INPUT -j IFB_CLSTR_SPARK
	    iptables -F IFB_CLSTR_SPARK
	    iptables -I IFB_CLSTR_SPARK -m multiport -p tcp --dport 80,111,662,875,892,2049,32803,7077,8080,8081,4040,18080,51810:51816 -j ACCEPT
	    iptables -I IFB_CLSTR_SPARK -m multiport -p udp --dport 80,111,662,875,892,2049,32803,7077,8080,8081,4040,18080,51810:51816 -j ACCEPT
    elif iscentos; then
        firewall-cmd --permanent --zone=public --add-port=6066/tcp
        firewall-cmd --permanent --zone=public --add-port=7077/tcp
        firewall-cmd --permanent --zone=public --add-port=8080-8081/tcp
        firewall-cmd --reload
    fi
}

Config_SPARK_master()
{
    Config_iptables_spark
    
	msg_info "Add nodes slave in conf/slaves..."
	
	cp $SPARK_ROOT_DIR/conf/slaves.template $SPARK_ROOT_DIR/conf/slaves
	
	#sed -i -e 's|# - SPARK_MASTER_IP.*|# - SPARK_MASTER_IP, to bind the master to a different IP address or hostname\nSPARK_MASTER_IP='${MASTER_IP}'|g' $SPARK_ROOT_DIR/conf/spark-env.sh
    
	# add slaves
	if [ "$category" == "Deployment" ]; then
        compute_node=$(ss-get compute.enable)
        if [ "$compute_node" == "false" ]; then
	        sed -i '/^localhost/d' $SPARK_ROOT_DIR/conf/slaves
        fi
        node_multiplicity=$(ss-get $SLAVE_NAME:multiplicity)
        if [ "$node_multiplicity" != "0" ]; then
        	for i in $(echo "$(ss-get $SLAVE_NAME:ids)" | sed 's/,/\n/g'); do
        	#for (( i=1; i <= $(ss-get $SLAVE_NAME:multiplicity); i++ )); do
        	
        	    if [ $IP_PARAMETER == "hostname" ]; then
                    node_host=$(ss-get $SLAVE_NAME.$i:ip.ready)
                else
                    node_host=$(ss-get $SLAVE_NAME.$i:$IP_PARAMETER)
                fi
        	    node_name=$SLAVE_NAME-$i
        	    
        	    #echo $node_host $node_name |  tee -a /etc/hosts
        	    
                msg_info "\t. on node $node_host"
        		if grep -q $node_host "$SPARK_ROOT_DIR/conf/slaves"; then
        		    echo "$node_host ready"
        		else
        			echo "$node_host" >> "$SPARK_ROOT_DIR/conf/slaves"
        		fi
                
                ss-get --timeout=3600 $SLAVE_NAME.$i:nfs.ready
                nfs_ready=$(ss-get $SLAVE_NAME.$i:nfs.ready)
                msg_info "Waiting NFS to be ready."
            	while [ "$nfs_ready" == "false" ]
            	do
            		sleep 10;
            		nfs_ready=$(ss-get $SLAVE_NAME.$i:nfs.ready)
            	done
            done
        fi
    else
        msg_info "master is a compute node"
	fi
    
	$SPARK_ROOT_DIR/sbin/stop-all.sh
	$SPARK_ROOT_DIR/sbin/start-all.sh
    
	ss-set spark.ready "true"
	
	msg_info "SPARK is configured."
    
    #command test
    # spark-submit --class org.apache.spark.examples.SparkPi --master spark://master-1:7077 /opt/spark/examples/src/main/python/pi.py 1000
}

Config_SPARK_slave()
{
    Config_iptables_spark
    
	test -f $SPARK_ROOT_DIR/conf/slaves && VAL=1 || VAL=0
	echo waiting...
	while [ $VAL -eq 0 ]
	do
		echo $SPARK_ROOT_DIR/conf/slaves not found
		sleep 10;
		test -f $SPARK_ROOT_DIR/conf/slaves && VAL=1 || VAL=0
	done
	sleep 1
	echo $SPARK_ROOT_DIR/conf/slaves found
    
    ss-set nfs.ready "true"
    msg_info "SPARK is configured."
}

add_nodes() {
    MASTER_ID=1
    category=$(ss-get ss:category)
    if [ "$category" == "Deployment" ]; then
        HOSTNAME=$(ss-get nodename)-$MASTER_ID
    else
        HOSTNAME=machine-$MASTER_ID
    fi

    HOSTNAME=$(echo $HOSTNAME | sed "s|_|-|g")
    echo "$HOSTNAME" > /etc/hostname
    hostname $HOSTNAME
    
    ss-display "ADD slave..."
    for INSTANCE_NAME in $SLIPSTREAM_SCALING_VMS; do
        INSTANCE_NAME_SAFE=$(echo $INSTANCE_NAME | sed "s/\./-/g")
        
        echo "Processing $INSTANCE_NAME"
        # Do something here. Example:
        #ss-get $INSTANCE_NAME:ready
        
        if [ $IP_PARAMETER == "hostname" ]; then
            ss-get --timeout=3600 $INSTANCE_NAME:net.services.enable
            ss-set $INSTANCE_NAME:net.services.enable "[]"
            ss-get --timeout=3600 $INSTANCE_NAME:ip.ready
            PUBLIC_SLAVE_IP=$(ss-get $INSTANCE_NAME:$IP_PARAMETER)
            SLAVE_IP=$(ss-get $INSTANCE_NAME:ip.ready)
        else
            PUBLIC_SLAVE_IP=$(ss-get $INSTANCE_NAME:hostname)
            SLAVE_IP=$(ss-get $INSTANCE_NAME:$IP_PARAMETER)
        fi
        sed -i "s|$PUBLIC_SLAVE_IP|$SLAVE_IP|g" /etc/hosts
        echo "New instance of $SLIPSTREAM_SCALING_NODE: $INSTANCE_NAME_SAFE, $SLAVE_IP"
        
        NFS_export_add /opt/spark
        NFS_export_add /home
       
       if grep -q $SLAVE_IP /etc/hosts; then
            echo "$SLAVE_IP ready"
        else
            echo "$SLAVE_IP $INSTANCE_NAME_SAFE" >> /etc/hosts
        fi
        
		if grep -q $node_host "$SPARK_ROOT_DIR/conf/slaves"; then
		    echo "$node_host ready"
		else
			echo "$node_host" >> "$SPARK_ROOT_DIR/conf/slaves"
		fi
        
        ss-get --timeout=3600 $SLAVE_NAME.$i:nfs.ready
        nfs_ready=$(ss-get $SLAVE_NAME.$i:nfs.ready)
        msg_info "Waiting NFS to be ready."
    	while [ "$nfs_ready" == "false" ]
    	do
    		sleep 10;
    		nfs_ready=$(ss-get $SLAVE_NAME.$i:nfs.ready)
    	done
    done
    NFS_start
    
	$SPARK_ROOT_DIR/sbin/stop-all.sh
	$SPARK_ROOT_DIR/sbin/start-all.sh
    
    ss-set spark.ready "true"
    ss-display "Slave is added."
}

## Remove slaves
rm_nodes() {
    MASTER_ID=1
    category=$(ss-get ss:category)
    if [ "$category" == "Deployment" ]; then
        HOSTNAME=$(ss-get nodename)-$MASTER_ID
    else
        HOSTNAME=machine-$MASTER_ID
    fi

    HOSTNAME=$(echo $HOSTNAME | sed "s|_|-|g")
    echo "$HOSTNAME" > /etc/hostname
    hostname $HOSTNAME
    
    ss-display "RM slave..."
    for INSTANCE_NAME in $SLIPSTREAM_SCALING_VMS; do
        INSTANCE_NAME_SAFE=$(echo $INSTANCE_NAME | sed "s/\./-/g")
    
        echo "Processing $INSTANCE_NAME"
        # Do something here. Example:
        #ss-get $INSTANCE_NAME:ready
        #SLAVE_IP=$(ss-get $INSTANCE_NAME:$IP_PARAMETER)
        
        if [ $IP_PARAMETER == "hostname" ]; then
            ss-get --timeout=3600 $INSTANCE_NAME:ip.ready
            PUBLIC_SLAVE_IP=$(ss-get $INSTANCE_NAME:$IP_PARAMETER)
            SLAVE_IP=$(ss-get $INSTANCE_NAME:ip.ready)
        else
            PUBLIC_SLAVE_IP=$(ss-get $INSTANCE_NAME:hostname)
            SLAVE_IP=$(ss-get $INSTANCE_NAME:$IP_PARAMETER)
        fi
        sed -i "s|$SLAVE_IP.*||g" /etc/hosts
        
        #remove nfs export
        sed -i 's|'$SLAVE_IP'(rw,sync,no_subtree_check,no_root_squash)||' /etc/exports
        
        #remove node
        sed -i 's|'$INSTANCE_NAME_SAFE'||' $SPARK_ROOT_DIR/conf/slaves
    done
    
	$SPARK_ROOT_DIR/sbin/stop-all.sh
	$SPARK_ROOT_DIR/sbin/start-all.sh
    
    ss-display "Slave is removed."
}