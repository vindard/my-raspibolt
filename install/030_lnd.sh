#!/bin/bash


# == Function definitions ==

VERSION="v0.11.1-beta"
GIT_DOWNLOAD_DIR="https://github.com/lightningnetwork/lnd/releases/download/$VERSION"

LND_DIRNAME=lnd-linux-armv7-$VERSION
TAR_FILE=$LND_DIRNAME.tar.gz
MANIFEST=manifest-$VERSION.txt
MANIFEST_SIG=$MANIFEST.sig
ROASBEEF_MANIFEST_SIG=roasbeef-$MANIFEST_SIG


ROASBEEF_PGP_URL=https://keybase.io/roasbeef/pgp_keys.asc
ROASBEEF_PGP_KEYS=roasbeef.asc
BITCONNER_PGP_URL=https://keybase.io/bitconner/pgp_keys.asc
BITCONNER_PGP_KEYS=bitconner.asc

CHECK_PASS=true
check() {
    if [[ ! "$CHECK_PASS" == "true" ]]; then
        return 1
    fi
}

fetch_and_verify() {
    wget -c $GIT_DOWNLOAD_DIR/$TAR_FILE
    wget -c $GIT_DOWNLOAD_DIR/$MANIFEST
    wget -c $GIT_DOWNLOAD_DIR/$MANIFEST_SIG
    wget -c $GIT_DOWNLOAD_DIR/$ROASBEEF_MANIFEST_SIG
    wget -c -O $ROASBEEF_PGP_KEYS  $ROASBEEF_PGP_URL
    wget -c -O $BITCONNER_PGP_KEYS $BITCONNER_PGP_URL

    echo "Checking sha256sum values..."
    if check && \
        sha256sum --check $MANIFEST --ignore-missing |& grep -q "$TAR_FILE: OK"
    then
        echo "All sha256sum checks passed!"
        echo
    else
        CHECK_PASS=0
        echo "sha256sum did not match for '$TAR_FILE'"
    fi

    echo "Retrieving '$ROASBEEF_PGP_KEYS' & '$BITCONNER_PGP_KEYS' keys..."
    gpg --import ./$ROASBEEF_PGP_KEYS
    gpg --import ./$BITCONNER_PGP_KEYS

    # Roasbeef discards keys entirely every so often
    OLD_ROASBEEF_FINGERPRINT=BC13F65E2DC84465
    gpg --recv-keys --keyserver keyserver.ubuntu.com $OLD_ROASBEEF_FINGERPRINT

    gpg --refresh-keys > /dev/null 2>&1

    echo
    echo "Checking signatures on '$MANIFEST' file..."
    VERIFY="Good signature from "
    if check && \
        gpg --verify $MANIFEST_SIG |& grep -q "$VERIFY" && \
        gpg --verify $ROASBEEF_MANIFEST_SIG $MANIFEST |& grep -q "$VERIFY"
    then
        echo "All signature checks on '$MANIFEST' checks passed!"
        echo
    else
        CHECK_PASS=0
        echo "Signature did not match for verifying '$MANIFEST' file"
    fi


    if ! check; then
        echo
        echo "Some verification step failed, exiting..."
        return 1
    fi
}

