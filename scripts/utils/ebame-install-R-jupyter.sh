#!/bin/bash
# to run as root
apt install -y curl  libgit2-dev libssl-dev

# Install R on Xenial
add-apt-repository "deb https://pbil.univ-lyon1.fr/CRAN/bin/linux/ubuntu xenial-cran35/"
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9

apt install -y r-base-dev

R -e "install.packages(c('Matrix', 'igraph', 'huge', 'BiocInstaller', 'gtools', 'devtools'))"

R -e "source('http://bioconductor.org/biocLite.R');biocLite('phyloseq')"

R -e "library(devtools);install_github(\"zdk123/SpiecEasi\")"

# Install R in Jupyter
# https://irkernel.github.io/docs/IRkernel/0.7/

R -e "install.packages(c('repr', 'IRdisplay', 'crayon', 'pbdZMQ', 'devtools'))"
R -e "library(devtools);install_github('IRkernel/IRkernel');IRkernel::installspec()"

#if necessary
#/opt/miniconda/miniconda3-4.2.12/bin/jupyter notebook --allow-root > /var/log/jupyter/jupyter.log &
