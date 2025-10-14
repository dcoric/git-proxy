# Git Proxy Docker - Quick Reference Card

## 📁 File Structure

```
git-proxy/
├── 🆕 START_HERE.md                  ← READ THIS FIRST!
│
├── Docker Compose Files:
│   ├── docker-compose.yml            (original dev)
│   ├── docker-compose.prod.yml       (original prod)
│   ├── 🆕 docker-compose.ssh-test.yml    (isolated SSH testing)
│   └── 🆕 docker-compose.remote.yml      (production with SSL)
│
├── Setup Scripts:
│   ├── docker-setup.sh               (original)
│   ├── 🆕 setup-ssh-test.sh          (SSH testing - executable)
│   └── 🆕 setup-remote.sh            (remote deploy - executable)
│
├── Configuration:
│   ├── proxy.config.json             (base config)
│   └── 🆕 env.template               (environment vars template)
│
└── Documentation:
    ├── DOCKER.md                     (original docs)
    ├── 🆕 DOCKER_SSH_QUICKSTART.md   (step-by-step guide)
    ├── 🆕 DOCKER_REVIEW_SUMMARY.md   (what changed & why)
    └── 🆕 DOCKER_IMPROVEMENTS.md     (technical details)
```

## 🚀 Commands Cheat Sheet

### Local SSH Testing

```bash
# Setup (one command)
./setup-ssh-test.sh

# Test SSH
ssh -T -p 2222 git@localhost

# Add git remote
git remote add proxy ssh://git@localhost:2222/user/repo.git

# View logs
docker compose -f docker-compose.ssh-test.yml logs -f

# Stop
docker compose -f docker-compose.ssh-test.yml down
```

### Remote Deployment (git.shur.im)

```bash
# Prerequisites
# 1. DNS: git.shur.im → server IP
# 2. Ports: 80, 443, 2222 open

# Deploy (one command)
./setup-remote.sh

# Test SSH
ssh -T -p 2222 git@git.shur.im

# Add git remote
git remote add proxy ssh://git@git.shur.im:2222/user/repo.git

# View logs
docker compose -f docker-compose.remote.yml logs -f

# Stop
docker compose -f docker-compose.remote.yml down
```

## 🔧 Configuration Files (Auto-Generated)

These files are created by setup scripts and git-ignored:

```
.ssh/
├── host_key              (private key)
└── host_key.pub          (public key - add to GitHub)

proxy.config.ssh-test.json    (SSH test config)
proxy.config.remote.json      (remote server config)
.env                          (environment variables)
```

## 📊 Port Mapping

| Port  | Service             | Local    | Remote        |
| ----- | ------------------- | -------- | ------------- |
| 2222  | SSH Git             | ✅       | ✅            |
| 8080  | Web UI (HTTP)       | ✅       | Internal only |
| 443   | Web UI (HTTPS)      | ❌       | ✅ (auto SSL) |
| 80    | HTTP→HTTPS redirect | ❌       | ✅            |
| 27017 | MongoDB             | Internal | Internal      |

## 🔍 Troubleshooting Quick Fixes

### SSH Connection Refused

```bash
# Check container status
docker compose -f docker-compose.ssh-test.yml ps

# Check SSH enabled
cat proxy.config.ssh-test.json | jq '.ssh.enabled'

# Restart
docker compose -f docker-compose.ssh-test.yml restart
```

### Authentication Failed

```bash
# Check logs
docker compose logs git-proxy | grep -i auth

# Verify GitHub SSH key
ssh -T git@github.com

# Check proxy public key
cat .ssh/host_key.pub
```

### SSL Not Working (Remote)

```bash
# Monitor SSL provisioning
docker compose -f docker-compose.remote.yml logs -f nginx-ssl

# Check DNS
dig git.shur.im

# Verify port 80 accessible
curl -I http://git.shur.im
```

## 📖 Documentation Guide

| File                     | When to Read          |
| ------------------------ | --------------------- |
| START_HERE.md            | First! Quick overview |
| DOCKER_SSH_QUICKSTART.md | When setting up       |
| DOCKER_REVIEW_SUMMARY.md | To understand changes |
| DOCKER_IMPROVEMENTS.md   | For advanced config   |
| QUICK_REFERENCE.md       | As a cheat sheet      |

## 🎯 What Changed

### Original Setup Issues:

- ❌ SSH disabled by default
- ❌ No isolated testing
- ❌ No remote deployment guide
- ❌ Manual SSL setup
- ❌ No environment template

### New Setup:

- ✅ One-command SSH testing
- ✅ Isolated test environment
- ✅ Automated remote deployment
- ✅ Automatic SSL (Let's Encrypt)
- ✅ Environment template
- ✅ Comprehensive docs

## 🏗️ Architecture

### SSH Flow:

```
Client → Git Proxy (SSH:2222) → GitHub/GitLab
            ↓
    Security Chain (17 processors)
            ↓
        Audit Logs
```

### Security Processors:

1. Secret detection (gitleaks)
2. Commit message validation
3. Author validation
4. Email domain validation
5. Hidden commit detection
6. Pre-receive hooks
7. File size limits
8. Binary file detection
9. License compliance
10. And 8 more...

## 🔐 Security Notes

### SSH Keys:

- Unique per environment
- Never commit to git (git-ignored)
- Add public key to GitHub/GitLab
- Proxy uses host key for upstream

### Environment:

- `.env` is git-ignored
- Auto-generated secure passwords
- Use `env.template` as reference
- Different configs per environment

### SSL/TLS:

- Local: Self-signed (auto-generated)
- Remote: Let's Encrypt (auto-renewed)
- HTTPS enforced in production

## ⚡ Quick Start Summary

### 1. Local Testing (5 min):

```bash
./setup-ssh-test.sh
# Add SSH key to GitHub
ssh -T -p 2222 git@localhost
```

### 2. Remote Deployment (10 min):

```bash
# Configure DNS first!
./setup-remote.sh
# Add SSH key to GitHub
ssh -T -p 2222 git@git.shur.im
```

## 📞 Support

- **Docs**: https://git-proxy.finos.org
- **Issues**: https://github.com/finos/git-proxy/issues
- **Slack**: FINOS #git-proxy

---

**Note**: This is a quick reference. For detailed instructions, see `START_HERE.md` or `DOCKER_SSH_QUICKSTART.md`.
