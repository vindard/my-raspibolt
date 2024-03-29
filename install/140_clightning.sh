#!/bin/bash

# == Setup variables ==

CLIGHTNING_USER="bitcoin"
CLIGHTNING_DIRNAME="lightning"

VERSION_TAG="v0.10.2"
CLIGHTNING_GIT_DIR="/home/$CLIGHTNING_USER/$CLIGHTNING_DIRNAME"
GITHUB_REPO="https://github.com/ElementsProject/$CLIGHTNING_DIRNAME.git"

MOUNTPOINT="/mnt/ext"
SYMLINK_DIR="/home/$CLIGHTNING_USER"
CLIGHTNING_DATA_SYMLINK="$SYMLINK_DIR/.$CLIGHTNING_DIRNAME"
CLIGHTNING_DATA_DIR="$MOUNTPOINT/$CLIGHTNING_DIRNAME"

# Note: Store on disk because external drive is mounted noexec (see 'sdb' entry in /etc/mtab)
CLIGHTNING_PLUGINS_DATA_DIR="$SYMLINK_DIR/cln-plugins-enabled"
CLIGHTNING_PLUGINS_DIR="$CLIGHTNING_DATA_DIR/plugins"

BACKUPS_DIR="$MOUNTPOINT/apps-data/backups"
CLIGHTNING_BACKUP_DIR="$BACKUPS_DIR/$CLIGHTNING_DIRNAME"

# == Helper functions ==
source install/000_helpers.sh

setup_symlinks() {
    # Check for successful mount
    if ! mount | grep -q $MOUNTPOINT; then
        echo "No drive mounted at '$MOUNTPOINT'"
        return 1
    fi

    # Setup symlinks
    sudo mkdir -p "$CLIGHTNING_DATA_DIR"
    sudo ln -s "$CLIGHTNING_DATA_DIR/" "$CLIGHTNING_DATA_SYMLINK"
    sudo mkdir -p "$CLIGHTNING_DATA_SYMLINK/bitcoin"
    sudo chown -R bitcoin:bitcoin "$CLIGHTNING_DATA_SYMLINK"
    sudo chown -R bitcoin:bitcoin "$CLIGHTNING_DATA_DIR"
}

verify_commit() {
    SIGNER="cdecker"
    SIGNER_PGP_FINGERPRINT="A26D6D9FE088ED58"
    SIGNER_PGP_KEYS="$SIGNER.txt"
    SIGNER_PGP_URL="https://raw.githubusercontent.com/ElementsProject/lightning/master/contrib/keys/$SIGNER_PGP_KEYS"

    pushd $CLIGHTNING_GIT_DIR > /dev/null

    echo_label ": Importing '$SIGNER' keys"
    sudo wget -c $SIGNER_PGP_URL
    FINGERPRINT=$(gpg --show-keys ${SIGNER_PGP_KEYS} 2>/dev/null | grep "${SIGNER_PGP_FINGERPRINT}" -c)
    if [ "${FINGERPRINT}" -lt 1 ]; then
        echo "Imported keys for '$SIGNER' did not match fingerprint '$SIGNER_PGP_FINGERPRINT'"
        return 1
    fi
    gpg --import ./$SIGNER_PGP_KEYS
    sudo rm $SIGNER_PGP_KEYS

    echo_label ": Verifying version tag '$VERSION_TAG' against signer '$SIGNER'"
    if git verify-tag $VERSION_TAG > /dev/null 2>&1; then
        echo "Good signature from '$SIGNER' on tag '$VERSION_TAG'"
        echo
    else
        echo "Signature did not match for verifying commit '$VERSION_TAG'"
        return 1
    fi

    pushd  > /dev/null
}

