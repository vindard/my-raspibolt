#!/bin/bash


# == Function definitions ==

install_specter_deps() {
    echo "Installing specter dependencies..."
    echo

	sudo apt update && sudo apt install -y \
		git \
        build-essential \
        libusb-1.0-0-dev \
        libudev-dev \
        libffi-dev \
        libssl-dev
}
