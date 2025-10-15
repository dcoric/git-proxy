# SSH Port 22 Setup Guide

This guide explains how to configure Git Proxy to use the standard SSH port 22 for Git operations, while moving your server's regular SSH to port 2222.

## Why Use Port 22?

Using the standard SSH port 22 for Git operations provides several benefits:

1. **Clean Git URLs**: Users can clone repositories without specifying ports:

   ```bash
   # Clean format (no port needed)
   git clone git@yourdomain.com:user/repo.git

   # Instead of this
   git clone ssh://git@yourdomain.com:2222/user/repo.git
   ```

2. **Standard SSH Experience**: Matches the behavior of GitHub, GitLab, and other Git hosting services.

3. **Firewall Friendly**: Port 22 is typically open in most network configurations.

4. **No SSH Config Required**: Users don't need special SSH client configurations.

## Server Configuration

### Step 1: Configure Server SSH Daemon

Edit your server's SSH configuration to use port 2222 for regular SSH access:

```bash
# Edit SSH daemon configuration
sudo nano /etc/ssh/sshd_config

# Change the port line from:
# Port 22
# To:
Port 2222

# Save and restart SSH service
sudo systemctl restart sshd
```

### Step 2: Update Firewall Rules

Configure your firewall to allow both ports:

```bash
# Allow SSH on port 2222 for server access
sudo ufw allow 2222/tcp

# Allow SSH on port 22 for Git operations
sudo ufw allow 22/tcp

# Check status
sudo ufw status
```

### Step 3: Update SSH Client Configuration (Optional)

If you frequently SSH into your server, update your SSH client config:

```bash
# Edit ~/.ssh/config
nano ~/.ssh/config

# Add entry for your server
Host your-server
    HostName your-server-ip
    Port 2222
    User your-username
```

Now you can connect with:

```bash
ssh your-server  # Uses port 2222 automatically
```

## Docker Configuration

### Port Mapping

All Docker Compose files now map port 22 for Git operations:

```yaml
# docker-compose.yml, docker-compose.prod.yml, docker-compose.remote.yml
ports:
  - '22:22' # Git SSH operations
  - '8080:8080' # Web UI (where applicable)
```

### Environment Variables

The SSH port is configurable via environment variables:

```bash
# Set in your .env file or environment
SSH_PORT=22
```

## Testing the Configuration

### 1. Test Server SSH Access (Port 2222)

```bash
# Connect to server using new port
ssh -p 2222 username@your-server-ip

# Or if you configured SSH client config
ssh your-server
```

### 2. Test Git SSH Access (Port 22)

```bash
# Test SSH connection to Git Proxy
ssh -T git@yourdomain.com

# Test Git clone
git clone git@yourdomain.com:user/repo.git
```

### 3. Verify Port Usage

```bash
# Check what's listening on port 22
sudo netstat -tlnp | grep :22

# Check what's listening on port 2222
sudo netstat -tlnp | grep :2222
```

## Deployment Examples

### Local Development

```bash
# Start Git Proxy locally
docker-compose up -d

# Test Git operations
ssh -T git@localhost
git clone git@localhost:user/repo.git
```

### Production with Custom Domain

```bash
# Set environment variables
export DOMAIN=git.yourdomain.com
export LETSENCRYPT_EMAIL=admin@yourdomain.com

# Deploy
docker-compose -f docker-compose.remote.yml up -d

# Test Git operations
ssh -T git@git.yourdomain.com
git clone git@git.yourdomain.com:user/repo.git
```

## Troubleshooting

### Port 22 Already in Use

If port 22 is already in use by your system SSH daemon:

1. **Stop system SSH daemon temporarily**:

   ```bash
   sudo systemctl stop sshd
   ```

2. **Start Git Proxy**:

   ```bash
   docker-compose up -d
   ```

3. **Verify Git Proxy is working**:

   ```bash
   ssh -T git@localhost
   ```

4. **Restart system SSH on port 2222**:
   ```bash
   sudo systemctl start sshd
   ```

### Git Clone Issues

If Git clone fails, check:

1. **SSH key authentication**:

   ```bash
   ssh -T git@yourdomain.com
   ```

2. **Port accessibility**:

   ```bash
   telnet yourdomain.com 22
   ```

3. **Docker container status**:
   ```bash
   docker-compose logs git-proxy
   ```

### SSH Connection Issues

If you can't SSH into your server:

1. **Verify SSH daemon is running on port 2222**:

   ```bash
   sudo systemctl status sshd
   sudo netstat -tlnp | grep :2222
   ```

2. **Check firewall rules**:

   ```bash
   sudo ufw status
   ```

3. **Test connection**:
   ```bash
   ssh -p 2222 username@your-server-ip
   ```

## Security Considerations

### SSH Key Management

- Use strong SSH keys for Git operations
- Regularly rotate SSH keys
- Consider using SSH certificates for better key management

### Firewall Configuration

- Only open necessary ports (22 for Git, 2222 for SSH, 80/443 for web)
- Consider using fail2ban for SSH protection
- Monitor SSH access logs

### Access Control

- Limit Git access to authorized users
- Use SSH key restrictions in Git Proxy configuration
- Regularly audit SSH access logs

## Migration from Port 2222

If you're migrating from the previous port 2222 configuration:

1. **Update Docker Compose files** (already done)
2. **Update server SSH configuration** (move to port 2222)
3. **Update firewall rules**
4. **Test both SSH access methods**
5. **Update documentation and user guides**

This configuration provides a clean, standard Git experience while maintaining secure server access through a custom SSH port.
