#! /bin/bash

NAME=$1
PORT=$2
NAME_CONTAINER=${NAME}-frontend
log=/var/log/$NAME.log

function msglog() 
{
     echo -e "$@" | tee -a $log
}

function msgerr() 
{ 
     msglog "================== \n ERROR $@" | tee -a $log
}



function portainer()
{
    msglog "Run GUI portainer on port $PORT with name $NAME_CONTAINER"
    msglog "docker run -d --name $NAME_CONTAINER -p $PORT:9000 -v /var/run/docker.sock:/var/run/docker.sock portainer/portainer"

    docker run -d --name $NAME_CONTAINER -p $PORT:9000 -v /var/run/docker.sock:/var/run/docker.sock portainer/portainer
}


# MAIN

msglog "Script to install GUI for managing docker containers."

usage="""
[gui_name] [port] \n
All parameters are required. \n
GUI supported : \n
\t portainer, not Swarm mode\n
\n
""" 

# Check command line
if [ "X$1" == "X-h" -o "X$1" == "X--help" ]; then
    msglog "$(echo -e $usage)"
    exit 0
fi


if [ $# -ne 2  ]; then
    msgerr "Missing parameters in command line"
    msglog "$(echo -e $usage)"
    exit 0
fi

case $1 in
    "portainer") portainer ;;
    *) msglog "GUI name invalid $name" ; msglog "$(echo -e $usage)" ;;
esac

