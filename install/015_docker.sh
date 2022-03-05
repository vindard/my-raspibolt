#!/bin/bash

# == Helper functions ==
source install/000_helpers.sh


# == Function definitions ==

install_docker() {
    # Install from convenience script
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh

    # Add each user that needs access to the 'docker' group
    sudo usermod -aG docker pi

    # add docker compose
    sudo pip3 install docker-compose
}
