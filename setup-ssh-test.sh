#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Git Proxy SSH Testing Setup${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Configuration
SSH_DIR="./.ssh"
CERTS_DIR="./certs"
CONFIG_FILE="./proxy.config.json"

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Create directories
echo -e "${BLUE}Setting up directories...${NC}"
mkdir -p "$SSH_DIR"
mkdir -p "$CERTS_DIR"
print_status "Directories created"

# Generate SSH host keys if they don't exist
echo -e "\n${BLUE}Setting up SSH keys...${NC}"
if [ ! -f "$SSH_DIR/host_key" ]; then
    ssh-keygen -t rsa -b 4096 -f "$SSH_DIR/host_key" -N "" -C "git-proxy-ssh-test"
    chmod 600 "$SSH_DIR/host_key"
    chmod 644 "$SSH_DIR/host_key.pub"
    print_status "SSH host keys generated"
else
    print_warning "SSH host keys already exist"
fi

# Display the public key for adding to GitHub/GitLab
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}   SSH Public Key${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Add this SSH public key to your Git provider:${NC}\n"
cat "$SSH_DIR/host_key.pub"
echo -e "\n${YELLOW}For GitHub:${NC} https://github.com/settings/keys"
echo -e "${YELLOW}For GitLab:${NC} https://gitlab.com/-/profile/keys"

# Generate self-signed TLS certificates for testing
echo -e "\n${BLUE}Setting up TLS certificates...${NC}"
if [ ! -f "$CERTS_DIR/cert.pem" ] || [ ! -f "$CERTS_DIR/key.pem" ]; then
    openssl req -x509 -newkey rsa:4096 -keyout "$CERTS_DIR/key.pem" -out "$CERTS_DIR/cert.pem" \
        -days 365 -nodes -subj "/CN=localhost/O=Git Proxy SSH Test/C=US"
    chmod 600 "$CERTS_DIR/key.pem"
    chmod 644 "$CERTS_DIR/cert.pem"
    print_status "Self-signed TLS certificates generated"
else
    print_warning "TLS certificates already exist"
fi

# Create SSH test config
echo -e "\n${BLUE}Creating SSH test configuration...${NC}"
if [ ! -f "$CONFIG_FILE" ]; then
    print_error "Config file not found at $CONFIG_FILE"
    exit 1
fi

SSH_TEST_CONFIG="./proxy.config.ssh-test.json"

# Create SSH test config with jq if available
if command -v jq &> /dev/null; then
    jq '.ssh.enabled = true |
        .ssh.port = 2222 |
        .ssh.hostKey.privateKeyPath = ".ssh/host_key" |
        .ssh.hostKey.publicKeyPath = ".ssh/host_key.pub" |
        .tls.enabled = true |
        .tls.key = "certs/key.pem" |
        .tls.cert = "certs/cert.pem" |
        .sink[0].enabled = true |
        .sink[1].enabled = false' "$CONFIG_FILE" > "$SSH_TEST_CONFIG"
    print_status "Created $SSH_TEST_CONFIG with SSH enabled"
else
    cp "$CONFIG_FILE" "$SSH_TEST_CONFIG"
    print_warning "jq not installed. Please manually enable SSH in $SSH_TEST_CONFIG"
    echo "  Set: ssh.enabled = true"
    echo "  Set: ssh.port = 2222"
    echo "  Set: ssh.hostKey.privateKeyPath = .ssh/host_key"
    echo "  Set: ssh.hostKey.publicKeyPath = .ssh/host_key.pub"
fi

# Start the containers
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}   Starting SSH Test Environment${NC}"
echo -e "${BLUE}========================================${NC}"

read -p "Start the SSH test environment now? (y/n) [y]: " start_now
start_now=${start_now:-y}

if [ "$start_now" = "y" ] || [ "$start_now" = "Y" ]; then
    if docker compose version &> /dev/null; then
        docker compose -f docker-compose.ssh-test.yml build
        docker compose -f docker-compose.ssh-test.yml up -d
    else
        docker-compose -f docker-compose.ssh-test.yml build
        docker-compose -f docker-compose.ssh-test.yml up -d
    fi

    print_status "SSH test environment started!"

    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}   SSH Test Environment Ready!${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Web UI:       ${GREEN}http://localhost:8080${NC}"
    echo -e "SSH Server:   ${GREEN}localhost:22${NC} (standard SSH port)"
    echo -e "\n${YELLOW}Test SSH connection:${NC}"
    echo -e "  ssh -T git@localhost"
    echo -e "\n${YELLOW}Add Git remote:${NC}"
    echo -e "  git remote add proxy git@localhost:user/repo.git"
    echo -e "\n${YELLOW}View logs:${NC}"
    echo -e "  docker compose -f docker-compose.ssh-test.yml logs -f git-proxy"
    echo -e "\n${YELLOW}Stop:${NC}"
    echo -e "  docker compose -f docker-compose.ssh-test.yml down"
    echo -e "\n${GREEN}Setup complete!${NC}"
else
    echo -e "\n${GREEN}Setup complete!${NC}"
    echo -e "Start with: ${YELLOW}docker compose -f docker-compose.ssh-test.yml up -d${NC}"
fi

