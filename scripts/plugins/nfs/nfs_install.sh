source /scripts/toolshed/os_detection.sh

# Warning: Use this script with parent component ****-ifb
# Slipstream parameter:
# nfs.ready
# server.nodename
# client.nodename

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

NFS_start()
{
	msg_info "Starting NFS..."
    if iscentos 7; then
        systemctl enable nfs-server
        systemctl start nfs-server
        systemctl reload nfs-server
    fi
    if isubuntu 16; then
	    systemctl start nfs-kernel-server
        systemctl reload nfs-kernel-server
    fi
    exportfs -av
    ss-set nfs.ready "true"
    msg_info "NFS is started."
}

NFS_ready(){
    ss-get --timeout=3600 server.nodename
    SERVER_HOSTNAME=$(ss-get server.nodename)
    
    ss-get --timeout=3600 $SERVER_HOSTNAME:nfs.ready
    nfs_ready=$(ss-get $SERVER_HOSTNAME:nfs.ready)
    msg_info "Waiting NFS to be ready."
	while [ "$nfs_ready" == "false" ]
	do
		sleep 10;
		nfs_ready=$(ss-get $SERVER_HOSTNAME:nfs.ready)
	done
}

# exporting NFS share from server
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

            ss-set server.nodename $(ss-get nodename)
            ss-get --timeout=3600 client.nodename
            CLIENT_NAME=$(ss-get client.nodename)
        
            EXPORTS_FILE=/etc/exports
            if grep -q --perl-regex "$EXPORT_DIR\t" $EXPORTS_FILE; then
        		echo "$EXPORT_DIR ready"
        	else
                echo -ne "$EXPORT_DIR\t" >> $EXPORTS_FILE
            fi
            for (( i=1; i <= $(ss-get $CLIENT_NAME:multiplicity); i++ )); do
                node_host=$(ss-get $CLIENT_NAME.$i:private_ip)
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

            ss-set client.nodename $(ss-get nodename)
            ss-get --timeout=3600 server.nodename
            SERVER_HOSTNAME=$(ss-get server.nodename)

            SERVER_IP=$(ss-get $SERVER_HOSTNAME:private_ip)

            umount $MOUNT_DIR
            mount $SERVER_IP:$MOUNT_DIR $MOUNT_DIR 2>/tmp/mount_error_message.txt
            ret=$?
            msg_info "$(cat /tmp/mount_error_message.txt)"

            if [ $ret -ne 0 ]; then
                ss-abort "$(cat /tmp/mount_error_message.txt)"
            else
                 msg_info "$MOUNT_DIR is mounted"
            fi
        fi
    fi
}

## ADD CLIENTS
UNSET_parameters(){
    ss-set nfs.ready "false"
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

            MASTER_ID=1
            category=$(ss-get ss:category)
            if [ "$category" == "Deployment" ]; then
                HOSTNAME=$(ss-get nodename)-$MASTER_ID
            else
                HOSTNAME=machine-$MASTER_ID
            fi

            ss-display "ADD client..."
            for INSTANCE_NAME in $SLIPSTREAM_SCALING_VMS; do
                INSTANCE_NAME_SAFE=$(echo $INSTANCE_NAME | sed "s/\./-/g")

                echo "Processing $INSTANCE_NAME"
                # Do something here. Example:
                #ss-get $INSTANCE_NAME:ready

                ss-get --timeout=3600 $INSTANCE_NAME:private_ip
                CLIENT_IP=$(ss-get $INSTANCE_NAME:private_ip)

                sed -i "s|$PUBLIC_SLAVE_IP|$SLAVE_IP|g" /etc/hosts
                echo "New instance of $SLIPSTREAM_SCALING_NODE: $INSTANCE_NAME_SAFE, $SLAVE_IP"

                EXPORTS_FILE=/etc/exports
                if grep -q --perl-regex "$EXPORT_DIR\t" $EXPORTS_FILE; then
                    echo "$EXPORT_DIR ready"
                else
                    echo -ne "$EXPORT_DIR\t" >> $EXPORTS_FILE
                    echo -ne "$CLIENT_IP(rw,sync,no_subtree_check,no_root_squash) " >> $EXPORTS_FILE
                    echo "" >> $EXPORTS_FILE # last for a newline
                fi
                if grep -q $EXPORT_DIR.*$CLIENT_IP $EXPORTS_FILE; then
                    echo "$CLIENT_IP ready"
                else
                    WD=$(echo $EXPORT_DIR | sed 's|\/|\\\/|g')
                    sed -i '/'$WD'/s/$/\t'$CLIENT_IP'(rw,sync,no_subtree_check,no_root_squash)/' $EXPORTS_FILE
                fi

                msg_info "$EXPORT_DIR is exported."
            done
        fi
    fi
}