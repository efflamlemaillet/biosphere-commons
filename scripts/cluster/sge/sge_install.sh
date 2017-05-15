source /scripts/toolshed/os_detection.sh

check_if_vpn_or_not()
{
    component_vpn_name=${component_vpn_name:-vpn}
    
    ss-display "test" 1>/dev/null 2>/dev/null
    ret=$?
    if [ $ret -ne 0 ]; then
        export USER_NEW=${USER_NEW:-sge-user}
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
                    USER_NEW=${USER_NEW:-sge-user}
                    ss-set net.services.enable "[]"
                    IP_PARAMETER=hostname
                fi
            else
                USER_NEW=${USER_NEW:-sge-user}
                ss-set net.services.enable "[]"
                IP_PARAMETER=hostname
            fi
        else
            USER_NEW=${USER_NEW:-sge-user}
            IP_PARAMETER=hostname
        fi
    fi
}

initiate_install_edugain()
{
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

initiate_variable_global()
{
    check_if_vpn_or_not
    
    WORKDIR=/root/mydisk
    HOMEDIR=/home/$USER_NEW
    SGE_ROOT_DIR=/tmp/sge
    ID=1    
    
    if [ $IP_PARAMETER == "vpn.address" ]; then
        #MASTER_IP=$(ss-get $MASTER_HOSTNAME:$IP_PARAMETER)
        IP_VPN=$(ss-get $component_vpn_name:hostname)
        url="ssh://$USER_NEW@$IP_VPN"
        #ss-set url.ssh "${url}"
        ss-set url.service "${url}"
        ss-set ss:url.service "${url}"
    fi
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

create_workdir()
{
    WORKDIR=/root/mydisk
    mkdir -p $WORKDIR
    chmod 750 /root
    chmod 775 $WORKDIR
    
    if iscentos; then
        SGEDIR=/opt/sge
        mkdir -p $SGEDIR
        chmod 775 $SGEDIR
    fi
}

make_file_test()
{
    WORKDIR=/root/mydisk
    mkdir -p $WORKDIR
    chmod 750 /root
    chmod 775 $WORKDIR
    echo "for i in {1..50}" > $WORKDIR/qsub_test.sh
    echo "    do" >> $WORKDIR/qsub_test.sh
    echo "        len=\$(shuf -i 1-10 -n 1)" >> $WORKDIR/qsub_test.sh
    echo "        echo \"sleep \$len\" > /tmp/sleep\$i-\$len.sh" >> $WORKDIR/qsub_test.sh
    echo "    qsub /tmp/sleep\$i-\$len.sh" >> $WORKDIR/qsub_test.sh
    echo "done" >> $WORKDIR/qsub_test.sh
    echo "echo \"run 'watch -n 1 qstat -f' to monitor the computation\"" >> $WORKDIR/qsub_test.sh
    chmod 755 $WORKDIR/qsub_test.sh
}

initiate_master()
{
    initiate_variable_global
    
    mkdir -p $SGE_ROOT_DIR
    
    HOSTIP=$(ss-get $IP_PARAMETER)

    if [ "$category" == "Deployment" ]; then
        HOSTNAME=$(ss-get nodename)-$ID
        SLAVE_NAME=$(ss-get slave.nodename)
        #echo $HOSTIP $HOSTNAME |  tee -a /etc/hosts
    else
        HOSTNAME=machine-$ID
    fi
    if [ $IP_PARAMETER == "hostname" ]; then
        ssh_root=/root/.ssh
        ssh_user=/home/$USER_NEW/.ssh
        if [ ! -f $ssh_user/authorized_keys ]; then
            mkdir -p $ssh_user
            touch $ssh_user/authorized_keys
            chmod 700 $ssh_user
            chmod 600 $ssh_user/authorized_keys
            chown $USER_NEW:$USER_NEW $ssh_user/authorized_keys
        fi
        cat $ssh_root/authorized_keys >> $ssh_user/authorized_keys
    fi
        
    echo "$HOSTNAME" > /etc/hostname
    hostname $HOSTNAME
    
    if isubuntu; then
        if grep -q "myhostname = ." "/etc/postfix/main.cf"; then
            sed -i "s|myhostname = .*|myhostname = $HOSTNAME|" /etc/postfix/main.cf
            /etc/init.d/postfix reload
        fi
    fi    
}

initiate_slave()
{
    initiate_variable_global
    
    if [ "$category" != "Deployment" ]; then
        ss-abort "You need to deploy with a master!!!"
    fi
    
    SLAVE_HOSTNAME=$(ss-get nodename).$(ss-get id)
    SLAVE_HOSTNAME_SAFE=$(ss-get nodename)-$(ss-get id)

    SLAVE_IP=$(ss-get $SLAVE_HOSTNAME:$IP_PARAMETER)

    MASTER_HOSTNAME=$(ss-get master.nodename)
    MASTER_HOSTNAME_SAFE=$MASTER_HOSTNAME-$ID

    MASTER_IP=$(ss-get $MASTER_HOSTNAME:$IP_PARAMETER)
    
    hostname $SLAVE_HOSTNAME_SAFE
    
    if isubuntu; then
        if grep -q "myhostname = ." "/etc/postfix/main.cf"; then
            sed -i "s|myhostname = .*|myhostname = $SLAVE_HOSTNAME_SAFE|" /etc/postfix/main.cf
            /etc/init.d/postfix reload
        fi
    fi
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

message_at_boot_master()
{
    echo "" > /etc/motd
    echo "$USER_NEW created for launch job" >> /etc/motd
    echo "" >> /etc/motd
    echo "qhost : show the status of Sun Grid  Engine  hosts,  queues,
     jobs" >> /etc/motd
    echo "qstat -f : show the status of Sun Grid Engine jobs and queues" >> /etc/motd
    echo "" >> /etc/motd
}

message_at_boot_slave()
{
    echo "" > /etc/motd
    echo "$USER_NEW created for launch job" >> /etc/motd
    echo "" >> /etc/motd
}

#####
# NFS
#####
# exporting NFS share from master
NFS_export_pdisk()
{
    msg_info "Exporting NFS share of $WORKDIR..."
	
    EXPORTS_FILE=/etc/exports
    if grep -q $WORKDIR $EXPORTS_FILE; then 
		echo "$WORKDIR ready"
	else 
        echo -ne "$WORKDIR\t" >> $EXPORTS_FILE
    fi
    for (( i=1; i <= $(ss-get $SLAVE_NAME:multiplicity); i++ )); do
        if [ $IP_PARAMETER == "hostname" ]; then
            node_host=$(ss-get $SLAVE_NAME.$i:ip.ready)
        else
            node_host=$(ss-get $SLAVE_NAME.$i:$IP_PARAMETER)
        fi
        if grep -q $WORKDIR.*$node_host $EXPORTS_FILE; then 
		    echo "$node_host ready"
	    else
            echo -ne "$node_host(rw,sync,no_subtree_check,no_root_squash) " >> $EXPORTS_FILE
        fi
    done
    echo "" >> $EXPORTS_FILE # last for a newline
	
	msg_info "$WORKDIR is exported."
}

# exporting NFS share from master
NFS_export_home()
{
    msg_info "Exporting NFS share of $HOMEDIR..."
    
    EXPORTS_FILE=/etc/exports
    if grep -q $HOMEDIR $EXPORTS_FILE; then 
		echo "$HOMEDIR ready"
	else
        echo -ne "$HOMEDIR\t" >> $EXPORTS_FILE
    fi
    for (( i=1; i <= $(ss-get $SLAVE_NAME:multiplicity); i++ )); do
        if [ $IP_PARAMETER == "hostname" ]; then
            node_host=$(ss-get $SLAVE_NAME.$i:ip.ready)
        else
            node_host=$(ss-get $SLAVE_NAME.$i:$IP_PARAMETER)
        fi
        if grep -q $HOMEDIR.*$node_host $EXPORTS_FILE; then 
		    echo "$node_host ready"
	    else
            echo -ne "$node_host(rw,sync,no_subtree_check,no_root_squash) " >> $EXPORTS_FILE
        fi
    done
    echo "" >> $EXPORTS_FILE # last for a newline
	
	msg_info "$HOMEDIR is exported."
}

NFS_export_sge()
{
    msg_info "Exporting NFS share of $HOMEDIR..."
    
    EXPORTS_FILE=/etc/exports
    if grep -q /opt/sge $EXPORTS_FILE; then 
		echo "/opt/sge ready"
	else
        echo -ne "/opt/sge\t" >> $EXPORTS_FILE
    fi
    for (( i=1; i <= $(ss-get $SLAVE_NAME:multiplicity); i++ )); do
        if [ $IP_PARAMETER == "hostname" ]; then
            node_host=$(ss-get $SLAVE_NAME.$i:ip.ready)
        else
            node_host=$(ss-get $SLAVE_NAME.$i:$IP_PARAMETER)
        fi
        if grep -q /opt/sge.*$node_host $EXPORTS_FILE; then 
		    echo "$node_host ready"
	    else
            echo -ne "$node_host(rw,sync,no_subtree_check,no_root_squash) " >> $EXPORTS_FILE
        fi
    done
    echo "" >> $EXPORTS_FILE # last for a newline
	
	msg_info "/opt/sge is exported."
}

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

# Mounting pdisk directory
NFS_mount_pdisk()
{
    msg_info "Mounting $WORKDIR..."
    umount $WORKDIR
    mount $MASTER_IP:$WORKDIR $WORKDIR 2>/tmp/mount_error_message.txt
    ret=$?
    msg_info "$(/tmp/mount_error_message.txt)"
     
    if [ $ret -ne 0 ]; then
        ss-abort "$(cat /tmp/mount_error_message.txt)"
    else
         msg_info "$WORKDIR is mounted"
    fi
}

# Mounting NFS share on nodes
NFS_mount_home()
{
    msg_info "Mounting $HOMEDIR..."
    umount $HOMEDIR
    mount $MASTER_IP:$HOMEDIR $HOMEDIR 2>>/tmp/mount_error_message.txt
    ret=$?
    msg_info "$(/tmp/mount_error_message.txt)"
     
    if [ $ret -ne 0 ]; then
        ss-abort "$(cat /tmp/mount_error_message.txt)"
    else
         msg_info "$HOMEDIR is mounted"
    fi
}

NFS_mount_sge()
{
    msg_info "Mounting /opt/sge..."
    umount /opt/sge
    mount $MASTER_IP:/opt/sge /opt/sge 2>>/tmp/mount_error_message.txt
    ret=$?
    msg_info "$(/tmp/mount_error_message.txt)"
     
    if [ $ret -ne 0 ]; then
        ss-abort "$(cat /tmp/mount_error_message.txt)"
    else
         msg_info "/opt/sge is mounted"
    fi
}

#####
# Install SGE
#####

check_if_sge_is_ready_on_master(){
    ss-get --timeout=3600 $MASTER_HOSTNAME:sge.ready
    sge_ready=$(ss-get $MASTER_HOSTNAME:sge.ready)
    msg_info "Waiting SGE to be ready."
	while [ "$sge_ready" == "false" ]
	do
		sleep 10;
		sge_ready=$(ss-get $MASTER_HOSTNAME:sge.ready)
	done
}

Install_SGE_master()
{
    msg_info "Installing SGE..."
    
    if iscentos; then
        sge_version="8.1.9"
        yum install -y http://arc.liv.ac.uk/downloads/SGE/releases/$sge_version/gridengine-$sge_version-1.el6.x86_64.rpm
        yum install -y http://arc.liv.ac.uk/downloads/SGE/releases/$sge_version/gridengine-qmaster-$sge_version-1.el6.x86_64.rpm
        yum install -y http://arc.liv.ac.uk/downloads/SGE/releases/$sge_version/gridengine-qmon-$sge_version-1.el6.x86_64.rpm
        yum install -y http://arc.liv.ac.uk/downloads/SGE/releases/$sge_version/gridengine-guiinst-$sge_version-1.el6.noarch.rpm
        yum install -y http://arc.liv.ac.uk/downloads/SGE/releases/$sge_version/gridengine-execd-$sge_version-1.el6.x86_64.rpm
        #yum install -y http://arc.liv.ac.uk/downloads/SGE/releases/$sge_version/gridengine-debuginfo-$sge_version-1.el6.x86_64.rpm
        
        #wget -O /opt/sge/util/install_modules/inst_ifb.conf https://github.com/cyclone-project/usecases-hackathon-2016/raw/master/scripts/cluster/sge/inst_ifb.conf
        
    	cd /opt/sge
    	./inst_sge -m -auto util/install_modules/inst_template.conf
    	. /opt/sge/default/common/settings.sh
        wget -O /etc/profile.d/sge_lib.sh https://github.com/cyclone-project/usecases-hackathon-2016/raw/master/scripts/cluster/sge/sge_lib.sh
        msg_info "SGE is installed."
        message_at_boot_master        
    elif isubuntu; then
        # Configure the master hostname for Grid Engine
        echo "gridengine-master       shared/gridenginemaster string  $HOSTNAME" |  debconf-set-selections
        echo "gridengine-master       shared/gridenginecell   string  default" |  debconf-set-selections
        echo "gridengine-master       shared/gridengineconfig boolean false" |  debconf-set-selections
        echo "gridengine-common       shared/gridenginemaster string  $HOSTNAME" |  debconf-set-selections
        echo "gridengine-common       shared/gridenginecell   string  default" |  debconf-set-selections
        echo "gridengine-common       shared/gridengineconfig boolean false" |  debconf-set-selections
        echo "gridengine-client       shared/gridenginemaster string  $HOSTNAME" |  debconf-set-selections
        echo "gridengine-client       shared/gridenginecell   string  default" |  debconf-set-selections
        echo "gridengine-client       shared/gridengineconfig boolean false" |  debconf-set-selections
        # Postfix mail server is also installed as a dependency
        echo "postfix postfix/main_mailer_type        select  No configuration" |  debconf-set-selections
    
        # Install Grid Engine
        DEBIAN_FRONTEND=noninteractive apt-get install -y gridengine-master gridengine-client
    
        # Set up Grid Engine
        su - sgeadmin -s/bin/bash -c '/usr/share/gridengine/scripts/init_cluster /var/lib/gridengine default /var/spool/gridengine/spooldb sgeadmin'

        service gridengine-master restart 2> /opt/sge_error_message.log
        ret=$?
        if [ $ret -ne 0 ]; then
        	msg_info ""
        	msg_info "Install SGE aborted."
            msg_info ""
            ss-abort "$(cat /opt/sge_error_message.log)"
        fi
    
        # Disable Postfix
        service postfix stop
        update-rc.d postfix disable
    
        msg_info "SGE is installed."
        message_at_boot_master
        
    else
        echo "Unsupported osfamily"
    fi
    
}

Install_SGE_slave()
{
    msg_info "Installing and Configuring SGE..."
    
    if iscentos; then
        sge_version="8.1.9"
        yum install -y http://arc.liv.ac.uk/downloads/SGE/releases/$sge_version/gridengine-$sge_version-1.el6.x86_64.rpm
        cd /opt/sge
        . /opt/sge/default/common/settings.sh        
        ./inst_sge -x -auto util/install_modules/inst_template.conf
        wget -O /etc/profile.d/sge_lib.sh https://github.com/cyclone-project/usecases-hackathon-2016/raw/master/scripts/cluster/sge/sge_lib.sh
    elif isubuntu; then   
        echo "gridengine-common       shared/gridenginemaster string  $MASTER_HOSTNAME_SAFE" |  debconf-set-selections
        echo "gridengine-common       shared/gridenginecell   string  default" |  debconf-set-selections
        echo "gridengine-common       shared/gridengineconfig boolean false" |  debconf-set-selections
        echo "gridengine-client       shared/gridenginemaster string  $MASTER_HOSTNAME_SAFE" |  debconf-set-selections
        echo "gridengine-client       shared/gridenginecell   string  default" |  debconf-set-selections
        echo "gridengine-client       shared/gridengineconfig boolean false" |  debconf-set-selections
        echo "postfix postfix/main_mailer_type        select  No configuration" |  debconf-set-selections
    
        DEBIAN_FRONTEND=noninteractive apt-get install -y gridengine-exec gridengine-client
    
        service postfix stop
        update-rc.d postfix disable
    
        echo $MASTER_HOSTNAME_SAFE |  tee /var/lib/gridengine/default/common/act_qmaster
        service gridengine-exec restart 2> /opt/sge_error_message.log
        ret=$?
        if [ $ret -ne 0 ]; then
        	msg_info ""
        	msg_info "Install SGE aborted."
            msg_info ""
            ss-abort "$(cat /opt/sge_error_message.log)"
        fi
    
        msg_info "SGE is installed and configured."
        message_at_boot_slave
    else
        echo "Unsupported osfamily"
    fi
}

Install_EXEC()
{
    QUEUE=all.q
    SLOTS='nproc'
    
    # add to the execution host list
    TMPFILE=/tmp/sge.hostname-$HOSTNAME
    echo -e "hostname $HOSTNAME\nload_scaling NONE\ncomplex_values NONE\nuser_lists NONE\nxuser_lists NONE\nprojects NONE\nxprojects NONE\nusage_scaling NONE\nreport_variables NONE" > $TMPFILE
    qconf -Ae $TMPFILE
    rm $TMPFILE
    
    # add to the all hosts list
    qconf -aattr hostgroup hostlist $HOSTNAME @allhosts
    
    # enable the host for the queue, in case it was disabled and not removed
    qmod -e $QUEUE@$HOSTNAME
    
    if [ "$SLOTS" ]; then
        qconf -aattr queue slots "[$HOSTNAME=$SLOTS]" $QUEUE
    fi
    
    if iscentos; then
        cd /opt/sge
        . /opt/sge/default/common/settings.sh        
        ./inst_sge -x -auto util/install_modules/inst_template.conf
    elif isubuntu; then
        echo "gridengine-common       shared/gridenginemaster string  $HOSTNAME" |  debconf-set-selections
        echo "gridengine-common       shared/gridenginecell   string  default" |  debconf-set-selections
        echo "gridengine-common       shared/gridengineconfig boolean false" |  debconf-set-selections
        echo "gridengine-client       shared/gridenginemaster string  $HOSTNAME" |  debconf-set-selections
        echo "gridengine-client       shared/gridenginecell   string  default" |  debconf-set-selections
        echo "gridengine-client       shared/gridengineconfig boolean false" |  debconf-set-selections
        echo "postfix postfix/main_mailer_type        select  No configuration" |  debconf-set-selections
    
        DEBIAN_FRONTEND=noninteractive apt-get install -y gridengine-exec gridengine-client
    
        service postfix stop
        update-rc.d postfix disable
    
        echo $HOSTNAME |  tee /var/lib/gridengine/default/common/act_qmaster
        service gridengine-exec restart 2> /opt/sge_error_message.log
        ret=$?
        if [ $ret -ne 0 ]; then
        	msg_info ""
        	msg_info "Install SGE aborted."
            msg_info ""
            ss-abort "$(cat /opt/sge_error_message.log)"
        fi
    else
        echo "Unsupported osfamily"
    fi
}
 
Config_SGE_master()
{   
    msg_info "Configuring SGE..."
    
    qconf -am $USER_NEW
	qconf -ao $USER_NEW
	
    # change scheduler config
    
    echo "algorithm                         default"  > $SGE_ROOT_DIR/grid
    echo "schedule_interval                 0:0:1" >> $SGE_ROOT_DIR/grid
    echo "maxujobs                          0" >> $SGE_ROOT_DIR/grid
    echo "queue_sort_method                 load" >> $SGE_ROOT_DIR/grid
    echo "job_load_adjustments              np_load_avg=0.50" >> $SGE_ROOT_DIR/grid
    echo "load_adjustment_decay_time        0:7:30" >> $SGE_ROOT_DIR/grid
    echo "load_formula                      np_load_avg" >> $SGE_ROOT_DIR/grid
    echo "schedd_job_info                   true" >> $SGE_ROOT_DIR/grid
    echo "flush_submit_sec                  0" >> $SGE_ROOT_DIR/grid
    echo "flush_finish_sec                  0" >> $SGE_ROOT_DIR/grid
    echo "params                            none" >> $SGE_ROOT_DIR/grid
    echo "reprioritize_interval             0:0:0" >> $SGE_ROOT_DIR/grid
    echo "halftime                          168" >> $SGE_ROOT_DIR/grid
    echo "usage_weight_list                 cpu=1.000000,mem=0.000000,io=0.000000" >> $SGE_ROOT_DIR/grid
    echo "compensation_factor               5.000000" >> $SGE_ROOT_DIR/grid
    echo "weight_user                       0.250000" >> $SGE_ROOT_DIR/grid
    echo "weight_project                    0.250000" >> $SGE_ROOT_DIR/grid
    echo "weight_department                 0.250000" >> $SGE_ROOT_DIR/grid
    echo "weight_job                        0.250000" >> $SGE_ROOT_DIR/grid
    echo "weight_tickets_functional         0" >> $SGE_ROOT_DIR/grid
    echo "weight_tickets_share              0" >> $SGE_ROOT_DIR/grid
    echo "share_override_tickets            TRUE" >> $SGE_ROOT_DIR/grid
    echo "share_functional_shares           TRUE" >> $SGE_ROOT_DIR/grid
    echo "max_functional_jobs_to_schedule   200" >> $SGE_ROOT_DIR/grid
    echo "report_pjob_tickets               TRUE" >> $SGE_ROOT_DIR/grid
    echo "max_pending_tasks_per_job         50" >> $SGE_ROOT_DIR/grid
    echo "halflife_decay_list               none" >> $SGE_ROOT_DIR/grid
    echo "policy_hierarchy                  OFS" >> $SGE_ROOT_DIR/grid
    echo "weight_ticket                     0.500000" >> $SGE_ROOT_DIR/grid
    echo "weight_waiting_time               0.278000" >> $SGE_ROOT_DIR/grid
    echo "weight_deadline                   3600000.000000" >> $SGE_ROOT_DIR/grid
    echo "weight_urgency                    0.500000" >> $SGE_ROOT_DIR/grid
    echo "weight_priority                   0.000000" >> $SGE_ROOT_DIR/grid
    echo "max_reservation                   0" >> $SGE_ROOT_DIR/grid
    echo "default_duration                  INFINITY" >> $SGE_ROOT_DIR/grid
    qconf -Msconf $SGE_ROOT_DIR/grid
    rm $SGE_ROOT_DIR/grid
    
    wget -O $SGE_ROOT_DIR/complex.conf https://github.com/cyclone-project/usecases-hackathon-2016/raw/master/scripts/cluster/sge/complex.conf
	qconf -Mc $SGE_ROOT_DIR/complex.conf
    
    # create a host list
    echo -e "group_name @allhosts\nhostlist NONE" > $SGE_ROOT_DIR/grid
    qconf -Ahgrp $SGE_ROOT_DIR/grid
    rm $SGE_ROOT_DIR/grid
    
    # create a queue
    echo "qname                 all.q" > $SGE_ROOT_DIR/grid
    echo "hostlist              @allhosts" >> $SGE_ROOT_DIR/grid
    echo "seq_no                0" >> $SGE_ROOT_DIR/grid
    echo "load_thresholds       NONE" >> $SGE_ROOT_DIR/grid
    echo "suspend_thresholds    NONE" >> $SGE_ROOT_DIR/grid
    echo "nsuspend              1" >> $SGE_ROOT_DIR/grid
    echo "suspend_interval      00:00:01" >> $SGE_ROOT_DIR/grid
    echo "priority              0" >> $SGE_ROOT_DIR/grid
    echo "min_cpu_interval      00:00:01" >> $SGE_ROOT_DIR/grid
    echo "processors            UNDEFINED" >> $SGE_ROOT_DIR/grid
    echo "qtype                 BATCH INTERACTIVE" >> $SGE_ROOT_DIR/grid
    echo "ckpt_list             NONE" >> $SGE_ROOT_DIR/grid
    echo "pe_list               make" >> $SGE_ROOT_DIR/grid
    echo "rerun                 FALSE" >> $SGE_ROOT_DIR/grid
    echo "slots                 2" >> $SGE_ROOT_DIR/grid
    echo "tmpdir                /tmp" >> $SGE_ROOT_DIR/grid
    echo "shell                 /bin/csh" >> $SGE_ROOT_DIR/grid
    echo "prolog                NONE" >> $SGE_ROOT_DIR/grid
    echo "epilog                NONE" >> $SGE_ROOT_DIR/grid
    echo "shell_start_mode      posix_compliant" >> $SGE_ROOT_DIR/grid
    echo "starter_method        NONE" >> $SGE_ROOT_DIR/grid
    echo "suspend_method        NONE" >> $SGE_ROOT_DIR/grid
    echo "resume_method         NONE" >> $SGE_ROOT_DIR/grid
    echo "terminate_method      NONE" >> $SGE_ROOT_DIR/grid
    echo "notify                00:00:01" >> $SGE_ROOT_DIR/grid
    echo "owner_list            NONE" >> $SGE_ROOT_DIR/grid
    echo "user_lists            NONE" >> $SGE_ROOT_DIR/grid
    echo "xuser_lists           NONE" >> $SGE_ROOT_DIR/grid
    echo "subordinate_list      NONE" >> $SGE_ROOT_DIR/grid
    echo "complex_values        NONE" >> $SGE_ROOT_DIR/grid
    echo "projects              NONE" >> $SGE_ROOT_DIR/grid
    echo "xprojects             NONE" >> $SGE_ROOT_DIR/grid
    echo "calendar              NONE" >> $SGE_ROOT_DIR/grid
    echo "initial_state         default" >> $SGE_ROOT_DIR/grid
    echo "s_rt                  INFINITY" >> $SGE_ROOT_DIR/grid
    echo "h_rt                  INFINITY" >> $SGE_ROOT_DIR/grid
    echo "s_cpu                 INFINITY" >> $SGE_ROOT_DIR/grid
    echo "h_cpu                 INFINITY" >> $SGE_ROOT_DIR/grid
    echo "s_fsize               INFINITY" >> $SGE_ROOT_DIR/grid
    echo "h_fsize               INFINITY" >> $SGE_ROOT_DIR/grid
    echo "s_data                INFINITY" >> $SGE_ROOT_DIR/grid
    echo "h_data                INFINITY" >> $SGE_ROOT_DIR/grid
    echo "s_stack               INFINITY" >> $SGE_ROOT_DIR/grid
    echo "h_stack               INFINITY" >> $SGE_ROOT_DIR/grid
    echo "s_core                INFINITY" >> $SGE_ROOT_DIR/grid
    echo "h_core                INFINITY" >> $SGE_ROOT_DIR/grid
    echo "s_rss                 INFINITY" >> $SGE_ROOT_DIR/grid
    echo "h_rss                 INFINITY" >> $SGE_ROOT_DIR/grid
    echo "s_vmem                INFINITY" >> $SGE_ROOT_DIR/grid
    echo "h_vmem                INFINITY" >> $SGE_ROOT_DIR/grid
    qconf -Aq $SGE_ROOT_DIR/grid
    rm $SGE_ROOT_DIR/grid
    
    # add the current host to the submit host list (will be able to do qsub)
    qconf -as $HOSTNAME
	
	# add to the admin host list so that we can do qstat, etc.
    qconf -ah $HOSTNAME
	
	# add slaves
	if [ "$category" == "Deployment" ]; then
        compute_node=$(ss-get compute.enable)
        if [ "$compute_node" != "false" ]; then
	        Install_EXEC
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
        		
        		QUEUE=all.q
                SLOTS=$(ssh root@$node_host 'nproc')
                
                # add to the execution host list
                TMPFILE=/tmp/sge.hostname-$node_name
                echo -e "hostname $node_name\nload_scaling NONE\ncomplex_values NONE\nuser_lists NONE\nxuser_lists NONE\nprojects NONE\nxprojects NONE\nusage_scaling NONE\nreport_variables NONE" > $TMPFILE
                qconf -Ae $TMPFILE
                rm $TMPFILE
                
                # add to the all hosts list
                qconf -aattr hostgroup hostlist $node_name @allhosts
                
                # enable the host for the queue, in case it was disabled and not removed
                qmod -e $QUEUE@$node_name
                
                if [ "$SLOTS" ]; then
                    qconf -aattr queue slots "[$node_name=$SLOTS]" $QUEUE
                fi
            done
        fi
    else
        Install_EXEC
	fi
	ss-set sge.ready "true"
	
	msg_info "SGE is configured."
}

## ADD SLAVES
UNSET_parameters(){
    ss-set nfs.ready "false"
    ss-set sge.ready "false"
}

#####
# NFS
#####
# exporting NFS share from master
NFS_export_pdisk_add()
{
    msg_info "Exporting NFS share of $WORKDIR..."
	
    EXPORTS_FILE=/etc/exports
    if grep -q $WORKDIR $EXPORTS_FILE; then 
		echo "$WORKDIR ready"
	else 
        echo -ne "$WORKDIR\t" >> $EXPORTS_FILE
        echo -ne "$SLAVE_IP(rw,sync,no_subtree_check,no_root_squash) " >> $EXPORTS_FILE
        echo "" >> $EXPORTS_FILE # last for a newline
    fi
    if grep -q $WORKDIR.*$SLAVE_IP $EXPORTS_FILE; then 
	    echo "$SLAVE_IP ready"
    else
        WD=$(echo $WORKDIR | sed 's|\/|\\\/|g')
        sed -ie '/'$WD'/s/$/\t'$SLAVE_IP'(rw,sync,no_subtree_check,no_root_squash)/' $EXPORTS_FILE
    fi
	
	msg_info "$WORKDIR is exported."
}

# exporting NFS share from master
NFS_export_home_add()
{
    msg_info "Exporting NFS share of $HOMEDIR..."
    
    EXPORTS_FILE=/etc/exports
    if grep -q $HOMEDIR $EXPORTS_FILE; then 
		echo "$HOMEDIR ready"
	else
        echo -ne "$HOMEDIR\t" >> $EXPORTS_FILE
        echo -ne "$SLAVE_IP(rw,sync,no_subtree_check,no_root_squash) " >> $EXPORTS_FILE
        echo "" >> $EXPORTS_FILE # last for a newline
    fi
    if grep -q $HOMEDIR.*$SLAVE_IP $EXPORTS_FILE; then 
	    echo "$SLAVE_IP ready"
    else
        HD=$(echo $HOMEDIR | sed 's|\/|\\\/|g')
        sed -ie '/'$HD'/s/$/\t'$SLAVE_IP'(rw,sync,no_subtree_check,no_root_squash)/' $EXPORTS_FILE
    fi
	
	msg_info "$HOMEDIR is exported."
}

NFS_export_sge_add()
{
    msg_info "Exporting NFS share of /opt/sge..."
    
    EXPORTS_FILE=/etc/exports
    if grep -q /opt/sge $EXPORTS_FILE; then 
		echo "/opt/sge ready"
	else
        echo -ne "/opt/sge\t" >> $EXPORTS_FILE
        echo -ne "$SLAVE_IP(rw,sync,no_subtree_check,no_root_squash) " >> $EXPORTS_FILE
        echo "" >> $EXPORTS_FILE # last for a newline
    fi
    if grep -q /opt/sge.*$SLAVE_IP $EXPORTS_FILE; then 
	    echo "$SLAVE_IP ready"
    else
        HD=$(echo /opt/sge | sed 's|\/|\\\/|g')
        sed -ie '/'$HD'/s/$/\t'$SLAVE_IP'(rw,sync,no_subtree_check,no_root_squash)/' $EXPORTS_FILE
    fi
	
	msg_info "/opt/sge is exported."
}

NFS_start_add()
{
	msg_info "Starting NFS..."
	service nfs-kernel-server start
    service nfs-kernel-server reload
    exportfs -av
    msg_info "NFS is started."
}

add_nodes() {
    MASTER_ID=1
    category=$(ss-get ss:category)
    if [ "$category" == "Deployment" ]; then
        HOSTNAME=$(ss-get nodename)-$MASTER_ID
    else
        HOSTNAME=machine-$MASTER_ID
    fi
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
        
        NFS_export_pdisk_add
        NFS_export_home_add
        if iscentos; then
            NFS_export_sge_add
        fi
        NFS_start_add
       
       if grep -q $SLAVE_IP /etc/hosts; then
            echo "$SLAVE_IP ready"
        else
            echo "$SLAVE_IP $INSTANCE_NAME_SAFE" >> /etc/hosts
        fi
        
        QUEUE=all.q
        SLOTS=$(ssh root@$SLAVE_IP 'nproc')
        
        # add to the execution host list
        TMPFILE=/tmp/sge.hostname-$SLAVE_IP
        echo -e "hostname $INSTANCE_NAME_SAFE\nload_scaling NONE\ncomplex_values NONE\nuser_lists NONE\nxuser_lists NONE\nprojects NONE\nxprojects NONE\nusage_scaling NONE\nreport_variables NONE" > $TMPFILE
        qconf -Ae $TMPFILE
        rm $TMPFILE
        
        # add to the all hosts list
        qconf -aattr hostgroup hostlist $INSTANCE_NAME_SAFE @allhosts
        
        # enable the host for the queue, in case it was disabled and not removed
        qmod -e $QUEUE@$INSTANCE_NAME_SAFE
        
        if [ "$SLOTS" ]; then
            qconf -aattr queue slots "[$INSTANCE_NAME_SAFE=$SLOTS]" $QUEUE
        fi
    done
    ss-set nfs.ready "true"
    ss-set sge.ready "true"
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
        
        #echo "$SLAVE_IP $INSTANCE_NAME_SAFE" >> /etc/hosts
        
        QUEUE=all.q
        
        # disable the host to avoid any jobs to be allocated to this host
        qmod -d $QUEUE@$INSTANCE_NAME_SAFE
        
        # remove it from the all hosts list
        qconf -dattr hostgroup hostlist $INSTANCE_NAME_SAFE @allhosts
        
        # remove it from the execution host list
        qconf -de $INSTANCE_NAME_SAFE
        
        # reschedules all jobs currently running in this  queue
        qmod -f -rq $QUEUE@$INSTANCE_NAME_SAFE
        
        # delete specific slot count for the host
        #qconf -purge queue slots $QUEUE@$SLAVE_IP
        
        #remove nfs export
        sed -i 's|'$SLAVE_IP'(rw,sync,no_subtree_check,no_root_squash)||' /etc/exports
    done
    ss-display "Slave is removed."
}


error(){ 
    echo "utilisez l'option -h pour en savoir plus" >&2 
} 

usage(){ 
    echo "Usage: source /scripts/cluster/sge/sge_install.sh" 
    echo "--help ou -h : afficher l'aide"
    echo "-m : Install sge master" 
    echo "-s : Install sge slave"
} 

master_help(){
    echo "You can do:"
    echo "    initiate_master"
    echo "    make_file_test"
    echo "    #if not vpn"
    echo "    check_ip"
    echo "    check_ip_slave_for_master"
    echo "    #Endif"
    echo "    user_add"
    echo "    #If one or several slaves "
    echo "    NFS_export_pdisk"
    echo "    NFS_export_home"
    echo "    NFS_start"
    echo "    #Endif"
    echo "    Install_SGE_master"
    echo "    Config_SGE"
} 

slave_help(){
    echo "You can do:" 
    echo "    initiate_slave"
    echo "    make_file_test"
    echo "    #if not vpn"
    echo "    check_ip"
    echo "    check_ip_master_for_slave"
    echo "    #Endif"
    echo "    user_add"
    echo "    #If one or several slaves "
    echo "    NFS_export_pdisk"
    echo "    NFS_export_home"
    echo "    NFS_start"
    echo "    #Endif"
    echo "    Install_SGE_master"
    echo "    Config_SGE"
} 

# Pas de paramètre 
[[ $# -lt 1 ]] && error

# -o : options courtes 
# -l : options longues 
options=$(getopt -o h,m,s: -l help -- "$@") 

set -- $options 

while true; do 
    case "$1" in 
        -m) master_help
            shift;;
        -s) slave_help
            shift;;
        -h|--help) usage 
            shift;;
        --)
            shift
            break;; 
        *) error 
            shift;;
    esac 
done