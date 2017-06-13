source /scripts/toolshed/os_detection.sh

check_if_vpn_or_not()
{
    component_vpn_name=${component_vpn_name:-vpn}
    
    ss-display "test" 1>/dev/null 2>/dev/null
    ret=$?
    if [ $ret -ne 0 ]; then
        export USER_NEW=${USER_NEW:-ifbuser}
        export IP_PARAMETER=${IP_PARAMETER:-hostname}
    else
        check_vpn=$(ss-get ss:groups | grep -c ":$component_vpn_name")
        category=$(ss-get ss:category)
        if [ "$check_vpn" != "0" ]; then            
            if [ "$category" == "Deployment" ]; then
                vpn_multiplicity=$(ss-get $component_vpn_name:multiplicity)
                if [ "$vpn_multiplicity" != "0" ]; then
                    USER_NEW=$(ss-get $component_vpn_name:edugain_username)
                    if [ "$(echo $(ss-get net.services.enable) | grep '"vpn"' | wc -l)" == "1" ]; then
                        IP_PARAMETER=vpn.address
                        ss-set net.services.enable "[\"vpn\"]"
                    else
                        ss-set net.services.enable "[]"
                        IP_PARAMETER=hostname
                    fi
                else
                    USER_NEW=${USER_NEW:-ifbuser}
                    ss-set net.services.enable "[]"
                    IP_PARAMETER=hostname
                fi
            else
                USER_NEW=${USER_NEW:-ifbuser}
                ss-set net.services.enable "[]"
                IP_PARAMETER=hostname
            fi
        else
            USER_NEW=${USER_NEW:-ifbuser}
            IP_PARAMETER=hostname
        fi
    fi
    
    #url.service display when vpn is on
    if [ $IP_PARAMETER == "vpn.address" ]; then
        #MASTER_IP=$(ss-get $MASTER_HOSTNAME:$IP_PARAMETER)
        IP_VPN=$(ss-get $component_vpn_name:hostname)
        url="ssh://$USER_NEW@$IP_VPN"
        #ss-set url.ssh "${url}"
        ss-set url.service "${url}"
        ss-set ss:url.service "${url}"
    fi
    
    WORKDIR=/root/mydisk
    mkdir -p $WORKDIR
    chmod 750 /root
    chmod 775 $WORKDIR
    
    ss-set allowed_components "$(echo $(ss-get allowed_components) | sed 's|ifbuser|'$USER_NEW'|g' )"
}

initiate_install_edugain()
{
    apt-get install -y python python-dev python-pip libpam-python
    pip install scriptine
    wget -O - https://raw.githubusercontent.com/cyclone-project/cyclone-python-pam/master/setup.sh | sed 's/~/\/tmp\//g' | sh
    wget -O /lib/security/cyclone_pam.py https://raw.githubusercontent.com/bryan-brancotte/cyclone-python-pam/patch-5/lib/security/cyclone_pam.py
    echo "{
      \"ports\":[[20000, 25000] ]
    }" > /lib/security/cyclone_config
    cp /etc/pam.d/sshd /etc/pam.d/sshd.bak
    cat /etc/pam.d/sshd.bak | sed 's/ auth /auth /g' | sed 's/auth /#auth /g' | sed 's/##auth /auth /g' > /etc/pam.d/sshd
    service ssh restart
}

initiate_install_edugain_ubuntu16()
{
    apt-get install -y python python-dev python-pip libpam-python
    
    # Clone and install python package dependencies
    cd ~
    mkdir cyclone-pam && cd cyclone-pam
    git clone https://github.com/cyclone-project/cyclone-python-pam.git .
    git checkout ubuntu1604
    pip install -r requirements.pip

    # Install python script and config
    cp usr/local/bin/cyclone_pam.py /usr/local/bin/cyclone_pam.py

sed -ie '/BASE_URI =/i\
global s\
s = socket\.socket(socket\.AF_INET, socket\.SOCK_DGRAM)\
s\.connect(("8\.8\.8\.8", 80))\
' /usr/local/bin/cyclone_pam.py
    sed -ie 's|host_ip = .*|host_ip = s\.getsockname()[0]|' /usr/local/bin/cyclone_pam.py

    mkdir /etc/cyclone
    cp -f etc/cyclone/cyclone.conf /etc/cyclone/cyclone.conf
    cp -f etc/cyclone/key.pem /etc/cyclone/key.pem

    # Update ssh PAM config
    cp -f etc/pam.d/sshd /etc/pam.d/sshd

    # Update sshd configuration and restart service
    cp -f etc/ssh/sshd_config /etc/ssh/sshd_config
    service ssh restart

    # Load default ports
    echo "{
      \"ports\":[[20000, 25000] ]
    }" > /etc/cyclone/cyclone.conf

    ## INSTALL SCRIPTS
    if [ ! -e /scripts/ ]; then
        git clone https://github.com/cyclone-project/usecases-hackathon-2016/ /tmp/usecases-hackathon-2016
        #ln -s /tmp/usecases-hackathon-2016/scripts /scripts
        cp -rf /tmp/usecases-hackathon-2016/scripts /scripts
        chmod a+rx -R /scripts/
        pip install -r /scripts/requirements.txt
    fi

    ## INSTALL XPRA
    # Install xPra latest version from WinSwitch repo
    #curl http://winswitch.org/gpg.asc | apt-key add -
    #echo "deb http://winswitch.org/ xenial main" > /etc/apt/sources.list.d/winswitch.list
    #apt-get install -y software-properties-common
    #add-apt-repository universe
    #apt-get update
    #apt-get install -y xpra
    # Install xFce
    #apt-get install -y xfce4

    # Start xPra at start and execute it now (need to update to use random local internal port!)
    #cp -f etc/rc.local /etc/rc.local
    #chmod +x /etc/rc.local
    
    # Clean up installation files
    cd ~ && rm -rf cyclone-pam    
}