extract_and_install_lnd() {
    tar -xvf $TAR_FILE
    sudo install -m 0755 -o root -g root -t /usr/local/bin $LND_DIRNAME/*

    echo
    echo "---------------"
    lnd --version \
        || echo "'lnd' was not successfully installed" && return 1
}

cleanup_install() {
    rm $TAR_FILE
    rm $MANIFEST
    rm $MANIFEST_SIG
    rm $ROASBEEF_MANIFEST_SIG

    rm $ROASBEEF_PGP_KEYS
    rm $BITCONNER_PGP_KEYS

    rm -rf $LND_DIRNAME

    echo
    echo "Cleaned up lnd install files."
    echo
}

enable_pi_permissions() {
    LND_DIR=$HOME/.lnd
    LND_DATA_DIR=$LND_DIR/data
    ADMIN_MACAROON=$LND_DATA_DIR/chain/bitcoin/mainnet/admin.macaroon

    echo "Allocating lnd/lncli permissions to 'pi' user"

    if [[ -e $LND_DATA_DIR ]]; then
        sudo chmod -R g+X $LND_DATA_DIR
    else
        echo "lnd data data dir not found at '$LND_DATA_DIR', skipping..."
        return 1
    fi

    if [[ -e $ADMIN_MACAROON ]]; then
        sudo chmod g+r $ADMIN_MACAROON
    else
        echo "'admin.macaroon' not found at '$ADMIN_MACAROON', skipping..."
        return 1
    fi

    echo
    echo "---------------"
    echo "Calling 'lncli' from user 'pi'..."
    echo
    lncli getinfo \
        || echo "'lnd' was not successfully permissioned to user 'pi'" && return 1
}

setup_auto_unlock() {
    PWD_FILE=/etc/lnd/pwd
    PWD_DIR=$(dirname $PWD_FILE)

    # Create 'pwd' file to store unlock password
    if [[ -z $LND_UNLOCK_PWD ]] ; then
        echo "Please enter value for 'LND_UNLOCK_PWD' in '.env' and re-run."
        return 1
    fi

    sudo mkdir -p $PWD_DIR
    sudo touch $PWD_FILE

    # Setup 'unlock' script
    # > This script complements the following line in lnd.service
    # > $ ExecStartPost=+/etc/lnd/unlock
    if [[ -e scripts/unlock ]]; then
        sudo cp scripts/unlock $PWD_DIR/
    else
        echo "No 'unlock' script found to copy to '$PWD_DIR', skipping..."
        return 1
    fi

    sudo chmod 400 $PWD_FILE
    sudo chmod 100 $PWD_DIR/unlock
    sudo chown root:root $PWD_DIR/*
}

setup_lnd_systemd() {
    SYSTEMD_FILE=systemd/lnd.service
    if [[ ! -e $SYSTEMD_FILE ]]; then
        echo "No file found at $SYSTEMD_FILE to setup systemd service with."
        return 1
    fi

    sudo cp $SYSTEMD_FILE /etc/systemd/system/
    sudo systemctl enable lnd
    sudo systemctl start lnd
}

install_lnd_connect() {
    LNDCONNECT_TAR_FILE=lndconnect-linux-armv7-v0.1.0.tar.gz

    wget -c https://github.com/LN-Zap/lndconnect/releases/download/v0.1.0/$LNDCONNECT_TAR_FILE
    sudo tar -xvf $LNDCONNECT_TAR_FILE --strip=1 -C /usr/local/bin
    rm $LNDCONNECT_TAR_FILE

    sudo ufw allow from 192.168.0.0/16 to any port 10009 comment 'allow LND grpc from local LAN'
    sudo ufw enable
    sudo ufw status
}

fetch_and_install_channel_backup() {
    INSTALL_DIR="/usr/local/bin"

    BACKUP_SCRIPT="lnd-channel-backup.sh"
    BACKUP_SCRIPT_URL="https://gist.githubusercontent.com/vindard/e0cd3d41bb403a823f3b5002488e3f90/raw/4bcf3c0163f77443a6f7c00caae0750b1fa0d63d/$BACKUP_SCRIPT"

    BACKUP_SYSTEMD_FILE=systemd/lnd-channel-backup.service
    SYSTEMD_DIR=/etc/systemd/system

    # Check for API token
    if [[ -z $DROPBOX_API_TOKEN ]] ; then
        echo "Please enter value for 'DROPBOX_API_TOKEN' in '.env' and re-run."
        return 1
    fi

    # Fetch script and setup permissions
    echo
    echo "Fetching '$BACKUP_SCRIPT' from $BACKUP_SCRIPT_URL ..."
    if wget -qN $BACKUP_SCRIPT_URL; then
        echo "Fetched."
    else
        echo "Could not fetch, skipping channel backup setup"
        return 1
    fi

    sudo chmod +x $BACKUP_SCRIPT
    sed -i "s/DROPBOX_APITOKEN=\".*\"/DROPBOX_APITOKEN=\"$DROPBOX_API_TOKEN\"/" $BACKUP_SCRIPT

    echo
    echo "Installing '$BACKUP_SCRIPT' to '$INSTALL_DIR'..."
    sudo mv $BACKUP_SCRIPT $INSTALL_DIR/
    echo "Installed."


    # Install systemd service and start
    if [[ ! -e $BACKUP_SYSTEMD_FILE ]]; then
        echo "No file found at $BACKUP_SYSTEMD_FILE to setup systemd service with."
        return 1
    fi

    sudo sed -i "s|ExecStart=.*|ExecStart=$INSTALL_DIR/$BACKUP_SCRIPT|g" $BACKUP_SYSTEMD_FILE

    echo
    echo "Installing '$BACKUP_SYSTEMD_FILE' to '$SYSTEMD_DIR'..."
    sudo cp $BACKUP_SYSTEMD_FILE $SYSTEMD_DIR/
    echo "Installed."

    sudo systemctl enable lnd-channel-backup
    sudo systemctl start lnd-channel-backup
}


# == Function calls ==

run_lnd_install() {
    fetch_and_verify || return 1
    extract_and_install_lnd || return 1
    cleanup_install || return 1
    enable_pi_permissions
    setup_auto_unlock || return 1
    setup_lnd_systemd || return 1
    install_lnd_connect
    fetch_and_install_channel_backup
}
