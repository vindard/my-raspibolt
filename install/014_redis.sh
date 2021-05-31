#!/bin/bash
# From guide: https://github.com/dangeross/guides/blob/master/raspibolt/raspibolt_6B_lndhub.md

# == Setup variables ==

REDIS_USER="redis"

SOURCE_DIR="/mnt/ext/apps-data/redis"
REDIS_DATA_DIR="$SOURCE_DIR/.redis"

CONFIG_DIR="/etc/redis"
CONFIG_FILENAME="redis.conf"
CONFIG_FILE="$CONFIG_DIR/$CONFIG_FILENAME"

# == Helper functions ==
source install/000_helpers.sh


# == Function definitions ==

install_redis() {
    echo_label "Redis"
    VERSION="6.2.3"
    DIRNAME="redis-$VERSION"
    TAR_FILE="$DIRNAME.tar.gz"

    Fetch the install files
    pushd /tmp
    wget "http://download.redis.io/releases/$TAR_FILE"
    tar -xzf $TAR_FILE

    # Install
    pushd $DIRNAME
    make
    sudo make install
    popd > /dev/null

    # Setup redis user
    if ! id $REDIS_USER > /dev/null 2>&1; then
        sudo adduser --system --group --no-create-home $REDIS_USER
    fi

    # Create working dir
    sudo mkdir -p "$REDIS_DATA_DIR"
    sudo chown -R $REDIS_USER: "$SOURCE_DIR"
    sudo chmod 770 $REDIS_DATA_DIR

    # Add conf to system
    sudo mkdir $CONFIG_DIR
    sudo cp $CONFIG_FILENAME $CONFIG_DIR
    popd > /dev/null
}

configure_redis() {
    echo_label ": Configuring Redis"

    append_to_sysctl \
        "" \
        "# For redis: https://thisdavej.com/how-to-install-redis-on-a-raspberry-pi-using-docker/" \
        "vm.overcommit_memory=1"

    sudo sed -i "s|^supervised no.*$|supervised systemd|g" $CONFIG_FILE
    sudo sed -i "s|^dir .*$|dir $REDIS_DATA_DIR|g" $CONFIG_FILE
}

setup_redis_systemd() {
    SYSTEMD_FILENAME="redis.service"
    SYSTEMD_FILE="systemd/$SYSTEMD_FILENAME"
    FILE_ON_SYSTEM="/etc/systemd/system/$SYSTEMD_FILENAME"

    if [[ ! -e $SYSTEMD_FILE ]]; then
        echo "No file found at $SYSTEMD_FILE to setup systemd service with."
        return 1
    fi

    sudo cp $SYSTEMD_FILE $FILE_ON_SYSTEM
    sudo sed -i \
        "s|<redis-conf>|$CONFIG_FILE|g" \
        $FILE_ON_SYSTEM
    sudo sed -i \
        "s|<redis-user>|$REDIS_USER|g" \
        $FILE_ON_SYSTEM

    sudo systemctl enable redis
    sudo systemctl start redis
}



run_install_redis() {
    install_redis
    configure_redis
    setup_redis_systemd
}
