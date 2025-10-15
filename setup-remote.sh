#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Git Proxy Remote Server Setup${NC}"
echo -e "${BLUE}   Domain: git.shur.im${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Configuration
SSH_DIR="./.ssh"
CONFIG_FILE="./proxy.config.json"
ENV_FILE="./.env"

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if running on remote server
echo -e "${BLUE}Checking environment...${NC}"
read -p "Are you setting this up on the remote server? (y/n) [y]: " is_remote
is_remote=${is_remote:-y}

# Email for Let's Encrypt
echo -e "\n${BLUE}Let's Encrypt Configuration${NC}"
read -p "Enter your email for SSL certificates: " letsencrypt_email

if [ -z "$letsencrypt_email" ]; then
    print_error "Email is required for Let's Encrypt"
    exit 1
fi

# Create directories
echo -e "\n${BLUE}Setting up directories...${NC}"
mkdir -p "$SSH_DIR"
print_status "Directories created"

# Generate SSH host keys if they don't exist
echo -e "\n${BLUE}Setting up SSH keys...${NC}"
if [ ! -f "$SSH_DIR/host_key" ]; then
    ssh-keygen -t rsa -b 4096 -f "$SSH_DIR/host_key" -N "" -C "git-proxy-remote"
    chmod 600 "$SSH_DIR/host_key"
    chmod 644 "$SSH_DIR/host_key.pub"
    print_status "SSH host keys generated"
else
    print_warning "SSH host keys already exist"
fi

# Display the public key
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}   SSH Public Key${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Add this SSH public key to your Git provider:${NC}\n"
cat "$SSH_DIR/host_key.pub"
echo ""

# Create .env file
echo -e "\n${BLUE}Setting up environment variables...${NC}"
if [ ! -f "$ENV_FILE" ]; then
    # Generate random MongoDB password
    if command -v openssl &> /dev/null; then
        MONGODB_PASS=$(openssl rand -base64 32)
    else
        MONGODB_PASS="changeme_$(date +%s)"
        print_warning "OpenSSL not found, using weak password. Please change it!"
    fi

    cat > "$ENV_FILE" << EOF
# Git Proxy Remote Server Environment Variables

# MongoDB Configuration
MONGODB_PASSWORD=${MONGODB_PASS}
MONGODB_USERNAME=admin
MONGODB_DATABASE=gitproxy

# Application Configuration
NODE_ENV=production
PORT=8080

# SSH Configuration
SSH_PORT=2222

# Domain Configuration
DOMAIN=git.shur.im
EOF
    print_status "Environment file created with secure MongoDB password"
else
    print_warning "Environment file already exists"
fi

# Create remote config
echo -e "\n${BLUE}Creating remote server configuration...${NC}"
REMOTE_CONFIG="./proxy.config.remote.json"

if command -v jq &> /dev/null; then
    jq '.ssh.enabled = true |
        .ssh.port = 2222 |
        .ssh.hostKey.privateKeyPath = ".ssh/host_key" |
        .ssh.hostKey.publicKeyPath = ".ssh/host_key.pub" |
        .tls.enabled = false |
        .sink[0].enabled = false |
        .sink[1].enabled = true |
        .sink[1].connectionString = "mongodb://admin:'"$MONGODB_PASS"'@mongodb:27017/gitproxy?authSource=admin"' \
        "$CONFIG_FILE" > "$REMOTE_CONFIG"
    print_status "Created $REMOTE_CONFIG with production settings"
else
    cp "$CONFIG_FILE" "$REMOTE_CONFIG"
    print_warning "jq not installed. Please manually configure $REMOTE_CONFIG"
fi

# Update docker-compose.remote.yml with email
echo -e "\n${BLUE}Updating Docker Compose configuration...${NC}"
if [ -f "docker-compose.remote.yml" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/your-email@example.com/$letsencrypt_email/g" docker-compose.remote.yml
    else
        sed -i "s/your-email@example.com/$letsencrypt_email/g" docker-compose.remote.yml
    fi
    print_status "Updated docker-compose.remote.yml with your email"
fi

# DNS check
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}   DNS Configuration${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Make sure your DNS is configured:${NC}"
echo -e "  git.shur.im → $(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"
echo -e "\n${YELLOW}Add these DNS records:${NC}"
echo -e "  A    git.shur.im → YOUR_SERVER_IP"
echo -e "  AAAA git.shur.im → YOUR_SERVER_IPv6 (if available)"

read -p "\nIs DNS already configured? (y/n) [n]: " dns_ready
dns_ready=${dns_ready:-n}

if [ "$dns_ready" != "y" ] && [ "$dns_ready" != "Y" ]; then
    print_warning "Please configure DNS before starting the containers"
    echo -e "\n${GREEN}Setup prepared!${NC}"
    echo -e "After configuring DNS, run: ${YELLOW}docker compose -f docker-compose.remote.yml up -d${NC}"
    exit 0
fi

# Start containers
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}   Starting Remote Server${NC}"
echo -e "${BLUE}========================================${NC}"

read -p "Start the remote server now? (y/n) [y]: " start_now
start_now=${start_now:-y}

if [ "$start_now" = "y" ] || [ "$start_now" = "Y" ]; then
    if docker compose version &> /dev/null; then
        docker compose -f docker-compose.remote.yml build
        docker compose -f docker-compose.remote.yml up -d
    else
        docker-compose -f docker-compose.remote.yml build
        docker-compose -f docker-compose.remote.yml up -d
    fi

    print_status "Remote server started!"

    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}   Git Proxy Remote Server Running!${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Web UI:       ${GREEN}https://git.shur.im${NC}"
    echo -e "SSH Server:   ${GREEN}git.shur.im:22${NC} (standard SSH port)"
    echo -e "\n${YELLOW}SSL certificates will be automatically provisioned by Let's Encrypt${NC}"
    echo -e "This may take a few minutes...\n"
    echo -e "${YELLOW}Test SSH connection:${NC}"
    echo -e "  ssh -T git@git.shur.im"
    echo -e "\n${YELLOW}Add Git remote:${NC}"
    echo -e "  git remote add proxy git@git.shur.im:user/repo.git"
    echo -e "\n${YELLOW}View logs:${NC}"
    echo -e "  docker compose -f docker-compose.remote.yml logs -f"
    echo -e "\n${YELLOW}Monitor SSL certificate provisioning:${NC}"
    echo -e "  docker compose -f docker-compose.remote.yml logs -f nginx-ssl"
    echo -e "\n${GREEN}Setup complete!${NC}"
else
    echo -e "\n${GREEN}Setup complete!${NC}"
    echo -e "Start with: ${YELLOW}docker compose -f docker-compose.remote.yml up -d${NC}"
fi

