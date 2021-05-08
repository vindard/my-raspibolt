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
	append_to_file "$@"
}

append_to_torrc() {
	FILE="/etc/tor/torrc"
	append_to_file "$@"
}

append_to_bash_aliases() {
	FILE="$HOME/.bash_aliases"
	append_to_file "$@"
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
