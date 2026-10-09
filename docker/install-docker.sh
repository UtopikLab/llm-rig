#!/bin/bash

# Install Docker Engine (Docker CE) on Ubuntu using the OFFICIAL procedure:
# https://docs.docker.com/engine/install/ubuntu/
#
# Procedure:
#   1. Uninstall any old/broken Docker packages
#   2. Add the official Docker APT repository (signed with Docker's GPG key)
#   3. Install docker-ce, cli, containerd, buildx, and compose plugin
#   4. Add the current user to the docker group (so Docker runs without sudo)
#   5. Verify the install

set -e

echo "========================================================"
echo " Installing Docker Engine (Official Procedure)"
echo "========================================================"

# 1. Architecture Check (dpkg uses 'amd64' / 'arm64', not 'x86_64' / 'aarch64')
ARCH=$(dpkg --print-architecture)
if [ "$ARCH" != "amd64" ] && [ "$ARCH" != "arm64" ]; then
    echo "ERROR: Unsupported architecture '$ARCH'. Only amd64 and arm64 are supported."
    exit 1
fi

# 2. Uninstall old/broken Docker packages (ignore if not present)
echo "Removing any old Docker packages..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    sudo apt-get remove -y "$pkg" >/dev/null 2>&1 || true
done

# 3. Set up the official Docker repository
echo "Setting up the Docker APT repository..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 4. Install Docker Engine + Compose plugin
echo "Installing Docker Engine, containerd, buildx, and Compose plugin..."
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

# 5. Make Docker usable without sudo for the current user
echo "Adding '$USER' to the docker group..."
sudo usermod -aG docker "$USER"
echo "NOTE: you must LOG OUT and LOG BACK IN for the docker-group change to take effect."
echo "      Until then, prefix docker commands with 'sudo'."

# 6. Verify the installation
echo "========================================================"
echo " Verifying Installation"
echo "========================================================"
docker --version
sudo docker info >/dev/null 2>&1 && echo "docker daemon: OK (sudo)" || echo "docker daemon: not started yet"

echo "========================================================"
echo " Docker Installation Complete!"
echo " After re-login, run: docker run hello-world"
echo "========================================================"
# Prompt the user to confirm before rebooting
read -r -p "System setup is complete. Do you want to reboot now? (yes/no) " response
case "$response" in
    yes|y|Y|YES)
        echo "Rebooting system..."
        sudo reboot
        ;;
    *)
        echo "Reboot skipped. Please reboot manually using: sudo reboot"
        ;;
esac
