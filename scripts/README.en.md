# Unix Secrets Manager Scripts Documentation

**Version:** 1.0.0
**Date:** December 2025
**Status:** Production Ready

---

## Overview

This document describes the auxiliary scripts for managing the Unix Secrets Manager system.

**Purpose of Scripts:**
- Automate routine operations
- Ensure operation security
- Simplify system administration

### Compatibility

| Script | Linux | macOS | Docker | Requires root |
|--------|-------|-------|--------|--------------|
| `decrypt-secrets.sh` | ✅ | ❌ | ⚠️ (adaptation) | ✅ |
| `generate-test-secrets.sh` | ✅ | ✅ | ✅ | ❌ |
| `rotate-secret.sh` | ✅ | ❌ | ⚠️ (adaptation) | ✅ |

### System Requirements

- **Bash:** 4.0+
- **GPG:** 2.2+ (for encryption)
- **systemd:** (for services)
- **OpenSSL:** (alternative to GPG)

## Scripts

### decrypt-secrets.sh

**Purpose:** Decrypt secrets into tmpfs for systemd services

**Usage:**
```bash
# Automatically started by systemd
sudo systemctl start secrets-decrypt.service

# Manual run (for debugging)
sudo /usr/local/bin/decrypt-secrets.sh
```

**What it does:**
- Creates tmpfs in `/run/secrets`
- Decrypts all `.gpg` files from `/etc/secrets.encrypted`
- Sets correct access permissions
- Works only with root permissions

**Requirements:**
- GPG key must be available
- Directory `/etc/secrets.encrypted` must exist
- Systemd must be running

### generate-test-secrets.sh

**Purpose:** Generate test secrets for development

**Usage:**
```bash
./generate-test-secrets.sh
```

**What it does:**
- Creates test secret files in `samples/`
- Creates encrypted versions in `secrets.encrypted/`
- Generates examples for all secret types

**Security:** For development only! Do not use in production.

### rotate-secret.sh

**Purpose:** Rotate secrets without downtime

**Usage:**
```bash
./rotate-secret.sh <secret_name> "<new_value>"
```

**Examples:**
```bash
./rotate-secret.sh db_password "new_secure_password_123"
./rotate-secret.sh api_key "sk-new-api-key-here"
```

**What it does:**
- Encrypts new secret value
- Atomically replaces file in `/etc/secrets.encrypted`
- Restarts decryption service
- Restarts dependent services

**Features:**
- Atomic operation (no intermediate states)
- Automatic service restart
- Logging to syslog

## Installation

```bash
# Copy scripts
sudo cp scripts/*.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/*.sh

# Configure systemd
sudo cp systemd-units/secrets-decrypt.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable secrets-decrypt.service
```

## Monitoring

### Systemd Logs
```bash
# Decryption service logs
sudo journalctl -u secrets-decrypt.service -f

# Secret rotation logs
sudo journalctl -t secrets-manager -f
```

### Status Check
```bash
# Service status
sudo systemctl status secrets-decrypt.service

# Secrets check
ls -la /run/secrets/
```

## Troubleshooting

### Service not starting
```bash
# Check status
sudo systemctl status secrets-decrypt.service

# Check logs
sudo journalctl -u secrets-decrypt.service -n 50

# Possible problems:
# - GPG key missing
# - Incorrect permissions on /etc/secrets.encrypted
# - Corrupted .gpg files
```

### Secrets not decrypting
```bash
# Check GPG
gpg --list-keys secrets@host

# Check files
ls -la /etc/secrets.encrypted/

# Manual decryption for test
gpg --decrypt /etc/secrets.encrypted/test.gpg
```

### Rotation not working
```bash
# Check arguments
./rotate-secret.sh db_password "new_password"

# Check logs
sudo journalctl -t secrets-manager -n 20

# Possible problems:
# - GPG key missing
# - Incorrect file permissions
# - Service cannot restart
```

## Security

- All scripts check for root permissions
- Secrets are never logged
- Temporary files securely deleted
- All operations audited via syslog

## Production Usage

### Automation
```bash
# Cron for automatic rotation (example)
0 2 * * 1 /usr/local/bin/rotate-secret.sh api_key "$(generate-new-key)"
```

### Monitoring
```bash
# Nagios/Icinga check
#!/bin/bash
if systemctl is-active secrets-decrypt.service >/dev/null; then
    echo "OK: Secrets service running"
    exit 0
else
    echo "CRITICAL: Secrets service down"
    exit 2
fi
```

### Backup
```bash
# Backup secrets
tar -czf secrets-backup-$(date +%Y%m%d).tar.gz /etc/secrets.encrypted/
```

## Docker Integration

For Docker environments, use modified script versions from `examples/telegram-bot/`:
- `decrypt-secrets-docker.sh` - container version
- `docker-deploy.sh` - Docker stack management

## Contributing

When adding new scripts:
1. Add shebang `#!/bin/bash`
2. Use `set -e` for fail-fast behavior
3. Add documentation to this file
4. Test with various scenarios
5. Add security checks
