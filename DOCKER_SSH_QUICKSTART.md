# Git Proxy SSH Testing - Quick Start Guide

This guide will help you test the SSH flow both locally and on your remote server (git.shur.im).

## Prerequisites

- Docker and Docker Compose installed
- Git installed
- (For remote) A server with Docker and ports 80, 443, 2222 accessible

## Local SSH Testing (5 minutes)

### 1. Run the setup script

```bash
./setup-ssh-test.sh
```

This script will:

- ✅ Generate SSH host keys
- ✅ Create self-signed TLS certificates
- ✅ Create SSH-enabled configuration
- ✅ Build and start Docker containers
- ✅ Display the public key to add to GitHub/GitLab

### 2. Add SSH key to GitHub

Copy the public key displayed by the script and add it to GitHub:

1. Go to: https://github.com/settings/keys
2. Click "New SSH key"
3. Paste the key and save

### 3. Test SSH connection

```bash
# Test basic SSH connection
ssh -T -p 2222 git@localhost

# Should respond with authentication success
```

### 4. Test Git operations

```bash
# Clone a test repository
git clone https://github.com/yourusername/test-repo.git
cd test-repo

# Add proxy remote
git remote add proxy ssh://git@localhost:2222/yourusername/test-repo.git

# Make a test commit
echo "test" >> README.md
git add .
git commit -m "Test commit via proxy"

# Push through the proxy
git push proxy main
```

### 5. Monitor the proxy

```bash
# View all logs
docker compose -f docker-compose.ssh-test.yml logs -f

# View only SSH-related logs
docker compose -f docker-compose.ssh-test.yml logs -f | grep SSH
```

### 6. Access Web UI

Open in browser: http://localhost:8080

### 7. Clean up when done

```bash
docker compose -f docker-compose.ssh-test.yml down
```

## Remote Server Deployment (git.shur.im)

### 1. Configure DNS

Before deploying, ensure your DNS is configured:

```
Type    Name          Value              TTL
A       git.shur.im   YOUR_SERVER_IP     300
```

Verify DNS propagation:

```bash
dig git.shur.im
# or
nslookup git.shur.im
```

### 2. SSH into your remote server

```bash
ssh your-user@YOUR_SERVER_IP
```

### 3. Install prerequisites

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y docker.io docker-compose git

# RHEL/CentOS
sudo yum install -y docker docker-compose git

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to docker group
sudo usermod -aG docker $USER
# Log out and back in for this to take effect
```

### 4. Clone the repository

```bash
git clone https://github.com/finos/git-proxy.git
cd git-proxy
```

### 5. Configure firewall

```bash
# UFW (Ubuntu/Debian)
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 2222/tcp

# firewalld (RHEL/CentOS)
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=2222/tcp
sudo firewall-cmd --reload
```

### 6. Run the remote setup script

```bash
./setup-remote.sh
```

This script will:

- ✅ Generate production SSH keys
- ✅ Set up environment variables with secure MongoDB password
- ✅ Configure Let's Encrypt for automatic SSL
- ✅ Create production configuration
- ✅ Build and start containers

### 7. Monitor SSL certificate provisioning

SSL certificates are automatically provisioned via Let's Encrypt (takes 1-2 minutes):

```bash
# Monitor certificate provisioning
docker compose -f docker-compose.remote.yml logs -f nginx-ssl

# Look for: "Successfully received certificate"
```

### 8. Test from your local machine

#### Add SSH key to GitHub

The setup script displayed a public key - add it to GitHub:

1. Go to: https://github.com/settings/keys
2. Click "New SSH key"
3. Paste the key and save

#### Test SSH connection

```bash
# From your local machine
ssh -T -p 2222 git@git.shur.im
```

#### Test Git operations

```bash
# Clone a repository
git clone https://github.com/yourusername/test-repo.git
cd test-repo

# Add proxy remote
git remote add proxy ssh://git@git.shur.im:2222/yourusername/test-repo.git

