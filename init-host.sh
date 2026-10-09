#!/bin/bash
# VM Initialization Script
# This script sets up a new VM with common configurations

set -e

echo "=== VM Initialization Script ==="
echo ""

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m' # No Color

# Function to print colored output
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to set passwordless sudo for local user
setup_passwordless_sudo() {
    log_info "Setting up passwordless sudo for local user..."
    
    # Create sudoers file entry (non-interactive)
    cat >> /etc/sudoers.d/local-user << 'EOF'
# Allow the local user to run commands without a password
%sudo ALL=(ALL) NOPASSWD:ALL
EOF

    # Set correct permissions on sudoers file
    chmod 440 /etc/sudoers.d/local-user

    # Validate the sudoers file
    if ! sudo -k -v >/dev/null 2>&1; then
        log_warn "Could not validate sudoers file. Skipping sudo validation."
    fi

    log_info "Passwordless sudo configured successfully!"
}

# Function to configure SSH for passwordless access
setup_ssh_passwordless() {
    log_info "Setting up passwordless SSH access..."
    
    # Generate SSH key if it doesn't exist
    if [ ! -f ~/.ssh/id_rsa ]; then
        log_info "Generating SSH key pair..."
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N '' -q
    fi

    # Copy public key to server
    if [ -f ~/.ssh/id_rsa.pub ]; then
        ssh-copy-id -o StrictHostKeyChecking=no user@localhost 2>/dev/null || true
    fi

    log_info "SSH passwordless access configured!"
}

# Function to update system packages
update_system() {
    log_info "Updating system packages..."
    
    # Update package lists
    apt-get update -qq
    
    # Upgrade installed packages
    apt-get upgrade -y -qq
    
    log_info "System packages updated!"
}

# Function to install essential tools
install_essential_tools() {
    log_info "Installing essential tools..."
    
    # Install git
    apt-get install -y git -qq
    
    # Install curl and wget
    apt-get install -y curl wget -qq
    
    # Install unzip
    apt-get install -y unzip -qq
    
    # Install vim
    apt-get install -y vim -qq
    
    # Install htop
    apt-get install -y htop -qq
    
    # Install net-tools
    apt-get install -y net-tools iotop -qq
    
    # Install tmux
    apt-get install -y tmux -qq
    
    # Install python3 and pip
    apt-get install -y python3 python3-pip python3-venv -qq
    
    log_info "Essential tools installed!"
}

# Function to configure firewall (optional)
setup_firewall() {
    log_info "Setting up firewall (ufw)..."
    
    # Install ufw
    apt-get install -y ufw -qq
    
    # Enable firewall
    ufw enable
    
    # Allow SSH
    ufw allow ssh
    
    # Allow HTTP/HTTPS
    ufw allow http
    ufw allow https
    
    log_info "Firewall configured!"
}

# Function to configure timezone
setup_timezone() {
    log_info "Configuring timezone to UTC..."
    
    # Set timezone to UTC
    timedatectl set-timezone UTC
    
    log_info "Timezone set to UTC!"
}

# Function to enable automatic updates
setup_automatic_updates() {
    log_info "Configuring automatic updates..."

    apt-get install -y cron -qq
    
    # Create unattended-upgrades directory
    mkdir -p /var/lib/apt/lists
    
    # Configure aptitude
    echo "APT::Periodic::Update-Package-Lists "1";" >> /etc/apt/apt.conf.d/50unattended-upgrades
    echo "APT::Periodic::Download-Upgradeable-Packages "1";" >> /etc/apt/apt.conf.d/50unattended-upgrades
    echo "APT::Periodic::AutocleanInterval "7";" >> /etc/apt/apt.conf.d/50unattended-upgrades
    
    # Create daily cron job for updates
    echo "0 3 * * * root apt-get update && apt-get upgrade -y" | sudo tee -a /etc/crontab
    
    log_info "Automatic updates configured!"
}

# Main execution
main() {
    echo ""
    log_info "VM Initialization Script Started"
    echo "================================="
    echo ""
    
    # Uncomment the lines below to run these configurations
    setup_passwordless_sudo
    setup_ssh_passwordless
    update_system
    install_essential_tools
    # setup_firewall
    setup_timezone
    setup_automatic_updates
    
    echo ""
    log_info "VM Initialization Complete!"
    echo ""
    log_info "To enable all configurations, uncomment the relevant lines above."
    echo ""
    log_info "Common post-installation commands:"
    echo "  - sudo -k  (clear sudo lock)"
    echo "  - sudo -i  (start a passwordless sudo shell)"
    echo ""
}

# Run main function
main "$@"
