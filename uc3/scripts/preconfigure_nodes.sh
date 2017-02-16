#! /bin/bash

BASH=~/.bashrc
PACKAGES="unzip"
UPDATE_DOCKER=yes

consul_version=0.6.4
log=/tmp/cluster.log

docker_realfile="/etc/default/docker"
docker_tmpfile="/tmp/docker"
docker_option="-H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock  --cluster-store consul://127.0.0.1:8500"


# DOCKER_OPTS=' -H unix:///var/run/docker.sock --cluster-advertise eth0:2375 --cluster-store consul://127.0.0.1:8500'

########################################################################################################################
#
### function
#
########################################################################################################################


function msglog()
{
    echo -e "$@" | tee -a $log
}

function msgerr()
{
   msglog "======== \n ERROR $@"
        
}

function update_docker_default_file() {

	if [ $(which docker > /dev/null ; echo $?) -ne 0 ]
	then 
		msgerr "Docker not installed"
		exit 1
	else
		# Clean containers
		msglog "Clean containers"
		docker stop $(docker ps -aq) &> /dev/null
		docker rm -v -f $(docker ps -aq) &> /dev/null
	fi

    msglog "Change option Docker"

    cp $docker_realfile $docker_tmpfile

    sed -i 's/^\(DOCKER_OPTS=\)/#\1/' $docker_tmpfile
    if [ "$?" -ne 0 ];then msgerr "update default docker file"; exit 1 ; fi

    echo DOCKER_OPTS=\"${docker_option}\" >> $docker_tmpfile
    if [ "$?" -ne 0 ];then msgerr "Update default docker file add new options"; exit 1 ; fi

    # Replace file
    cp $docker_tmpfile $docker_realfile

    # recreate key.json after restart docker
    msglog "Re initialize identifiant file"
    rm /etc/docker/key.json

    msglog "Restart Docker "
    service docker stop
    service docker start

    docker version

}


function check_requiement(){
	# Check OS; shoud be Ubuntu with kernel 3.13 or more and docker installed
	msglog "========= Check requierements"
	osname=$(grep -iho "ubuntu" /etc/*-release | head -n1)
	msglog "DEBUG $osname"
	if [ "X$osname" != "XUbuntu" ]; then msgerr "Should be Ubuntu system" ; exit 1; fi

	kernel_major=$(uname -r | cut -d '.' -f 1)
	kernel_minor=$(uname -r | cut -d '.' -f 2)
	kernel=${kernel_major}.${kernel_minor}
	msglog  "DEBUG kernel $kernel"
	if [ "$kernel_major" -lt "3" -a "$kernel_minor" -lt "13" ]
	then 
		msgerr "Kernel version invalid, expected 3.13 or more, is ${kernel}"
		exit 1
	fi

	msglog "========= Update OS"
	# update 
	apt-get update &> /dev/null 
	apt-get install --yes $PACKAGES &> /dev/null
	# apt-get upgrade -qq &> /dev/null

	msglog " OS ready"
	msglog " OS $osname"
	msglog " Kernel $kernel"
	msglog " Docker "

}

function install_consul(){

	msglog "============= Install consul"

	which consul &> /dev/null

	if [ $? -eq 0 ]; then
		msglog "Consul is already install"
	else 
		cd /usr/local/bin
		wget --no-verbose  https://releases.hashicorp.com/consul/${consul_version}/consul_${consul_version}_linux_amd64.zip
		unzip consul_${consul_version}_linux_amd64.zip
		rm consul_${consul_version}_linux_amd64.zip
		cd 

		consul version

		# Create configuration directory
		mkdir /etc/consul.d && chmod a+w /etc/consul.d
	fi
}



function update_bashrc(){
	msglog "\n=======  Add command in .bashrc file"

	echo -e "\n# Add entry for Docker Swarm"   >> $BASH
	echo -e "alias ldocker='docker -H tcp://0.0.0.0:2375 --cluster-advertise eth0:2375'  "  >> $BASH
	#used only on the swarm manager
	echo -e "alias swarm-docker='docker -H tcp://0.0.0.0:5732 --cluster-advertise eth0:2375' "  >> $BASH

	# echo -e "\nIP=$(ifconfig |grep "192.54.201."|cut -d ":" -f 2|cut -d " " -f 1)"  >> $BASH
	echo -e "\nIP=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/') " >> $BASH
}

########################################################################################################################
#
### MAIN
#
########################################################################################################################


if [ -f /tmp/config_node_swarm ]; then
	msglog "Node is already configure for cluster"
	exit 0
fi

check_requiement

install_consul


if [ $UPDATE_DOCKER == "yes" ]; then
	msglog "\n=========== Configure docker daemon"

	# Configure Docker daemon
	update_docker_default_file
fi

update_bashrc

source ~/.bashrc

touch /tmp/config_node_swarm