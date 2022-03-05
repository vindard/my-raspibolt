#!/bin/bash

# == Setup variables ==

MEMPOOL_USER="mempool"

# Dir & GitHub values
MEMPOOL_DIRNAME="mempool"
MEMPOOL_GIT_DIR="/home/$MEMPOOL_USER/$MEMPOOL_DIRNAME"
GITHUB_REPO="https://github.com/mempool/$MEMPOOL_DIRNAME.git"


# == Helper functions ==
source install/000_helpers.sh


# == Dependencies function definitions ==

# configure_ufw() {
#     sudo ufw allow from 192.168.0.0/16 to any port "$MEMPOOL_PORT" comment "allow mempool.space from Local LAN"
# }

install_mempool() {
    echo_label "mempool.space"

    # Check for nodejs & install if not present
    if ! check_dependency npm; then
        source install/013_nodejs.sh
        install_nodejs
    fi

    # Install MariaDB
    # echo_label "MariaDB for mempool.space"
    # sudo apt update && sudo apt install -y \
    #     mariadb-server \
    #     mariadb-client

    # Configure MariaDB
    # sudo mariadb -u root < \
    #     "configs/mempool-setup.sql"

    # Install nginx
    # echo_label "Nginx for mempool.space"
    # sudo apt update && sudo apt install -y \
    #     nginx \
    #     python-certbot-nginx

    sudo mkdir -p "/var/www"

    # Setup mempool.space user
    if ! id $MEMPOOL_USER > /dev/null 2>&1; then
        sudo adduser --gecos "" --disabled-password $MEMPOOL_USER
    fi

    # Clone repo
    pushd /tmp > /dev/null
    git clone $GITHUB_REPO $MEMPOOL_DIRNAME
    sudo mv $MEMPOOL_DIRNAME /home/$MEMPOOL_USER/
    popd > /dev/null

    # Change ownership of git (run) folder
    sudo chown -R $MEMPOOL_USER: $MEMPOOL_GIT_DIR

    # Fetch bitcoin rpc credentials
    RPC_USER=$(cat $HOME/.bitcoin/bitcoin.conf| grep "rpcuser" | awk -F= '{print $2}')
    RPC_PASS=$(cat $HOME/.bitcoin/bitcoin.conf| grep "rpcpass" | awk -F= '{print $2}')

    # Install mempool.space
    sudo -u $MEMPOOL_USER install/121_mempool_install.sh \
        $MEMPOOL_GIT_DIR \
        $RPC_USER \
        $RPC_PASS
}

setup_nginx_files() {
    pushd "$MEMPOOL_GIT_DIR/frontend" > /dev/null
    if [[ -d dist/mempool ]]; then
        echo "Copying frontend to /var/www/ for nginx..."
        sudo rsync -av --delete "dist/mempool" "/var/www/"
        sudo chown -R www-data: "/var/www/mempool"

        pushd $MEMPOOL_GIT_DIR > /dev/null
        cp nginx.conf nginx-mempool.conf /etc/nginx/
        popd > /dev/null

        sudo systemctl restart nginx
    else
        echo "Skipping: couldn't copy frontend to /var/www/, dir missing '$MEMPOOL_GIT_DIR/frontend'"
    fi
    popd > /dev/null
}

setup_mempool_systemd() {
    SYSTEMD_FILENAME="mempool.service"
    SYSTEMD_FILE="systemd/$SYSTEMD_FILENAME"
    FILE_ON_SYSTEM="/etc/systemd/system/$SYSTEMD_FILENAME"

    if [[ ! -e $SYSTEMD_FILE ]]; then
        echo "No file found at $SYSTEMD_FILE to setup systemd service with."
        return 1
    fi

    sudo cp $SYSTEMD_FILE $FILE_ON_SYSTEM

    sudo systemctl enable mempool
    sudo systemctl start mempool
}


# == Function calls ==

run_mempool_install() {
    # configure_ufw
    install_mempool
    setup_nginx_files
    # setup_mempool_systemd
}
