start_fire(){
	if ! systemctl -q is-active firewalld ;then

		echo "echo rc $? : $is_started"	
		systemctl start firewalld
	else 
		echo "rc $? do nothin !"	
	fi
}

start_fire
