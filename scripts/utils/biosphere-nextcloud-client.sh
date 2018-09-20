#!/bin/bash

NEXTCLOUD_HOST=10.158.16.80

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
sudo adduser $USER davfs2
mkdir ~/nextcloud
mkdir ~/.davfs2
sudo cp  /etc/davfs2/secrets ~/.davfs2/secrets
sudo chown $USER:$USER ~/.davfs2/secrets
chmod 600 ~/.davfs2/secrets

# Configure mount
echo "https://$NEXTCLOUD_HOST/remote.php/webdav/ /home/$USER/nextcloud davfs user,rw,auto 0 0" | sudo tee -a /etc/fstab
