#! /bin/bash

## Library to install GUI on docker from name

SCRIPT=`basename "$0"`
NAME_GUI=$1
CONTAINER_NAME=frontend_$NAME_GUI
PORT=${PORT:-8080}
DIR=/ifb
DIR_DATA=/ifb/$NAME_GUI-data
DIR_CERTS=/ifb/$NAME_GUI-certs
LOG=/var/log/$NAME_GUI.log

SLIPSTREAM_CONTEXT=$( which ss-display &> /dev/null; echo $? )

msg_info(){
    echo -e "$@"
    if [ $SLIPSTREAM_CONTEXT -eq 0 ] ; then ss-display "$@" ; fi
}


msg_err(){
    echo -e "ERROR: $@"
    if [ $SLIPSTREAM_CONTEXT -eq 0 ] ; then ss-abort "ERROR: $@" ; fi
}

function clean()
{
    docker stop $CONTAINER_NAME
    docker rm -v $CONTAINER_NAME
}

################################
## Install frontend           ##
################################


function portainer()
{
 
    clean $CONTAINER_NAME
    mkdir -p $DIR_DATA $DIR_CERTS 2> /dev/null
 
   docker run -d \
            -p $PORT:9000 \
            -v $DIR_CERTS:/certs \
            -v $DIR_DATA:/data \
            -v /var/run/docker.sock:/var/run/docker.sock \
            --name $CONTAINER_NAME \ 
            portainer/portainer
    
    msg_info "Running Containers $NAME_GUI"
    docker ps
}

################################
## Main function              ##
################################

function usage()
{
    echo -e "Script to install frontend manager Docker\n"
    echo -e "\t$SCRIPT frontend-name-available <options>"
    echo -e "\tTo change port : export PORT:8080."
    echo -e "\n\tList available"
    echo -e "\t\t portainer : install portainer, no yet implemented to access on docker swarm manager.\n"

}


# Pas de paramètre
# [[ $# -lt 1 ]] && ( echo "Fail to run script"; usage)

# -o : options courtes
# -l : options longues
# options=$(getopt -o h,m,s: -l help -- "$@")
# set -- $options

case "$1" in
   portainer) 
	portainer
        ;;
   *) usage
	;;
esac