# Make a change
echo "test" >> README.md
git add .
git commit -m "Test via remote proxy"

# Push through proxy
git push proxy main
```

### 9. Access Web UI

Open in browser: https://git.shur.im

(HTTP automatically redirects to HTTPS)

### 10. Monitor the deployment

```bash
# View all logs
docker compose -f docker-compose.remote.yml logs -f

# View specific service logs
docker compose -f docker-compose.remote.yml logs -f git-proxy
docker compose -f docker-compose.remote.yml logs -f nginx
docker compose -f docker-compose.remote.yml logs -f mongodb

# Check container status
docker compose -f docker-compose.remote.yml ps

# Check resource usage
docker stats
```

## Understanding the SSH Flow

### Architecture

```
┌─────────────┐     SSH:2222      ┌──────────────┐     SSH:22      ┌─────────────┐
│             │ ─────────────────> │              │ ─────────────> │             │
│  Developer  │                    │  Git Proxy   │                │   GitHub    │
│   (Client)  │ <───────────────── │   (Server)   │ <───────────── │  (Remote)   │
└─────────────┘                    └──────────────┘                └─────────────┘
                                           │
                                           ↓
                                   ┌──────────────┐
                                   │   Security   │
                                   │    Chain     │
                                   │(17 processors)│
                                   └──────────────┘
```

### Flow Steps

1. **Client connects** to Git Proxy SSH server (port 2222)
2. **Authentication** via SSH public key or password
3. **Command received** (e.g., `git-receive-pack` for push)
4. **Pack data extracted** from SSH stream
5. **Security chain runs** (17 processors validate the push)
   - Secret detection (gitleaks)
   - Commit message validation
   - Author email validation
   - Hidden commit detection
   - Pre-receive hooks
   - And more...
6. **If approved**: Proxy forwards to remote Git server
7. **If blocked**: Error message returned to client
8. **Audit log** created for compliance

## Troubleshooting

### Local Testing Issues

#### SSH connection refused

```bash
# Check if container is running
docker compose -f docker-compose.ssh-test.yml ps

# Check if SSH is enabled in config
cat proxy.config.ssh-test.json | grep -A 5 '"ssh"'

# Restart container
docker compose -f docker-compose.ssh-test.yml restart
```

#### Authentication failed

```bash
# Check logs for auth errors
docker compose -f docker-compose.ssh-test.yml logs git-proxy | grep -i auth

# Verify your SSH key is added to GitHub
ssh -T git@github.com

# Verify proxy public key
cat .ssh/host_key.pub
```

### Remote Deployment Issues

#### DNS not resolving

```bash
# Check DNS propagation
dig git.shur.im

# If not propagated, wait and check again
# DNS can take 5-60 minutes to propagate
```

#### SSL certificate not provisioning

```bash
# Check nginx-ssl logs
docker compose -f docker-compose.remote.yml logs nginx-ssl

# Verify DNS points to server
curl -I http://git.shur.im

# Check if port 80 is accessible
sudo netstat -tlnp | grep :80

# Manually trigger certificate renewal
docker compose -f docker-compose.remote.yml restart nginx-ssl
```

#### Port already in use

```bash
# Find what's using the port
sudo lsof -i :2222
sudo lsof -i :80
sudo lsof -i :443

# Stop conflicting service or change port in config
```

#### Container keeps restarting

```bash
# Check logs for errors
docker compose -f docker-compose.remote.yml logs git-proxy

# Common issues:
# - Invalid config JSON
# - Missing SSH keys
# - MongoDB connection failed

# Validate config
cat proxy.config.remote.json | jq .

# Check if SSH keys exist
ls -la .ssh/
```

## Advanced Configuration

### Custom Domain Configuration

To use a different domain, edit `setup-remote.sh` and `docker-compose.remote.yml`:

```bash
# In setup-remote.sh, change:
DOMAIN=git.shur.im

