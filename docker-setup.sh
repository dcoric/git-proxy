#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SSH_DIR="./.ssh"
CERTS_DIR="./certs"
DATA_DIR="./data"
CONFIG_FILE="./proxy.config.json"
ENV_FILE="./.env"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Git Proxy Docker Setup Script${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Function to print status messages
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

print_status "Docker and Docker Compose are installed"

# Create necessary directories
echo -e "\n${BLUE}Creating directories...${NC}"
mkdir -p "$SSH_DIR"
mkdir -p "$CERTS_DIR"
mkdir -p "$DATA_DIR"
print_status "Directories created: $SSH_DIR, $CERTS_DIR, $DATA_DIR"

# Generate SSH host keys for SSH server
echo -e "\n${BLUE}Setting up SSH keys...${NC}"
if [ ! -f "$SSH_DIR/host_key" ]; then
    ssh-keygen -t rsa -b 4096 -f "$SSH_DIR/host_key" -N "" -C "git-proxy-host-key"
    print_status "SSH host keys generated"
else
    print_warning "SSH host keys already exist, skipping generation"
fi

# Set proper permissions for SSH keys
chmod 600 "$SSH_DIR/host_key"
chmod 644 "$SSH_DIR/host_key.pub"
print_status "SSH key permissions set"

# Generate self-signed TLS certificates
echo -e "\n${BLUE}Setting up TLS certificates...${NC}"
if [ ! -f "$CERTS_DIR/cert.pem" ] || [ ! -f "$CERTS_DIR/key.pem" ]; then
    read -p "Generate self-signed TLS certificates? (y/n) [y]: " generate_certs
    generate_certs=${generate_certs:-y}

    if [ "$generate_certs" = "y" ] || [ "$generate_certs" = "Y" ]; then
        openssl req -x509 -newkey rsa:4096 -keyout "$CERTS_DIR/key.pem" -out "$CERTS_DIR/cert.pem" \
            -days 365 -nodes -subj "/CN=localhost/O=Git Proxy/C=US"
        chmod 600 "$CERTS_DIR/key.pem"
        chmod 644 "$CERTS_DIR/cert.pem"
        print_status "Self-signed TLS certificates generated"
        print_warning "For production, replace these with proper certificates"
    else
        print_warning "Skipping certificate generation. Add your own certificates to $CERTS_DIR/"
    fi
else
    print_warning "TLS certificates already exist, skipping generation"
fi

# Create Docker-specific config file
echo -e "\n${BLUE}Creating Docker-specific config file...${NC}"
if [ ! -f "$CONFIG_FILE" ]; then
    print_error "Config file not found at $CONFIG_FILE"
    exit 1
fi

DOCKER_CONFIG_FILE="./proxy.config.docker.json"

# Copy the original config and update paths for Docker
if command -v jq &> /dev/null; then
    # Create a Docker-specific config with corrected paths
    jq '.ssh.hostKey.privateKeyPath = ".ssh/host_key" |
        .ssh.hostKey.publicKeyPath = ".ssh/host_key.pub" |
        .tls.key = "certs/key.pem" |
        .tls.cert = "certs/cert.pem"' "$CONFIG_FILE" > "$DOCKER_CONFIG_FILE"
    print_status "Created $DOCKER_CONFIG_FILE with Docker-specific paths"
    print_warning "Original $CONFIG_FILE unchanged (as intended for source control)"
else
    # If jq not available, just copy the file and warn
    cp "$CONFIG_FILE" "$DOCKER_CONFIG_FILE"
    print_warning "jq not installed. Copied config to $DOCKER_CONFIG_FILE"
    print_warning "Please manually update SSH and TLS paths in $DOCKER_CONFIG_FILE"
    echo "  SSH privateKeyPath: .ssh/host_key"
    echo "  SSH publicKeyPath: .ssh/host_key.pub"
    echo "  TLS key: certs/key.pem"
    echo "  TLS cert: certs/cert.pem"
fi

# Create .env file from template if it doesn't exist
echo -e "\n${BLUE}Setting up environment variables...${NC}"
if [ ! -f "$ENV_FILE" ] && [ -f "env.template" ]; then
    cp env.template "$ENV_FILE"

    # Generate random MongoDB password
    if command -v openssl &> /dev/null; then
        MONGODB_PASS=$(openssl rand -base64 32)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/your_secure_password_here/$MONGODB_PASS/" "$ENV_FILE"
        else
            sed -i "s/your_secure_password_here/$MONGODB_PASS/" "$ENV_FILE"
        fi
        print_status "Environment file created with secure MongoDB password"
    else
        cp env.template "$ENV_FILE"
        print_warning "Environment file created. Please set MONGODB_PASSWORD in $ENV_FILE"
    fi
elif [ -f "$ENV_FILE" ]; then
    print_warning "Environment file already exists, skipping"
else
    print_warning "No env.template found, skipping environment file creation"
fi

# Display configuration summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}   Configuration Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "SSH Host Keys:    ${GREEN}$SSH_DIR/host_key${NC}"
echo -e "TLS Certificates: ${GREEN}$CERTS_DIR/cert.pem${NC}"
echo -e "Docker Config:    ${GREEN}$DOCKER_CONFIG_FILE${NC}"
echo -e "Original Config:  ${GREEN}$CONFIG_FILE${NC} (unchanged)"
echo -e "Data Directory:   ${GREEN}$DATA_DIR${NC}"
echo -e "Env File:         ${GREEN}$ENV_FILE${NC}"

# Ask which compose file to use
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}   Docker Compose Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Which environment do you want to run?"
echo "1) Development (docker-compose.yml)"
echo "2) Production (docker-compose.prod.yml)"
echo "3) Skip and configure manually"
read -p "Enter your choice [1]: " env_choice
env_choice=${env_choice:-1}

