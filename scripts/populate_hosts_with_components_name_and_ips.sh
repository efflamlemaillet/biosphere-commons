#!/bin/bash

populate_hosts_with_components_name_and_ips(){
    ss-display "Populating /etc/hosts"
    category=$(ss-get ss:category)
    if [ "$category" == "Deployment" ]; then
        ip_field_name=${1:-hostname}
        echo "Using $ip_field_name as field containing the ip"
        for name in `ss-get ss:groups | sed 's/, /,/g' | sed 's/,/\n/g' `; do 
            name=$(echo $name| cut -d':' -f2)
            mult=$(ss-get --timeout 480 $name:multiplicity)
            if [ "mult" == "" ]; then
                ss-abort "Failed to retrieve multiplicity of $name on $(ss-get hostname)"
                return 1
            fi
            for (( i=1; i <= $mult; i++ )); do
                echo -e "Fetching ip of $name.$i"
                ip=$(ss-get --timeout 480 $name.$i:$ip_field_name)
                if [ "$mult" == "1" ]; then
                    comp_name="$name.1 "
                    comp_name_safe="$name "
                else
                    comp_name="$name-$i "
                    comp_name_safe="$name-$i "
                fi
                echo "$ip    $comp_name" >> /etc/hosts
                echo "$ip    $comp_name_safe" >> /etc/hosts
                echo "$ip is now in /etc/hosts and known as $comp_name"
            done
        done
    else
        echo "Populating is not needed as we are not in a Deployment"
    fi
}

populate_hosts_with_components_name_and_ips_on_vm_add(){
    ip_field_name=${1:-hostname}
    for INSTANCE_NAME in $SLIPSTREAM_SCALING_VMS; do
        INSTANCE_NAME_SAFE=$(echo $INSTANCE_NAME | sed "s/./-/g")
        echo Processing $INSTANCE_NAME
        vpn_address=$(ss-get $INSTANCE_NAME:$ip_field_name)
        echo "New instance of $SLIPSTREAM_SCALING_NODE: $INSTANCE_NAME/$INSTANCE_NAME_SAFE, $vpn_address"
        echo "$vpn_address    $INSTANCE_NAME " >> /etc/hosts
        echo "$vpn_address    $INSTANCE_NAME_SAFE " >> /etc/hosts
    done
}

populate_hosts_with_components_name_and_ips_on_vm_remove(){
    ip_field_name=${1:-hostname}
    for INSTANCE_NAME in $SLIPSTREAM_SCALING_VMS; do
        INSTANCE_NAME_SAFE=$(echo $INSTANCE_NAME | sed "s/./-/g")
        echo Processing $INSTANCE_NAME
        vpn_address=$(ss-get $INSTANCE_NAME:$ip_field_name)
        echo "Removing instance of $SLIPSTREAM_SCALING_NODE: $INSTANCE_NAME/$INSTANCE_NAME_SAFE, $vpn_address"
        sed -i '/$INSTANCE_NAME /d' /etc/hosts
        sed -i '/$INSTANCE_NAME_SAFE /d' /etc/hosts
    done
}

if [ "$1" == "--dry-run" ]; then
    echo "function loaded for populate_hosts_with_components_name_and_ips.sh"
else
    populate_hosts_with_components_name_and_ips $1
fi
