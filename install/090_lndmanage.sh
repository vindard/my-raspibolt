#!/bin/bash

# == Setup variables ==

LNDMANAGE_USER="lntools"
VENV_NAME="lndmanage"

LNDMANAGE_DIRNAME="lndmanage"
LNDMANAGE_DIR="/home/$LNDMANAGE_USER/$LNDMANAGE_DIRNAME"
REPO_URL="https://github.com/bitromortac/$LNDMANAGE_DIRNAME"

LND_DATA_DIR="/mnt/ext/$LNDMANAGE_USER/lnd-data"
LND_DATA_SYMLINK="/home/$LNDMANAGE_USER/.lnd-data"

# == Helper functions ==
source install/000_helpers.sh


# == Function definitions ==

install_lndmanage() {
	echo_label "lndmanage for user '$LNDMANAGE_USER'"

    if ! id $LNDMANAGE_USER > /dev/null 2>&1; then
        sudo adduser --gecos "" --disabled-password $LNDMANAGE_USER
    fi


    # Setup lndmanage lnd data dir
    sudo mkdir -p $LND_DATA_DIR
    sudo rm -rf $LND_DATA_SYMLINK
    sudo ln -s $LND_DATA_DIR $LND_DATA_SYMLINK

    # Copy LND files required
    if [[ ! "$LNDMANAGE_USER" == "bitcoin" ]]; then
        sudo mkdir -p $LND_DATA_SYMLINK/data/chain/bitcoin/mainnet
        sudo cp "$LND_DIR/data/chain/bitcoin/mainnet/admin.macaroon" "$LND_DATA_SYMLINK/data/chain/bitcoin/mainnet/"

        sudo cp "$LND_DIR/tls.cert" $LND_DATA_SYMLINK
    fi

    # Change LND data dir ownership
    sudo chown -R $LNDMANAGE_USER: $LND_DATA_DIR
    sudo chown -R $LNDMANAGE_USER: $LND_DATA_SYMLINK

    # Install pyenv for lndmanage user
    install_pyenv_for_user $LNDMANAGE_USER

    # Fetch repo & install
    pushd /tmp > /dev/null
    git clone $REPO_URL
    sudo mv $LNDMANAGE_DIRNAME /home/$LNDMANAGE_USER/
    sudo chown -R $LNDMANAGE_USER: $LNDMANAGE_DIR
    popd > /dev/null

    sudo -u $LNDMANAGE_USER install/091_lndmanage_install.sh \
        $LNDMANAGE_DIR \
        $VENV_NAME

    # Alias current user to lndmanage user binary location
    append_to_bash_aliases \
        "" \
        "# lndmanage virtualenv alias" \
        "alias lndmanage='/home/$LNDMANAGE_USER/.pyenv/versions/$VENV_NAME/bin/lndmanage'"
}


# == Function calls ==

run_lndmanage_install() {
    install_lndmanage
}