fetch_and_verify() {
    # Clone repo
    echo_label ": Cloning c-lightning repo"
    pushd /tmp > /dev/null
    git clone $GITHUB_REPO $CLIGHTNING_DIRNAME
    sudo rm -rf $CLIGHTNING_GIT_DIR
    sudo mv $CLIGHTNING_DIRNAME /home/$CLIGHTNING_USER/
    sudo chown -R $CLIGHTNING_USER: $CLIGHTNING_GIT_DIR
    popd > /dev/null

    # Verify
    verify_commit
}

install_clightning() {

    # Install clightning dependencies
    echo_label "c-lightning dependencies"
    sudo apt update && sudo apt install -y \
        autoconf \
        automake \
        build-essential \
        git \
        libtool \
        libgmp-dev \
        libsqlite3-dev \
        python3 \
        python3-mako \
        python3-pip \
        net-tools \
        zlib1g-dev \
        libsodium-dev \
        gettext

    sudo python3 -m pip install --upgrade pip
    sudo python3 -m pip install mrkd mistune==0.8.4


    # Make clightning
    echo_label ": c-lightning from repo"
    pushd $CLIGHTNING_GIT_DIR > /dev/null
    sudo git checkout $VERSION_TAG
    sudo -u bitcoin ./configure --enable-experimental-features
    sudo -u bitcoin make

    echo_label ": Install to /usr/local/bin/"
    sudo make install

    sudo git checkout -
    popd > /dev/null

    # Configure clightning
    echo_label ": Adding clightning configs"
    sudo cp "configs/cl.conf" "$CLIGHTNING_DATA_SYMLINK/"

    # Configure plugins dir
    echo_label ": Creating c-lightning plugins dir"
    sudo mkdir -p $CLIGHTNING_PLUGINS_DATA_DIR
    sudo chown -R $CLIGHTNING_USER: $CLIGHTNING_PLUGINS_DATA_DIR
    sudo ln -s $CLIGHTNING_PLUGINS_DATA_DIR $CLIGHTNING_PLUGINS_DIR
    sudo chown -R $CLIGHTNING_USER: $CLIGHTNING_PLUGINS_DIR

    sudo chown -R $CLIGHTNING_USER: $CLIGHTNING_DATA_DIR
}

add_backup_plugin() {
    # Add backup plugin
    PLUGIN_NAME="backup"

    pushd /tmp > /dev/null
    sudo rm -rf plugins
    git clone git@github.com:lightningd/plugins.git
    pushd plugins > /dev/null
    sudo cp -r $PLUGIN_NAME $CLIGHTNING_PLUGINS_DIR
    popd > /dev/null
    popd > /dev/null

    sudo -u bitcoin python3 -m pip install --user \
        -r $CLIGHTNING_PLUGINS_DIR/$PLUGIN_NAME/requirements.txt
    sudo chmod +x $CLIGHTNING_PLUGINS_DIR/$PLUGIN_NAME/$PLUGIN_NAME.py

    sudo mkdir -p $CLIGHTNING_BACKUP_DIR
    sudo chown -R $CLIGHTNING_USER: $CLIGHTNING_BACKUP_DIR
    sudo -u bitcoin python3 $CLIGHTNING_PLUGINS_DIR/backup/backup-cli init \
        --lightning-dir $CLIGHTNING_DATA_SYMLINK/bitcoin \
        file://$CLIGHTNING_BACKUP_DIR/lightningd.sqlite3.backup

    sudo chown -R $CLIGHTNING_USER: $CLIGHTNING_DATA_DIR
}

setup_clightning_systemd() {
    SYSTEMD_FILE=systemd/lightningd.service
    if [[ ! -e $SYSTEMD_FILE ]]; then
        echo "No file found at $SYSTEMD_FILE to setup systemd service with."
        return 1
    fi

    sudo cp $SYSTEMD_FILE /etc/systemd/system/
    sudo systemctl enable lightningd
    sudo systemctl start lightningd
}

