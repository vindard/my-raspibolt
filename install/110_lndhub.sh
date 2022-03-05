#!/bin/bash

# == Setup variables ==

LNDHUB_USER="lndhub"
REDIS_PORT="6379"

# Dir & GitHub values
LNDHUB_DIRNAME="LndHub"
LNDHUB_GIT_DIR="/home/$LNDHUB_USER/$LNDHUB_DIRNAME"
GITHUB_REPO="https://github.com/BlueWallet/$LNDHUB_DIRNAME.git"

SOURCE_DIR="/mnt/ext/apps-data/lndhub"
LNDHUB_DATA_DIR="$SOURCE_DIR/.lndhub"
LNDHUB_LND_DIR="$SOURCE_DIR/.lnd"

SYMLINK_DIR="/home/$LNDHUB_USER"
LNDHUB_DATA_SYMLINK="$SYMLINK_DIR/.lndhub"
LNDHUB_LND_SYMLINK="$SYMLINK_DIR/.lnd"

LND_DIR="/home/bitcoin/.lnd"

# Set in .env to override default '4010' here
LNDHUB_PORT="${LNDHUB_PORT:-4010}"



# == Helper functions ==
source install/000_helpers.sh


# == Dependencies function definitions ==

configure_ufw() {
    sudo ufw allow from 192.168.0.0/16 to any port "$LNDHUB_PORT" comment "allow LNDHub from Local LAN"
}

install_lndhub() {
    echo_label "LNDHub"

    # Check for redis & install if not present
    if ! check_dependency redis-server; then
        source install/014_redis.sh
        run_install_redis
    fi

    # Check for nodejs & install if not present
    if ! check_dependency npm; then
        source install/013_nodejs.sh
        install_nodejs
    fi


    # Setup LNDHub user
    if ! id $LNDHUB_USER > /dev/null 2>&1; then
        sudo adduser --gecos "" --disabled-password $LNDHUB_USER
    fi

    # Setup LNDHub data dirs
    sudo mkdir -p $LNDHUB_DATA_DIR
    sudo rm -rf $LNDHUB_DATA_SYMLINK
    sudo ln -s $LNDHUB_DATA_DIR $LNDHUB_DATA_SYMLINK

    sudo mkdir -p $LNDHUB_LND_DIR
    sudo rm -rf $LNDHUB_LND_SYMLINK
    sudo ln -s $LNDHUB_LND_DIR $LNDHUB_LND_SYMLINK

    # Copy LND files required
    if [[ ! "$LNDHUB_USER" == "bitcoin" ]]; then
        sudo mkdir -p $LNDHUB_LND_SYMLINK/data/chain/bitcoin/mainnet
        sudo cp "$LND_DIR/data/chain/bitcoin/mainnet/admin.macaroon" \
            "$LNDHUB_LND_SYMLINK/data/chain/bitcoin/mainnet/"

        sudo cp "$LND_DIR/tls.cert" $LNDHUB_LND_SYMLINK
    fi

    # Change data dir ownership
    sudo chown -R $LNDHUB_USER: $LNDHUB_DATA_DIR
    sudo chown -R $LNDHUB_USER: $LNDHUB_DATA_SYMLINK

    sudo chown -R $LNDHUB_USER: $LNDHUB_LND_DIR
    sudo chown -R $LNDHUB_USER: $LNDHUB_LND_SYMLINK

    # Clone repo
    pushd /tmp > /dev/null
    git clone $GITHUB_REPO $LNDHUB_DIRNAME
    sudo mv $LNDHUB_DIRNAME /home/$LNDHUB_USER/
    popd > /dev/null

    # Place lnd symlinks
    sudo ln -s "$LNDHUB_LND_SYMLINK/data/chain/bitcoin/mainnet/admin.macaroon" \
        $LNDHUB_GIT_DIR/
    sudo ln -s "$LNDHUB_LND_SYMLINK/tls.cert" \
        $LNDHUB_GIT_DIR/

    # Change ownership of git (run) folder
    sudo chown -R $LNDHUB_USER: $LNDHUB_GIT_DIR

    # Fetch bitcoin rpc credentials
    RPC_USER=$(cat $HOME/.bitcoin/bitcoin.conf| grep "rpcuser" | awk -F= '{print $2}')
    RPC_PASS=$(cat $HOME/.bitcoin/bitcoin.conf| grep "rpcpass" | awk -F= '{print $2}')

    # Install LNDHhub
    sudo -u $LNDHUB_USER install/111_lndhub_install.sh \
        $LNDHUB_GIT_DIR \
        $LNDHUB_DATA_SYMLINK \
        $LNDHUB_LND_SYMLINK \
        $RPC_USER \
        $RPC_PASS \
        $REDIS_PORT
}

setup_lndhub_systemd() {
    SYSTEMD_FILENAME="lndhub.service"
    SYSTEMD_FILE="systemd/$SYSTEMD_FILENAME"
    FILE_ON_SYSTEM="/etc/systemd/system/$SYSTEMD_FILENAME"

    if [[ ! -e $SYSTEMD_FILE ]]; then
        echo "No file found at $SYSTEMD_FILE to setup systemd service with."
        return 1
    fi

    sudo cp $SYSTEMD_FILE $FILE_ON_SYSTEM
    sudo sed -i \
        "s|<lndhub-port>|$LNDHUB_PORT|g" \
        $FILE_ON_SYSTEM
    sudo sed -i \
        "s|<lndhub-user>|$LNDHUB_USER|g" \
        $FILE_ON_SYSTEM
    sudo sed -i \
        "s|<node-bin>|$(which node)|g" \
        $FILE_ON_SYSTEM

    sudo systemctl enable lndhub
    sudo systemctl start lndhub
}


# == Function calls ==

run_lndhub_install() {
    configure_ufw
    install_lndhub
    setup_lndhub_systemd
}
