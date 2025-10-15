# DNS-Agnostic Configuration Guide

This document explains how to configure Git Proxy to be DNS-agnostic for different deployment scenarios.

## Overview

Git Proxy is designed to be DNS-agnostic and can be deployed in various environments without hardcoded domain dependencies. The application uses environment variables and configuration files to determine its hostnames and service endpoints.

## SSH Port Configuration

Git Proxy uses the **standard SSH port 22** for Git operations, which provides several benefits:

### Benefits of Using Port 22

1. **Clean Git URLs**: Users can use standard Git SSH URLs without specifying ports:

   ```bash
   # Clean, standard format
   git clone git@yourdomain.com:user/repo.git

   # No need for port specification
   git clone ssh://git@yourdomain.com:22/user/repo.git  # Optional
   ```

2. **Standard SSH Configuration**: Works with standard SSH client configurations and doesn't require special port forwarding.

3. **Firewall Friendly**: Port 22 is typically open in most network configurations.

4. **User Experience**: Matches the expected behavior of Git hosting services like GitHub, GitLab, etc.

### Server SSH Configuration

When deploying Git Proxy on port 22, you'll need to configure your server's SSH daemon to use a different port for regular SSH access:

```bash
# Edit /etc/ssh/sshd_config
Port 2222  # Change from default 22 to 2222

# Restart SSH service
sudo systemctl restart sshd
```

### Docker Port Mapping

The Docker configuration maps the container's port 22 to the host's port 22:

```yaml
ports:
  - '22:22' # Git SSH operations
  - '8080:8080' # Web UI
```

## Environment Variables

### Core Application Configuration

| Variable                      | Default            | Description                     |
| ----------------------------- | ------------------ | ------------------------------- |
| `GIT_PROXY_UI_HOST`           | `http://localhost` | Base URL for the web UI         |
| `GIT_PROXY_SERVER_PORT`       | `8000`             | Port for the git proxy server   |
| `GIT_PROXY_UI_PORT`           | `8080`             | Port for the web UI             |
| `GIT_PROXY_HTTPS_SERVER_PORT` | `8443`             | Port for HTTPS git proxy server |

### SSH Configuration

| Variable   | Default | Description                                 |
| ---------- | ------- | ------------------------------------------- |
| `SSH_PORT` | `22`    | SSH port for Git operations (standard port) |

### Domain Configuration

| Variable            | Default                  | Description                          |
| ------------------- | ------------------------ | ------------------------------------ |
| `DOMAIN`            | `git.shur.im`            | Primary domain for the application   |
| `LETSENCRYPT_EMAIL` | `your-email@example.com` | Email for Let's Encrypt certificates |

### MongoDB Configuration

| Variable           | Default                     | Description           |
| ------------------ | --------------------------- | --------------------- |
| `MONGODB_HOST`     | `localhost`                 | MongoDB hostname      |
| `MONGODB_PORT`     | `27017`                     | MongoDB port          |
| `MONGODB_DATABASE` | `gitproxy`                  | MongoDB database name |
| `MONGODB_USERNAME` | `admin`                     | MongoDB username      |
| `MONGODB_PASSWORD` | `your_secure_password_here` | MongoDB password      |

## Configuration Files

### proxy.config.json

The main configuration file supports environment variable substitution:

```json
{
  "sink": [
    {
      "type": "mongo",
      "connectionString": "mongodb://${MONGODB_HOST:-localhost}:${MONGODB_PORT:-27017}/${MONGODB_DATABASE:-gitproxy}",
      "enabled": false
    }
  ],
  "domains": {},
  "api": {
    "github": {
      "baseUrl": "https://api.github.com"
    }
  }
}
```

### domains Configuration

You can override default domain resolution by configuring the `domains` section:

```json
{
  "domains": {
    "service": "https://your-custom-domain.com",
    "proxy": "https://git.your-custom-domain.com"
  }
}
```

## Deployment Scenarios

### 1. Local Development

```bash
# Use default localhost configuration
docker-compose up -d
```

Access:

- Web UI: http://localhost:8080
- SSH: localhost:22 (standard SSH port)

### 2. Custom Domain Deployment

```bash
# Set environment variables
export DOMAIN=git.yourdomain.com
export LETSENCRYPT_EMAIL=admin@yourdomain.com
export GIT_PROXY_UI_HOST=https://git.yourdomain.com

# Deploy with custom domain
docker-compose -f docker-compose.remote.yml up -d
```

