#! /bin/bash -xe

# Install and configure docker
# Use environment variable

NONE=none

DOCKER_VERSION=${DOCKER_VERSION:-latest}
DOCKER_STORE_DIRECTORY=${DOCKER_STORE_DIRECTORY:-$NONE}
DOCKER_OPTIONS=${DOCKER_OPTIONS:-$NONE}

# Set particular options
# Registry : only IPs, separated by comma
DOCKER_REGISTRIES=${DOCKER_REGISTRIES:-$NONE}
# Set default host
DOCKER_NEW_HOST=${DOCKER_NEW_HOST:-$NONE}
# Storage type
DOCKER_STORAGE=${DOCKER_STORAGE:-$NONE}

DOCKER_MACHINE_VERSION=${DOCKER_MACHINE_VERSION:-0.10.0}
DOCKER_COMPOSE_VERSION=${DOCKER_COMPOSE_VERSION:-1.11.2}

LOG=/var/log/install_docker
LOG_OUT=${LOG}.out
LOG_ERR=${LOG}.err


DEFAULT_DOCKER_PATH=/var/lib/docker
SOCKET_DOCKER=/var/run/sock.sock
DEFAULT_DOCKER_FILE_INIT=/etc/default/docker
DEFAULT_DOCKER_FILE_SYSTEMD=/etc/default/docker

OS_NAME=$(uname -s)
OS_ARCHI=$(uname -m)
OS_VERSION=$(uname -r)

################################
## Usefull function           ##
################################

msg_info(){
	echo -e "INFO : $@" | tee -a $LOG_OUT
}

msg_err(){
	echo -e "ERROR : $@" | tee -a $LOG_OUT
}

function print_variable()
{
	msg_info "var DOCKER_VERSION=$DOCKER_VERSION"
	msg_info "var DOCKER_STORE_DIRECTORY=$DOCKER_STORE_DIRECTORY"
	msg_info "var DOCKER_OPTIONS=$DOCKER_OPTIONS"
	msg_info "var DOCKER_REGISTRIES=$DOCKER_REGISTRIES"
	msg_info "var DOCKER_NEW_HOST=$DOCKER_NEW_HOST"
	msg_info "var DOCKER_STORAGE=$DOCKER_STORAGE"
	msg_info "var DOCKER_MACHINE_VERSION=$DOCKER_MACHINE_VERSION"
	msg_info "var DOCKER_COMPOSE_VERSION=$DOCKER_COMPOSE_VERSION"
}

function update_bashrc()
{
	# Remove -H
	host=${1:3}
	echo "export DOCKER_HOST=\"$host\" " >> $HOME/.bashrc
}

function update_version_with_os()
{
	os_codename=$(lsb_release -c | cut -f2)
	codename_from_version=$(echo $DOCKER_VERSION | rev | cut -d'~' -f 1 | rev | cut -d '-' -f 2)

	if [ "$os_codename" = "$codename_from_version" ]; then
		echo $DOCKER_VERSION
	else
		echo $(echo $DOCKER_VERSION | sed "s/$codename_from_version/$os_codename/")
	fi
}

function remove_docker()
{	
	which docker &> /dev/null
	res=$(echo $?)
	if [ "$res" -eq 0 ]; then
		msg_info "Docker already install, version $(docker --version)"
		
		msg_info "Stop all containers"
		docker stop $(docker ps -aq)
		docker rm -v $(docker ps -aq)
		service docker stop

		msg_info "Remove docker"
		apt-get purge -y docker-engine
		apt-get autoremove -y --purge docker-engine
		apt-get autoclean
		rm -rf /var/lib/docker

		msg_info "Docker is removed"
	fi

}

function create_new_options()
{
	# Compile all options in one line
	opts=""

	if [ "$DOCKER_OPTIONS" != "$NONE" ]; then
		opts=$DOCKER_OPTIONS
	fi

	if [ "$DOCKER_NEW_HOST" != "$NONE" ]; then
		if [ $(echo $DOCKER_NEW_HOST | grep -c ':') -eq "0" ]; then
			host="-H tcp://0.0.0.0:2375"
		else 
			if [  "${DOCKER_NEW_HOST:0:1}" != "-" ]; then
				host="-H $DOCKER_NEW_HOST"
			else
				host=$DOCKER_NEW_HOST
			fi
		fi
		opts="$opts $host"
		update_bashrc $host
	fi

	if [ "$DOCKER_REGISTRIES" != "$NONE" ]; then
		registries=""
		for registry in $(echo $DOCKER_REGISTRIES | tr -d ' ' | sed 's/,/\n/g')
		do
			registries="$registries --insecure-registry $registry --registry-mirror=http://$registry"
		done

		opts="$opts $registries"
	fi

	if [ "$DOCKER_STORAGE" != "$NONE" ]; then
		store="--storage-driver=$DOCKER_STORAGE"

		opts="$opts $store"
	fi

	echo $opts
}


function update_default_docker_file()
{
	FULL_DOCKER_OPTIONS=$(create_new_options)
	msg_info "New docker options : $FULL_DOCKER_OPTIONS"
	# Check systemd ou init service manager

	sed -i.bak "s/\([#]*DOCKER_OPTS.*\)/#\1/" $DEFAULT_DOCKER_FILE_INIT
    echo -e DOCKER_OPTS=\"$FULL_DOCKER_OPTIONS\" >> $DEFAULT_DOCKER_FILE_INIT

    
}

