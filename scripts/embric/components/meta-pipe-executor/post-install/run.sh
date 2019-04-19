#!/bin/bash -xe

check_rootfs_size(){
min_needed_size=$1
root_fs_size=$(df  / -BG --output="avail" |tail -n+2|tr -s ' ' |xargs)
smallest=$(cat <<-EOF | sort -rh |tail -n+2
$root_fs_size
$min_needed_size
EOF
)
if [[ "$smallest" != "$min_needed_size" ]]; then
	return 1		
fi
return 0

}
_run(){

        systemctl restart docker

	DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

	METAPIPE_GIT="https://gitlab.com/uit-sfb/newpan-tools.git"
        GIT_DIR=$(basename $METAPIPE_GIT .git)

	git clone $METAPIPE_GIT
	export METAPIPE_SBIN_DIR=$DIR/$GIT_DIR

	cenv_lines=$(cat <<-EOF
export METAPIPE_SBIN_DIR=$DIR/GIT_DIR
EOF
)
	
#on essaie de placer métapipe sur le root fs avec 80GO au mois de libre )
#si on y arrive on prévient la phase deploy en ajoutant la ligne METAPIPE_HOME dans le env.sh du COMPONENT_NAME

	check_rootfs_size

	if [[ $biggest != $size ]];then
		export METAPIPE_HOME='/var/lib/metapipe'
        	cenv_lines=$(cat <<-EOF
export METAPIPE_HOME='/var/lib/metapipe'
$cenv_lines
EOF
		cd $METAPIPE_SBIN_DIR/example/services/executor/
		./downloadPackages.sh
 
)
	fi


echo $cenv_lines > /etc/profile.d/$COMPONENT_NAME-env.sh 

	

}
_run
