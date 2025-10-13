# Docker Setup for Git Proxy

This directory contains Docker configuration for running Git Proxy in containers.

## Quick Start

Run the interactive setup script:

```bash
./docker-setup.sh
```

This script will:

1. Generate SSH host keys for the SSH server
2. Generate self-signed TLS certificates (or skip if you have your own)
3. Create `proxy.config.docker.json` with correct paths for Docker
4. Keep your original `proxy.config.json` unchanged for source control
5. Set up environment variables
6. Build and start the containers

## Configuration Philosophy

**Important:** The original `proxy.config.json` is intentionally configured with incorrect/placeholder paths. This forces developers to review and configure paths properly for their environment.

For Docker:

- `./docker-setup.sh` creates `proxy.config.docker.json` with Docker-specific paths
- This file is git-ignored and not committed
- Original `proxy.config.json` remains unchanged for source control

## Manual Setup

If you prefer manual setup:

1. **Generate SSH keys:**

   ```bash
   mkdir -p .ssh
   ssh-keygen -t rsa -b 4096 -f .ssh/host_key -N ""
   ```

2. **Generate TLS certificates (optional):**

   ```bash
   mkdir -p certs
   openssl req -x509 -newkey rsa:4096 -keyout certs/key.pem -out certs/cert.pem \
     -days 365 -nodes -subj "/CN=localhost/O=Git Proxy/C=US"
   ```

3. **Create Docker config:**

   ```bash
   cp proxy.config.json proxy.config.docker.json
   # Edit proxy.config.docker.json and update:
   # - ssh.hostKey.privateKeyPath: ".ssh/host_key"
   # - ssh.hostKey.publicKeyPath: ".ssh/host_key.pub"
   # - tls.key: "certs/key.pem"
   # - tls.cert: "certs/cert.pem"
   ```

4. **Start containers:**
   ```bash
   docker-compose up -d
   ```

## Files

- **Dockerfile** - Multi-stage build for optimized production image
- **docker-compose.yml** - Development/local deployment
- **docker-compose.prod.yml** - Production deployment with MongoDB
- **docker-setup.sh** - Interactive setup script
- **.dockerignore** - Excludes unnecessary files from builds
- **.env.example** - Environment variables template
- **proxy.config.docker.json** - Docker-specific config (generated, git-ignored)

## Volume Mounts

The Docker setup mounts these volumes:

- `./proxy.config.docker.json` → `/app/proxy.config.json` (config file)
- `./.ssh` → `/app/.ssh` (SSH host keys)
- `./certs` → `/app/certs` (TLS certificates)
- `git-proxy-data` → `/app/data` (persistent data)

## Updating Configuration

To update the configuration:

1. Edit `proxy.config.docker.json`
2. Restart the container:
   ```bash
   docker-compose restart git-proxy
   ```

No rebuild required!

## Ports

- **8080** - HTTP/HTTPS web interface
- **2222** - SSH server for git operations

## Production Deployment

For production, use `docker-compose.prod.yml`:

```bash
docker-compose -f docker-compose.prod.yml up -d
```

This includes:

- MongoDB for persistent storage
- Resource limits
- Health checks
- Proper logging configuration
- Restart policies

Make sure to:

1. Update `MONGODB_PASSWORD` in `.env`
2. Use proper TLS certificates (not self-signed)
3. Configure authentication properly
4. Review security settings in the config

## Troubleshooting

**Container keeps restarting:**

- Check logs: `docker-compose logs -f git-proxy`
- Common issue: Invalid config file format
- Validate your `proxy.config.docker.json` against the schema

**Config validation errors:**

- The config schema may have changed
- Check `config.schema.json` for the current schema
- Update your `proxy.config.docker.json` accordingly

**SSH keys not found:**

- Ensure `.ssh/host_key` exists
- Check permissions: `chmod 600 .ssh/host_key`
- Verify paths in `proxy.config.docker.json`
