check_json_tool_shed(){
    if [ ! -e /scripts/json_tool_shed.py ]; then
        mkdir -p /scripts/
        wget https://github.com/cyclone-project/usecases-hackathon-2016/blob/master/scripts/json_tool_shed.py  -O /scripts/json_tool_shed.py
        chmod a+rx -R /scripts/
    fi
}

get_users_that_i_should_have(){
    users=""
    category=$(ss-get ss:category)
    nodename=$(ss-get nodename)
    if [ "$category" == "Deployment" ]; then    
        for name in `ss-get ss:groups | sed 's/, /,/g' | sed 's/,/\n/g' | cut -d':' -f2`; do 
            users="$users
$(ss-get $name.1:allowed_components | grep -v none | sed 's/, /,/g' | sed 's/,/\n/g' | grep "$nodename" | cut -d: -f2)"
        done  
    fi
    users="$users
$(ss-get allowed_components | grep -v none | sed 's/, /,/g' | sed 's/,/\n/g' | cut -d: -f3)"
    echo $users | sort | uniq | grep -v "^$"
}

gen_key_for_user_and_allows_hosts(){
    ss-display "Setting ssh key for $1 to hosts $2"
    echo "Setting ssh key for $1 to hosts $2"
    if [ "$1" == "" ]; then
        return
    fi
    if [ "$1" == "root" ]; then
        usr_home=/root
    else
        usr_home=/home/$1
    fi
    if [ -e $usr_home/.ssh/id_rsa ]; then
        return
    fi
    if [ "$(getent passwd $1 | wc -l)" == "0" ]; then
        useradd --shell /bin/bash --create-home $1
        chmod 755 $usr_home/
    fi
    mkdir -p $usr_home/.ssh/
    chmod 755 $usr_home/.ssh/
    ssh-keygen -f $usr_home/.ssh/id_rsa -t rsa -N ''
    ssh-keygen -y -f $usr_home/.ssh/id_rsa > $usr_home/.ssh/id_rsa.pub
    category=$(ss-get ss:category)
    if [ "$category" == "Deployment" ]; then
        hostnames_in_cluster="$2"
        echo "Host $hostnames_in_cluster
        ConnectTimeout 3
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
        
        ">>$usr_home/.ssh/config
        chmod 755 $usr_home/.ssh/config
    fi
    chown $1:$1 -R $usr_home/.ssh/
    echo "Setting ssh key for $1 done"
}

get_hostnames_in_cluster(){
    hostnames_in_cluster=" "
    for name in `ss-get ss:groups | sed 's/, /,/g' | sed 's/,/\n/g' | cut -d':' -f2`; do 
        mult=$(ss-get --timeout 480 $name:multiplicity)
        if [ "mult" == "" ]; then
            ss-abort "Failed to retrieve multiplicity of $name on $(ss-get hostname)"
            return 1
        fi
        if [ "$mult" == "1" ]; then
            hostnames_in_cluster="$hostnames_in_cluster $name"
        else
            for (( i=1; i <= $mult; i++ )); do
                hostnames_in_cluster="$hostnames_in_cluster $name-$i $name.$i"
            done
        fi
    done
    echo  $hostnames_in_cluster
}

gen_key_for_user(){
    gen_key_for_user_and_allows_hosts $1 $(get_hostnames_in_cluster)
}

publish_pubkey(){
    ss-display "Fetching already published pubkey(s)"
    check_json_tool_shed
    #pubkey=$(ss-get --timeout 480 pubkey)
    pubkey="{}"
    echo "Publishing pubkey of root"
    pubkey=$(/scripts/json_tool_shed.py add_in_json "$pubkey" 'root' "u'$(cat ~/.ssh/id_rsa.pub)'" --print-value)
    for user in $(ls -1 /home/); do 
        if [ -e /home/$user/.ssh/id_rsa.pub ]; then
            echo "Publishing pubkey of $user"
            pubkey=$(/scripts/json_tool_shed.py add_in_json "$pubkey" "$user" "u'$(cat /home/$user/.ssh/id_rsa.pub)'" --print-value)
        else
            echo "Publishing pubkey of $user impossible, /home/$user/.ssh/id_rsa.pub is missing "
        fi
    done
    ss-set pubkey "$pubkey"
}

