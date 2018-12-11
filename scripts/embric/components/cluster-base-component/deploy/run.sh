#!/bin/bash


set_hostname(){
	hostnamectl set-hostname $(ss-get nodename)$(ss-get id)
}

rsa_with_passphrase_exists (){
        file=${1:-~/.ssh/id_rsa}
        rc=0
        if [[ -f $file ]]
        then
                rc=$(expect -c "
                spawn ssh-keygen -yf $file
                expect {
                        -exact \"Enter passphrase:\" {
                                exit 1
                        }
                        eof {
                                exit 0
                        }
                }
                ")
        fi
}
gather_hosts_entries(){
	IFS=','
	for group in $(ss-get ss:groups)
	do
		component_name=${group##*:}
		for id in $(ss-get "${component_name}:ids")
		do
			echo $(ss-get --timeout=3600 ${component_name}.$id:hosts_entry) >> /etc/hosts
			#trust it in firewalld
			firewall-cmd --permanent --zone=trusted --add-source=$(ss-get --timeout=3600 ${component_name}.$id:private_ip)
		done
	done
}
create_ssh_key(){
        yesv="n"
        rsa_with_passphrase_exists
        if [[ $? -eq 1 ]];then
                yesv="y"
        fi
        yes ${yesv}|ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa

}

_run () {
	
	ss-set component_name $(ss-get nodename)
	create_ssh_key
	set_hostname
	if ! systemctl -q is-active firewalld ;then
		systemctl start firewalld
	fi
	#authorize local ssh 
	cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
	ssh-keyscan $(hostname -s),$(hostname -i),0.0.0.0 >> ~/.ssh/known_hosts
	#publish ssh pub key & /etc/hosts entry
	ss-set public_key  "$(cat /root/.ssh/id_rsa.pub)"
	ss-set hosts_entry "$(ss-get private_ip) $(hostname -s)"
	gather_hosts_entries
	
}



_run
