# Unix Secrets Manager Administrator Guide

**Version:** 1.0.0
**Date:** December 2025
**Status:** Production Ready

---

## Overview

This guide is intended for system administrators, DevOps engineers, and developers responsible for deploying and operating the Unix Secrets Manager system.

**Target Audience:**
- Linux system administrators
- DevOps engineers
- Application developers
- Security specialists

**Prerequisites:**
- Linux system administration basics
- systemd knowledge
- GPG usage basics
- Docker (for containerized deployments)

### History of Changes

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 1.0.0 | 2025-12 | Development Team | Initial release |

---

## 1. Introduction

### 1.1 Purpose

This document provides comprehensive guidance for deploying, configuring, and maintaining the Unix Secrets Manager system in production environments.

### 1.2 Scope

The guide covers:
- System architecture and components
- Installation and initial configuration
- Operational procedures
- Troubleshooting and diagnostics
- Security considerations
- Maintenance and monitoring

### 1.3 References

- [systemd Documentation](https://www.freedesktop.org/software/systemd/man/)
- [GnuPG Manual](https://www.gnupg.org/documentation/manuals/gnupg/)
- [Docker Documentation](https://docs.docker.com/)
- [Linux tmpfs Documentation](https://www.kernel.org/doc/html/latest/filesystems/tmpfs.html)

---

## 2. Concept of Operations

### 2.1 System Architecture

Unix Secrets Manager operates on the principle of "encrypt at rest, decrypt in memory":

```
Encrypted Storage (disk) → Decryption Service → RAM Storage → Application Access
     GPG files               systemd service      tmpfs          credentials
```

#### Key Components:

1. **Encrypted Storage Layer**
   - GPG-encrypted files on disk
   - Access controlled by filesystem permissions
   - Backup and recovery capabilities

2. **Decryption Service Layer**
   - systemd service for automated decryption
   - Runs with minimal privileges
   - Monitors encrypted file changes

3. **Memory Storage Layer**
   - tmpfs filesystem in RAM
   - Automatic cleanup on reboot
   - No persistent storage

4. **Access Control Layer**
   - systemd LoadCredential mechanism
   - Service-specific credential directories
   - Dynamic user isolation

### 2.2 Operational Modes

#### Production Mode
- Automated startup via systemd
- Continuous monitoring and health checks
- Audit logging of all operations
- High availability considerations

#### Development Mode
- Manual operations for testing
- Debug logging enabled
- Relaxed security for troubleshooting
- Isolated test environments

#### Maintenance Mode
- Service pause for updates
- Backup operations
- Key rotation procedures
- Emergency recovery

### 2.3 Security Model

#### Defense in Depth
1. **Encryption at Rest:** All secrets encrypted with GPG
2. **Access Control:** POSIX ACL and systemd isolation
3. **Memory Protection:** Secrets exist only in RAM
4. **Audit Trail:** Complete logging of access
5. **Key Management:** Secure GPG key lifecycle

#### Threat Model
- **Physical Access:** System can be compromised
- **Network Attacks:** System may be network-isolated
- **Insider Threats:** Authorized users may be malicious
- **Supply Chain:** Dependencies may be compromised

**Assumptions:**
- System administrator is trusted
- Hardware platform is secure
- GPG keys are properly protected
- Network isolation where required

---

## 3. Installation and Configuration

### 3.1 Prerequisites

#### Hardware Requirements
- **CPU:** 1 GHz minimum, 2 GHz recommended
- **RAM:** 512 MB minimum, 1 GB recommended
- **Storage:** 100 MB free space
- **Network:** None required (air-gapped operation supported)

#### Software Requirements
- **Operating System:** Linux with systemd
  - Ubuntu 18.04 LTS or later
  - RHEL/CentOS 7 or later
  - Debian 9 or later
- **GPG:** 2.2.0 or later
- **systemd:** 232 or later

#### Access Requirements
- Root or sudo access for installation
- GPG key generation capability
- Ability to modify systemd configuration

### 3.2 Installation Procedure

#### Step 1: Prepare System
```bash
# Update package lists
sudo apt update

# Install required packages
sudo apt install -y gnupg systemd

# Verify systemd version
systemctl --version
```

#### Step 2: Configure GPG
```bash
# Generate GPG key pair
gpg --full-generate-key

# During key generation:
# - Key type: RSA (default)
# - Key size: 4096 bits
# - Key usage: Encrypt only (no signing)
# - Expiration: 2 years (recommended)
# - User ID: secrets@hostname
# - Passphrase: (leave empty for automated operation)

# List generated keys
gpg --list-keys

# Export public key for backup
gpg --export -a secrets@hostname > secrets-public.asc
```

#### Step 3: Deploy System Files
```bash
# Create directories
sudo mkdir -p /etc/secrets.encrypted
sudo mkdir -p /usr/local/lib/unix-secrets

# Set permissions
sudo chmod 700 /etc/secrets.encrypted
sudo chown root:root /etc/secrets.encrypted

# Copy system files
sudo cp scripts/decrypt-secrets.sh /usr/local/bin/
sudo cp systemd-units/secrets-decrypt.service /etc/systemd/system/

# Make scripts executable
sudo chmod +x /usr/local/bin/decrypt-secrets.sh
```

#### Step 4: Initial Configuration
```bash
# Create test secret
echo "test_secret_value" | gpg --encrypt --recipient secrets@hostname > /tmp/test.gpg
sudo mv /tmp/test.gpg /etc/secrets.encrypted/

# Verify encryption
gpg --decrypt /etc/secrets.encrypted/test.gpg
```

#### Step 5: Start Services
```bash
# Reload systemd configuration
sudo systemctl daemon-reload

# Enable service startup
sudo systemctl enable secrets-decrypt.service

# Start decryption service
sudo systemctl start secrets-decrypt.service

# Verify service status
sudo systemctl status secrets-decrypt.service
```

### 3.3 Post-Installation Verification

#### Functional Tests
```bash
# Check service is running
sudo systemctl is-active secrets-decrypt.service

# Verify secrets are decrypted
ls -la /run/secrets/

# Test secret access
cat /run/secrets/test

# Check systemd credentials directory
ls -la /run/credentials/secrets-decrypt.service/
```

#### Security Verification
```bash
# Verify file permissions
ls -ld /etc/secrets.encrypted/
ls -ld /run/secrets/

# Check running processes
ps aux | grep decrypt-secrets

# Verify GPG key availability
gpg --list-keys secrets@hostname
```

---

## 4. Procedures

### 4.1 Secret Management

#### Adding New Secrets
**Purpose:** Introduce new secret into the system

**Prerequisites:**
- System operational
- GPG key available
- Administrative access

**Procedure:**
1. Prepare secret value:
   ```bash
   # Create temporary file with secret
   echo "new_secret_value" > /tmp/new_secret.txt
   chmod 600 /tmp/new_secret.txt
   ```

2. Encrypt secret:
   ```bash
   # Encrypt with GPG
   gpg --encrypt --recipient secrets@hostname /tmp/new_secret.txt
   ```

3. Deploy encrypted secret:
   ```bash
   # Move to encrypted storage
   sudo mv /tmp/new_secret.txt.gpg /etc/secrets.encrypted/new_secret.gpg
   sudo chown root:root /etc/secrets.encrypted/new_secret.gpg
   sudo chmod 600 /etc/secrets.encrypted/new_secret.gpg
   ```

4. Trigger decryption:
   ```bash
   # Restart decryption service
   sudo systemctl restart secrets-decrypt.service
   ```

5. Verify deployment:
   ```bash
   # Check decrypted secret
   ls -la /run/secrets/new_secret
   cat /run/secrets/new_secret
   ```

**Postconditions:**
- Secret available at `/run/secrets/new_secret`
- File permissions correct (600, root:root)
- Service logs show successful decryption

#### Rotating Secrets
**Purpose:** Change secret value without service disruption

**Prerequisites:**
- Existing secret to rotate
- New secret value prepared
- Administrative access

**Procedure:**
1. Prepare new secret:
   ```bash
   echo "new_secret_value_$(date +%s)" > /tmp/updated_secret.txt
   ```

2. Create encrypted version:
   ```bash
   gpg --encrypt --recipient secrets@hostname /tmp/updated_secret.txt
   ```

3. Atomic replacement:
   ```bash
   # Use atomic move to prevent race conditions
   sudo mv /tmp/updated_secret.txt.gpg /etc/secrets.encrypted/existing_secret.gpg.tmp
   sudo mv /etc/secrets.encrypted/existing_secret.gpg.tmp /etc/secrets.encrypted/existing_secret.gpg
   ```

4. Trigger update:
   ```bash
   sudo systemctl restart secrets-decrypt.service
   ```

5. Verify rotation:
   ```bash
   # Check new value
   cat /run/secrets/existing_secret
   # Check service logs
   sudo journalctl -u secrets-decrypt.service -n 10
   ```

**Postconditions:**
- Secret value updated
- No service downtime
- Audit log entry created

#### Removing Secrets
**Purpose:** Remove secret from system

**Prerequisites:**
- Secret exists in system
- No dependent services (or services stopped)
- Administrative access

**Procedure:**
1. Identify dependent services:
   ```bash
   # Check systemd services using the secret
   grep -r "existing_secret" /etc/systemd/system/
   ```

2. Stop dependent services:
   ```bash
   sudo systemctl stop dependent-service.service
   ```

3. Remove encrypted secret:
   ```bash
   sudo rm /etc/secrets.encrypted/existing_secret.gpg
   ```

4. Restart decryption service:
   ```bash
   sudo systemctl restart secrets-decrypt.service
   ```

5. Verify removal:
   ```bash
   # Confirm secret no longer available
   ls -la /run/secrets/existing_secret  # Should not exist
   ```

**Postconditions:**
- Secret removed from all locations
- No traces in memory or disk
- Dependent services notified

### 4.2 System Operations

#### Backup and Recovery
**Purpose:** Create and restore system backups

**Backup Procedure:**
```bash
# Create timestamped backup
BACKUP_DIR="/var/backups/secrets"
sudo mkdir -p "$BACKUP_DIR"

# Archive encrypted secrets
sudo tar -czf "$BACKUP_DIR/secrets-$(date +%Y%m%d-%H%M%S).tar.gz" \
  -C /etc secrets.encrypted

# Encrypt backup
gpg --encrypt --recipient backup@company.com \
  "$BACKUP_DIR/secrets-$(date +%Y%m%d-%H%M%S).tar.gz"
```

**Recovery Procedure:**
```bash
# Decrypt backup
gpg --decrypt secrets-backup.tar.gz.gpg > secrets-backup.tar.gz

# Extract to temporary location
sudo mkdir -p /tmp/secrets-recovery
sudo tar -xzf secrets-backup.tar.gz -C /tmp/secrets-recovery

# Restore secrets
sudo cp -r /tmp/secrets-recovery/secrets.encrypted/* /etc/secrets.encrypted/

# Restart service
sudo systemctl restart secrets-decrypt.service

# Cleanup
sudo rm -rf /tmp/secrets-recovery secrets-backup.tar.gz
```

#### Log Management
**Purpose:** Configure and maintain system logs

**Log Configuration:**
```bash
# Configure systemd logging
sudo mkdir -p /etc/systemd/journald.conf.d/

cat << EOF | sudo tee /etc/systemd/journald.conf.d/secrets.conf
[Journal]
# Retain logs for 90 days
MaxRetentionSec=7776000
# Compress old logs
Compress=yes
# Limit log size
SystemMaxUse=100M
EOF

# Restart logging service
sudo systemctl restart systemd-journald
```

**Log Analysis:**
```bash
# View recent logs
sudo journalctl -u secrets-decrypt.service -n 50

# Search for specific events
sudo journalctl -u secrets-decrypt.service --grep="decryption"

# Export logs for analysis
sudo journalctl -u secrets-decrypt.service --since="2025-01-01" > secrets-audit.log
```

### 4.3 Application Integration

#### Systemd Service Configuration
**Basic Configuration:**
```ini
[Unit]
Description=My Application
After=secrets-decrypt.service
Requires=secrets-decrypt.service

[Service]
Type=simple
User=myapp
Group=myapp
DynamicUser=yes
LoadCredential=db_password:/run/secrets/db_password
LoadCredential=api_key:/run/secrets/api_key
Environment=CREDENTIALS_DIR=/run/credentials/%n
ExecStart=/usr/bin/myapp
Restart=always

[Install]
WantedBy=multi-user.target
```

#### Application Code Examples

**Python Application:**
```python
import os
import sys

class SecretsManager:
    def __init__(self):
        self.credentials_dir = os.environ.get('CREDENTIALS_DIR', '/run/credentials/system')
        self._secrets = {}

    def get_secret(self, name):
        if name not in self._secrets:
            try:
                with open(f'{self.credentials_dir}/{name}', 'r') as f:
                    self._secrets[name] = f.read().strip()
            except FileNotFoundError:
                return None
        return self._secrets[name]

# Usage
secrets = SecretsManager()
db_password = secrets.get_secret('db_password')
api_key = secrets.get_secret('api_key')
```

**Node.js Application:**
```javascript
const fs = require('fs');
const path = require('path');

class SecretsManager {
    constructor() {
        this.credentialsDir = process.env.CREDENTIALS_DIR || '/run/credentials/system';
    }

    getSecret(name) {
        try {
            const secretPath = path.join(this.credentialsDir, name);
            return fs.readFileSync(secretPath, 'utf8').trim();
        } catch (error) {
            console.error(`Secret ${name} not found:`, error.message);
            return null;
        }
    }
}

// Usage
const secrets = new SecretsManager();
const dbPassword = secrets.getSecret('db_password');
const apiKey = secrets.getSecret('api_key');
```

---

## 5. Troubleshooting and Error Handling

### 5.1 Common Issues

#### Service Startup Failures
**Symptom:** `secrets-decrypt.service` fails to start

**Possible Causes:**
- Missing GPG key
- Incorrect file permissions
- Corrupted encrypted files
- Missing dependencies

**Diagnostic Steps:**
```bash
# Check service status
sudo systemctl status secrets-decrypt.service

# View detailed logs
sudo journalctl -u secrets-decrypt.service -n 20 --no-pager

# Manual execution test
sudo -u root /usr/local/bin/decrypt-secrets.sh
```

**Resolution:**
```bash
# Fix GPG key
gpg --list-keys secrets@hostname

# Fix permissions
sudo chown -R root:root /etc/secrets.encrypted
sudo chmod -R 600 /etc/secrets.encrypted

# Recreate corrupted files
# Remove and re-add affected secrets
```

#### Secret Decryption Failures
**Symptom:** Secrets not appearing in `/run/secrets/`

**Possible Causes:**
- GPG passphrase required
- Corrupted encrypted files
- Insufficient permissions
- GPG agent issues

**Diagnostic Steps:**
```bash
# Test manual decryption
gpg --decrypt /etc/secrets.encrypted/test.gpg

# Check GPG agent
gpg-agent --version
ps aux | grep gpg-agent

# Verify file integrity
file /etc/secrets.encrypted/*.gpg
```

**Resolution:**
```bash
# Ensure no passphrase on GPG key
gpg --edit-key secrets@hostname
# Use 'passwd' command to set empty passphrase

# Recreate encrypted files
# Use the secret rotation procedure
```

#### Application Access Issues
**Symptom:** Application cannot read credentials

**Possible Causes:**
- Incorrect systemd configuration
- Missing LoadCredential directives
- Wrong credentials directory
- File permission issues

**Diagnostic Steps:**
```bash
# Check systemd service configuration
sudo systemctl cat myapp.service

# Verify credentials directory exists
ls -la /run/credentials/myapp.service/

# Test file access
sudo -u myapp cat /run/credentials/myapp.service/secret
```

**Resolution:**
```bash
# Update systemd service
sudo systemctl edit myapp.service
# Add LoadCredential directives

# Reload configuration
sudo systemctl daemon-reload
sudo systemctl restart myapp.service
```

### 5.2 Advanced Troubleshooting

#### Performance Issues
**Symptom:** High CPU or memory usage

**Analysis:**
```bash
# Monitor system resources
top -p $(pgrep -f decrypt-secrets)

# Check memory usage
ps aux --sort=-%mem | head -10

# Analyze systemd logs for patterns
sudo journalctl -u secrets-decrypt.service --since="1 hour ago" | grep -i "error\|warning"
```

#### Network-Related Issues (if applicable)
**Symptom:** GPG keyserver access failures

**Resolution:**
```bash
# Configure local keyserver
echo "keyserver hkps://keyserver.ubuntu.com" >> ~/.gnupg/gpg.conf

# Disable keyserver if air-gapped
echo "no-keyserver" >> ~/.gnupg/gpg.conf
```

### 5.3 Error Codes and Messages

#### GPG Error Codes
- `gpg: decryption failed: No secret key`: GPG key not available
- `gpg: decryption failed: Bad session key`: Corrupted encrypted file
- `gpg: [don't know]: invalid packet (ctb=xx)`: File format error

#### Systemd Error Codes
- `exit-code`: Script execution failed
- `signal`: Process terminated by signal
- `timeout`: Operation timed out
- `dependency`: Required service not running

---

## 6. Information for Removal or Decommissioning

### 6.1 Removal Conditions

System removal may be required for:
- Migration to alternative secret management solutions
- End-of-life system decommissioning
- Security policy changes
- Hardware replacement

### 6.2 Removal Procedure

**⚠️ Warning:** This procedure is irreversible. Ensure backups exist.

**Pre-removal Steps:**
1. Notify all stakeholders
2. Create final backup of secrets
3. Stop all dependent applications
4. Document removal reason

**Removal Procedure:**
```bash
# Stop and disable decryption service
sudo systemctl stop secrets-decrypt.service
sudo systemctl disable secrets-decrypt.service

# Remove systemd configuration
sudo rm /etc/systemd/system/secrets-decrypt.service
sudo systemctl daemon-reload

# Remove scripts and binaries
sudo rm /usr/local/bin/decrypt-secrets.sh

# Remove secret storage
sudo rm -rf /etc/secrets.encrypted
sudo rm -rf /run/secrets

# Optional: Remove GPG keys
gpg --delete-secret-key secrets@hostname
gpg --delete-key secrets@hostname

# Reboot to clear memory
sudo reboot
```

**Post-removal Verification:**
```bash
# Confirm services removed
sudo systemctl list-units --all | grep secrets

# Confirm files removed
ls -la /etc/secrets.encrypted 2>/dev/null || echo "Directory removed"
ls -la /run/secrets 2>/dev/null || echo "Directory removed"

# Confirm GPG keys removed
gpg --list-keys secrets@hostname 2>/dev/null || echo "Keys removed"
```

### 6.3 Data Migration

**Migration to Alternative Systems:**

**To HashiCorp Vault:**
1. Export secrets in plaintext
2. Import into Vault using API
3. Update application configurations
4. Test access controls

**To AWS Secrets Manager:**
1. Use AWS CLI to create secrets
2. Update IAM policies
3. Modify application code for AWS SDK
4. Validate secret rotation

**To Azure Key Vault:**
1. Create Key Vault instance
2. Import secrets via Azure CLI
3. Configure access policies
4. Update application authentication

---

## 7. Examples

### 7.1 Complete Web Application Deployment

**Scenario:** Deploy web application with database secrets

**Prerequisites:**
- Ubuntu 20.04 server
- PostgreSQL database
- Nginx web server
- Application code repository

**Deployment Steps:**

1. **Install System Dependencies:**
   ```bash
   sudo apt update
   sudo apt install -y gnupg postgresql nginx python3-pip
   ```

2. **Configure Unix Secrets Manager:**
   ```bash
   # Follow installation procedure from section 3.2
   # Create GPG key and deploy system files
   ```

3. **Create Application Secrets:**
   ```bash
   # Database credentials
   echo "db_user=myapp" > /tmp/db_user.txt
   echo "db_password=$(openssl rand -base64 32)" > /tmp/db_password.txt
   echo "secret_key=$(openssl rand -hex 32)" > /tmp/secret_key.txt

   # Encrypt secrets
   gpg --encrypt --recipient secrets@hostname /tmp/db_user.txt
   gpg --encrypt --recipient secrets@hostname /tmp/db_password.txt
   gpg --encrypt --recipient secrets@hostname /tmp/secret_key.txt

   # Deploy to system
   sudo mv /tmp/db_user.txt.gpg /etc/secrets.encrypted/
   sudo mv /tmp/db_password.txt.gpg /etc/secrets.encrypted/
   sudo mv /tmp/secret_key.txt.gpg /etc/secrets.encrypted/

   # Restart decryption service
   sudo systemctl restart secrets-decrypt.service
   ```

4. **Configure Database:**
   ```sql
   -- Create application user
   CREATE USER myapp WITH PASSWORD 'password_from_secrets';
   CREATE DATABASE myapp OWNER myapp;
   ```

5. **Deploy Application:**
   ```bash
   # Create application user
   sudo useradd -r -s /bin/false myapp

   # Deploy application code
   sudo mkdir -p /opt/myapp
   sudo cp -r application_code/* /opt/myapp/
   sudo chown -R myapp:myapp /opt/myapp

   # Install Python dependencies
   cd /opt/myapp
   sudo -u myapp pip3 install -r requirements.txt
   ```

6. **Configure Systemd Service:**
   ```ini
   # /etc/systemd/system/myapp.service
   [Unit]
   Description=My Web Application
   After=secrets-decrypt.service postgresql.service
   Requires=secrets-decrypt.service

   [Service]
   Type=simple
   User=myapp
   Group=myapp
   WorkingDirectory=/opt/myapp
   Environment=PYTHONPATH=/opt/myapp
   LoadCredential=db_user:/run/secrets/db_user
   LoadCredential=db_password:/run/secrets/db_password
   LoadCredential=secret_key:/run/secrets/secret_key
   Environment=CREDENTIALS_DIR=/run/credentials/%n
   ExecStart=/usr/bin/python3 app.py
   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```

7. **Configure Nginx:**
   ```nginx
   # /etc/nginx/sites-available/myapp
   server {
       listen 80;
       server_name myapp.example.com;

       location / {
           proxy_pass http://127.0.0.1:8000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```

8. **Start Services:**
   ```bash
   # Enable and start services
   sudo systemctl enable myapp.service nginx.service
   sudo systemctl start myapp.service nginx.service

   # Verify operation
   sudo systemctl status myapp.service
   curl http://localhost/health
   ```

### 7.2 Docker Container Integration

**Scenario:** Deploy application in Docker with secret management

**Dockerfile:**
```dockerfile
FROM python:3.9-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Create application user
RUN useradd --create-home --shell /bin/bash app

# Set working directory
WORKDIR /app

# Copy application code
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Create secrets volume mount point
VOLUME ["/app/secrets"]

# Switch to non-root user
USER app

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python healthcheck.py

# Start application
CMD ["python", "app.py"]
```

**Docker Compose Configuration:**
```yaml
version: '3.8'

services:
  secrets-decrypt:
    build:
      context: .
      dockerfile: Dockerfile.secrets
    volumes:
      - ./secrets.encrypted:/etc/secrets.encrypted:ro
      - secrets_volume:/run/secrets
    environment:
      - GPG_KEY_ID=secrets@hostname
    command: ["/usr/local/bin/decrypt-secrets.sh"]

  webapp:
    build: .
    depends_on:
      - secrets-decrypt
    volumes:
      - secrets_volume:/app/secrets:ro
    ports:
      - "8000:8000"
    environment:
      - SECRETS_DIR=/app/secrets
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  secrets_volume:
    driver: local
    driver_opts:
      type: tmpfs
      device: tmpfs
```

**Deployment:**
```bash
# Build and deploy
docker-compose up -d

# Verify operation
docker-compose ps
docker-compose logs webapp
curl http://localhost:8000/health
```

---

## 8. Maintenance

### 8.1 Monitoring

#### Health Checks
```bash
#!/bin/bash
# /usr/local/bin/check-secrets-health.sh

# Check service status
if ! systemctl is-active --quiet secrets-decrypt.service; then
    echo "CRITICAL: secrets-decrypt service not running"
    exit 2
fi

# Check secrets directory
if [ ! -d /run/secrets ]; then
    echo "CRITICAL: secrets directory not found"
    exit 2
fi

# Check for expected secrets
expected_secrets=("db_password" "api_key")
for secret in "${expected_secrets[@]}"; do
    if [ ! -f "/run/secrets/$secret" ]; then
        echo "WARNING: expected secret $secret not found"
    fi
done

echo "OK: Secrets system healthy"
exit 0
```

#### Nagios/Icinga Integration
```bash
# /etc/nagios/nrpe.d/secrets.cfg
command[check_secrets_health]=/usr/local/bin/check-secrets-health.sh
```

#### Prometheus Metrics
```bash
# /usr/local/bin/secrets-exporter.sh
#!/bin/bash

# Service status
if systemctl is-active --quiet secrets-decrypt.service; then
    echo "secrets_service_status 1"
else
    echo "secrets_service_status 0"
fi

# Secrets count
secrets_count=$(ls /run/secrets/ | wc -l)
echo "secrets_count $secrets_count"

# Service uptime
uptime_seconds=$(systemctl show secrets-decrypt.service -p ActiveEnterTimestamp --value | cut -d' ' -f3)
echo "secrets_service_uptime_seconds $uptime_seconds"
```

### 8.2 Backup Strategy

#### Automated Backups
```bash
# /etc/cron.daily/secrets-backup
#!/bin/bash

BACKUP_DIR="/var/backups/secrets"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup encrypted secrets
tar -czf "$BACKUP_DIR/secrets-$TIMESTAMP.tar.gz" -C /etc secrets.encrypted

# Encrypt backup
gpg --encrypt --recipient backup@company.com "$BACKUP_DIR/secrets-$TIMESTAMP.tar.gz"

# Remove unencrypted backup
rm "$BACKUP_DIR/secrets-$TIMESTAMP.tar.gz"

# Rotate old backups (keep 30 days)
find "$BACKUP_DIR" -name "secrets-*.tar.gz.gpg" -mtime +30 -delete

# Log backup completion
logger "Secrets backup completed: secrets-$TIMESTAMP.tar.gz.gpg"
```

#### Backup Verification
```bash
# /usr/local/bin/verify-secrets-backup.sh
#!/bin/bash

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Decrypt and extract backup
temp_dir=$(mktemp -d)
gpg --decrypt "$BACKUP_FILE" | tar -xzf - -C "$temp_dir"

# Compare with current secrets
diff -r /etc/secrets.encrypted "$temp_dir/secrets.encrypted"

# Cleanup
rm -rf "$temp_dir"

echo "Backup verification completed"
```

### 8.3 Key Management

#### Key Rotation Procedure
```bash
# Generate new GPG key
gpg --full-generate-key
# New key ID: secrets-new@hostname

# Re-encrypt all secrets
for secret_file in /etc/secrets.encrypted/*.gpg; do
    secret_name=$(basename "$secret_file" .gpg)

    # Decrypt with old key
    gpg --decrypt "$secret_file" > "/tmp/$secret_name"

    # Encrypt with new key
    gpg --encrypt --recipient secrets-new@hostname "/tmp/$secret_name"
    mv "/tmp/$secret_name.gpg" "$secret_file"

    # Cleanup
    rm "/tmp/$secret_name"
done

# Update systemd service configuration if needed
# Restart decryption service
sudo systemctl restart secrets-decrypt.service

# Verify all secrets decrypted successfully
ls -la /run/secrets/

# Optional: Remove old key after verification
gpg --delete-secret-key secrets@hostname
gpg --delete-key secrets@hostname
```

#### Key Backup and Recovery
```bash
# Export private key for backup
gpg --export-secret-key secrets@hostname > secrets-private-key.asc
gpg --export-ownertrust > ownertrust.asc

# Secure storage (external HSM, encrypted USB, etc.)
# Store in multiple secure locations

# Key recovery
gpg --import secrets-private-key.asc
gpg --import-ownertrust ownertrust.asc

# Test key functionality
echo "test" | gpg --encrypt --recipient secrets@hostname | gpg --decrypt
```

---

## Appendices

### Appendix A: Glossary

| Term | Definition |
|------|------------|
| **Air-gapped** | System with no network connectivity |
| **Atomic operation** | Operation that either completes fully or not at all |
| **Credential** | Authentication information (username/password, API key) |
| **Decryption** | Process of converting encrypted data to plaintext |
| **Dynamic user** | User account created automatically by systemd |
| **Encryption** | Process of converting plaintext to encrypted data |
| **GPG** | GNU Privacy Guard encryption software |
| **LoadCredential** | systemd directive for loading secrets into services |
| **Secret** | Sensitive information requiring protection |
| **systemd** | System and service manager for Linux |
| **tmpfs** | Temporary filesystem stored in memory |
| **TPM** | Trusted Platform Module hardware security |

### Appendix B: Abbreviations

| Abbreviation | Full Form |
|--------------|-----------|
| ACL | Access Control List |
| AES | Advanced Encryption Standard |
| API | Application Programming Interface |
| CPU | Central Processing Unit |
| DNS | Domain Name System |
| GPG | GNU Privacy Guard |
| HTTP | HyperText Transfer Protocol |
| HTTPS | HTTP Secure |
| JSON | JavaScript Object Notation |
| RAM | Random Access Memory |
| REST | Representational State Transfer |
| RSA | Rivest-Shamir-Adleman |
| SDK | Software Development Kit |
| SELinux | Security-Enhanced Linux |
| SSH | Secure Shell |
| SSL | Secure Sockets Layer |
| TLS | Transport Layer Security |
| TPM | Trusted Platform Module |
| URL | Uniform Resource Locator |
| UUID | Universally Unique Identifier |
| XML | Extensible Markup Language |

### Appendix C: Index

- Backup: 8.2
- Configuration: 3.0
- Docker: 7.2
- Encryption: 2.3, 4.1
- GPG: 3.2, 5.1
- Installation: 3.2
- Maintenance: 8.0
- Monitoring: 8.1
- Removal: 6.0
- Rotation: 4.1, 8.3
- Secrets: 2.1, 4.1
- Security: 2.3
- systemd: 3.3, 4.4
- Troubleshooting: 5.0
- tmpfs: 2.1

---

*End of Unix Secrets Manager Administrator Guide*
