#!/bin/bash

RPC_USER="$1"
RPC_PASS="$2"

# == Helper functions ==
source install/000_helpers.sh

# == Dependencies function definitions ==

VERSION=v1.3.0
REPO_NAME=specter-desktop
REPO_URL=https://github.com/cryptoadvance/$REPO_NAME

VENV_PY_VERSION=3.8.8
VENV_NAME=specter-desktop

SPECTER_CONFIG_TEMPLATE=configs/specter.json
SPECTER_CONFIG=$HOME/.specter/config.json


INSTALLS_DIR=$HOME/Installs
REPO_DIR=$INSTALLS_DIR/$REPO_NAME

fetch_specter() {
    mkdir -p $INSTALLS_DIR

    pushd $INSTALLS_DIR > /dev/null
    git clone $REPO_URL
    popd > /dev/null

    pushd $REPO_DIR > /dev/null
    git checkout $VERSION
    sed -i "s/vx.y.z-get-replaced-by-release-script/${VERSION}/g; " setup.py
    popd > /dev/null
}

install_specter() {
    load_pyenv
    pushd $REPO_DIR > /dev/null

    # Switch to '$VENV_NAME' virtualenv
    if ! pyenv versions | grep -q $VENV_PY_VERSION; then
        pyenv install -v $VENV_PY_VERSION
    fi
    if ! pyenv versions | grep -q $VENV_NAME; then
        pyenv virtualenv $VENV_PY_VERSION $VENV_NAME
    fi

    pyenv shell $VENV_NAME
    python -m pip install --upgrade pip
    echo "Python pyenv version: $(pyenv version)"

    # Install specter
    python -m pip install .
    popd > /dev/null

    # Enable in firewall
    sudo ufw allow from 192.168.0.0/16 to any port 25441 comment 'allow Specter from local LAN'
    sudo ufw enable
    sudo ufw status

    # Print bitcoin.conf notes
    echo "Ensure the following are set in your bitcoin.conf file:"
    echo " server=1"
    echo " blockfilterindex=1"
    echo " disablewallet=0"
    echo
    echo "(bitcoin.conf suggestions taken from: https://btcguide.github.io/setup-computer/bitcoin-node)"
    echo
}

setup_config() {
    # Copy seed config file
    cp \
        $SPECTER_CONFIG_TEMPLATE \
        $SPECTER_CONFIG

    # Add RPC details to specter config file
    change_json_value \
        $SPECTER_CONFIG \
        user \
        $RPC_USER

    change_json_value \
        $SPECTER_CONFIG \
        password \
        $RPC_PASS
}

setup_tor_and_tor_requests() {
    # Enable Tor and toggle "only tor" to true
    change_json_value $SPECTER_CONFIG \
        "proxy_url" \
        "socks5h://localhost:9050"

    toggle_json_true $SPECTER_CONFIG \
        "only_tor"


    # Setup fairly private price checker over Tor
    toggle_json_true $SPECTER_CONFIG \
        "price_check"

    change_json_value $SPECTER_CONFIG \
        "alt_symbol" \
        "$"

    change_json_value $SPECTER_CONFIG \
        "price_provider" \
        "spotbit_bitstamp"
}

# == Function calls ==

run_specter_install() {
    fetch_specter
    install_specter
    setup_config
    setup_tor_and_tor_requests
}

run_specter_install
