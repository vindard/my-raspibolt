#!/bin/bash

# This script is called from '120_mempool_space.sh'. It is
# required to be separate so that it can be called
# and run as another user from the parent script.

MEMPOOL_GIT_DIR=$1
MEMPOOL_DATA_SYMLINK=$2
RPC_USER=$3
RPC_PASS=$4

# == Helper functions ==
source install/000_helpers.sh


# == Function definitions ==

install_mempool_as_user() {
    echo_label "NPM step of mempool.space"

    # Check for repo
    if [[ ! -d $MEMPOOL_GIT_DIR ]]; then
        echo "Repo not setup at $MEMPOOL_GIT_DIR, clone repo and retry..."
        return 1
    fi

    # Configure npm global
    npm config set prefix "$HOME/.npm-global"
    export PATH="$HOME/.npm-global/bin:$PATH"


    # Configure mariadb db
    pushd $MEMPOOL_GIT_DIR > /dev/null
    echo && echo "Configuring MySQL database" && echo "---"
    mariadb -umempool -pmempool mempool < \
        mariadb-structure.sql
    popd > /dev/null

    # Install backend
    echo && echo "\$ npm install (backend)" && echo "---"
    pushd "$MEMPOOL_GIT_DIR/backend" > /dev/null
    npm install
    npm run build
    popd > /dev/null

    # frontend
    echo && echo "\$ npm install (frontend)" && echo "---"
    pushd "$MEMPOOL_GIT_DIR/frontend" > /dev/null
    npm install
    npm run build
    popd > /dev/null


}

configure_mempool() {
    # From guide: https://github.com/dangeross/guides/blob/master/raspibolt/raspibolt_6B_mempool.md
    echo_label ": Configuring mempool.space backend"

    # Edit config file
    CONFIG_FILE="$MEMPOOL_GIT_DIR/backend/mempool-config.json"
    cp "$MEMPOOL_GIT_DIR/backend/mempool-config.sample.json" \
        "$CONFIG_FILE"

    cat "$CONFIG_FILE" | \
        jq ".CORE_RPC.USERNAME = \"$RPC_USER\"" | \
        jq ".CORE_RPC.PASSWORD = \"$RPC_PASS\""
}

start_backend() {
    pushd "$MEMPOOL_GIT_DIR/backend" > /dev/null
    npm run start
    popd > /dev/null
}

# == Function calls ==

install_mempool_as_user
configure_mempool
start_backend
