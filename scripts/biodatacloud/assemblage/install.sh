create_tools_dir(){
    # Pas de paramètre 
    if [[ $# -lt 1 ]]; then
        echo "This function expects a directory in argument !"
    else    
        tools_dir=$1
        
        if [ ! -d "$tools_dir" ]; then
            mkdir -p $tools_dir
        fi
        if grep -q $tools_dir "/etc/profile.d/asm.sh" ; then
            echo "PATH ready"
        else
        	echo "export PATH=\$PATH:$tools_dir" > /etc/profile.d/asm.sh
        fi       
    fi

}

install_canu(){
    tool_id="canu" 
    tool_bin="canu" 
    tool_version="1.1"
    tool_url="https://github.com/marbl/canu/archive"
    tool_ark="${tool_id}-${tool_version}"
    tool_pkg="v${tool_version}.tar.gz" 

    wget http://people.centos.org/tru/devtools-2/devtools-2.repo -O /etc/yum.repos.d/devtools-2.repo
    # Installation des composantes nécessaires pour la compilation C++
    # (Version par defaut de gcc dans CentOS:4.4.7, alors que Canu requiert 4.5+)
    yum -y install devtoolset-2-gcc-c++
    yum -y install devtoolset-2-binutils

    # Fetch the tool pkg
    wget "${tool_url}/${tool_pkg}" 
    # install the tool 
    tar xzf ${tool_pkg}
    rm -rf ${tool_pkg}
    cd "${tool_ark}/src"
    scl enable devtoolset-2 bash
    make
    
    cp -r ../Linux-amd64 $tools_dir/

    if grep -q $tools_dir/Linux-amd64/bin "/etc/profile.d/ifb.sh" ; then
        echo "PATH ready"
    else
    	echo "export PATH=\$PATH:$tools_dir/Linux-amd64/bin" > /etc/profile.d/canu.sh
    fi
}

install_lordec(){
    tool_id="LoRDEC" 
    tool_bin="lordec" 
    tool_version="0.6"
    tool_url="http://www.atgc-montpellier.fr/download/sources/lordec" 
    tool_pkg="${tool_id}-${tool_version}"
    tool_ark="${tool_pkg}.tar.gz"

    dep_id="gatb-core"
    dep_version="1.1.0"

    # Librairie nécessaire pour traiter les fichiers zippes (?)
    yum -y install zlib-devel
    ## Librairie necessaire pour la parallelisation
    yum -y install boost-devel
    ## Ajout du repository de dev pour centOS
    wget http://people.centos.org/tru/devtools-2/devtools-2.repo -O /etc/yum.repos.d/devtools-2.repo
    # Installation des composantes nécessaires pour la compilation C++
    # (Version par defaut de gcc dans CentOS:4.4.7, alors que Lordec requiert 4.5+)
    yum -y install devtoolset-2-gcc-c++
    yum -y install devtoolset-2-binutils

    # Fetch and untar the tool package
    wget "${tool_url}/${tool_ark}" 
    tar xzf ${tool_ark}
    #rm -f ${tool_ark}
    cd "${tool_pkg}"
    # Modify gatb library version in Makefile
    sed -i "s/\(GATB_VER\)\=.*/\1\=${dep_version}/" Makefile
    sed -i "s/wget\ http\:\/\/gatb\-core\.gforge\.inria\.fr\/versions\/bin\/gatb\-core\-\$(GATB_VER)\-Linux\.tar\.gz/wget\ https\:\/\/github\.com\/GATB\/gatb\-core\/releases\/download\/v\$(GATB_VER)\/gatb\-core\-\$(GATB_VER)\-bin\-Linux\.tar\.gz/" Makefile
    sed -i "s/tar\ \-axf\ gatb\-core\-\$(GATB_VER)\-Linux\.tar\.gz/tar\ \-axf\ gatb\-core\-\$(GATB_VER)\-bin\-Linux\.tar\.gz/" Makefile
    # Fetch and install dependencies (gatb library)
    make install_dep
    #rm -f ${dep_id}-${dep_version}-Linux.tar.gz
    # Install tool via external shell running in the devtools environment
    scl enable devtoolset-2 bash
    make
    

    mkdir -p $tools_dir/lordec/bin
    cp -r gatb-core-1.1.0-Linux/* $tools_dir/lordec
    cp lordec-* $tools_dir/lordec/bin
    cp test-lordec.sh $tools_dir/lordec
    cp -r DATA/ $tools_dir/lordec

    if grep -q $tools_dir/lordec/bin "/etc/profile.d/ifb.sh"; then
        echo "PATH ready"
    else
    	echo "export PATH=\$PATH:$tools_dir/lordec/bin" > /etc/profile.d/lordec.sh
    fi
}

install_pipeline(){
    cp /scripts/biodatacloud/assemblage/lordec_2_fastq.pl $tools_dir
    cp /scripts/biodatacloud/assemblage/lordec_pipeline.pl $tools_dir
    chmod 755 $tools_dir/lordec_2_fastq.pl
    chmod 755 $tools_dir/lordec_pipeline.pl
}

create_readme(){
    # Pas de paramètre 
    if [[ $# -lt 1 ]]; then
        echo "This function expects a directory in argument !"
    else    
        README_DIR=$1
        
        if [ ! -d "$README_DIR" ]; then
            mkdir -p $README_DIR
        fi
            
        echo "Description:
                This is a wrapper script for LoRDEC [Salmela & Rivals, 2014].
                It corrects Long Reads using Short Reads by pipelining the commands
                that (1) create a DeBruijn Graph of the SR, (2) correct the LR, and (3)
                adapt a fitted set of the input quality values to the corrected sequences.
        Version:
                v.1.2.2
        Usage:
                $tools_dir/hybrid_correction -short <DIR> -long <DIR> -out <DIR> [options]
        Options:
                -short|sr DIR   : Short reads directory.
                -long|lr DIR    : Long reads directory.
                -output DIR     : Output directory.
                -k INT          : Kmer length to use in LoRDEC (Default = 19).
                -s INT          : Solid kmer abundance threshold to use in LoRDEC (Default = 3).
                -dbg FILE       : Don't create De Bruijn Graph anew, instead use existing FILE.
                -fasta          : Keep initial Lordec fasta output (Default: remove).

                -submit JSCHED  : Specify underlying job scheduler to use: PBS (Default) or SGE.
                -maxcores INT   : Use at most INT cores in cluster (Default: use all available).

                -gauge          : Measure resource usage (time, mem...) for each job (Default: don't).
                -help           : Display this description and exit.
        " > $README_DIR/HOWTO.README
    fi
}