install_edugain()
{
    source /scripts/edugain_access_tool_shed.sh --dry-run
    source /scripts/allows_other_to_access_me.sh --dry-run
    #auto_gen_users
    gen_key_for_user $USER_NEW
    init_edugain_acces_to_user $USER_NEW
    add_email_for_edugain_acces_to_user $(echo_owner_email) $USER_NEW
    #publish_pubkey
    #allow_others
    #source /scripts/populate_hosts_with_components_name_and_ips.sh --dry-run
    #populate_hosts_with_components_name_and_ips $IP_PARAMETER
    
    service ssh restart
    #echo $(hostname -I | sed 's/ /\n/g' | head -n 1) > /etc/hostname 
    
    #hostname -F /etc/hostname
    
    url="ssh://$USER_NEW@$(ss-get hostname)"
    ss-set url.ssh "${url}"
    ss-set url.service "${url}"
    ss-set ss:url.service "${url}"
    
    echo "FederatedEntryPoint overlay deploy done"
}

msg_info()
{
    ss-display "test" 1>/dev/null 2>/dev/null
    ret=$?
    if [ $ret -ne 0 ]; then
        echo -e "$@"
    else
        echo -e "$@"
        ss-display "$@"
    fi
}

user_add()
{
    getent passwd $1 > /dev/null
    user_missing=$?
    if [ "$user_missing" != "0" ]; then
        useradd --create-home -u 666 $USER_NEW --shell /bin/bash
    else
        usermod -u 666 $USER_NEW
    fi
    ln -s /root/mydisk/ /home/$USER_NEW/work
    usermod -aG root $USER_NEW
    
    msg_info ""
    msg_info "$USER_NEW created for launch job"
}

user_sudoers(){
	if grep -q $USER_NEW "/etc/sudoers"; then 
		echo "$USER_NEW ready"
	else 
		echo -e "$USER_NEW\tALL=(ALL)\tNOPASSWD:ALL" >> /etc/sudoers
	fi
}

selinux_config(){
    setenforce 1
    setsebool -P use_nfs_home_dirs=true
}

check_ip()
{
    NETWORK_MODE=$(ss-get network)
    if [ "$NETWORK_MODE" == "Public" ]; then
        PUBLIC_IP=$(ss-get $IP_PARAMETER)
        #ss-set hostname "${PRIVATE_IP}"
        HOSTIP=$(echo $(hostname -I | sed 's/ /\n/g' | head -n 1))
        SLAVE_IP=$HOSTIP
        sed -i "s|$PUBLIC_IP|$HOSTIP|g" /etc/hosts
    else
        PUBLIC_IP=$(ss-get $IP_PARAMETER)
        HOSTIP=$(ss-get $IP_PARAMETER)
        SLAVE_IP=$HOSTIP
    fi
    ss-set ip.ready "$HOSTIP"
}

check_ip_slave_for_master()
{
    url="ssh://$USER_NEW@$PUBLIC_IP"
    #ss-set url.ssh "${url}"
    ss-set url.service "${url}"
    ss-set ss:url.service "${url}"
    
    for (( i=1; i <= $(ss-get $SLAVE_NAME:multiplicity); i++ )); do
        ss-get --timeout=3600 $SLAVE_NAME.$i:ip.ready
        #url=$(ss-get $SLAVE_NAME.$i:url.ssh)
        #PUBLIC_SLAVE_IP=$(echo $url | cut -d "@" -f2)
        PUBLIC_SLAVE_IP=$(ss-get $SLAVE_NAME.$i:$IP_PARAMETER)
        SLAVE_IP=$(ss-get $SLAVE_NAME.$i:ip.ready)
        sed -i "s|$PUBLIC_SLAVE_IP|$SLAVE_IP|g" /etc/hosts
    done
}

check_ip_master_for_slave()
{
    ss-get --timeout=3600 $MASTER_HOSTNAME:ip.ready
    url=$(ss-get $MASTER_HOSTNAME:url.service)
    #PUBLIC_IP_MASTER=$(echo $url | cut -d "@" -f2)
    PUBLIC_IP_MASTER=$(ss-get $MASTER_HOSTNAME:$IP_PARAMETER)
    MASTER_IP=$(ss-get $MASTER_HOSTNAME:ip.ready)
    sed -i "s|$PUBLIC_IP_MASTER|$MASTER_IP|g" /etc/hosts
    ss-set url.service "${url}"
    ss-set ss:url.service "${url}"    
}