get_ip_for_component(){
    echo $(getent hosts $(ss-get $1:hostname) | awk '{ print $1 }' | head -n 1)
    #echo $(ss-get $1:vpn.address)
}

allow_others(){
    ss-display "Allowing others to access to me"
    echo "Allowing others to access to me"
    check_json_tool_shed
    for name in `ss-get allowed_components | sed 's/, /,/g' | sed 's/,/\n/g' `; do 
        if [ "$name" == "none" ]; then
            echo -e "not needed in fact"
        else
            #IFS=:
            #ary=($name)
            #name=${ary[0]}
            #remote_user=${ary[1]:-root}
            #local_user=${ary[2]:-root}
            remote_user=$(echo $name| cut -d':' -f2)
            local_user=$(echo $name| cut -d':' -f3)
            name=$(echo $name| cut -d':' -f1)
            remote_user=${remote_user:-root}
            local_user=${local_user:-root}
            mult=$(ss-get --timeout 480 $name:multiplicity)
            if [ "mult" == "" ]; then
                ss-abort "Failed to retrieve multiplicity of $name on $(ss-get hostname)"
                return 1
            fi
            for (( i=1; i <= $mult; i++ )); do
                echo -e "Allowing $remote_user of $name.$i to ssh me on user $local_user"
                pubkey=$(ss-get --timeout 480 $name.$i:pubkey)
                pubkey=$(/scripts/json_tool_shed.py find_in_json "$pubkey" "$remote_user" --print-values)
                if [ "$pubkey" == "" ]; then
                    ss-abort "Failed to retrieve pubkey of $name.$i on $(ss-get hostname)"
                    return 1
                fi
                if [ "$local_user" == "root" ]; then
                    DOT_SSH=~/.ssh
                else
                    if [ "$(getent passwd $local_user | wc -l)" == "0" ]; then
                        useradd --create-home $local_user --shell /bin/bash
                    else
                        if [ ! -e /home/$local_user ]; then
                            mkhomedir_helper $local_user
                        fi
                    fi
                    DOT_SSH=/home/$local_user/.ssh/
                    mkdir -p $DOT_SSH
                    chmod 755 $DOT_SSH
                    touch $DOT_SSH/authorized_keys
                    chmod 744 $DOT_SSH/authorized_keys
                    chown -R $local_user:$local_user /home/$local_user/
                fi
                echo "#other components that can access to it" >> $DOT_SSH/authorized_keys
                echo "#$name.$i" >> $DOT_SSH/authorized_keys
                echo "$pubkey" >> $DOT_SSH/authorized_keys
                ls -la $DOT_SSH
                echo -e "Allowing $remote_user of $name.$i to ssh me on user $local_user done"
            done
        fi
    done
    echo "Allowing others to access to me done"
}

auto_gen_users(){
    hostnames_in_cluster="$(get_hostnames_in_cluster)"
    for user in $(get_users_that_i_should_have); do 
        gen_key_for_user_and_allows_hosts $user $hostnames_in_cluster
    done
}

if [ "$1" == "--dry-run" ]; then
    echo "function loaded"
    echo "You can do:"
    echo "    source /scripts/allows_other_to_access_me.sh --dry-run "
    echo "    auto_gen_users"
    echo "    gen_key_for_user alice"
    echo "    gen_key_for_user bob"
    echo "    gen_key_for_user charlie"
    echo "    publish_pubkey"
    echo "    allow_others"
else
    auto_gen_users
    publish_pubkey
    allow_others
fi
