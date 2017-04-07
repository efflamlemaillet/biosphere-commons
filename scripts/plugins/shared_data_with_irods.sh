#! /bin/bash -xe

# Library command to access, shared, save and move data from irods user account.
# To use without paramters on function, create a configuration file and export the path 
# export CONF_SHARED_DATA_FILE='<path_to_the_file>'

# Content key=value
# USERNAME=root
# IRODS_SESSION_NAME=<requiered>
# IRODS_DOMAINE_NAME=<requiered>
# IRODS_SOURCE_ANALYSIS_DIRECTORY=<optional | input>
# COPY_LOCAL_DIRECTORY=<optional | $HOME/mydisk>
# PASS=

function shared_space_directory_path()
{
	user=$(get_username $1)
	echo "$(getent passwd $user | cut -d: -f6)/my_shared_space"
}

function shared_space_directory_dir_input()
{
	user=$(get_username $1)
	echo "$(getent passwd $user | cut -d: -f6)/my_shared_space/input"
}

function get_username()
{
	if [ "X$1" != "X" ]; then USERNAME=$1 ; else USERNAME=${USERNAME:-root} ; fi
	echo $USERNAME
}

function get_user_home()
{
	user=$(get_username $1)
	echo $(getent passwd $USERNAME | cut -d: -f6)
}

function get_local_workdir()
{
	user=$(get_username $1)
	DEFAULT="$(get_user_home)/mydisk"
	if [ "X$2" != "X" ];	then LOCAL_DIR=$2 ; else LOCAL_DIR=${LOCAL_DIR:-$DEFAULT} ; fi
	echo $LOCAL_DIR
}

#####################################
## Install iRODS-clients           ##
#####################################

function install_irods_client()
{
	echo "DEBUG f-install irods"

	echo "DEBUG set variables"	
	PROTOCOLE_REPO=ftp://ftp.renci.org/pub/irods/releases/
	IRODS_CLIENT_VERSION=4.1.10
	IRODS_PACKAGE=irods-icommands-${IRODS_CLIENT_VERSION}-ubuntu14-x86_64.deb

	LOG1=/var/log/irods_package_install
	LOG2=/var/log/irods_dependancies_install

	ss-display "Install iRODS client version $IRODS_CLIENT_VERSION "
	ss-display "Download package ${IRODS_PACKAGE}"
	wget ${PROTOCOLE_REPO}${IRODS_CLIENT_VERSION}/ubuntu14/${IRODS_PACKAGE} -P /tmp
	wget ${PROTOCOLE_REPO}${IRODS_CLIENT_VERSION}/checksums.txt -P /tmp

	#ss-display "Check md5sum value"
	#sed  -n "/${IRODS_PACKAGE}/{n;p}" /tmp/checksums.txt | awk -v var="${IRODS_PACKAGE}" '{ print $2"  "var }' | \
	#    md5sum -c --status
	#rep=$?
	#ss-display "Check package $IRODS_PACKAGE downloaded : exit value $rep." 

	ss-display "Install package"
	dpkg -i /tmp/$IRODS_PACKAGE 1> $LOG1.out 2> $LOG1.err
	apt-get -f install 1> $LOG2.out 2> $LOG2.err

	ss-display "End install iRODS client"
	ss-display "Test $(which iinit)"
}

#####################################
## Configure iRODS-clients         ##
#####################################

