#!/bin/bash


# == > IMPORT FUNCTION DEFINTIONS < ==

# == Environment variables ==
if [[ ! -e .env ]]; then
    echo "Please create a '.env' file and set required variables"
    exit 1
fi
source .env

# == Helper functions ==
source install/000_helpers.sh

# == System setup functions ==
source install/010_system.sh
source install/015_docker.sh

# == bitcoind install functions ==
source install/020_bitcoind.sh

# == lnd install functions ==
source install/030_lnd.sh

# == electrs install functions ==
source install/040_electrs.sh

# == specter install functions ==
source install/051_specter_deps.sh
source install/052_specter_systemd.sh

# == transmission install functions ==
source install/060_transmission.sh

# == sphinx.chat install functions ==
source install/070_sphinx.sh

# == thunderhub install functions ==
source install/080_thunderhub.sh

# == lndmanage install functions ==
source install/090_lndmanage.sh

# == bos install functions ==
source install/100_bos.sh

# == lndhub install functions ==
source install/110_lndhub.sh

# == mempool.space install functions ==
source install/120_mempool.sh

# == clightning install functions ==
source install/140_clightning.sh
source install/141_cln_spark.sh
source install/142_clboss.sh
source install/143_cln_remote_backup.sh


# == > SCRIPT START < ==

# == Step function definitions ==

# Step 1
# Run  sudo raspi-config and change:
#    1. Set pi password with '$ sudo passwd pi'
#    2. Set root password with '$ sudo passwd root'
#    3. Run sudo raspi-config and set localisation

# Step 2
step_02() {
    run_first_update
    install_standard
    install_recommended
    install_speedtest
    install_magic_wormhole
    install_zsh
}

# Step 3
# Double-check ssh keys in auth file before running
step_03() {
    disable_ssh_password
}

# Step 4
step_04() {
    setup_node_users && \
        echo "Rebooting now to save changes..." && \
        sudo reboot
}

# Step 5
# > Mount the external Hard Drive
step_05() {
    setup_symlinks
    
    move_swap_file && \
        echo "Rebooting now to save changes..." && \
        sudo reboot
}


# Step 6
step_06() {
    setup_ufw
    setup_fail2ban

    # Optionally manually increase open file limits for TCP connections
    # > https://stadicus.github.io/RaspiBolt/raspibolt_21_security.html#increase-your-open-files-limit
}


# Step 7
step_07() {
    install_tor
}


# Step 8
step_08() {
    run_bitcoind_install
}

# Step 9
step_09() {
    run_lnd_install
}

# Step 10
step_10() {
    run_electrs_install
}

# Step 11: Install pyenv for 'specter' user (optional)
step_11() {
    SPECTER_USER=specter
	echo_label "pyenv for $SPECTER_USER"

    # Install pyenv system dependencies
    source install/011_pyenv_deps.sh
    install_pyenv_deps

    # Install pyenv
    if ! id $SPECTER_USER > /dev/null 2>&1; then
        sudo adduser --gecos "" --disabled-password $SPECTER_USER
    fi
    sudo -u $SPECTER_USER install/012_pyenv.sh

    # Install Python latest version
    PY_VERSION=3.8.8
    sudo -u $SPECTER_USER bash -c "pyenv install -v $PY_VERSION"
    sudo -u $SPECTER_USER bash -c "pyenv global $PY_VERSION"
}

# Step 12
step_12() {
    SPECTER_USER=specter
	echo_label "specter-desktop for $SPECTER_USER"

    # Install specter system dependencies
    install_specter_deps

    if ! id $SPECTER_USER > /dev/null 2>&1; then
        sudo adduser --gecos "" --disabled-password $SPECTER_USER
    fi

    RPC_USER=$(cat $HOME/.bitcoin/bitcoin.conf| grep "rpcuser" | awk -F= '{print $2}')
    RPC_PASS=$(cat $HOME/.bitcoin/bitcoin.conf| grep "rpcpass" | awk -F= '{print $2}')
    sudo -u $SPECTER_USER install/050_specter.sh "$RPC_USER" "$RPC_PASS"

    # Setup systemd service
    setup_specter_systemd \
        $SPECTER_USER
}

# Step 13
step_13() {
    run_transmission_install
}

step_14() {
    run_sphinx_install
    # Todo:
    # - persist sphinx.db file to cloud
}

step_15() {
    run_thunderhub_install
}

step_16() {
    run_lndmanage_install
}

step_17() {
    run_bos_install
}

step_18() {
    run_lndhub_install
}

step_19() {
    run_mempool_install
}

step_20() {
    run_clightning_install
}

step_21() {
    run_spark_install
}

step_22() {
    run_clboss_install
}

step_23() {
    run_cln_remote_backup_install
}

step_24() {
    install_docker
}

# == Step function calls ==

run_setup() {
    # step_01
    # step_02
    # step_03
    # step_04
    # step_05
    # step_06
    # step_07
    # step_08
    # step_09
    # step_10
    # step_11
    # step_12
    # step_13
    # step_14
    # step_15
    # step_16
    # step_17
    # step_18
    # step_19
    # step_20
    # step_21
    # step_22
    # step_23
    # step_24
}

run_setup
