#!/bin/bash


# == Function definitions ==

install_standard() {
	echo_label "standard tools"

	mkdir -p $HOME/Developer
	touch $HOME/.commonrc

	sudo apt update && sudo apt install -y \
		htop \
		vim \
		tree \
		jq \
		git \
		vnstat \
		tmux \
		nmap
}

install_recommended() {
    # From https://stadicus.github.io/RaspiBolt/raspibolt_20_pi.html#software-update
	echo_label "recommended tools"

	sudo apt update && sudo apt install -y \
        curl \
        bash-completion \
        qrencode \
        dphys-swapfile \
        hdparm \
    --install-recommends
}

install_speedtest() {
	echo_label "speedtest"

	sudo apt install -y gnupg1 apt-transport-https dirmngr
	export INSTALL_KEY=379CE192D401AB61
	sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $INSTALL_KEY
	echo "deb https://ookla.bintray.com/debian generic main" | sudo tee  /etc/apt/sources.list.d/speedtest.list
	sudo apt update

	# Other non-official binaries will conflict with Speedtest CLI
	# Example how to remove using apt-get
	# sudo apt remove speedtest-cli
	sudo apt install -y speedtest
}

install_magic_wormhole() {
	echo_label "Magic Wormhole"

	sudo apt update && \
		sudo apt install -y \
			magic-wormhole
}

disable_ssh_password() {
    SSH_AUTH_FILE=$HOME/.ssh/authorized_keys

    if [[ -e $SSH_AUTH_FILE ]]; then
        sudo sed -i \
            '/#PasswordAuthentication yes/a PasswordAuthentication no' \
            /etc/ssh/sshd_config

        sudo systemctl restart sshd
    else
        echo "No file found at '$SSH_AUTH_FILE', skipping ssh password disable"
    fi
}

setup_node_users() {
    sudo adduser admin
    sudo adduser admin sudo

    sudo adduser bitcoin
    sudo adduser admin bitcoin
}

setup_symlinks() {
    MOUNTPOINT=/mnt/ext
    BITCOIN_HOME_DIR=/home/bitcoin

    # Check for successful mount
    if ! mount | grep -q $MOUNTPOINT; then
        echo "No drive mounted at '$MOUNTPOINT'"
        return 1
    fi

    # Setup symlinks
    DIRS=(bitcoin lnd)
    for dir in ${DIRS[@]}; do
        mkdir $MOUNTPOINT/$dir
        sudo ln -s $MOUNTPOINT/$dir/ $BITCOIN_HOME_DIR/.$dir
        sudo chown -R bitcoin:bitcoin $BITCOIN_HOME_DIR/.$dir

        ln -s $MOUNTPOINT/$dir/ $HOME/.$dir
    done

    sudo chown -R bitcoin:bitcoin $MOUNTPOINT
}

move_swap_file() {
    SWAP_CONFIG_FILE=/etc/dphys-swapfile
    CONF_SWAPFILE=/mnt/ext/swapfile

    # Comment 'CONF_SWAPSIZE' setting
    sudo sed -i "s/^.\{0,2\}\(CONF_SWAPSIZE\)/#\1/g" $SWAP_CONFIG_FILE

    # Set 'CONF_SWAPFILE' setting
    sudo sed -i "s|^.\{0,2\}\(CONF_SWAPFILE\)|\1|g" $SWAP_CONFIG_FILE
    sudo sed -i "s|^.\{0,2\}\(CONF_SWAPFILE\).*|\1=${CONF_SWAPFILE}|g" $SWAP_CONFIG_FILE

    sudo dphys-swapfile install
}

setup_ufw() {
	echo_label "ufw"

    sudo apt update && sudo apt install -y \
        ufw

    if ! sudo ufw status > /dev/null 2>&1; then
        echo "UFW not installed successfully, or REBOOT may be required. Skipping rest of config..."
        return 1
    fi

    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    sudo ufw allow 22 comment 'allow SSH'
    # sudo ufw allow 50002 comment 'allow Electrum SSL'

    sudo ufw enable
    sudo systemctl enable ufw
    sudo ufw status
}

setup_fail2ban() {
    # Install fail2ban with default config
    echo_label "ufw fail2ban"

    sudo apt update && sudo apt install -y \
        fail2ban
}

install_tor() {
	echo_label "Tor daemon"

	TOR_URL="https://deb.torproject.org/torproject.org"

	sudo apt update && sudo apt install -y \
		dirmngr \
		apt-transport-https

	append_to_sources_list \
		"deb $TOR_URL buster main" \
		"deb-src $TOR_URL buster main"

	PGP_KEY="A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89"
	curl $TOR_URL/$PGP_KEY.asc | gpg --import
	gpg --export $PGP_KEY | sudo apt-key add -

	sudo apt update && sudo apt install -y \
		tor \
		tor-arm

	echo "Running '$ tor --version':"
	tor --version


    # Adjust users and groups
    SERVICE_CONFIG_FILE=/usr/share/tor/tor-service-defaults-torrc
    if cat $SERVICE_CONFIG_FILE | grep -q "User debian-tor"; then
        sudo adduser bitcoin debian-tor
        cat /etc/group | grep debian-tor
    else
        echo "Skipping user/group changes. Check that 'User' is 'debian-tor' in '$SERVICE_CONFIG_FILE'"
    fi


	# 'torrc' edits from Raspibolt instructions
	# - https://stadicus.github.io/RaspiBolt/raspibolt_69_tor.html

	echo "Editing '/etc/tor/torrc' file"
	uncomment_torrc \
		"ControlPort 9051" \
		"CookieAuthentication 1"
	append_to_torrc \
		"# Added from Raspibolt instructions" \
		"CookieAuthFileGroupReadable 1"

	sudo systemctl restart tor
}

install_zsh() {
	echo_label "zsh"

	sudo apt update && sudo apt install -y zsh

	sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
	# echo && echo "Enter the password for current user '$USER' to change shell to 'Zsh'"
	# chsh -s $(which zsh)

	git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
	sed -i -E "s/(^plugins=.*)\)/\1 zsh-autosuggestions)/g" $HOME/.zshrc
    # > Set theme to 'bira' in .zshrc (ZSH_THEME="bira") as per https://zshthem.es/all/
}