function restart_docker()
{
	n=$(ps aux | grep -v grep | grep -c docker)

	if [ "$n" -gt 1 ]; then
		service docker stop
	fi

	msg_info "Restart service docker"
    service docker start &> /tmp/restart_docker.out
    rep=$?
    
    msg_info "Restart output $(cat /tmp/restart_docker.out)."
    if [ $rep -ne 0 ]; then
        msg_err "Fail to restart docker service."
        msg_err "$(docker version)"
    fi	
}

function move_docker_directory()
{
	msg_info "Change storage docker directory to $DOCKER_STORE_DIRECTORY."

	if [ ! -d $DOCKER_STORE_DIRECTORY ]; then
		msg_info "Not found DOCKER_STORE_DIRECTORY $DOCKER_STORE_DIRECTORY"
	fi

	# Stop docker, no container running
	docker stop $(docker ps -aq)
	service docker stop
 
	# archive directory
	tar -zcC /var/lib docker > /tmp/var_lib_docker-$(date +"%Y%d%m").tar.gz
 
	# move to new destination
	mv /var/lib/docker ${DOCKER_STORE_DIRECTORY}/docker

	if [ $? -ne 0 ]; then
		msg_info "Force move docker directory."
		mv /var/lib/docker{,-old}
	fi
 
	# create symbolic link to default destination
	ln -s ${DOCKER_STORE_DIRECTORY}/docker /var/lib/docker

	msg_info "Successfull change storage directory docker to $DOCKER_STORE_DIRECTORY"
}

# ======================================================================== #

################################
## Install Docker             ##
################################

function install_docker()
{
	msg_info "Install docker $DOCKER_VERSION"

    if [ $(docker --version &>/dev/null; echo $?) -eq 0 ]; then
        msg_info "Docker is already install, remove this version $(docker --version)"
        service docker stop
        apt-get --purge remove docker
    fi
    
    msg_info "Install Docker version ${DOCKER_VERSION}"
    if [ "$DOCKER_VERSION" = "latest" ]; then
    	yes N | curl -fsSL https://get.docker.com/ |  sh
    else 
    	DOCKER_VERSION=$(update_version_with_os)
    	msg_info "Updated Docker version ${DOCKER_VERSION}"
    	yes N | curl -fsSL https://get.docker.com/ | sed -e "s/docker-engine/--force-yes docker-engine=${DOCKER_VERSION}/" | sh
    fi

    current_user=$(whoami)
    usermod -aG docker ${current_user}

    msg_info "Successfull install Docker version : docker --version"

    if [ "$DOCKER_STORE_DIRECTORY" != "$NONE" ]; then
    	move_docker_directory
    fi
}

################################
## Install Docker machine     ##
################################

function install_docker_machine()
{
	msg_info "Install docker-machine $DOCKER_MACHINE_VERSION"

	msg_info "CMD : curl -L https://github.com/docker/machine/releases/download/v$DOCKER_MACHINE_VERSION/docker-machine-${OS_NAME}-${OS_ARCHI} >/usr/local/bin/docker-machine "
	
	curl -L https://github.com/docker/machine/releases/download/v$DOCKER_MACHINE_VERSION/docker-machine-${OS_NAME}-${OS_ARCHI} >/usr/local/bin/docker-machine && \
	chmod +x /usr/local/bin/docker-machine

	msg_info "Successfull install docker-machine $(docker-machine -version)"
}


################################
## Install Docker compose     ##
################################

function install_docker_compose()
{
	msg_info "Install docker-compose $DOCKER_COMPOSE_VERSION"

	msg_info "CMD : curl -L https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-${OS_NAME}-${OS_ARCHI} > /usr/local/bin/docker-compose"
	curl -L https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-${OS_NAME}-${OS_ARCHI} > /usr/local/bin/docker-compose && \
	chmod +x /usr/local/bin/docker-compose

	msg_info "Successfull install docker-compose $(docker-compose -version)"
	
}


################################
## Install change options     ##
################################

function change_options_docker()
{
    # run script to configure docker engine options
    msg_info "Update docker engine with options $DOCKER_OPTIONS."

	update_default_docker_file
    
	restart_docker
    
    msg_info "$(docker version)"
    msg_info "End of docker engine configuration."

    if [ "$DOCKER_STORE_DIRECTORY" != "$NONE" ]; then
    	move_docker_directory
    fi
}



################################
## Main     ##
################################


if [ "$1" == "--dry-run" ]; then
    echo -e "function loaded"
    echo -e "You can do:"
    echo -e "\tsource /scripts/install_configure_docker.sh --dry-run "
    echo -e "\tinstall_docker"
    echo -e "\t\texport DOCKER_VERSION, to not install latest."
    echo -e "\t\texport DOCKER_STORE_DIRECTORY, to change /var/lib/docker."

    echo -e "\tchange_options_docker"
    echo -e "\t\texport DOCKER_REGISTRIES, set IP:port separated by comma."
    echo -e "\t\texport DOCKER_NEW_HOST, set host : yes use deafault or full option."
    echo -e "\t\texport DOCKER_STORAGE, set storage name, replace defaults."
    echo -e "\t\texport DOCKER_OPTIONS, set docker engine options."
    
    echo -e "\tinstall_docker_machine"
    echo -e "\t\texport DOCKER_MACHINE_VERSION, to not install latest."
    echo -e "\tinstall_docker_compose"
    echo -e "\t\texport DOCKER_COMPOSE_VERSION, to not install latest."
    echo -e ""
    echo -e "\tPrint variable print_variable"
    echo -e ""
	
	print_variable

else
	install_docker
	install_docker_compose	
fi