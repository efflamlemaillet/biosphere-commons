#!/bin/bash

get_ids_for_component(){
    if [ "$(ss-get $1:multiplicity)" == "0" ]; then
        echo ""
    else
        echo $(ss-get --timeout 1200 $1:ids)
    fi
}

populate_hosts_with_components_name_and_ips(){
    ss-display "Populating /etc/hosts"
    category=$(ss-get ss:category)
    if [ "$category" == "Deployment" ]; then
        ip_field_name=${1:-hostname}
        echo "Using $ip_field_name as field containing the ip"
        for name in `ss-get ss:groups | sed 's/, /,/g' | sed 's/,/\n/g' `; do 
            name=$(echo $name| cut -d':' -f2)
            mult=$(ss-get --timeout 3600 $name:multiplicity)
            if [ "mult" == "" ]; then
                ss-abort "Failed to retrieve multiplicity of $name on $(ss-get hostname)"
                return 1
            fi
            ids=$(get_ids_for_component $name)
            for i in $(echo $ids | sed 's/,/\n/g'); do
                echo -e "Fetching ip of $name.$i"
                ip=$(ss-get --timeout 3600 $name.$i:$ip_field_name)
                echo "$ip    $name-$i " >> /etc/hosts
                echo "$ip    $name.$i " >> /etc/hosts
                if [ "$mult" == "1" ]; then
                    echo "$ip    $name " >> /etc/hosts
                fi
                echo "$ip is now in /etc/hosts and known as $name-$i, $name.$i and maybe $name if only one"
            done
        done
    else
        echo "Populating is not needed as we are not in a Deployment"
    fi
}

populate_hosts_with_components_name_and_ips_on_vm_add(){
    ip_field_name=${1:-hostname}
    for INSTANCE_NAME in $SLIPSTREAM_SCALING_VMS; do
        INSTANCE_NAME_SAFE=$(echo $INSTANCE_NAME | sed "s/\./-/g")
        INSTANCE_NAME_NO_NUM=$(echo $INSTANCE_NAME | cut -d. -f1)
        echo Processing $INSTANCE_NAME
        vpn_address=$(ss-get --timeout=3600 $INSTANCE_NAME:$ip_field_name)
        echo "New instance of $SLIPSTREAM_SCALING_NODE: $INSTANCE_NAME/$INSTANCE_NAME_SAFE, $vpn_address"
        echo "$vpn_address    $INSTANCE_NAME_SAFE " >> /etc/hosts
        echo "$vpn_address    $INSTANCE_NAME " >> /etc/hosts
        sed -i "/$INSTANCE_NAME_NO_NUM /d" /etc/hosts
    done
}

populate_hosts_with_components_name_and_ips_on_vm_remove(){
    ip_field_name=${1:-hostname}
    for INSTANCE_NAME in $SLIPSTREAM_SCALING_VMS; do
        INSTANCE_NAME_SAFE=$(echo $INSTANCE_NAME | sed "s/\./-/g")
        echo Processing $INSTANCE_NAME
        vpn_address=$(ss-get $INSTANCE_NAME:$ip_field_name)
        echo "Removing instance of $SLIPSTREAM_SCALING_NODE: $INSTANCE_NAME/$INSTANCE_NAME_SAFE, $vpn_address"
        sed -i "/$INSTANCE_NAME /d" /etc/hosts
        #as INSTANCE_NAME contains a dot where it can also be a - the next line is useless
        #sed -i "/$INSTANCE_NAME_SAFE /d" /etc/hosts 
    done
}

if [ "$1" == "--dry-run" ]; then
    echo "function loaded for populate_hosts_with_components_name_and_ips.sh"
else
    populate_hosts_with_components_name_and_ips $1
fi
