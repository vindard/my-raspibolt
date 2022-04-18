#!/bin/bash

# == Setup variables ==

CLBOSS_USER="bitcoin"

CLBOSS_VERSION="0.10"
DIRNAME="clboss-$CLBOSS_VERSION"
TAR_FILE="$DIRNAME.tar.gz"
SOURCE_TAR_FILE="https://github.com/ZmnSCPxj/clboss/releases/download/v$CLBOSS_VERSION/$TAR_FILE"

PLUGINS_AVAILABLE_DIR="/home/$CLBOSS_USER/cln-plugins-available"
PLUGINS_ENABLED_DIR="/home/$CLBOSS_USER/cln-plugins-enabled"

# == Helper functions ==
source install/000_helpers.sh

fetch_and_verify() {
    # Fetch tarball
    echo_label ": Fetching clboss tarball"
    sudo mkdir -p $PLUGINS_AVAILABLE_DIR
    sudo mkdir -p $PLUGINS_ENABLED_DIR
    sudo chown -R $CLIGHTNING_USER: $PLUGINS_AVAILABLE_DIR
    sudo chown -R $CLIGHTNING_USER: $PLUGINS_ENABLED_DIR

    sudo -u bitcoin wget \
        "$SOURCE_TAR_FILE" \
        -O "$PLUGINS_AVAILABLE_DIR/$TAR_FILE" \
        || return 1
}

install_clboss() {
    # Install clightning dependencies
    echo_label "clboss dependencies"
    sudo apt update && sudo apt install -y \
        build-essential \
        pkg-config \
        libev-dev \
        libcurl4-gnutls-dev \
        libsqlite3-dev \
        dnsutils

    # Install
    pushd $PLUGINS_AVAILABLE_DIR > /dev/null
    sudo -u bitcoin tar -xvf $TAR_FILE
    pushd $DIRNAME > /dev/null
    sudo -u bitcoin ./configure && sudo -u bitcoin make
    popd > /dev/null
    popd > /dev/null

    sudo ln -s \
        $PLUGINS_AVAILABLE_DIR/$DIRNAME/clboss \
        $PLUGINS_ENABLED_DIR

    sudo chown -R $CLIGHTNING_USER: $PLUGINS_AVAILABLE_DIR
    sudo chown -R $CLIGHTNING_USER: $PLUGINS_ENABLED_DIR

    sudo systemctl restart lightningd
}


# == Function calls ==

run_clboss_install() {
    fetch_and_verify || return 1
    install_clboss || return 1

    echo_label ": Finished installing clboss"
}
