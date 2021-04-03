#!/bin/bash


# == Function definitions ==

install_pyenv() {
    INSTALLS_DIR=$HOME/Installs
    mkdir $INSTALLS_DIR
    pushd $INSTALLS_DIR > /dev/null

	# Log script for manual double-check, optionally break function
	# -> see 'https://github.com/pyenv/pyenv-installer' for script
	SCRIPT="https://raw.githubusercontent.com/pyenv/pyenv-installer/master/bin/pyenv-installer"

	PARENT_SCRIPT="https://pyenv.run"
	echo && echo "Checking \$SCRIPT against parent script..."
	if curl -s $PARENT_SCRIPT | grep -q $SCRIPT; then
		echo "Check passed!"
		echo
	else
		echo "Check failed, re-check and correct in script"
		echo
		echo "Exiting 'pyenv' install..."
		echo
		return 1
	fi

	echo "Fetching install script for check before running from '$SCRIPT'" && echo
	echo
	SEP="================================"
	echo $SEP
	curl -L $SCRIPT
	echo $SEP
	echo
	read -p "Does script look ok to continue? (Y/n): " RESP
	echo
	if [[ $RESP == 'Y' ]] || [[ $RESP == 'y' ]]
	then
		echo "Starting 'pyenv' install"
	else
		echo "Skipping rest of 'pyenv' install"
		echo
		return 1
	fi

	# Proceed with pyenv install
	if ! command -v pyenv >/dev/null 2>&1
	then
		curl -L $SCRIPT | bash && \
		cat << 'EOF' >> $HOME/.bashrc

# For pyenv
# Comment one of the following blocks

export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# if echo $SHELL | grep -q "/fish"
# 	set -x PATH "$HOME/.pyenv/bin" $PATH
# 	status --is-interactive; and . (pyenv init -|psub)
# 	status --is-interactive; and . (pyenv virtualenv-init -|psub)
# end
EOF

		echo "Reset shell to complete:"
		echo "\$ exec \"\$SHELL\""
		echo
	else
		echo "'pyenv' already installed"
	fi

	# Print instructions to install Python
	echo
	echo "Run the following next steps to install Python:"
	echo "$ pyenv install --list | grep \" 3\.\""
	echo "$ pyenv install -v <version>"

	# Add IPython manual fix note, can be removed after new IPython release
	echo
	echo "Note: IPython 7.19.0 has a tab autocompletion bug that is fixed by doing this: https://github.com/ipython/ipython/issues/12745#issuecomment-751892538"
	echo

    popd > /dev/null
}


# == Function calls ==
install_pyenv
