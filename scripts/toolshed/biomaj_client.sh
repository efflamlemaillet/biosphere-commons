source ./os_detection.sh

install_autofs(){
    if iscentos 7; then
        yum -y install autofs
        systemctl enable autofs.service
        
    elif iscentos 6; then
        yum -y install autofs
        chkconfig --add autofs
        
    elif isubuntu; then
        apt-get -y install autofs
        update-rc.d autofs defaults
        
    else
        echo "unsupported os"
        exit
    fi
}

install_biomaj_client(){
    
    install_autofs
    
    # --- Define variables -------------------------------------------------

    LOG_FILE="/var/log/ostack-bio-context.log"

    AUTOFS_MASTER_FILE="/etc/auto.master"
    AUTOFS_BIO_FILE="/etc/auto.bio"
    AUTOFS_MOUNT_DIR="/automnt"

    BIO_MOUNT=${BIO_MOUNT-/ifb}
    BIO_ENV_FILE=${BIO_ENV_FILE:-/etc/profile.d/bio.sh}
    BIO_DB_VOLUME=${BIO_DB_VOLUME:-/biomaj/vdisk/db/pub}
    BIO_DB_MOUNT_OPTIONS=${BIO_DB_MOUNT_OPTIONS:-ro,soft,intr,nosuid,nodev,noexec}
    BIO_DB_MOUNT="${BIO_DB_MOUNT:-databases}"         # relative to BIO_MOUNT
    #BIO_DB_SERVER=${BIO_DB_SERVER:-biodb.france-bioinformatique.fr}
    #BIO_DB_SERVER=${BIO_DB_SERVER}

    echo "======================================================================"
    echo ":: running ostack-bio-context on $(date)"

    # --- Check variables --------------------------------------------------

    if [ -z "$BIO_DB_SERVER" -o -z "$BIO_DB_VOLUME" ]; then
        echo ":: undefined biodb server or volume, abort"
        exit 1
    fi

    # --- Configure autofs -------------------------------------------------

    if ! grep "$AUTOFS_BIO_FILE" "$AUTOFS_MASTER_FILE" >/dev/null; then
        echo ":: configuring autofs master file"
        echo "$AUTOFS_MOUNT_DIR    $AUTOFS_BIO_FILE" >> "$AUTOFS_MASTER_FILE"
    fi

    if [ -f "$AUTOFS_BIO_FILE" ]; then
        echo ":: backuping autofs bio file"
        cp -f -p "$AUTOFS_BIO_FILE" "$AUTOFS_BIO_FILE.old"
    fi
    echo "$BIO_DB_MOUNT   -$BIO_DB_MOUNT_OPTIONS   $BIO_DB_SERVER:$BIO_DB_VOLUME" > $AUTOFS_BIO_FILE


    service autofs restart

    mkdir -p "$BIO_MOUNT/"
    ln -fs "$AUTOFS_MOUNT_DIR/$BIO_DB_MOUNT" "$BIO_MOUNT/"

    # --- Configure environment --------------------------------------------

    if [ -f "$BIO_ENV_FILE" ]; then
        echo ":: backuping environment bio file"
        cp -p "$BIO_ENV_FILE" "$BIO_ENV_FILE.old"
    fi

    if grep "BIO_DB_DIR=" "$BIO_ENV_FILE" >/dev/null 2>&1; then
        sed -i -e "s#\(BIO_DB_DIR=\).*#\1\"$BIO_MOUNT/$BIO_DB_MOUNT\"#g" "$BIO_ENV_FILE"
    else
        echo "export BIO_DB_DIR=\"$BIO_MOUNT/$BIO_DB_MOUNT\"" >> $BIO_ENV_FILE
    fi
}

if [ "$1" == "--dry-run" ]; then
    echo "function loaded"
    echo "You can do:"
    echo "    source biomaj_client.sh --dry-run "
    echo "    install_biomaj_client"
else
    install_biomaj_client
fi