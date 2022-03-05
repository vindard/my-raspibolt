#!/bin/bash

# == Setup variables ==

BOS_USER="bos"

# Dir & GitHub values
BOS_DIRNAME="bos"
BOS_DIR="/home/$BOS_USER/$BOS_DIRNAME"
GITHUB_REPO="https://github.com/alexbosworth/balanceofsatoshis.git"

BOS_DATA_DIR="/mnt/ext/$BOS_DIRNAME"
BOS_DATA_SYMLINK="/home/$BOS_USER/.$BOS_DIRNAME"
LND_DIR="/home/bitcoin/.lnd"
USER_LND_DIR="/home/$BOS_USER/.lnd"


# == Helper functions ==
source install/000_helpers.sh


# == Dependencies function definitions ==

install_bos() {
    echo_label "Balance of Satoshis"

    # Check for nodejs & install if not present
    if ! check_dependency npm; then
        source install/013_nodejs.sh
        install_nodejs
    fi

    # Setup bos user
    if ! id $BOS_USER > /dev/null 2>&1; then
        sudo adduser --gecos "" --disabled-password $BOS_USER
    fi

    # Setup bos data dir
    sudo mkdir -p $BOS_DATA_DIR
    sudo rm -rf $BOS_DATA_SYMLINK
    sudo ln -s $BOS_DATA_DIR $BOS_DATA_SYMLINK

    # Change data dir ownership
    sudo chown -R $BOS_USER: $BOS_DATA_DIR
    sudo chown -R $BOS_USER: $BOS_DATA_SYMLINK

    # Clone repo
    pushd /tmp > /dev/null
    git clone $GITHUB_REPO $BOS_DIRNAME
    sudo rm -rf /home/$BOS_USER/$BOS_DIRNAME
    sudo mv $BOS_DIRNAME /home/$BOS_USER/
    sudo chown -R $BOS_USER: $BOS_DIR
    popd > /dev/null

    # Install bos
    sudo -u $BOS_USER install/101_bos_install.sh \
        $BOS_DIR \
        $BOS_DATA_SYMLINK
}



# == Function calls ==

run_bos_install() {
    install_bos
}
