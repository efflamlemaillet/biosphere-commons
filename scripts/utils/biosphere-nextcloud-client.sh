#!/bin/bash

NEXTCLOUD_HOST=10.158.16.80
LOCUSER='ubuntu'
LOCUSER_HOME=`eval echo "~$LOCUSER"`

# Install client for Ubuntu
cat <<EOF | sudo debconf-set-selections
davfs2 davfs2/suid_file boolean true
EOF

sudo apt-get -y install davfs2

# Configure server certificate
openssl s_client -connect $NEXTCLOUD_HOST:443 -showcerts </dev/null 2>/dev/null | openssl x509 -outform PEM > mycertificate.pem
sudo cp mycertificate.pem /etc/davfs2/certs/mycertificate.pem
sudo sed -i 's/# trust_server_cert/trust_server_cert \/etc\/davfs2\/certs\/mycertificate.pem/' /etc/davfs2/davfs2.conf

# Configure user
sudo adduser $LOCUSER davfs2
mkdir $LOCUSER_HOME/nextcloud
chown -R $LOCUSER:$LOCUSER $LOCUSER_HOME/nextcloud
mkdir $LOCUSER_HOME/.davfs2
sudo cp  /etc/davfs2/secrets $LOCUSER_HOME/.davfs2/secrets
sudo chown -R $LOCUSER:$LOCUSER $LOCUSER_HOME/.davfs2
sudo chmod 600 $LOCUSER_HOME/.davfs2/secrets

# Configure mount
echo "https://$NEXTCLOUD_HOST/remote.php/webdav/ $LOCUSER_HOME/nextcloud davfs user,rw,noauto 0 0" | sudo tee -a /etc/fstab
