#!/bin/bash

# == Setup variables ==

SPARK_USER="bitcoin"
SPARK_VERSION="v0.3.1"

SPARK_PORT="8000"

SPARK_LOGIN_USERNAME=""
SPARK_LOGIN_PASSWORD=""

# Dir & GitHub values
SPARK_DIRNAME="spark-wallet"
SPARK_GITHUB_DIR="/home/$SPARK_USER/$SPARK_DIRNAME"
GITHUB_REPO="https://github.com/shesek/$SPARK_DIRNAME"

SPARK_DATA_DIR="/mnt/ext/apps-data/$SPARK_DIRNAME"
SPARK_DATA_SYMLINK="/home/$SPARK_USER/.$SPARK_DIRNAME"
SPARK_CONFIG_FILE="$SPARK_DATA_SYMLINK/config"


# == Helper functions ==
source install/000_helpers.sh


# == Dependencies function definitions ==

configure_ufw() {
    sudo ufw allow from 192.168.0.0/16 to any port "$SPARK_PORT" comment "allow Spark Wallet from Local LAN"
}

install_spark() {
    echo_label "Spark Wallet"

    # Check for nodejs & install if not present
    if ! check_dependency npm; then
        source install/013_nodejs.sh
        install_nodejs
    fi

    # Setup spark user
    if ! id $SPARK_USER > /dev/null 2>&1; then
        sudo adduser --gecos "" --disabled-password $SPARK_USER
    fi

    # Setup spark data dir
    sudo mkdir -p $SPARK_DATA_DIR
    sudo ln -s $SPARK_DATA_DIR $SPARK_DATA_SYMLINK

    # Setup config file
    sudo cp "configs/spark-wallet.config" "$SPARK_CONFIG_FILE"
    sudo sed -i \
        "s|<username>|$SPARK_LOGIN_USERNAME|g" \
        $SPARK_CONFIG_FILE
    sudo sed -i \
        "s|<password>|$SPARK_LOGIN_PASSWORD|g" \
        $SPARK_CONFIG_FILE
    sudo sed -i \
        "s|<port>|$PORT|g" \
        $SPARK_CONFIG_FILE

    # Change data dir ownership
    sudo chown -R $SPARK_USER: $SPARK_DATA_DIR
    sudo chown -R $SPARK_USER: $SPARK_DATA_SYMLINK

    # Clone repo
    pushd /tmp > /dev/null
    git clone $GITHUB_REPO
    sudo mv $SPARK_DIRNAME /home/$SPARK_USER/
    sudo chown -R $SPARK_USER: $SPARK_GITHUB_DIR
    popd > /dev/null

    # Install spark
    pushd $SPARK_GITHUB_DIR > /dev/null
    sudo -u $SPARK_USER git checkout ${SPARK_VERSION}
    echo_label ": Running Spark npm steps"
    sudo -u $SPARK_USER npm install @babel/cli
    sudo -u $SPARK_USER npm run dist:npm
    popd > /dev/null
}

setup_spark_systemd() {
    SYSTEMD_FILENAME="spark-wallet.service"
    SYSTEMD_FILE="systemd/$SYSTEMD_FILENAME"
    FILE_ON_SYSTEM="/etc/systemd/system/$SYSTEMD_FILENAME"

    if [[ ! -e $SYSTEMD_FILE ]]; then
        echo "No file found at $SYSTEMD_FILE to setup systemd service with."
        return 1
    fi

    sudo cp $SYSTEMD_FILE $FILE_ON_SYSTEM

    sudo systemctl enable spark-wallet
    sudo systemctl start spark-wallet
}


# == Function calls ==

run_spark_install() {
    if [[ -z "$SPARK_LOGIN_USERNAME" ]] || [[ -z "$SPARK_LOGIN_PASSWORD" ]]
    then
        echo "CLN-Spark install: Please set username & password for the service"
        echo "CLN-Spark install:Exiting..." && echo
    fi

    configure_ufw
    install_spark
    setup_spark_systemd
}