# In docker-compose.remote.yml, change:
VIRTUAL_HOST=your-domain.com
LETSENCRYPT_HOST=your-domain.com
```

### Custom SSH Port

To use a different SSH port, edit `docker-compose.*.yml`:

```yaml
ports:
  - '2222:2222' # Change first number: 'HOST_PORT:CONTAINER_PORT'
```

### MongoDB External Access

To access MongoDB externally (for debugging):

```yaml
# Add to docker-compose.remote.yml mongodb service
ports:
  - '27017:27017'
```

⚠️ **Security Warning**: Only do this temporarily and secure with firewall rules.

### Resource Limits

Adjust based on your usage:

```yaml
# In docker-compose.remote.yml
deploy:
  resources:
    limits:
      cpus: '4' # Increase for high traffic
      memory: 4G # Increase for many users
```

## Security Best Practices

### SSH Keys

- ✅ Generate unique keys per environment (test vs prod)
- ✅ Never commit private keys to git
- ✅ Rotate keys periodically
- ✅ Use strong key algorithms (RSA 4096 or Ed25519)

### Passwords

- ✅ Use strong, random passwords (script auto-generates)
- ✅ Store passwords in `.env` file (git-ignored)
- ✅ Change default MongoDB password
- ✅ Use different passwords per environment

### Network

- ✅ Use HTTPS for web UI (automated with Let's Encrypt)
- ✅ Restrict SSH port (2222) with firewall if needed
- ✅ Use Docker networks for internal communication
- ✅ Don't expose MongoDB port externally

### Monitoring

- ✅ Regularly check logs for suspicious activity
- ✅ Set up log rotation (automatically configured)
- ✅ Monitor failed authentication attempts
- ✅ Review audit logs for compliance

## Next Steps

After successful testing:

1. **Configure authorized repositories**
   - Edit config to add your allowed repos
   - Set up approval workflows

2. **Set up authentication**
   - Configure LDAP/Active Directory
   - Set up OIDC/SAML
   - Create user accounts

3. **Customize security rules**
   - Configure gitleaks patterns
   - Set up custom plugins
   - Define pre-receive hooks

4. **Scale for production**
   - Increase resource limits
   - Set up monitoring and alerts
   - Configure backup strategy
   - Implement log aggregation

## Useful Commands

### Local Testing

```bash
# Start
./setup-ssh-test.sh

# Restart
docker compose -f docker-compose.ssh-test.yml restart

# Stop
docker compose -f docker-compose.ssh-test.yml down

# View logs
docker compose -f docker-compose.ssh-test.yml logs -f

# Shell into container
docker compose -f docker-compose.ssh-test.yml exec git-proxy sh
```

### Remote Deployment

```bash
# Deploy
./setup-remote.sh

# Restart
docker compose -f docker-compose.remote.yml restart

# Stop
docker compose -f docker-compose.remote.yml down

# Update config (no rebuild needed)
vim proxy.config.remote.json
docker compose -f docker-compose.remote.yml restart git-proxy

# Rebuild after code changes
docker compose -f docker-compose.remote.yml build
docker compose -f docker-compose.remote.yml up -d
```

## Support

- **Documentation**: https://git-proxy.finos.org
- **GitHub Issues**: https://github.com/finos/git-proxy/issues
- **Slack**: FINOS Slack #git-proxy channel
- **Email**: git-proxy@lists.finos.org

## Files Reference

- `docker-compose.ssh-test.yml` - Local SSH testing environment
- `docker-compose.remote.yml` - Production deployment
- `setup-ssh-test.sh` - Local SSH setup automation
- `setup-remote.sh` - Remote deployment automation
- `proxy.config.ssh-test.json` - SSH test configuration (generated)
- `proxy.config.remote.json` - Remote server configuration (generated)
- `env.template` - Environment variables template
- `.env` - Environment variables (generated, git-ignored)
- `.ssh/` - SSH keys directory (git-ignored)