enable_pi_permissions() {
    echo "Allocating lightningd/lightning-cli permissions to 'pi' user"
    CLIGHTNING_BITCOIN_DIR="$CLIGHTNING_DATA_DIR/bitcoin"

    if [[ -e $CLIGHTNING_BITCOIN_DIR ]]; then
        sudo chmod g+X $CLIGHTNING_BITCOIN_DIR
    else
        echo "c-lightning data data dir not found at '$CLIGHTNING_BITCOIN_DIR', skipping..."
        return 1
    fi

    echo
    echo "---------------"
    echo "Calling 'lightning-cli' from user 'pi'..."
    echo
    lightning-cli getinfo \
        || echo "'lightning-cli' was not successfully permissioned to user 'pi'" && return 1
}

setup_backup_compaction_cronjob() {
    # TODO implement this from: https://github.com/rootzoll/raspiblitz/blob/6d3af0cd8c79129d838cc91063e56c9d8c458ad7/home.admin/config.scripts/cl-plugin.backup.sh#L140
    echo
}

setup_backup_auto_upload() {
    INSTALL_DIR="/usr/local/bin"

    BACKUP_SERVICE_NAME="cln-sqlite-backup"
    BACKUP_SCRIPT="$BACKUP_SERVICE_NAME.sh"
    BACKUP_SCRIPT_URL="https://gist.githubusercontent.com/vindard/e0cd3d41bb403a823f3b5002488e3f90/raw/999cca069387c866893f688e755c341c300b05c9/$BACKUP_SCRIPT"

    SOURCE_SYSTEMD_FILE=systemd/inotify-backup.service
    BACKUP_SYSTEMD_FILE=$BACKUP_SERVICE_NAME.service
    SYSTEMD_DIR=/etc/systemd/system

    # Check for API token
    if [[ -z $DROPBOX_API_TOKEN ]] ; then
        echo "Please enter value for 'DROPBOX_API_TOKEN' in '.env' and re-run."
        return 1
    fi

    # TODO: Add steps to setup dropbox_uploader, with modified chunk validation
    # (https://github.com/andreafabrizi/Dropbox-Uploader)

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
    if [[ ! -e $SOURCE_SYSTEMD_FILE ]]; then
        echo "No file found at $SOURCE_SYSTEMD_FILE to setup systemd service with."
        return 1
    fi


    echo
    echo "Installing '$SOURCE_SYSTEMD_FILE' to '$SYSTEMD_DIR/$BACKUP_SYSTEMD_FILE'..."
    sudo cp \
        $SOURCE_SYSTEMD_FILE \
        $SYSTEMD_DIR/$BACKUP_SYSTEMD_FILE
    sudo sed -i \
        "s|ExecStart=.*|ExecStart=$INSTALL_DIR/$BACKUP_SCRIPT|g" \
        $SYSTEMD_DIR/$BACKUP_SYSTEMD_FILE
    echo "Installed."

    sudo systemctl enable $BACKUP_SERVICE_NAME
    sudo systemctl start $BACKUP_SERVICE_NAME
}

bootstrap_node() {
    # This script simply connects to 2 random recommended nodes. Alternatively we
    # can manually connect with `$ lightning-cli connect <nodeid> <ip> <port>`.

    pushd $CLIGHTNING_GIT_DIR > /dev/null
    contrib/bootstrap-node.sh
    popd > /dev/null
}

cleanup() {
    sudo rm -rf $CLIGHTNING_GIT_DIR
}

# == Function calls ==

run_clightning_install() {
    setup_symlinks || return 1
    fetch_and_verify || return 1
    install_clightning || return 1
    add_backup_plugin || return 1
    setup_clightning_systemd || return 1
    enable_pi_permissions || return 1
    setup_backup_compaction_cronjob || return 1
    setup_backup_auto_upload || return 1
    bootstrap_node || return 1
    cleanup || return 1

    echo_label ": Finished installing and initiating 'lightningd' system service"
    echo "Check '$CLIGHTNING_DATA_SYMLINK/cl.log' to confirm 'lightningd' is running..."
}
