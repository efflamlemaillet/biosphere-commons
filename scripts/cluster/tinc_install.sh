source /scripts/toolshed/os_detection.sh

port_tinc=${port_tinc:-443}
IP_subnet=${IP_subnet:-10}

msg_info()
{
    ss-display "test if deployment" 1>/dev/null 2>/dev/null
    ret=$?
    if [ $ret -ne 0 ]; then
        echo -e "$@"
    else
        echo -e "$@"
        ss-display "$@"
    fi
}

configure_firewall(){    
    # Allow Tinc VPN connections
    iptables -A INPUT -p tcp --sport $port_tinc -j ACCEPT
    iptables -A INPUT -p tcp --dport $port_tinc -j ACCEPT
    iptables -A OUTPUT -p tcp --sport $port_tinc -j ACCEPT
    iptables -A OUTPUT -p tcp --dport $port_tinc -j ACCEPT

    iptables -A INPUT -p udp --sport $port_tinc -j ACCEPT
    iptables -A INPUT -p udp --dport $port_tinc -j ACCEPT
    iptables -A OUTPUT -p udp --sport $port_tinc -j ACCEPT
    iptables -A OUTPUT -p udp --dport $port_tinc -j ACCEPT
}

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
    
    tinc_version="1.0.32"
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
    msg_info "Configuring tinc server..."
    
    NB_PROC=$(nproc)
    ss-set cpu.nb "$NB_PROC"

    NB_RAM_GO=$(echo $(($(getconf _PHYS_PAGES) * $(getconf PAGE_SIZE) / (1024 * 1024 * 1000))))
    ss-set ram.GB "$NB_RAM_GO"
    
    configure_firewall
    
    tinc_dir="/usr/local/etc/tinc"
    
    NETWORK_MODE=$(ss-get network)
    if [ "$NETWORK_MODE" == "Public" ]; then
        PUBLIC_IP=$(ss-get hostname)
        #ss-set hostname "${PRIVATE_IP}"
        HOSTIP=$(echo $(hostname -I | sed 's/ /\n/g' | head -n 1))
    else
        ss-abort "You need to deploy the server with a public network!!!"
        #PUBLIC_IP=$(ss-get $IP_PARAMETER)
        #HOSTIP=$(ss-get $IP_PARAMETER)
    fi
    ss-set private_ip "$HOSTIP"
    
    INTERFACE="tun0"
    netname="vpn"
    externalnyc="vpn_server"
    externalnyc_public_IP=$(ss-get hostname)
    second_mask=$(echo $externalnyc_public_IP | cut -d. -f3)
    third_mask=$(echo $externalnyc_public_IP | cut -d. -f4)
    
    mkdir -p $tinc_dir/$netname/hosts
    echo "Name = $externalnyc" > $tinc_dir/$netname/tinc.conf
    echo "AddressFamily = ipv4" >> $tinc_dir/$netname/tinc.conf
    echo "Interface = $INTERFACE" >> $tinc_dir/$netname/tinc.conf
    
    echo "Address = $externalnyc_public_IP" > $tinc_dir/$netname/hosts/$externalnyc
    echo "Subnet = $IP_subnet.$second_mask.$third_mask.1/32" >> $tinc_dir/$netname/hosts/$externalnyc
    echo "Port = $port_tinc" >> $tinc_dir/$netname/hosts/$externalnyc
    
    yes "" | tincd -n $netname -K4096
    
    echo "#!/bin/sh" > $tinc_dir/$netname/tinc-up
    echo "ifconfig $INTERFACE $IP_subnet.$second_mask.$third_mask.1 netmask 255.0.0.0" >> $tinc_dir/$netname/tinc-up
    
    echo "#!/bin/sh" > $tinc_dir/$netname/tinc-down
    echo "ifconfig $INTERFACE down" >> $tinc_dir/$netname/tinc-down
    
    chmod 755 $tinc_dir/$netname/tinc-*
    mkdir -p /usr/local/var/run/
    
    ss-set hosts_configuration_file "$(cat $tinc_dir/$netname/hosts/$externalnyc)"
    
    ss-set vpn.address "$IP_subnet.$second_mask.$third_mask.1"

    server_name=$(ss-get nodename)
    # ss:groups  cyclone-fr2:VPN,cyclone-fr1:client2,cyclone-fr2:client1
#    groups=$(ss-get ss:groups)
#    IFS=','
#    read -ra ADDR <<< "$groups"
#    for c in "${ADDR[@]}"; do
#        IFS=':'
#        read -ra ADDR <<< "$c"
#        client_name=${ADDR[1]}
    j = 0
    for client_name in `ss-get ss:groups | sed 's/, /,/g' | sed 's/,/\n/g' | cut -d':' -f2`; do
        if [ "$client_name" != "$server_name" ]; then
            for i in $(echo "$(ss-get $client_name:ids)" | sed 's/,/\n/g'); do
                j=$[$j+$i+1]
                ss-set $client_name.$i:vpn.address "$IP_subnet.$second_mask.$third_mask.$j"

                node_name=$client_name$i
                ss-get --timeout=3600 $client_name.$i:hosts_configuration_file > $tinc_dir/$netname/hosts/$node_name
            done
            j=$[$j+1]
        fi
    done
    #echo 1 >/proc/sys/net/ipv4/ip_forward
    
    tincd -n $netname -D&
    ss-set vpn.ready "true"
    msg_info "Tinc server is configured."
}

