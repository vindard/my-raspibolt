
SAMBA_USER="samba"

SAMBA_PUBLIC_DIRNAME="public"
SAMBA_PUBLIC_DIR="/mnt/ext/$SAMBA_USER/$SAMBA_DIRNAME"
SAMBA_PUBLIC_SYMLINK="/home/$SAMBA_USER/$SAMBA_DIRNAME"

# == Helper functions ==
source install/000_helpers.sh


# == Dependencies function definitions ==
install_samba() {
    echo_label "Samba (for file-sharing)"

    # Setup samba user
    if ! id $SAMBA_USER > /dev/null 2>&1; then
        sudo adduser --gecos "" --disabled-password $SAMBA_USER
    fi

    # Setup samba data dir
    sudo mkdir -p $SAMBA_PUBLIC_DIR
    sudo rm -rf $SAMBA_PUBLIC_SYMLINK
    sudo ln -s $SAMBA_PUBLIC_DIR $SAMBA_PUBLIC_SYMLINK

    # Change data dir ownership
    sudo chown -R $SAMBA_USER: $SAMBA_PUBLIC_DIR
    sudo chown -R $SAMBA_USER: $SAMBA_PUBLIC_SYMLINK

    sudo apt update && sudo apt install -y \
        samba
}

enable_systemd() {
    sudo systemctl enable --now smbd
}

configure_samba() {
    echo "\
To configure samba:

1. EDIT CONFIG
Open /etc/samba.smb.conf

At the bottom of that file, paste the following:

    [Public]
    path = /home/USER/Public
    browsable = yes
    writable = yes
    read only = no
    force create mode = 0666
    force directory mode = 0777

Where USER is your username.

Note: If you don't want other users to be able to make changes to files and folders, set writable to no. 

2. RESTART SAMBA
With the configuration file edited, it's time to restart Samba with:

sudo systemctl restart smbd

At this point, your Samba share will be visible to the network, but won't allow anyone to access it. Let's fix that.

3. FOLLOW REST OF INTRUCTION

Follow instruction from here to configure user
https://www.zdnet.com/article/how-to-share-folders-to-your-network-from-linux/
"
}

# == Function calls ==

run_fileshare_install() {
    install_samba
    enable_systemd
    configure_samba
}
