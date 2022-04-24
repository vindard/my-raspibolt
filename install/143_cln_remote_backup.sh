#!/bin/bash


# == Function definitions ==

fetch_and_install_channel_backup() {
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


# == Function calls ==

run_cln_remote_backup_install() {
    fetch_and_install_channel_backup || return 1
}
