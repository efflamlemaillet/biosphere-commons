source /scripts/cluster/cluster_install.sh

install_elasticluster(){
    elastic_dir="/opt/elasticluster"
    
    if isubuntu; then
        apt-get update -y
        apt-get install -y gcc g++ git libc6-dev libffi-dev libssl-dev python-dev git
    elif iscentos; then
        yum update -y
        yum install -y gcc gcc-c++ git libffi-devel openssl-devel python-devel git
    fi
    
    pip install --upgrade 'pip>=9.0.0'
    pip install --upgrade setuptools
    pip install backports.ssl_match_hostname
    
    mkdir $elastic_dir
    cd $elastic_dir
    git clone https://github.com/gc3-uzh-ch/elasticluster.git src
    cd src
    
    pip install -e .
}

config_elasticluster(){
    echo "library = /usr/share/ansible:library" >> /etc/ansible/ansible.cfg
    sed -i 's|#host_key_checking.*|host_key_checking = False|' /etc/ansible/ansible.cfg
    
    #master
    msg_info "Waiting ip of master to be ready."
    MASTER_HOSTNAME=master
    ss-get --timeout=3600 $MASTER_HOSTNAME:ip.ready
    MASTER_IP=$(ss-get $MASTER_HOSTNAME:ip.ready)
    echo "[slurm_master]" >> /etc/ansible/hosts
    echo $MASTER_IP >> /etc/ansible/hosts
    
    #slave
    echo "" >> /etc/ansible/hosts
    echo "[slurm_worker]" >> /etc/ansible/hosts
    for (( i=1; i <= $(ss-get slave:multiplicity); i++ )); do
        msg_info "Waiting ip of slave to be ready."
        ss-get --timeout=3600 $SLAVE_NAME.$i:ip.ready
        SLAVE_IP=$(ss-get $SLAVE_NAME.$i:ip.ready)
        echo $SLAVE_IP >> /etc/ansible/hosts
    done
    
    playbook_dir=$elastic_dir/src/elasticluster/share/playbooks
}

install_slurm(){
    ansible-playbook $playbook_dir/roles/slurm.yml
}