#!/bin/bash

PROFILECONF=/etc/profile.d/ebame18-longread-metagenomics.sh
DATADIR=/mnt/ebame18
sudo mkdir -p $DATADIR
chown ubuntu.ubuntu $DATADIR

# get Kraken data

URL_KRAKEN=https://ccb.jhu.edu/software
#URL_KRAKEN=http://10.158.16.7/ebame-cache

cd $DATADIR
wget $URL_KRAKEN/kraken/dl/minikraken_20171019_8GB.tgz
tar xvfz minikraken_20171019_8GB.tgz
echo 'export KRAKEN_DEFAULT_DB=/mnt/ebame18/minikraken_20171019_8GB' >> $PROFILECONF


# get Kraken2 data

URL_KRAKEN2=https://refdb.s3.climb.ac.uk
#URL_KRAKEN2=http://10.158.16.7/ebame-cache

mkdir -p $DATADIR/kraken2-microbial-fatfree/
cd $DATADIR/kraken2-microbial-fatfree/
wget $URL_KRAKEN2/kraken2-microbial/hash.k2d
wget $URL_KRAKEN2/kraken2-microbial/opts.k2d
wget $URL_KRAKEN2/kraken2-microbial/taxo.k2d
wget $URL_KRAKEN2/kraken2-microbial/database.kraken
wget $URL_KRAKEN2/kraken2-microbial/database2500mers.kraken
wget $URL_KRAKEN2/kraken2-microbial/database2500mers.kmer_distrib
echo 'export KRAKEN2_DEFAULT_DB=/mnt/ebame18/kraken2-microbial-fatfree' >> $PROFILECONF

# get Nanopore data

URL_NANOPORE=http://nanopore.s3.climb.ac.uk
#URL_NANOPORE=http://10.158.16.7/ebame-cache/nanopore

cd $DATADIR
wget $URL_NANOPORE/Kefir_RBK.fastq
