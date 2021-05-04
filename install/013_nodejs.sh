#!/bin/bash


# == Function definitions ==

install_nodejs() {
    SETUP_SCRIPT="setup_12"

    # Add the Node JS package repository
    pushd /tmp
    wget -O $SETUP_SCRIPT.sh https://deb.nodesource.com/$SETUP_SCRIPT.x
    sudo chmod +x $SETUP_SCRIPT.sh
    sudo ./$SETUP_SCRIPT.sh
    rm $SETUP_SCRIPT.sh

    sudo apt install nodejs
}
