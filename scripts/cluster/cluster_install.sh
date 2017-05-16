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