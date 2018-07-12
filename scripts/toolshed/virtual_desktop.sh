source ./os_detection.sh

install_x2go(){
    if iscentos 7; then
        rpm -ivh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-9.noarch.rpm
        yum -y install x2goserver-xsession
        yum -y groupinstall "Xfce"
        
    elif iscentos 6; then
        wget http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
        rpm -ivh epel-release-6-8.noarch.rpm
        yum -y install x2goserver
        yum -y install x2goserver-xsession
        yum -y groupinstall Xfce
        yum -y groupinstall Fonts
        yum -y install xorg-x11-fonts-Type1 xorg-x11-fonts-misc
        
    elif isubuntu 14; then
        apt-get -y install x2goserver x2goserver-xsession
        apt-get -y install xfce4
        #apt-get -y install kde-plasma-desktop
    elif isubuntu 16; then
        apt-get -y install software-properties-common
        add-apt-repository ppa:x2go/stable -y
        apt-get update
        apt-get -y install x2goserver x2goserver-xsession
        apt-get -y install xfce4
    else
        echo "unsupported os"
        exit
    fi
}