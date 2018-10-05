#!/bin/bash
# to run as root in an ubuntu 18.04 (requires python3)

#
# Pre-install

# Install R on Bionic
add-apt-repository "deb https://pbil.univ-lyon1.fr/CRAN/bin/linux/ubuntu bionic-cran35/"
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9

#
# Install packages
apt-get update
apt install -y curl  libgit2-dev libssl-dev
apt install -y r-base-dev

#
# Post-install

# Install python package
#apt install python3-pip
#pip3 install --upgrade pip
pip3 install matplotlib cobra panda 

# Install Jupyter
pip3 install jupyter

# Install R packages
R -e "install.packages(c('Matrix', 'igraph', 'huge', 'BiocInstaller', 'gtools', 'devtools'))"
R -e "source('http://bioconductor.org/biocLite.R');biocLite('phyloseq')"
R -e "library('devtools');install_github(\"zdk123/SpiecEasi\")"

# Install R in Jupyter
# https://irkernel.github.io/docs/IRkernel/0.7/
R -e "install.packages(c('repr', 'IRdisplay', 'evaluate', 'crayon', 'pbdZMQ', 'devtools', 'uuid', 'digest'))"
R -e "library(devtools);install_github('IRkernel/IRkernel',force=TRUE);IRkernel::installspec(user = FALSE)"

#
# Deployment

# Run jupyter
mkdir -p /var/log/jupyter
jupyter notebook --port 80 --allow-root --generate-config
CONF=/root/.jupyter/jupyter_notebook_config.py
echo "c.NotebookApp.port = 80" >> $CONF
echo "c.NotebookApp.ip = \"0.0.0.0\" " >> $CONF
JUPYTER_TOKEN=`openssl rand -hex 32`
echo "JUPYTER_TOKEN = ${JUPYTER_TOKEN}"
echo "c.NotebookApp.token = '${JUPYTER_TOKEN}' " >> $CONF
echo "c.NotebookApp.open_browser = False " >> $CONF
echo "c.NotebookApp.allow_origin = '*' " >> $CONF

jupyter notebook --allow-root > /var/log/jupyter/jupyter.log &
