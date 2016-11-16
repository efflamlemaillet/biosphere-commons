mkdir -p /scripts/
if [ ! -e /scripts/json_tool_shed.py ]; then
    wget https://github.com/cyclone-project/usecases-hackathon-2016/blob/master/scripts/json_tool_shed.py  -O /scripts/json_tool_shed.py
fi

ss-display "Allowing others to access to me"
for name in `ss-get allowed_components | sed 's/, /,/g' | sed 's/,/\n/g' `; do 
    if [ "$name" == "none" ]; then
        echo -e "not needed in fact"
    else
        IFS=:
        ary=($name)
        name=${ary[0]}
        remote_user=${ary[1]:-root}
        local_user=${ary[2]:-root}
        mult=$(ss-get --timeout 480 $name:multiplicity)
        if [ "mult" == "" ]; then
            ss-abort "Failed to retrieve multiplicity of $name on $(ss-get hostname)"
            return 1
        fi
        for (( i=1; i <= $mult; i++ )); do
            echo -e "Allowing $name.$i to ssh me"
            pubkey=$(ss-get --timeout 480 $name.$i:pubkey)
            pubkey=$(/scripts/json_tool_shed.py find_in_json "$pubkey" "$remote_user" --print-values)
            if [ "$pubkey" == "" ]; then
                ss-abort "Failed to retrieve pubkey of $name.$i on $(ss-get hostname)"
                return 1
            fi
            if [ "$local_user" == "root" ]; then
                DOT_SSH=~/.ssh
            else
                DOT_SSH=/home/$local_user/.ssh/
                mkdir -p $DOT_SSH
                chmod +x+r $DOT_SSH
                touch $DOT_SSH/authorized_keys
                chmod +x $DOT_SSH/authorized_keys
                chown -R $local_user:$local_user /home/$local_user/
            fi
            echo "#other components that can access to it" >> $DOT_SSH/authorized_keys
            echo "#$name.$i" >> $DOT_SSH/authorized_keys
            echo "$pubkey" >> $DOT_SSH/authorized_keys
        done
    fi
done
