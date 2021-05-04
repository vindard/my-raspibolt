#!/bin/bash

# This script is called from '070_sphinx.sh'. It is
# required to be separate so that it can be called
# and run as another user from the parent script.

SPHINX_DIR=$1
LOCAL_IP=$2
SPHINX_PORT=$3
SPHINX_DATA_DIR=$4
SPHINX_DATA_SYMLINK=$5
LND_DIR=$6
SPHINX_USER=$7

SETTINGS_FILE=$SPHINX_DIR/config/app.json
CONFIG_FILE=$SPHINX_DIR/config/config.json


# == Helper functions ==
source install/000_helpers.sh


# == Function definitions ==

install_sphinx_as_user() {
    echo_label "NPM step of Sphinx Chat"

    # Check for repo
    if [[ ! -d $SPHINX_DIR ]]; then
        echo "Repo not setup at $SPHINX_DIR, clone repo and retry..."
        return 1
    fi

    # Install
    pushd $SPHINX_DIR > /dev/null
    npm install
}

configure_sphinx() {
    echo_label ": Configuring Sphinx Chat"

    # Configure settings

    CERTS_DIR=$LND_DIR
    if [[ ! "$SPHINX_USER" == "bitcoin" ]]; then
        CERTS_DIR=$SPHINX_DATA_SYMLINK
    fi

    cat $SETTINGS_FILE | \
        jq ".production.macaroon_location = \"$CERTS_DIR/data/chain/bitcoin/mainnet/admin.macaroon\"" | \
        jq ".production.tls_location = \"$CERTS_DIR/tls.cert\"" | \
        jq ".production.lnd_log_location = \"$LND_DIR/logs/bitcoin/mainnet/lnd.log\"" | \
        jq ".production.public_url = \"$LOCAL_IP:$SPHINX_PORT\"" | \
        jq ".production.node_http_port = \"$SPHINX_PORT\"" \
    > $SETTINGS_FILE.tmp
    mv $SETTINGS_FILE.tmp $SETTINGS_FILE


    # Configure sphinx db

    cat $CONFIG_FILE | \
        jq ".production.storage = \"$SPHINX_DATA_SYMLINK/sphinx.db\"" \
    > $CONFIG_FILE.tmp
    mv $CONFIG_FILE.tmp $CONFIG_FILE
}


# == Function calls ==

install_sphinx_as_user
configure_sphinx
