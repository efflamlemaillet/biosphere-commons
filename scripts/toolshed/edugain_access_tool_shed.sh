#!/bin/bash

add_email_for_edugain_acces_to_user(){
    echo "Adding $1 for user $2 (in /home/$2/.edugain)"
    echo $(./json_tool_shed.py add-in-json "$(cat /home/$2/.edugain)" "users" "u'$1'" --print-values) > /home/$2/.edugain
}

init_edugain_acces_to_user(){
    echo "Initializing user $1 (in /home/$1/.edugain)"
    echo $(./json_tool_shed.py add-in-json "{}" "users" "[]" --print-values) > /home/$1/.edugain
}

echo_owner_email(){
    username=$(cat /opt/slipstream/client/bin/slipstream.context | grep username | sed 's/username = //g')
    cat /opt/slipstream/client/bin/slipstream.context | grep cookie | sed 's/cookie = //g' > /root/.slipstream-cookie
    ss-user-get $username 1> /root/user.xml
    export OWNER_EMAIL=$(cat /root/user.xml | sed 's/ /\n/g' | grep email= | sed 's/email=//g' | sed 's/"//g')
    echo $OWNER_EMAIL
    rm -f /root/user.xml /root/.slipstream-cookie
}

echo "edugain_access_tool_shed.sh loaded"

if [ "$1" == "--dry-run" ]; then
    echo "you could do :"
    echo "    init_edugain_acces_to_user edugain "
    echo "    EDUGAIN_EMAIL=echo_owner_email"
    echo "    add_email_for_edugain_acces_to_user \$(echo_owner_email) edugain"
    echo "    add_email_for_edugain_acces_to_user john.doe@nowhere.com edugain"
fi
