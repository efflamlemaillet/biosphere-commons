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

create_ssh_key(){
        yesv="n"
        rsa_with_passphrase_exists
        if [[ $? -eq 1 ]];then
                yesv="y"
        fi
        yes ${yesv}|ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa

}

_run () {

	create_ssh_key
	set_hostname
	ss-set hosts_entry $(ss-get private_ip) $(hostname -s)

}



_run