Access:

- Web UI: https://git.yourdomain.com
- SSH: git.yourdomain.com:22 (standard SSH port)

### 3. Internal Network Deployment

```bash
# Set internal network configuration
export GIT_PROXY_UI_HOST=http://git-proxy.internal.company.com
export MONGODB_HOST=mongodb.internal.company.com
export DOMAIN=git-proxy.internal.company.com

# Deploy
docker-compose -f docker-compose.prod.yml up -d
```

### 4. Multi-tenant Deployment

```bash
# Tenant A
export DOMAIN=tenant-a.gitproxy.com
export GIT_PROXY_UI_HOST=https://tenant-a.gitproxy.com
docker-compose -f docker-compose.remote.yml up -d

# Tenant B (separate deployment)
export DOMAIN=tenant-b.gitproxy.com
export GIT_PROXY_UI_HOST=https://tenant-b.gitproxy.com
docker-compose -f docker-compose.remote.yml up -d
```

## Docker Compose Files

### docker-compose.yml

- **Purpose**: Local development
- **DNS**: Uses localhost defaults
- **SSL**: Self-signed certificates

### docker-compose.prod.yml

- **Purpose**: Production with MongoDB
- **DNS**: Configurable via environment variables
- **SSL**: Custom certificates

### docker-compose.remote.yml

- **Purpose**: Production with automatic SSL
- **DNS**: Fully parameterized with Let's Encrypt
- **SSL**: Automatic certificate management

### docker-compose.ssh-test.yml

- **Purpose**: SSH flow testing
- **DNS**: Localhost-based
- **SSL**: Optional

## Host Resolution Logic

The application uses the following priority order for host resolution:

1. **Configured domains** (from `proxy.config.json` domains section)
2. **Environment variables** (`GIT_PROXY_UI_HOST`)
3. **Request headers** (`Host` header from incoming requests)
4. **Default fallback** (`localhost`)

## Best Practices

### 1. Use Environment Variables

Always use environment variables for deployment-specific configuration:

```bash
# Good
export DOMAIN=your-production-domain.com
export GIT_PROXY_UI_HOST=https://your-production-domain.com

# Avoid hardcoding in config files
```

### 2. DNS Configuration

Ensure your DNS is properly configured before deployment:

```bash
# Check DNS resolution
dig your-domain.com
nslookup your-domain.com
```

### 3. SSL Certificate Management

For production deployments, use the remote compose file for automatic SSL:

```bash
# Automatic SSL with Let's Encrypt
docker-compose -f docker-compose.remote.yml up -d
```

### 4. Health Checks

All health checks are DNS-agnostic and use environment variables:

```yaml
healthcheck:
  test: echo 'db.runCommand("ping").ok' | mongosh ${MONGODB_HOST:-localhost}:${MONGODB_PORT:-27017}/test --quiet
```

## Troubleshooting

### Common Issues

1. **Domain not resolving**

   ```bash
   # Check DNS configuration
   dig your-domain.com
   curl -I http://your-domain.com
   ```

2. **MongoDB connection issues**

   ```bash
   # Verify MongoDB host configuration
   echo $MONGODB_HOST
   telnet $MONGODB_HOST $MONGODB_PORT
   ```

3. **SSL certificate issues**
   ```bash
   # Check Let's Encrypt logs
   docker logs git-proxy-ssl
   ```

### Validation Commands

```bash
# Test application health
curl http://localhost:8080/api/health

# Test SSH connection
ssh -T git@localhost

# Test domain resolution
curl -I https://your-domain.com/api/health
```

## Migration Guide

### From Hardcoded to DNS-Agnostic

1. **Identify hardcoded domains** in your configuration
2. **Replace with environment variables**:

   ```json
   // Before
   "connectionString": "mongodb://localhost:27017/gitproxy"

   // After
   "connectionString": "mongodb://${MONGODB_HOST:-localhost}:${MONGODB_PORT:-27017}/${MONGODB_DATABASE:-gitproxy}"
   ```

3. **Set environment variables** for your deployment
4. **Test configuration** in your target environment

This DNS-agnostic approach ensures Git Proxy can be deployed in any environment without modification of the core configuration files.
