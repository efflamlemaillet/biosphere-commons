source /scripts/cluster/cluster_install.sh

install_tinc(){
    if isubuntu; then
        msg_info "Installing requirements with apt-get."
        apt-get update -y
        apt-get install -y liblzo2-2 liblzo2-dev zlib1g-dev libssl-dev
    elif iscentos; then
        msg_info "Installing requirements with yum."
        yum update -y
        yum install -y lzo lzo-devel zlib-devel openssl-devel
    fi
    msg_info "Requirements are installed."
    
    tinc_version="1.0.31"
    tinc_name="tinc-$tinc_version"
    tinc_pkg="$tinc_name.tar.gz"
    tinc_url=https://www.tinc-vpn.org/packages/$tinc_pkg
    tinc_dir=/tmp
    
    wget -O $tinc_dir/$tinc_pkg $tinc_url
    cd $tinc_dir
    tar -xzf $tinc_pkg
    rm -rf $tinc_pkg
    cd $tinc_name
    ./configure
    make
    make install
}

configure_tinc_server(){
    tinc_dir="/usr/local/etc/tinc"
    
    component_vpn_name=${component_vpn_name:-vpn}
    component_server_name=${component_server_name:-master}
    component_client_name=${component_client_name:-slave}
    
    NETWORK_MODE=$(ss-get network)
    if [ "$NETWORK_MODE" == "Public" ]; then
        PUBLIC_IP=$(ss-get hostname)
        #ss-set hostname "${PRIVATE_IP}"
        HOSTIP=$(echo $(hostname -I | sed 's/ /\n/g' | head -n 1))
    else
        PUBLIC_IP=$(ss-get $IP_PARAMETER)
        HOSTIP=$(ss-get $IP_PARAMETER)
    fi
    ss-set private_ip "$HOSTIP"
    
    INTERFACE="eth0"
    netname="vpn"
    externalnyc="vpn_server"
    externalnyc_public_IP=$(ss-get $component_server_name:hostname)
    
    mkdir -p $tinc_dir/$netname/hosts
    echo "Name = $externalnyc" > $tinc_dir/$netname/tinc.conf
    echo "AddressFamily = ipv4" >> $tinc_dir/$netname/tinc.conf
    echo "Interface = $INTERFACE" >> $tinc_dir/$netname/tinc.conf
    
    echo "Address = $externalnyc_public_IP" > $tinc_dir/$netname/hosts/$externalnyc
    echo "Subnet = 10.0.0.1/32" >> $tinc_dir/$netname/hosts/$externalnyc
    
    yes "" | tincd -n $netname -K4096
    
    echo "#!/bin/sh" > $tinc_dir/$netname/tinc-up
    echo "ifconfig $INTERFACE 10.0.0.1 netmask 255.255.255.0" >> $tinc_dir/$netname/tinc-up
    
    echo "#!/bin/sh" > $tinc_dir/$netname/tinc-down
    echo "ifconfig $INTERFACE down" >> $tinc_dir/$netname/tinc-down
    
    chmod 755 $tinc_dir/$netname/tinc-*
    mkdir -p /usr/local/var/run/
    
    ss-set hosts_configuration_file "$(cat $tinc_dir/$netname/hosts/$externalnyc)"
    
    ss-set $component_server_name:vpn.adress "10.0.0.1"
    
    for i in $(echo "$(ss-get $component_client_name:ids)" | sed 's/,/\n/g'); do
        j=$i+1
        ss-set $component_client_name.$i:vpn.adress "10.0.0.$j"
        
        node_name=$component_client_name-$i
        ss-get --timeout=3600 $component_client_name.$i:hosts_configuration_file > $tinc_dir/$netname/hosts/$node_name
    done
    
    ss-set server.ready "true" 
}

configure_tinc_client(){
    tinc_dir="/usr/local/etc/tinc"
    
    component_server_name=${component_server_name:-master}
    component_client_name=${component_client_name:-slave}
    
    NETWORK_MODE=$(ss-get network)
    if [ "$NETWORK_MODE" == "Public" ]; then
        PUBLIC_IP=$(ss-get hostname)
        #ss-set hostname "${PRIVATE_IP}"
        HOSTIP=$(echo $(hostname -I | sed 's/ /\n/g' | head -n 1))
    else
        PUBLIC_IP=$(ss-get $IP_PARAMETER)
        HOSTIP=$(ss-get $IP_PARAMETER)
    fi
    ss-set private_ip "$HOSTIP"
    
    INTERFACE="eth0"
    netname="vpn"
    externalnyc="vpn_server"
    ID=$(ss-get id)
    node_name=$component_client_name-$ID
    
    mkdir -p $tinc_dir/$netname/hosts
    echo "Name = $node_name" > $tinc_dir/$netname/tinc.conf
    echo "AddressFamily = ipv4" >> $tinc_dir/$netname/tinc.conf
    echo "Interface = $INTERFACE" >> $tinc_dir/$netname/tinc.conf
    echo "ConnectTo = $externalnyc" >> $tinc_dir/$netname/tinc.conf
    
    ip_client=$(ss-get --timeout=3600 vpn.adress)
    echo "Subnet = $ip_client/32" > $tinc_dir/$netname/hosts/$node_name
    
    yes "" | tincd -n $netname -K4096
    
    echo "#!/bin/sh" > $tinc_dir/$netname/tinc-up
    echo "ifconfig $INTERFACE $ip_client netmask 255.255.255.0" >> $tinc_dir/$netname/tinc-up
    
    echo "#!/bin/sh" > $tinc_dir/$netname/tinc-down
    echo "ifconfig $INTERFACE down" >> $tinc_dir/$netname/tinc-down
    
    chmod 755 $tinc_dir/$netname/tinc-*
    mkdir -p /usr/local/var/run/
    
    externalnyc_private_IP=$(ss-get $component_server_name:private_ip)
    ss-set hosts_configuration_file "$(cat $tinc_dir/$netname/hosts/$node_name)"
    
    ss-get --timeout=3600 $component_server_name:hosts_configuration_file > $tinc_dir/$netname/hosts/$externalnyc
    sed -i "s|Address = .*|Address = "$externalnyc_private_IP"|" $tinc_dir/$netname/hosts/$externalnyc
    
    echo "# This file contains all names of the networks to be started on system startup." > $tinc_dir/nets.boot
    echo "$netname" >> $tinc_dir/nets.boot
    
    service tinc start
}