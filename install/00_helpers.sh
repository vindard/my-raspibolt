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

uncomment_torrc() {
	FILE="/etc/tor/torrc"

	for string in "$@"; do
		sudo sed -i \
			"s/#\s\?\($string\)/\1/g" \
			$FILE
	done
}
