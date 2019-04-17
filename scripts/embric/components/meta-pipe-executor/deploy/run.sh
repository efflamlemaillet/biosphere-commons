#!/bin/bash -xe


_run(){
	METAPIPE_GIT="https://gitlab.com/uit-sfb/newpan-tools.git"
	GIT_DIR=$(basename $METAPIPE_GIT .git)
	
	#. /etc/profile.d/$COMPONENT_NAME-env.sh
	touch /etc/profile.d/$COMPONENT_NAME-env.sh
	export MASTER_HOSTNAME=$(hostname)
	export METAPIPE_HOME=$(ss-get mount_point_path)'/metapipe'
	mkdir -p $METAPIPE_HOME
	
	echo "export METAPIPE_HOME='/var/lib/metapipe'" >> /etc/profile.d/$COMPONENT_NAME-env.sh
	DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
	git clone $METAPIPE_GIT
	envsubst '$MASTER_HOSTNAME' < ${DIR}/../config/exec_conf.json.template > ./newpan-tools/exec_conf.json
	systemctl restart docker
	cd $GIT_DIR
	echo "admin" > minio.pswd
	echo "password" >> minio.pswd
	mkdir -p $METAPIPE_HOME/.secret/local/minio/
	cp minio.pswd $METAPIPE_HOME"/.secret/local/minio/"

	./example/services/minio/minio.sh start 
	./example/services/authService/auth.sh start
	./example/services/jobManager/jobman.sh start
	./example/services/executor/executor.sh start -e ./exec_conf.json
}

_run