# Create irods configuration file
# 3 parameter : username (default root), irods.session.name, irods.domaine.name
function configure_irods_client()
{
	echo "DEBUG f-configure irods"
	echo "DEBUG set variables"

	# Set with export variable or parameters
	if [ "X$1" != "X" ]; then USERNAME=$1 ; else USERNAME=${USERNAME:-root} ; fi
	if [ "X$2" != "X" ]; then IRODS_SESSION_NAME=$2 ; else IRODS_SESSION_NAME=$IRODS_SESSION_NAME ; fi
	if [ "X$3" != "X" ]; then IRODS_DOMAINE_NAME=$3 ; else IRODS_DOMAINE_NAME=$IRODS_DOMAINE_NAME ; fi

	if [ "X$USERNAME" = "X" ]; then ss-display "ERROR-PLUGIN : missing username value "; exit 1; fi
	if [ "X$IRODS_SESSION_NAME" = "X" ]; then ss-display "ERROR-PLUGIN : missing IRODS_SESSION_NAME value "; exit 1; fi
	if [ "X$IRODS_DOMAINE_NAME" = "X" ]; then ss-display "ERROR-PLUGIN : missing IRODS_DOMAINE_NAME value "; exit 1; fi
	
	IRODS_DIR="$(get_user_home $USERNAME)/.irods"
	IRODS_CONF=$IRODS_DIR/irods_environment.json

    ss-display "Create configuration iRODS client $IRODS_CONF."
    
    mkdir -p $IRODS_DIR
    
    echo "DEBUG Write conf file "

    echo -e "{ " >> $IRODS_CONF
    echo -e "\"irods_host\": \"irods01.france-bioinformatique.fr\", " >> $IRODS_CONF
    echo -e "\"irods_port\": 1247, " >> $IRODS_CONF
    echo -e "\"irods_default_resource\": \"rootResc\", " >> $IRODS_CONF
    echo -e "\"irods_home\": \"/${IRODS_DOMAINE_NAME}/home/${IRODS_SESSION_NAME}\", " >> $IRODS_CONF
    echo -e "\"irods_cwd\": \"/${IRODS_DOMAINE_NAME}/home/${IRODS_SESSION_NAME}\", " >> $IRODS_CONF
    echo -e "\"irods_user_name\": \"${IRODS_SESSION_NAME}\", " >> $IRODS_CONF
    echo -e "\"irods_zone_name\": \"${IRODS_DOMAINE_NAME}\", " >> $IRODS_CONF
    echo -e "\"irods_client_server_negotiation\": \"request_server_negotiation\", " >> $IRODS_CONF
    echo -e "\"irods_client_server_policy\": \"CS_NEG_REFUSE\", " >> $IRODS_CONF
    echo -e "\"irods_encryption_key_size\": 32, " >> $IRODS_CONF
    echo -e "\"irods_encryption_salt_size\": 8, " >> $IRODS_CONF
    echo -e "\"irods_encryption_num_hash_rounds\": 16, " >> $IRODS_CONF
    echo -e "\"irods_encryption_algorithm\": \"AES-256-CBC\", " >> $IRODS_CONF
    echo -e "\"irods_default_hash_scheme\": \"SHA256\", " >> $IRODS_CONF
    echo -e "\"irods_match_hash_policy\": \"compatible\"  " >> $IRODS_CONF
    echo -e "} " >> $IRODS_CONF
    
    
    ss-display "End configure file."
    ss-display "$(cat $IRODS_CONF)"

    ss-display "Init iRODS client"
    yes $PASS | iinit

}


#####################################
## Mount directory                 ##
#####################################

function mount_irods_directory()
{
	echo "DEBUG f-mount-dir"
	
	MOUNT_DIR=$(shared_space_directory_path $USERNAME)

	mkdir -p $MOUNT_DIR
	irodsFs $MOUNT_DIR

	if [ $? -eq 0 ]; then echo "DEBUG succes mount"; else echo "DEBUG FAIL mount"; fi

}

#####################################
## Copy data from iRODS to local   ##
#####################################

function copy_data_sharedspace_to_local()
{
	echo "DEBUG f-copy data"

	USERNAME=$(get_username $1)

	SOURCE=input
	DEST=$(get_local_workdir $USERNAME)

	ss-display "Copy all contents directory $SOURCE in $DEST"
	iget $SOURCE $DEST

	if [ $? -eq 0 ]; then echo "DEBUG succes copy"; else echo "DEBUG FAIL copy"; fi
}


#####################################
## Save data from local to iRODS   ##
#####################################



#####################################
## Main                            ##
#####################################


if [ "$1" == "--dry-run" ]; then
    echo "function loaded"
    echo "You can do:"
    echo "    source /scripts/shared_data_with_irods.sh --dry-run "
    echo "    install_irods_client"
    echo "    configure_irods_client"
    echo "    mount_irods_directory"
    echo "    copy_data_sharedspace_to_local"

else
	# Check lock configuration shared data exist
	if [ -f $CONF_SHARED_DATA_FILE ]; then

		echo "DEBUG main"
		install_irods_client 
		configure_irods_client
		mount_irods_directory
		copy_data_sharedspace_to_local
	fi

	echo "DEBUG no conf set $CONF_SHARED_DATA_FILE"
fi




