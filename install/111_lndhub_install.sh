#!/bin/bash

# This script is called from '110_lndhub.sh'. It is
# required to be separate so that it can be called
# and run as another user from the parent script.

LNDHUB_GIT_DIR=$1
LNDHUB_DATA_SYMLINK=$2
LNDHUB_LND_SYMLINK=$3
RPC_USER=$4
RPC_PASS=$5
REDIS_PORT=$6

# == Helper functions ==
source install/000_helpers.sh


# == Function definitions ==

install_lndhub_as_user() {
    echo_label "NPM step of LNDHub"

    # Check for repo
    if [[ ! -d $LNDHUB_GIT_DIR ]]; then
        echo "Repo not setup at $LNDHUB_GIT_DIR, clone repo and retry..."
        return 1
    fi

    # Configure npm global
    npm config set prefix "$HOME/.npm-global"
    export PATH="$HOME/.npm-global/bin:$PATH"


    # Install dir packages
    pushd $LNDHUB_GIT_DIR > /dev/null
    echo && echo "\$ npm install" && echo "---"
    npm install

    # Install babel
    # Original docs errored, changed to this: https://stackoverflow.com/a/53925127
    echo && echo "\$ npm install -g @babel/cli" && echo "---"
    npm install -g @babel/cli
    echo && echo "\$ npm install -g @babel/core" && echo "---"
    npm install -g @babel/core

    # Build with babel
    mkdir -p build
    babel ./ --out-dir ./build --copy-files --ignore node_modules
}

configure_lndhub() {
    # From guide: https://github.com/dangeross/guides/blob/master/raspibolt/raspibolt_6B_lndhub.md
    echo_label ": Configuring LNDHub"

    # Edit config file
    CONFIG_FILE="$LNDHUB_GIT_DIR/config.js"

    sed -i \
        "s|1\.1\.1\.1|127.0.0.1|g" \
        $CONFIG_FILE

    sed -i \
        "s|login:password|$RPC_USER:$RPC_PASS|g" \
        $CONFIG_FILE

    sed -i \
        "s|port: [0-9]\+|port: $REDIS_PORT|g" \
        $CONFIG_FILE

    sed -i "/password/d" \
        $CONFIG_FILE
}


# == Function calls ==

install_lndhub_as_user
configure_lndhub
