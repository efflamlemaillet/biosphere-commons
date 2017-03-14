#------------miniconda install----------------
msg_info()
{
    ss-display "test" 1>/dev/null 2>/dev/null
    ret=$?
    if [ $ret -ne 0 ]; then
        echo -e "$@"
    else
        echo -e "$@"
        ss-display "$@"
    fi
}

miniconda_pkg()
{
    msg_info ""    
    msg_info "Installing MiniConda..."
    miniconda_dir=/opt/miniconda
    miniconda_version="3"
    miniconda_subversion="4.2.12"
    miniconda_bin=$miniconda_dir/miniconda$miniconda_version-$miniconda_subversion/bin
    
    mkdir $miniconda_dir
    wget -O $miniconda_dir/Miniconda$miniconda_version-$miniconda_subversion-Linux-x86_64.sh https://repo.continuum.io/miniconda/Miniconda$miniconda_version-$miniconda_subversion-Linux-x86_64.sh
    bash $miniconda_dir/Miniconda$miniconda_version-$miniconda_subversion-Linux-x86_64.sh -b -p  $miniconda_dir/miniconda$miniconda_version-$miniconda_subversion
    rm -rf $miniconda_dir/Miniconda$miniconda_version-$miniconda_subversion-Linux-x86_64.sh
    
    ln -s $miniconda_bin/conda $miniconda_dir/conda
    echo "export PATH=$miniconda_bin:\$PATH" > /etc/profile.d/miniconda.sh
    #exec /bin/bash
    
    msg_info ""
    msg_info "Updating MiniConda..."
    $miniconda_bin/conda update conda
    $miniconda_bin/conda install -y anaconda-client
    msg_info ""
    msg_info "MiniConda is installed and updated."
}

conda_install()
{
    miniconda_dir=/opt/miniconda
    #Warning Application Parameters required: miniconda.package and miniconda.channel
    tools_name=$(ss-get miniconda.package)
    channels_name=$(ss-get miniconda.channel)
    if [ $tools_name == "none" ]; then return ; fi;
    if [ $channels_name == "none" ]; then
        add_channels="" 
    else
        add_channels=$(echo $channels_name | sed -e 's/^/-c /g' | sed -e 's/,/ -c /g')
    fi
    
    add_tools=$(echo $tools_name | sed -e 's/,/ /g;s/;/ /g')
    
    msg_info ""    
    msg_info "Conda will be RUN and INSTALL $add_tools.."
    
    $miniconda_dir/conda install -y $add_channels $add_tools 2>/tmp/miniconda_error_message.txt
    ret=$?
    #msg_info "$(cat /tmp/miniconda_error_message.txt)"
     
    if [ $ret -ne 0 ]; then
        ss-abort "$(cat /tmp/miniconda_error_message.txt)"
    fi
}

echo "function loaded"
echo "You can do:"
echo "    source /scripts/conda/sge_install.sh"
echo "    miniconda_pkg"
echo "    conda_install"