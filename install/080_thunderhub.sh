#!/bin/bash

# == Setup variables ==

THUNDERHUB_USER="thunderhub"

# Dir & GitHub values
THUNDERHUB_DIRNAME="thunderhub"
THUNDERHUB_GIT_DIR="/home/$THUNDERHUB_USER/$THUNDERHUB_DIRNAME"
GITHUB_REPO="https://github.com/apotdevin/$THUNDERHUB_DIRNAME.git"

SOURCE_DIR="/mnt/ext/apps-data/thunderhub"
THUNDERHUB_DATA_DIR="$SOURCE_DIR/.thunderhub"
THUNDERHUB_LND_DIR="$SOURCE_DIR/.thunderhub"

SYMLINK_DIR="/home/$THUNDERHUB_USER"
THUNDERHUB_DATA_SYMLINK="$SYMLINK_DIR/.thunderhub"
THUNDERHUB_LND_SYMLINK="$SYMLINK_DIR/.lnd"

LND_DIR="/home/bitcoin/.lnd"

# Set in .env to override default '3010' here
THUNDERHUB_PORT="${THUNDERHUB_PORT:-3010}"


# == Helper functions ==
source install/000_helpers.sh


# == Dependencies function definitions ==

configure_ufw() {
    sudo ufw allow from 192.168.0.0/16 to any port "$THUNDERHUB_PORT" comment "allow Thunderhub from Local LAN"
}

install_thunderhub() {
    echo_label "Thunderhub"

    # Check for nodejs & install if not present
    if ! check_dependency npm; then
        source install/013_nodejs.sh
        install_nodejs
    fi

    # Setup thunderhub user
    if ! id $THUNDERHUB_USER > /dev/null 2>&1; then
        sudo adduser --gecos "" --disabled-password $THUNDERHUB_USER
    fi

    # Setup thunderhub data dirs
    sudo mkdir -p $THUNDERHUB_DATA_DIR
    sudo rm -rf $THUNDERHUB_DATA_SYMLINK
    sudo ln -s $THUNDERHUB_DATA_DIR $THUNDERHUB_DATA_SYMLINK

    sudo mkdir -p $THUNDERHUB_LND_DIR
    sudo rm -rf $THUNDERHUB_LND_SYMLINK
    sudo ln -s $THUNDERHUB_LND_DIR $THUNDERHUB_LND_SYMLINK

    # Copy LND files required
    if [[ ! "$THUNDERHUB_USER" == "bitcoin" ]]; then
        sudo mkdir -p $THUNDERHUB_LND_SYMLINK/data/chain/bitcoin/mainnet
        sudo cp "$LND_DIR/data/chain/bitcoin/mainnet/admin.macaroon" \
            "$THUNDERHUB_LND_SYMLINK/data/chain/bitcoin/mainnet/"

        sudo cp "$LND_DIR/tls.cert" $THUNDERHUB_LND_SYMLINK
    fi

    # Change data dir ownership
    sudo chown -R $THUNDERHUB_USER: $THUNDERHUB_DATA_DIR
    sudo chown -R $THUNDERHUB_USER: $THUNDERHUB_DATA_SYMLINK

    sudo chown -R $THUNDERHUB_USER: $THUNDERHUB_LND_DIR
    sudo chown -R $THUNDERHUB_USER: $THUNDERHUB_LND_SYMLINK

    # Clone repo
    pushd /tmp > /dev/null
    git clone $GITHUB_REPO
    sudo mv $THUNDERHUB_DIRNAME /home/$THUNDERHUB_USER/
    sudo chown -R $THUNDERHUB_USER: $THUNDERHUB_GIT_DIR
    popd > /dev/null

    # Install thunderhub
    sudo -u $THUNDERHUB_USER install/081_thunderhub_install.sh \
        $THUNDERHUB_GIT_DIR \
        $THUNDERHUB_DATA_SYMLINK \
        $THUNDERHUB_LND_SYMLINK
}

setup_thunderhub_systemd() {
    SYSTEMD_FILENAME="thunderhub.service"
    SYSTEMD_FILE="systemd/$SYSTEMD_FILENAME"
    FILE_ON_SYSTEM="/etc/systemd/system/$SYSTEMD_FILENAME"

    if [[ ! -e $SYSTEMD_FILE ]]; then
        echo "No file found at $SYSTEMD_FILE to setup systemd service with."
        return 1
    fi

    sudo cp $SYSTEMD_FILE $FILE_ON_SYSTEM
    sudo sed -i \
        "s|<thunderhub-dir>|$THUNDERHUB_GIT_DIR|g" \
        $FILE_ON_SYSTEM
    sudo sed -i \
        "s|<thunderhub-user>|$THUNDERHUB_USER|g" \
        $FILE_ON_SYSTEM

    sudo systemctl enable thunderhub
    sudo systemctl start thunderhub
}



# == Function calls ==

run_thunderhub_install() {
    configure_ufw
    install_thunderhub
    setup_thunderhub_systemd
}
