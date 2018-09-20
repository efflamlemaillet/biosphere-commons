#!/bin/bash

# for Ubuntu
apt-get -y install davfs2

sudo adduser $USER davfs2

mkdir ~/nextcloud
mkdir ~/.davfs2
sudo cp  /etc/davfs2/secrets ~/.davfs2/secrets
sudo chown $USER:$USER ~/.davfs2/secrets
chmod 600 ~/.davfs2/secrets

sudo echo "https://10.158.16.80/remote.php/webdav/ /home/ubuntu/nextcloud davfs user,rw,auto 0 0" >> /etc/fstab
