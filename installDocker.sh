#!/bin/bash

# Ensure script is run as root or sudo
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root or with sudo."
    echo "Please restart it with 'sudo $0'"
    exit 1
fi

# Check if the -y flag is passed
AUTO_YES=false
if [[ "$1" == "-y" ]]; then
    AUTO_YES=true
fi

# Function to ask for user confirmation
confirm() {
    if [ "$AUTO_YES" = true ]; then
        return 0
    fi
    while true; do
        read -p "$1 (y/n): " choice
        case "$choice" in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer y or n.";;
        esac
    done
}

# Detect OS
OS_TYPE=$(uname -s)
ARCH_TYPE=$(uname -m)

echo "Detecting OS..."
if [[ "$OS_TYPE" == "Linux" ]]; then
    echo "OS: Linux detected"
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO=$ID
    else
        echo "Unsupported Linux distribution"
        exit 1
    fi
elif [[ "$OS_TYPE" == "Darwin" ]]; then
    echo "OS: macOS detected"
    if [[ "$ARCH_TYPE" == "arm64" ]]; then
        echo "Architecture: Apple Silicon (M1/M2)"
    else
        echo "Architecture: Intel"
    fi
else
    echo "Unsupported OS"
    exit 1
fi

# Function to check if Docker is installed
is_docker_installed() {
    if command -v docker &>/dev/null; then
        return 0
    elif [[ -f "/usr/local/bin/docker" || -f "/usr/bin/docker" || -f "/opt/homebrew/bin/docker" ]]; then
        return 0
    elif [[ "$OS_TYPE" == "Darwin" && -d "/Applications/Docker.app" ]]; then
        return 0
    fi
    return 1
}

# Install Docker on Linux
install_docker_linux() {
    echo "Installing Docker on Linux..."
    if confirm "Do you want to install Docker?"; then
        if [[ "$DISTRO" == "ubuntu" || "$DISTRO" == "debian" ]]; then
            sudo apt update && sudo apt install -y docker.io
        elif [[ "$DISTRO" == "fedora" ]]; then
            sudo dnf install -y docker
        elif [[ "$DISTRO" == "arch" ]]; then
            sudo pacman -S --noconfirm docker
        else
            echo "Unsupported Linux distribution for automated install"
            exit 1
        fi
        sudo systemctl enable --now docker
        sudo usermod -aG docker $USER
    else
        echo "Skipping Docker installation."
    fi
}

# Install Docker on macOS
install_docker_macos() {
    echo "Installing Docker on macOS..."
    if confirm "Do you want to install Docker?"; then
        if [[ "$ARCH_TYPE" == "arm64" ]]; then
            DOCKER_URL="https://desktop.docker.com/mac/main/arm64/Docker.dmg"
        else
            DOCKER_URL="https://desktop.docker.com/mac/main/amd64/Docker.dmg"
        fi

        DOWNLOAD_PATH="/tmp/Docker.dmg"
        echo "Downloading Docker..."
        curl -L "$DOCKER_URL" -o "$DOWNLOAD_PATH"

        echo "Mounting Docker.dmg..."
        hdiutil attach "$DOWNLOAD_PATH"

        echo "Installing Docker..."
        cp -R "/Volumes/Docker/Docker.app" /Applications

        echo "Ejecting installer..."
        hdiutil detach "/Volumes/Docker"

        echo "Cleaning up..."
        rm "$DOWNLOAD_PATH"

        echo "Docker installed. Please open Docker manually to finish setup."
    else
        echo "Skipping Docker installation."
    fi
}

# Install Docker if not already installed
if is_docker_installed; then
    echo "Docker is already installed. Skipping installation."
else
    if [[ "$OS_TYPE" == "Linux" ]]; then
        install_docker_linux
    elif [[ "$OS_TYPE" == "Darwin" ]]; then
        install_docker_macos
    fi
fi

# Function to check if Docker is running
is_docker_running() {
    docker info >/dev/null 2>&1
}

# Function to wait for Docker to start
wait_for_docker() {
    echo "Waiting for Docker to start..."
    local tries=0
    local max_tries=20
    while ! is_docker_running; do
        sleep 5
        tries=$((tries+1))
        if [[ $tries -ge $max_tries ]]; then
            echo "Docker is taking too long to start. Please check manually."
            exit 1
        fi
    done
    echo "Docker is now running!"
}

# Check if Docker is running
if ! is_docker_running; then
    if confirm "Docker is not running. Start Docker now?"; then
        if [[ "$OS_TYPE" == "Linux" ]]; then
            sudo systemctl start docker
        elif [[ "$OS_TYPE" == "Darwin" ]]; then
            open -a Docker
            echo "Waiting for Docker to start..."
        fi
        wait_for_docker
    else
        echo "Docker must be running to proceed. Exiting."
        exit 1
    fi
fi

# Install and start Portainer
install_portainer() {
    echo "Installing and launching Portainer..."
    docker volume create portainer_data
    docker run -d --name=portainer --restart=always -p 8000:8000 -p 9000:9000 -p 9443:9443 \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        portainer/portainer-ce
    echo "Portainer is now running at https://localhost:9443"
}

if confirm "Do you want to install and launch Portainer?"; then
    install_portainer
else
    echo "Skipping Portainer installation."
fi
