#!/bin/bash


# == Dependencies function definitions ==

RUST_TAR_FILE=rust.tar.gz
RUST_SIG_FILE=rust.tar.gz.asc

RUST_DIR=$HOME/rust


rust_fetch_and_verify() {

    wget -c -O $RUST_TAR_FILE https://static.rust-lang.org/dist/rust-1.48.0-armv7-unknown-linux-gnueabihf.tar.gz
    wget -c -O $RUST_SIG_FILE https://static.rust-lang.org/dist/rust-1.48.0-armv7-unknown-linux-gnueabihf.tar.gz.asc
    curl https://keybase.io/rust/pgp_keys.asc | gpg --import

    echo
    echo "Checking signatures on '$RUST_TAR_FILE' file..."
    VERIFY="Good signature from "
    if gpg --verify $RUST_SIG_FILE $RUST_TAR_FILE |& grep -q "$VERIFY"
    then
        echo "All signature checks on '$RUST_TAR_FILE' checks passed!"
        echo
    else
        CHECK_PASS=0
        echo "Signature did not match for verifying '$RUST_TAR_FILE' file"
    fi

}

install_rust() {
    if [[ ! -e $RUST_TAR_FILE ]]; then
        echo "Run 'rust_fetch_and_verify' function first to fetch Rust tar file"
        return 1
    fi

    mkdir $RUST_DIR
    tar --strip-components 1 -C $RUST_DIR -xzvf $RUST_TAR_FILE
    rm $RUST_TAR_FILE $RUST_SIG_FILE

    pushd $RUST_DIR
    sudo ./install.sh
    popd
}

install_build_tools() {
    sudo apt update && sudo apt install -y \
        clang \
        cmake
}

install_electrs_deps() {
    rust_fetch_and_verify
    install_rust
    install_build_tools
}


# == Electrs function definitions ==

fetch_and_install_electrs() {
    # download
    electrsgit=$(curl -s https://api.github.com/repos/romanz/electrs/tags | jq -r '.[0].name')
    git clone --branch ${electrsgit} https://github.com/romanz/electrs.git
    pushd electrs

    # compile
    cargo build --locked --release

    # install
    sudo cp ./target/release/electrs /usr/local/bin/

    # cleanup
    popd
    rm -rf electrs
}

setup_lnd_systemd() {
    SYSTEMD_FILE=systemd/electrs.service
    if [[ ! -e $SYSTEMD_FILE ]]; then
        echo "No file found at $SYSTEMD_FILE to setup systemd service with."
        return 1
    fi

    sudo cp $SYSTEMD_FILE /etc/systemd/system/
    sudo systemctl enable electrs
    sudo systemctl start electrs
}


run_electrs_install() {
    # install_electrs_deps
    # fetch_and_install_electrs
    setup_lnd_systemd
}