COMPOSE_FILE=""
case $env_choice in
    1)
        COMPOSE_FILE="docker-compose.yml"
        ;;
    2)
        COMPOSE_FILE="docker-compose.prod.yml"
        print_warning "Production mode selected. Make sure to configure MongoDB password and proper certificates!"
        ;;
    3)
        echo -e "\n${GREEN}Setup complete!${NC}"
        echo -e "Run manually with: ${YELLOW}docker-compose up -d${NC}"
        exit 0
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

# Build and start containers
echo -e "\n${BLUE}Building and starting Docker containers...${NC}"
read -p "Build and start containers now? (y/n) [y]: " start_now
start_now=${start_now:-y}

if [ "$start_now" = "y" ] || [ "$start_now" = "Y" ]; then
    if docker compose version &> /dev/null; then
        docker compose -f "$COMPOSE_FILE" build
        docker compose -f "$COMPOSE_FILE" up -d
    else
        docker-compose -f "$COMPOSE_FILE" build
        docker-compose -f "$COMPOSE_FILE" up -d
    fi

    print_status "Containers started successfully!"

    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}   Git Proxy is Running!${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Web UI:       ${GREEN}http://localhost:8080${NC}"
    echo -e "SSH Server:   ${GREEN}localhost:22${NC} (standard SSH port)"
    echo -e "\nView logs:    ${YELLOW}docker-compose -f $COMPOSE_FILE logs -f${NC}"
    echo -e "Stop:         ${YELLOW}docker-compose -f $COMPOSE_FILE down${NC}"
    echo -e "Restart:      ${YELLOW}docker-compose -f $COMPOSE_FILE restart${NC}"
    echo -e "\n${GREEN}Setup complete!${NC}"
else
    echo -e "\n${GREEN}Setup complete!${NC}"
    echo -e "Start containers with: ${YELLOW}docker-compose -f $COMPOSE_FILE up -d${NC}"
fi
