#!/bin/bash

populate_hosts_with_components_name_and_ips(){
    ss-display "Populating /etc/hosts"
    category=$(ss-get ss:category)
    if [ "$category" == "Deployment" ]; then
        ip_field_name=${1:-hostname}
        echo "Using $ip_field_name as field containing the ip"
        for name in `ss-get ss:groups | sed 's/, /,/g' | sed 's/,/\n/g' `; do 
            IFS=:
            ary=($name)
            cloud=${ary[0]}
            name=${ary[1]}
            mult=$(ss-get --timeout 480 $name:multiplicity)
            if [ "mult" == "" ]; then
                ss-abort "Failed to retrieve multiplicity of $name on $(ss-get hostname)"
                return 1
            fi
            for (( i=1; i <= $mult; i++ )); do
                echo -e "Fetching ip of $name.$i"
                ip=$(ss-get --timeout 480 $name.$i:$ip_field_name)
                echo "$ip    $name-$i" >> /etc/hosts
                echo "$ip is now in /etc/hosts and known as $name-$i"
            done
        done
    else
        echo "Populating is not needed as we are not in a Deployment"
    fi
}

if [ "$1" == "--dry-run" ]; then
    echo "function loaded for populate_hosts_with_components_name_and_ips.sh"
else
    populate_hosts_with_components_name_and_ips $1
fi
