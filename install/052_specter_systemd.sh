#!/bin/bash

setup_specter_systemd() {
    SERVICE_NAME=specter
    SYSTEMD_FILE=systemd/$SERVICE_NAME.service

    # Check for args
    SPECTER_USER="$1"
    if [[ -z $SPECTER_USER ]]; then
        echo "Please pass in a \$SPECTER_USER argument"
        return 1
    fi

    # Check for systemd template file
    if [[ ! -e $SYSTEMD_FILE ]]; then
        echo "No file found at $SYSTEMD_FILE to setup systemd service with."
        return 1
    fi

    # Configure systemd file
    sudo sed \
        "s/<specter-user>/$SPECTER_USER/g" \
        $SYSTEMD_FILE \
    > \
        /etc/systemd/system/$(basename $SYSTEMD_FILE)

    sudo systemctl enable $SERVICE_NAME
    sudo systemctl start $SERVICE_NAME
}