#####
# NFS
#####

NFS_start()
{
	msg_info "Starting NFS..."
    if iscentos 7; then
        systemctl enable nfs-server
        systemctl start nfs-server
        systemctl reload nfs-server
    elif iscentos 6; then
        chkconfig nfs on 
	    service nfs start
        service nfs reload
    fi
    if isubuntu; then
	    service nfs-kernel-server start
        service nfs-kernel-server reload
    fi
    exportfs -av
    ss-set nfs.ready "true"
    msg_info "NFS is started."
}

NFS_ready(){
    ss-get --timeout=3600 $MASTER_HOSTNAME:nfs.ready
    nfs_ready=$(ss-get $MASTER_HOSTNAME:nfs.ready)
    msg_info "Waiting NFS to be ready."
	while [ "$nfs_ready" == "false" ]
	do
		sleep 10;
		nfs_ready=$(ss-get $MASTER_HOSTNAME:nfs.ready)
	done
}

# exporting NFS share from master
NFS_export()
{
    # Pas de paramètre 
    if [[ $# -lt 1 ]]; then
        echo "This function expects a directory in argument !"
    else    
        EXPORT_DIR=$1

        if [ ! -d "$EXPORT_DIR" ]; then
            msg_info "$EXPORT_DIR doesn't exist !"
        else    
            msg_info "Exporting NFS share of $EXPORT_DIR..."
	
            EXPORTS_FILE=/etc/exports
            if grep -q $EXPORT_DIR $EXPORTS_FILE; then 
        		echo "$EXPORT_DIR ready"
        	else 
                echo -ne "$EXPORT_DIR\t" >> $EXPORTS_FILE
            fi
            for (( i=1; i <= $(ss-get $SLAVE_NAME:multiplicity); i++ )); do
                if [ $IP_PARAMETER == "hostname" ]; then
                    node_host=$(ss-get $SLAVE_NAME.$i:ip.ready)
                else
                    node_host=$(ss-get $SLAVE_NAME.$i:$IP_PARAMETER)
                fi
                if grep -q $EXPORT_DIR.*$node_host $EXPORTS_FILE; then 
        		    echo "$node_host ready"
        	    else
                    echo -ne "$node_host(rw,sync,no_subtree_check,no_root_squash) " >> $EXPORTS_FILE
                fi
            done
            echo "" >> $EXPORTS_FILE # last for a newline
	
        	msg_info "$EXPORT_DIR is exported."
        fi
    fi
}

# Mounting directory
NFS_mount()
{
    # Pas de paramètre 
    if [[ $# -lt 1 ]]; then
        echo "This function expects a directory in argument !"
    else    
        MOUNT_DIR=$1
    
        if [ ! -d "$MOUNT_DIR" ]; then
            msg_info "$MOUNT_DIR doesn't exist !"
        else    
            msg_info "Mounting $MOUNT_DIR..."
    
            umount $MOUNT_DIR
            mount $MASTER_IP:$MOUNT_DIR $MOUNT_DIR 2>/tmp/mount_error_message.txt
            ret=$?
            msg_info "$(/tmp/mount_error_message.txt)"
     
            if [ $ret -ne 0 ]; then
                ss-abort "$(cat /tmp/mount_error_message.txt)"
            else
                 msg_info "$MOUNT_DIR is mounted"
            fi
        fi
    fi
}

## ADD SLAVES
UNSET_parameters(){
    ss-set nfs.ready "false"
    ss-set sge.ready "false"
}

NFS_export_add()
{
    # Pas de paramètre 
    if [[ $# -lt 1 ]]; then
        echo "This function expects a directory in argument !"
    else    
        EXPORT_DIR=$1

        if [ ! -d "$EXPORT_DIR" ]; then
            msg_info "$EXPORT_DIR doesn't exist !"
        else    
            msg_info "Exporting NFS share of $EXPORT_DIR..."
	
            EXPORTS_FILE=/etc/exports
            if grep -q $EXPORT_DIR $EXPORTS_FILE; then 
        		echo "$EXPORT_DIR ready"
        	else 
                echo -ne "$EXPORT_DIR\t" >> $EXPORTS_FILE
                echo -ne "$SLAVE_IP(rw,sync,no_subtree_check,no_root_squash) " >> $EXPORTS_FILE
                echo "" >> $EXPORTS_FILE # last for a newline
            fi
            if grep -q $EXPORT_DIR.*$SLAVE_IP $EXPORTS_FILE; then 
        	    echo "$SLAVE_IP ready"
            else
                WD=$(echo $EXPORT_DIR | sed 's|\/|\\\/|g')
                sed -ie '/'$WD'/s/$/\t'$SLAVE_IP'(rw,sync,no_subtree_check,no_root_squash)/' $EXPORTS_FILE
            fi
	
        	msg_info "$EXPORT_DIR is exported."
        fi
    fi
}