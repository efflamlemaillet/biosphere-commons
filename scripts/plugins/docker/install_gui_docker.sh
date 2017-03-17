#! /bin/bash

## Library to install GUI on docker from name

SCRIPT=`basename "$0"`
NAME_GUI=$1
CONTAINER_NAME=frontend_$NAME_GUI
PORT=${PORT:-9000}
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


################################
## Install frontend           ##
################################


function portainer()
{
    
    mkdir -p $DIR_DATA $DIR_CERTS
    docker run -d --name $ONTAINER_NAME \
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
    echo -e "Script to install frontend manager Docker"
    echo -e "$SCRIPT frontend-name-available <options>"
    echo -e "To change port : export PORT:8080."
    echo -e "List available"
    echo -e "\t portainer : install portainer, no yet implemented to access on docker swarm manager"

}


# Pas de paramètre
[[ $# -lt 1 ]] && ( echo "Fail to run script"; usage)

# -o : options courtes
# -l : options longues
# options=$(getopt -o h,m,s: -l help -- "$@")
# set -- $options

case "$1" in
   portainer) portainer
        break;;
   *) usage
	break;;
esac
