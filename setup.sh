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

# == bitcoind install functions ==
source install/020_bitcoind.sh

# == lnd install functions ==
source install/030_lnd.sh

# == electrs install functions ==
source install/040_electrs.sh


# == > SCRIPT START < ==

# == Step function definitions ==

# Step 1
# Run  sudo raspi-config and change:
#    1. <1> change password
#    2. <8> Update system
#    3. Set root password with '$ sudo passwd root'

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
    setup_ufw_and_fail2ban

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
}

run_setup
