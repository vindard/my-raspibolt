#!/bin/bash

# This script is called from '080_bos.sh'. It is
# required to be separate so that it can be called
# and run as another user from the parent script.

BOS_DIR=$1
BOS_DATA_SYMLINK=$2

# == Helper functions ==
source install/000_helpers.sh


# == Function definitions ==

install_bos_as_user() {
    echo_label "NPM step of Balance of Satoshis"

    # Check for repo
    if [[ ! -d $BOS_DIR ]]; then
        echo "Repo not setup at $BOS_DIR, clone repo and retry..."
        return 1
    fi

    # set up npm-global
    mkdir "$HOME/.npm-global"
    npm config set prefix "$HOME/.npm-global"
    echo "PATH=$PATH:$HOME/.npm-global/bin" >> "$HOME/.bashrc"

    # Install
    pushd $BOS_DIR > /dev/null
    echo && echo "\$ npm install -g balanceofsatoshis" && echo "---"
    npm install -g balanceofsatoshis
}

configure_bos() {
    # From guide: https://gist.github.com/openoms/8ba963915c786ce01892f2c9fa2707bc#env-file
    echo_label ": Configuring Balance of Satoshis"

    if [[ "$USER" == "bitcoin" ]]; then
        echo "Using default configs for user 'bitcoin'"
        return 1
    fi

    echo_label ": Symlinking creds to ~/.lnd"

    # CREDS_DIR can be instantiated with 'scripts/copy_lnd_creds.sh'
    CREDS_DIR="/mnt/ext/apps-data/lnd-certs/"
    LND_DIR="$HOME/.lnd"
    ln -s "$CREDS_DIR" "$LND_DIR"

    # START CREDS CONFIG
    # This is an alternative to symlinking a .lnd dir above

    # # Set dir location
    # CREDS_FILENAME="credentials.json"

    # # Configure credentials.json
    # # NOTE!: Not sure what to put for 'YOUR_NODE_NAME'
    # cp "configs/bos_credentials.json" \
    #     "$BOS_DATA_SYMLINK/YOUR_NODE_NAME/$CREDS_FILENAME"

    # sed -i \
    #     "s|<data-dir>|$BOS_DATA_SYMLINK|g" \
    #     "$BOS_DATA_SYMLINK/$CREDS_FILENAME"

    # echo "Configured 'credentials.json' for balance of satoshis"
    # END CREDS CONFIG
}

# == Function calls ==

install_bos_as_user
configure_bos     # Can't figure what to put for 'YOUR_NODE_NAME'
