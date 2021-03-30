#!/bin/bash


# == Function definitions ==

BITCOIN_DIRNAME="bitcoin-0.20.1"
TAR_FILE="$BITCOIN_DIRNAME-arm-linux-gnueabihf.tar.gz"
KEY_FILE="laanwj-releases.asc"
SHA256SUMS="SHA256SUMS.asc"

CHECK_PASS=true
check() {
    if [[ ! "$CHECK_PASS" == "true" ]]; then
        return 1
    fi
}

fetch_and_verify() {
    # download Bitcoin Core binary
    wget -c https://bitcoincore.org/bin/bitcoin-core-0.20.1/$TAR_FILE
    wget -c https://bitcoincore.org/bin/bitcoin-core-0.20.1/$SHA256SUMS
    wget -c https://bitcoin.org/$KEY_FILE
    echo && echo

    # check that the reference checksum matches the real checksum
    # (ignore the "lines are improperly formatted" warning)
    echo "Checking sha256sum values..."
    if check && \
        sha256sum --check $SHA256SUMS --ignore-missing |& grep -q "$TAR_FILE: OK"
    then
        echo "All sha256sum checks passed!"
        echo
    else
        CHECK_PASS=0
        echo "sha256sum did not match for '$TAR_FILE'"
    fi

    # import the public key of Wladimir van der Laan, verify the signed  checksum file
    # and check the fingerprint again in case of malicious keys
    echo "Retrieving '$KEY_FILE' keys..."
    gpg --import ./$KEY_FILE
    gpg --refresh-keys > /dev/null 2>&1

    echo
    echo "Checking signatures on '$SHA256SUMS' file..."
    VERIFY_1="Good signature from \"Wladimir J. van der Laan"
    VERIFY_2="Primary key fingerprint: 01EA.*5486.*DE18.*A882.*D4C2.*6845.*90C8.*019E.*36C2.*E964"
    if check && \
        gpg --verify $SHA256SUMS |& grep -q "$VERIFY_1" && \
        gpg --verify $SHA256SUMS |& grep -q "$VERIFY_2"
    then
        echo "All signature checks on '$SHA256SUMS' checks passed!"
        echo
    else
        CHECK_PASS=0
        echo "Signature did not match for verifying '$SHA256SUMS' file"
    fi

    if ! check; then
        echo
        echo "Some verification step failed, exiting..."
        return 1
    fi
}

extract_and_install_bitcoind() {
    tar -xvf $TAR_FILE
    sudo install -m 0755 -o root -g root -t /usr/local/bin $BITCOIN_DIRNAME/bin/*

    echo
    echo "---------------"
    bitcoind --version \
        || echo "'bitcoind' was not successfully installed" && return 1
}

cleanup_install() {
    rm $TAR_FILE
    rm $SHA256SUMS
    rm $KEY_FILE
    rm -rf $BITCOIN_DIRNAME

    echo
    echo "Cleaned up bitcoind install files."
    echo
}

setup_bitcoin_systemd() {
    SYSTEMD_FILE=systemd/bitcoind.service
    if [[ ! -e $SYSTEMD_FILE ]]; then
        echo "No file found at $SYSTEMD_FILE to setup systemd service with."
        return 1
    fi

    sudo cp $SYSTEMD_FILE /etc/systemd/system/
    sudo systemctl enable bitcoind
    sudo systemctl start bitcoind
}

# == Function calls ==

run_bitcoind_install() {
    fetch_and_verify || return 1
    extract_and_install_bitcoind || return 1
    cleanup_install || return 1
    setup_bitcoin_systemd || return 1
}
