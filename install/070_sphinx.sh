#!/bin/bash

# == Setup variables ==

# Note: can't figure access to lnd logs for other users, so using 'bitcoin' for now
# SPHINX_USER="sphinxchat"
SPHINX_USER="bitcoin"

# Dir & GitHub values
SPHINX_DIRNAME="sphinx-relay"
SPHINX_DIR="/home/$SPHINX_USER/$SPHINX_DIRNAME"
GITHUB_REPO="https://github.com/stakwork/$SPHINX_DIRNAME"

SPHINX_DATA_DIR="/mnt/ext/sphinx"
SPHINX_DATA_SYMLINK="/home/$SPHINX_USER/.sphinx"
LND_DIR="/home/bitcoin/.lnd"

# Set in .env to override default '3300' here
SPHINX_PORT="${SPHINX_PORT:-3300}"

# Check for local ip value
if [[ -z $LOCAL_IP ]] ; then
    echo "Please enter value for 'LOCAL_IP' in '.env' and re-run."
    exit 1
fi


# == Helper functions ==
source install/000_helpers.sh


# == Dependencies function definitions ==

install_deps() {
    echo_label "sphinx.chat dependencies"

    sudo apt update && sudo apt install -y \
        sqlite3 \
        jq
}

configure_ufw() {
    sudo ufw allow from 192.168.0.0/16 to any port "$SPHINX_PORT" comment "allow Sphinx-Chat from Local LAN"
}

install_sphinx() {
    echo_label "Sphinx Chat"

    # Check for nodejs & install if not present
    if ! check_dependency npm; then
        source install/013_nodejs.sh
        install_nodejs
    fi

    # Setup sphinx user
    if ! id $SPHINX_USER > /dev/null 2>&1; then
        sudo adduser $SPHINX_USER
    fi

    # Setup sphinx data dir
    sudo mkdir -p $SPHINX_DATA_DIR
    sudo ln -s $SPHINX_DATA_DIR $SPHINX_DATA_SYMLINK

    # Copy LND files required
    if [[ ! "$SPHINX_USER" == "bitcoin" ]]; then
        mkdir -p $SPHINX_DATA_SYMLINK/data/chain/bitcoin/mainnet
        sudo cp "$LND_DIR/data/chain/bitcoin/mainnet/admin.macaroon" "$SPHINX_DATA_SYMLINK/data/chain/bitcoin/mainnet/"

        sudo cp "$LND_DIR/tls.cert" $SPHINX_DATA_SYMLINK
    fi

    # Change data dir ownership
    sudo chown -R $SPHINX_USER: $SPHINX_DATA_DIR
    sudo chown -R $SPHINX_USER: $SPHINX_DATA_SYMLINK

    # Clone repo
    pushd /tmp > /dev/null
    git clone $GITHUB_REPO
    sudo mv $SPHINX_DIRNAME /home/$SPHINX_USER/
    sudo chown -R $SPHINX_USER: $SPHINX_DIR
    popd > /dev/null

    # Install sphinx
    sudo -u $SPHINX_USER install/071_sphinx_install.sh \
        $SPHINX_DIR \
        $LOCAL_IP \
        $SPHINX_PORT \
        $SPHINX_DATA_DIR \
        $SPHINX_DATA_SYMLINK \
        $LND_DIR \
        $SPHINX_USER
}

setup_sphinx_systemd() {
    SYSTEMD_FILENAME="sphinx-relay.service"
    SYSTEMD_FILE="systemd/$SYSTEMD_FILENAME"
    FILE_ON_SYSTEM="/etc/systemd/system/$SYSTEMD_FILENAME"

    if [[ ! -e $SYSTEMD_FILE ]]; then
        echo "No file found at $SYSTEMD_FILE to setup systemd service with."
        return 1
    fi

    sudo cp $SYSTEMD_FILE $FILE_ON_SYSTEM
    sudo sed -i \
        "s|<sphinx-dir>|$SPHINX_DIR|g" \
        $FILE_ON_SYSTEM
    sudo sed -i \
        "s|<sphinx-user>|$SPHINX_USER|g" \
        $FILE_ON_SYSTEM

    sudo systemctl enable sphinx-relay
    sudo systemctl start sphinx-relay
}


# == Function calls ==

run_sphinx_install() {
    install_deps
    configure_ufw
    install_sphinx
    setup_sphinx_systemd
}
