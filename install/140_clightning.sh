#!/bin/bash

# == Setup variables ==

CLIGHTNING_USER="bitcoin"
CLIGHTNING_DIRNAME="lightning"

VERSION_TAG="v0.10.2"
CLIGHTNING_GIT_DIR="/home/$CLIGHTNING_USER/$CLIGHTNING_DIRNAME"
GITHUB_REPO="https://github.com/ElementsProject/$CLIGHTNING_DIRNAME.git"

SYMLINK_DIR="/home/$CLIGHTNING_USER"
CLIGHTNING_DATA_SYMLINK="$SYMLINK_DIR/.$CLIGHTNING_DIRNAME"


# == Helper functions ==
source install/000_helpers.sh

setup_symlinks() {
    MOUNTPOINT="/mnt/ext"
    CLIGHTNING_DATA_DIR="$MOUNTPOINT/$CLIGHTNING_DIRNAME"

    # Check for successful mount
    if ! mount | grep -q $MOUNTPOINT; then
        echo "No drive mounted at '$MOUNTPOINT'"
        return 1
    fi

    # Setup symlinks
    sudo mkdir -p "$CLIGHTNING_DATA_DIR"
    sudo ln -s "$CLIGHTNING_DATA_DIR/" "$CLIGHTNING_DATA_SYMLINK"
    sudo chown -R bitcoin:bitcoin "$CLIGHTNING_DATA_SYMLINK"
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

    sudo rm -rf $CLIGHTNING_GIT_DIR

    # Configure clightning
    echo_label ": Adding clightning configs"
    sudo cp "configs/cl.conf" "$CLIGHTNING_DATA_SYMLINK/"

    # TODO: Configure plugins dir
    # TODO: Add clboss
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



# == Function calls ==

run_clightning_install() {
    setup_symlinks || return 1
    fetch_and_verify || return 1
    install_clightning || return 1
    setup_clightning_systemd || return 1

    echo_label ": Finished installing and initiating 'lightningd' system service"
    echo "Check '$CLIGHTNING_DATA_SYMLINK/cl.log' to confirm 'lightningd' is running..."
}
