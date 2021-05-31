#!/bin/bash

echo_label() {
	echo && echo "Installing $1" && echo "---" && echo
}

run_first_update() {
    echo "Running first full update" && echo "---" && echo

    sudo apt update && \
        sudo apt -y full-upgrade
}

append_to_file() {
	if [[ -e $FILE ]]; then
		for line in "$@"; do
			if [[ -z $line ]] || ! cat $FILE | grep -q "$line"; then
				echo "$line" | tee -a $FILE > /dev/null
			fi
		done

		# Delete all trailing blank lines at end of file
		# (https://unix.stackexchange.com/a/81687)
		sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' $FILE
		echo | tee -a $FILE > /dev/null
	else
		echo "Cannot append to '$FILE', file does not exist"
	fi
}

su_append_to_file() {
	if [[ -e $FILE ]]; then
		for line in "$@"; do
			if [[ -z $line ]] || ! sudo cat $FILE | grep -q "$line"; then
				echo "$line" | sudo tee -a $FILE > /dev/null
			fi
		done

		# Delete all trailing blank lines at end of file
		# (https://unix.stackexchange.com/a/81687)
		sudo sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' $FILE
		echo | sudo tee -a $FILE > /dev/null
	else
		echo "Cannot append to '$FILE', file does not exist"
	fi
}

append_to_sources_list() {
	FILE="/etc/apt/sources.list"
	su_append_to_file "$@"
}

append_to_torrc() {
	FILE="/etc/tor/torrc"
	su_append_to_file "$@"
}

append_to_bash_aliases() {
	FILE="$HOME/.bash_aliases"
	touch $FILE

	append_to_file "$@"
}

append_to_sysctl() {
	FILE="/etc/sysctl.conf"
	su_append_to_file "$@"
}

UNCOMMENT_FILE=""
uncomment_file() {
	if [[ -z $UNCOMMENT_FILE ]]; then
		echo "Filename for uncommenting not set at \$UNCOMMENT_FILE, skipping..."
		return 1
	elif [[ ! -e $UNCOMMENT_FILE ]]; then
		echo "File $UNCOMMENT_FILE does not exist, skipping..."
		return 1
	fi

	for string in "$@"; do
		sudo sed -i \
			"s/#\s\?\($string\)/\1/g" \
			$UNCOMMENT_FILE
	done
}

uncomment_torrc() {
	FILE="/etc/tor/torrc"

	for string in "$@"; do
		sudo sed -i \
			"s/#\s\?\($string\)/\1/g" \
			$FILE
	done
}

check_dependency() {
	for cmd in "$@"; do
		if ! command -v $cmd >/dev/null 2>&1; then
			echo "This script requires \"${cmd}\" to be installed"
			return 1
		fi
	done
}

change_json_value() {
	FILE_PATH="$1"
	KEY="$2"
	VALUE="$3"
	if [[ -z $VALUE ]]; then
		echo "Error: Please pass valid \$FILE_PATH, \$KEY & \$VALUE args to the function."
		return 1
	fi

	# Alternative 1 WITH comma at end
	sed -i \
		"s|\(.*\"$KEY\"\:\).*,\s*\$|\1 \"$VALUE\",|g" \
		$FILE_PATH

	# Alternative 2 FOR NO comma at end
	sed -i \
		"s|\(.*\"$KEY\"\:\).*[^,]\s*\$|\1 \"$VALUE\"|g" \
		$FILE_PATH
}

toggle_json_true() {
	FILE_PATH="$1"
	KEY="$2"
	VALUE="true"
	if [[ -z $KEY ]]; then
		echo "Error: Please pass valid \$FILE_PATH & \$KEY args to the function."
		return 1
	fi

	# Alternative 1 WITH comma at end
	sed -i \
		"s/\(.*\"$KEY\"\:\).*,\s*\$/\1 $VALUE,/g" \
		$FILE_PATH

	# Alternative 2 FOR NO comma at end
	sed -i \
		"s/\(.*\"$KEY\"\:\).*[^,]\s*\$/\1 $VALUE/g" \
		$FILE_PATH

}


install_pyenv_for_user() {
	PYENV_USER=$1
	echo_label "pyenv for user '$PYENV_USER'"

    # Install pyenv system dependencies
    source install/011_pyenv_deps.sh
    install_pyenv_deps

    # Install pyenv
    if ! id $PYENV_USER > /dev/null 2>&1; then
        sudo adduser $PYENV_USER
    fi
    sudo -u $PYENV_USER install/012_pyenv.sh
}


load_pyenv() {
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"

    if ! check_dependency pyenv; then
        echo "'pyenv' not installed, skipping rest of 'specter' setup..."
        exit 1
    fi

    eval "$(pyenv init --path)"
    if command -v pyenv 1>/dev/null 2>&1; then
        eval "$(pyenv init -)"
    fi
}

load_pyenv_virtual_env() {
    # Check for required variables
    if [[ -z $VENV_PY_VERSION ]]; then
        echo "Please specify a Python version number for pyenv in \$VENV_PY_VERSION before continuing"
        return 1
    elif [[ -z $VENV_NAME ]]; then
        echo "Please specify a Python version number for pyenv in \$VENV_NAME before continuing"
        return 1
    fi

    # Load pyenv into shell
    load_pyenv

    # Switch to '$VENV_NAME' virtualenv
    if ! pyenv versions | grep -q $VENV_PY_VERSION; then
        pyenv install -v $VENV_PY_VERSION
    fi
    if ! pyenv versions | grep -q $VENV_NAME; then
        pyenv virtualenv $VENV_PY_VERSION $VENV_NAME
    fi

    pyenv shell $VENV_NAME
    python -m pip install --upgrade pip
    echo "Python pyenv version: $(pyenv version)"
}