configure_tinc_client(){
    msg_info "Configuring tinc client..."
    
    NB_PROC=$(nproc)
    ss-set cpu.nb "$NB_PROC"
    
    NB_RAM_GO=$(echo $(($(getconf _PHYS_PAGES) * $(getconf PAGE_SIZE) / (1024 * 1024 * 1000))))
    ss-set ram.GB "$NB_RAM_GO"
    
    configure_firewall
    
    tinc_dir="/usr/local/etc/tinc"
    
    server_name=${component_server_name}
    if [ -z "${server_name}" ] ; then
        return
    fi
    
    NETWORK_MODE=$(ss-get network)
    if [ "$NETWORK_MODE" == "Public" ]; then
        PUBLIC_IP=$(ss-get hostname)
        #ss-set hostname "${PRIVATE_IP}"
        HOSTIP=$(echo $(hostname -I | sed 's/ /\n/g' | head -n 1))
    else
        #PUBLIC_IP=$(ss-get $IP_PARAMETER)
        HOSTIP=$(ss-get hostname)
    fi
    ss-set private_ip "$HOSTIP"
    
    INTERFACE="tun0"
    netname="vpn"
    externalnyc="vpn_server"
    ID=$(ss-get id)
    client_name=$(ss-get nodename)
    node_name=$client_name$ID
    
    mkdir -p $tinc_dir/$netname/hosts
    echo "Name = $node_name" > $tinc_dir/$netname/tinc.conf
    echo "AddressFamily = ipv4" >> $tinc_dir/$netname/tinc.conf
    echo "Interface = $INTERFACE" >> $tinc_dir/$netname/tinc.conf
    echo "ConnectTo = $externalnyc" >> $tinc_dir/$netname/tinc.conf
    
    ip_client=$(ss-get --timeout=3600 vpn.address)
    echo "Subnet = $ip_client/32" > $tinc_dir/$netname/hosts/$node_name
    echo "Port = $port_tinc" >> $tinc_dir/$netname/hosts/$node_name
    
    yes "" | tincd -n $netname -K4096
    
    echo "#!/bin/sh" > $tinc_dir/$netname/tinc-up
    echo "ifconfig $INTERFACE $ip_client netmask 255.0.0.0" >> $tinc_dir/$netname/tinc-up
    
    echo "#!/bin/sh" > $tinc_dir/$netname/tinc-down
    echo "ifconfig $INTERFACE down" >> $tinc_dir/$netname/tinc-down
    
    chmod 755 $tinc_dir/$netname/tinc-*
    mkdir -p /usr/local/var/run/
    
    externalnyc_private_IP=$(ss-get $server_name:private_ip)
    ss-set hosts_configuration_file "$(cat $tinc_dir/$netname/hosts/$node_name)"
    
    ss-get --timeout=3600 $server_name:hosts_configuration_file > $tinc_dir/$netname/hosts/$externalnyc
    #sed -i "s|Address = .*|Address = "$externalnyc_private_IP"|" $tinc_dir/$netname/hosts/$externalnyc
    
    echo "# This file contains all names of the networks to be started on system startup." > $tinc_dir/nets.boot
    echo "$netname" >> $tinc_dir/nets.boot
    #echo 1 >/proc/sys/net/ipv4/ip_forward
    
    ss-get --timeout=3600 $server_name:vpn.ready
    tincd -n $netname -D&
    #service tinc start
    
    msg_info "Tinc client is configured."
}

add_tinc_client(){
    tinc_dir="/usr/local/etc/tinc"
    netname="vpn"
    
    msg_info "ADD client to vpn."
    for INSTANCE_NAME in $SLIPSTREAM_SCALING_VMS; do
        INSTANCE_NAME_SAFE=$(echo $INSTANCE_NAME | sed "s/\./-/g")
    
        echo "Processing $INSTANCE_NAME"
        
        externalnyc_public_IP=$(ss-get hostname)
        second_mask=$(echo $externalnyc_public_IP | cut -d. -f3)
        third_mask=$(echo $externalnyc_public_IP | cut -d. -f4)
        
        ID=$(ss-get $INSTANCE_NAME:id)
        j=$[$ID+1]
        ss-set $INSTANCE_NAME:vpn.address "$IP_subnet.$second_mask.$third_mask.$j"
        
        node_name=$(echo $INSTANCE_NAME | sed "s/\.//g")
        ss-get --timeout=3600 $INSTANCE_NAME:hosts_configuration_file > $tinc_dir/$netname/hosts/$node_name
    done
}

rm_tinc_client(){
    tinc_dir="/usr/local/etc/tinc"
    netname="vpn"
    
    msg_info "RM client to vpn."
    for INSTANCE_NAME in $SLIPSTREAM_SCALING_VMS; do
        INSTANCE_NAME_SAFE=$(echo $INSTANCE_NAME | sed "s/\./-/g")
    
        echo "Processing $INSTANCE_NAME"
        
        ID=$(ss-get $INSTANCE_NAME:id)
        
        node_name=$(echo $INSTANCE_NAME | sed "s/\.//g")
        rm $tinc_dir/$netname/hosts/$node_name
    done
}