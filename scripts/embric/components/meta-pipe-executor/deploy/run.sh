#!/bin/bash -xe


_run(){
	METAPIPE_GIT="https://gitlab.com/uit-sfb/newpan-tools.git"
	GIT_DIR=$(basename $METAPIPE_GIT .git)

	. /etc/profile.d/$COMPONENT_NAME-env.sh

	if [[ ! ( -z ${METAPIPE_HOME+x} && -d METAPIPE_HOME ) ]];then
		mp_id="$(ss-get dependencies_fs_id)"
		mp_options="$(ss-get dependencies_fs_options)"
		mp_type="$(ss-get dependencies_fs_type)"
		mp_path="$(ss-get dependencies_mount_point)"
		export METAPIPE_HOME=$mp_path'/metapipe'
		mkdir -p $METAPIPE_HOME
		echo "export METAPIPE_HOME=\"$METAPIPE_HOME\"" >> /etc/profile.d/$COMPONENT_NAME-env.sh
		mount -t $mp_type -o $mp_options $mp_id $mp_path
	fi
	

	DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
	export MASTER_HOSTNAME=$(hostname)
	envsubst '$MASTER_HOSTNAME' < ${DIR}/../config/exec_conf.json.template > $METAPIPE_SBIN_DIR/newpan-tools/exec_conf.json
	systemctl restart docker
	cd $GIT_DIR

	$METAPIPE_SBIN_DIR/example/services/minio/minio.sh start -c admin password 
	$METAPIPE_SBIN_DIR/example/services/authService/auth.sh start
	$METAPIPE_SBIN_DIR/example/services/jobManager/jobman.sh start
	$METAPIPE_SBIN_DIR/example/services/executor/executor.sh start -e ./exec_conf.json
}

_run

