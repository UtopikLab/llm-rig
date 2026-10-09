#!/bin/bash

# Update and install dependencies
sudo apt update
sudo apt install curl zstd -y

# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Create the systemd override directory for Ollama
sudo mkdir -p /etc/systemd/system/ollama.service.d

# Write the network configuration block to the override file
sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null << 'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
Environment="OLLAMA_ORIGINS=*"
EOF

# Reload systemd configs and restart the service
sudo systemctl daemon-reload
sudo systemctl restart ollama

# Verify installation
ollama --version
