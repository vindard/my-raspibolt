#!/bin/bash

# This script is called from '080_thunderhub.sh'. It is
# required to be separate so that it can be called
# and run as another user from the parent script.

THUNDERHUB_DIR=$1
THUNDERHUB_DATA_SYMLINK=$2

# == Helper functions ==
source install/000_helpers.sh


# == Function definitions ==

install_thunderhub_as_user() {
    echo_label "NPM step of Thunderhub"

    # Check for repo
    if [[ ! -d $THUNDERHUB_DIR ]]; then
        echo "Repo not setup at $THUNDERHUB_DIR, clone repo and retry..."
        return 1
    fi

    # Install
    pushd $THUNDERHUB_DIR > /dev/null
    echo && echo "\$ npm install" && echo "---"
    npm install
    echo && echo "\$ npm run build" && echo "---"
    npm run build
}

configure_thunderhub() {
    # From guide: https://gist.github.com/openoms/8ba963915c786ce01892f2c9fa2707bc#env-file
    echo_label ": Configuring Thunderhub"

    # EDIT .env FILE

    ENV_FILE="$THUNDERHUB_DIR/.env.local"
    cp $THUNDERHUB_DIR/.env $ENV_FILE

    # Edit config file location
    sed -i \
        "s|/path/to/config|/home/thunderhub/.thunderhub|s" \
        $ENV_FILE

    # Activate setting
    export UNCOMMENT_FILE=$ENV_FILE
    uncomment_file \
        "ACCOUNT_CONFIG_PATH="


    # CREATE CONFIG FILE

    # Set dir location
    CERTS_DIR=$LND_DIR
    if [[ ! "$USER" == "bitcoin" ]]; then
        CERTS_DIR=$THUNDERHUB_DATA_SYMLINK
    fi

    # Configure thubConfig.yaml
    cp configs/thubConfig.yaml $THUNDERHUB_DATA_SYMLINK/

    sed -i \
        "s|/home/<user>/.lnd|$THUNDERHUB_DATA_SYMLINK|g" \
        $THUNDERHUB_DATA_SYMLINK/thubConfig.yaml

    if [[ -z $THUB_MASTER_PASS ]] ; then
        echo "Please enter value for 'THUB_MASTER_PASS' in '.env' and re-run."
        exit 1
    fi
    sed -i \
        "s|<PASSWORD>|$THUB_MASTER_PASS|g" \
        $THUNDERHUB_DATA_SYMLINK/thubConfig.yaml
}

# == Function calls ==

install_thunderhub_as_user
configure_thunderhub
