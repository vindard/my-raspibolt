#!/bin/bash


# == Function definitions ==

install_pyenv_deps() {
    echo "Installing pyenv dependencies..."
    echo

	sudo apt update && sudo apt install -y \
		make build-essential libssl-dev zlib1g-dev \
		libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev \
		xz-utils tk-dev libffi-dev liblzma-dev \
		libxml2-dev libxmlsec1-dev
		# libncursesw5-dev python-openssl
}
