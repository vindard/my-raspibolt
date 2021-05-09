#!/bin/bash

# This script is called from '090_lndmanage.sh'. It is
# required to be separate so that it can be called
# and run as another user from the parent script.

LNDMANAGE_DIR=$1
VENV_NAME=$2

VENV_PY_VERSION="3.9.2"

# == Helper functions ==
source install/000_helpers.sh


# == Function definitions ==

install_lndmanage() {
    if [[ ! -d $LNDMANAGE_DIR ]]; then
        echo "Please clone the lndmanage repo to '$LNDMANAGE_DIR before continuing"
        return 1
    fi

    load_pyenv_virtual_env || return 1
    pushd $LNDMANAGE_DIR > /dev/null
    python -m pip install .
}

configure_lndmanage() {
    CONFIG_FILE="$HOME/.lndmanage/config.ini"

    # First run
    lndmanage

    # Edit config
    sed -i \
        "s|\.lnd/|\.lnd-data/|g" \
        $CONFIG_FILE

    # Set alias
    append_to_bash_aliases \
        "" \
        "# lndmanage virtualenv alias" \
        "alias lndmanage='/home/$USER/.pyenv/versions/$VENV_NAME/bin/lndmanage'"
}

# == Function calls ==

install_lndmanage || exit 1
configure_lndmanage
