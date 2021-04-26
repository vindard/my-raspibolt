#!/bin/bash

# == Helper functions ==
source install/000_helpers.sh

install_transmission() {
    sudo apt update && sudo apt install -y \
        transmission-daemon
}

# == Function definitions ==

configure_transmission() {
    TORRENT_DIR=/home/$TSM_USER/Downloads/_torrents
    INCOMPLETE_DIR=$TORRENT_DIR/incomplete
    SETTINGS_FILE=/etc/transmission-daemon/settings.json
    SYSTEMD_FILE_1=/etc/systemd/system/multi-user.target.wants/transmission-daemon.service
    SYSTEMD_FILE_2=/lib/systemd/system/transmission-daemon.service

    # Check for Transmission user value
    if [[ -z $TSM_USER ]] ; then
        echo "Please enter value for 'TSM_USER' in '.env' and re-run."
        return 1
    fi

    # Check for Transmission password value
    if [[ -z $TSM_PASS ]] ; then
        echo "Please enter value for 'TSM_PASS' in '.env' and re-run."
        return 1
    fi


    if ! check_dependency transmission-remote; then
        echo "'transmission-remote' not found, installing via 'transmission-daemon'..."
        install_transmission
    fi

    sudo systemctl stop transmission-daemon

    # Check user, and create if not found
    if ! id $TSM_USER > /dev/null 2>&1; then
        sudo adduser $TSM_USER
    fi


    # Create the Transmission torrent dir and allocate to torrent user
    mkdir -p $INCOMPLETE_DIR
    sudo chown -R $TSM_USER:$TSM_USER $TORRENT_DIR

    sudo chown -R $TSM_USER:$TSM_USER /etc/transmission-daemon
    sudo mkdir -p /home/$TSM_USER/.config/transmission-daemon/
    sudo ln -s $SETTINGS_FILE /home/$TSM_USER/.config/transmission-daemon/
    sudo chown -R $TSM_USER:$TSM_USER /home/$TSM_USER/.config/transmission-daemon/

    # Configure Transmission settings
    sudo cp $SETTINGS_FILE $SETTINGS_FILE.bak

    change_json_value $SETTINGS_FILE \
        "download-dir" \
        "$TORRENT_DIR"

    change_json_value $SETTINGS_FILE \
        "incomplete-dir" \
        "$INCOMPLETE_DIR"

    toggle_json_true $SETTINGS_FILE \
        "incomplete-dir-enabled"

    change_json_value $SETTINGS_FILE \
        "rpc-username" \
        "$TSM_USER"

    change_json_value $SETTINGS_FILE \
        "rpc-password" \
        "$TSM_PASS"

    change_json_value $SETTINGS_FILE \
        "rpc-whitelist" \
        "127.0.0.1,192.168.*.*"


    # Configure user in systemd files
    sudo sed -i "s/^User=.*/User=$TSM_USER/g" $SYSTEMD_FILE_1
    sudo sed -i "s/^User=.*/User=$TSM_USER/g" $SYSTEMD_FILE_2


    # 'active' mode requires port 51413 be opened on the router and forwarded to this device
    # sudo ufw allow 51413/tcp \
        # comment 'allow Transmission active mode'


    # Reload and restart daemon
    sudo systemctl daemon-reload
    sudo systemctl enable transmission-daemon
    # May need to delete the existing file at $SYSTEMD_FILE_1 if $SYSTEMD_FILE_2 exists and above errors
    sudo systemctl start transmission-daemon


    # Setup alias
	FILE="/home/$TSM_USER/.bashrc"
	append_to_file \
        "" \
        "# Transmission alias" \
        "alias tsm='transmission-remote --auth $TSM_USER:$TSM_PASS'"

	FILE="/home/$TSM_USER/.zshrc"
	append_to_file \
        "" \
        "# Transmission alias" \
        "alias tsm='transmission-remote --auth $TSM_USER:$TSM_PASS'"
}

# == Function calls ==

run_transmission_install() {
    configure_transmission || return 1
}
