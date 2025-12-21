# Unix Secrets Manager

**Version:** 1.0.0
**Date:** December 2025
**Status:** Production Ready

---

## Overview

Secure secret management system based on internal Linux tools, without external dependencies.

**Target Audience:** System administrators, application developers, DevOps engineers

**Prerequisites:** Linux system administration, systemd, GPG basics

### History of Changes

| Version | Date | Description |
|---------|------|-------------|
| 1.0.0 | 2025-12 | Initial release |

### References

- **Complete Guide:** `docs/unix-secrets-manager-guide.md`
- **Scripts Documentation:** `scripts/README.md`
- **Telegram Bot Example:** `examples/telegram-bot/README.md`

---

## 1. Introduction

### 1.1 Purpose

Unix Secrets Manager provides enterprise-grade secret management (passwords, API keys, tokens) using only internal Linux primitives. The system ensures:

- **Complete Security:** Secrets are never stored in plaintext on disk
- **Isolation:** Each service has access only to its own secrets
- **Audit:** Complete logging of all secret operations
- **Rotation:** Secure secret changes without downtime

### 1.2 Scope

- Air-gapped (isolated) environments
- Embedded systems and appliances
- Regulated environments with restrictions on external dependencies
- Microservices architectures
- CI/CD pipelines

### 1.3 Architecture

```
Encrypted secrets (.gpg files)
    ↓ [GPG decryption]
Decrypted secrets (RAM tmpfs)
    ↓ [systemd credentials]
Isolated services
    ↓ [SecretsManager API]
Applications with secrets
```

**Key Components:**
- **GPG Encryption:** Military-grade secret protection
- **tmpfs Storage:** Secrets exist only in RAM
- **systemd Credentials:** Service access isolation
- **POSIX ACL:** Detailed access control

**Supported Platforms:**
- Linux with systemd
- Docker containers
- Kubernetes (with adaptation)

### 1.4 Project Structure

```
unixSecrets/
├── docs/                          # 📚 Complete documentation
│   └── unix-secrets-manager-guide.md
├── examples/                      # 🚀 Usage examples
│   └── telegram-bot/              # Telegram bot with 50+ secrets
├── scripts/                       # ⚙️ Management tools
│   ├── decrypt-secrets.sh        # Secret decryption
│   ├── generate-test-secrets.sh  # Test secret generation
│   └── rotate-secret.sh          # Secret rotation
├── systemd-units/                 # 🔧 Systemd configurations
│   ├── secrets-decrypt.service   # Decryption service
│   └── example-app.service       # Example service
├── secrets.encrypted/             # 🔒 Encrypted secrets
├── samples/                       # 💡 Code examples
│   └── example-app.py            # Python application
└── README.md                      # 📖 This file
```

---

## 2. Concept of Operations

### 2.1 Typical Usage Scenarios

**Scenario 1: Web Application with Database**
```
Application → SecretsManager → DB password from /run/secrets/db_password
```

**Scenario 2: API Service with External Integrations**
```
API Service → SecretsManager → API keys from /run/secrets/
                                      ├── stripe_secret_key
                                      ├── openai_api_key
                                      └── slack_webhook_url
```

**Scenario 3: CI/CD Pipeline**
```
Pipeline → SecretsManager → Deployment keys
```

### 2.2 User Roles

- **System Administrator:** System installation and configuration
- **Application Developer:** Integrating secrets into code
- **DevOps Engineer:** Deployment automation and monitoring
- **Security Operator:** Access control and audit management

---

## 3. Installation and Configuration

### 3.1 System Requirements

**Minimum Requirements:**
- Linux with systemd (Ubuntu 18.04+, RHEL 7+)
- GPG 2.2+
- 100 MB free space
- Root access for installation

**Recommended:**
- Ubuntu 20.04+ or RHEL 8+
- 1 GB RAM
- SSD storage

### 3.2 Quick Installation (5 minutes)

#### Prerequisites
- Root access to system
- Internet for package downloads
- GPG not installed (will be installed)

#### Installation Procedure

**Step 1: Install dependencies**
```bash
sudo apt update && sudo apt install -y gnupg systemd
```

**Step 2: Create GPG key**
```bash
gpg --full-generate-key
# Choose:
# - Key type: RSA
# - Size: 4096 bits
# - Identifier: secrets@host
# - No password for automatic operation
```

**Step 3: Deploy system**
```bash
# Copy scripts
sudo cp scripts/decrypt-secrets.sh /usr/local/bin/
sudo cp systemd-units/secrets-decrypt.service /etc/systemd/system/
sudo chmod +x /usr/local/bin/decrypt-secrets.sh

# Create directories
sudo mkdir -p /etc/secrets.encrypted
sudo chmod 700 /etc/secrets.encrypted
```

**Step 4: Create test secret**
```bash
echo "testpassword" | gpg --encrypt --recipient secrets@host > /etc/secrets.encrypted/test.gpg
```

**Step 5: Start system**
```bash
sudo systemctl daemon-reload
sudo systemctl enable secrets-decrypt.service
sudo systemctl start secrets-decrypt.service
```

#### Postconditions
- `secrets-decrypt.service` is running and active
- Secrets decrypted in `/run/secrets/`
- Test secret available `/run/secrets/test`

#### Installation Verification
```bash
# Check service status
sudo systemctl status secrets-decrypt.service

# Check secrets
ls -la /run/secrets/
cat /run/secrets/test
```

---

## 4. Usage Procedures

### 4.1 Adding Secrets

**Purpose:** Add new secret to system

**Prerequisites:**
- System installed and running
- GPG key available
- Root permissions

**Steps:**
1. Create secret in file:
   ```bash
   echo "my_secret_value" > /tmp/secret.txt
   ```

2. Encrypt secret:
   ```bash
   gpg --encrypt --recipient secrets@host /tmp/secret.txt
   ```

3. Move to storage:
   ```bash
   sudo mv /tmp/secret.txt.gpg /etc/secrets.encrypted/my_secret.gpg
   ```

4. Restart service:
   ```bash
   sudo systemctl restart secrets-decrypt.service
   ```

**Result:** Secret available at `/run/secrets/my_secret`

### 4.2 Application Integration

#### Systemd Services
```ini
[Service]
LoadCredential=db_password:/run/secrets/db_password
LoadCredential=api_key:/run/secrets/api_key
Environment=CREDENTIALS_DIR=/run/credentials/%n
ExecStart=/usr/bin/myapp
```

#### Python Applications
```python
import os

credentials_dir = os.environ['CREDENTIALS_DIR']
with open(f'{credentials_dir}/db_password', 'r') as f:
    password = f.read().strip()
```

---

## 5. Troubleshooting

### 5.1 Common Issues

#### Service not starting
**Symptoms:**
```
secrets-decrypt.service: Failed with result 'exit-code'
```

**Solution:**
```bash
# Check logs
sudo journalctl -u secrets-decrypt.service -n 20

# Possible causes:
# - GPG key missing
# - Corrupted .gpg files
# - Insufficient permissions
```

#### Secrets not decrypting
**Symptoms:**
```bash
ls /run/secrets/  # empty directory
```

**Solution:**
```bash
# Check GPG keys
gpg --list-keys secrets@host

# Check encrypted files
ls -la /etc/secrets.encrypted/

# Manual decryption test
gpg --decrypt /etc/secrets.encrypted/test.gpg
```

#### Application cannot read secrets
**Symptoms:**
```
Permission denied: /run/credentials/service/secret
FileNotFoundError: /run/credentials/service/secret
```

**Solution:**
```bash
# Check systemd configuration
sudo systemctl cat your-service.service

# Check secret file permissions
ls -la /run/secrets/
```

---

## 6. System Removal

### 6.1 Removal Conditions

Removal is required when:
- Migrating to another secret management system
- Decommissioning server
- Changing security requirements
- Upgrading to new version

### 6.2 Removal Procedure

**⚠️ Warning:** Operation is irreversible! Create backup of secrets first.

**Steps:**
1. **Create backup** (recommended):
   ```bash
   sudo tar -czf secrets-backup-$(date +%Y%m%d).tar.gz /etc/secrets.encrypted/
   gpg --encrypt --recipient your-email@example.com secrets-backup-*.tar.gz
   ```

2. **Stop all dependent services:**
   ```bash
   sudo systemctl stop secrets-decrypt.service
   sudo systemctl stop your-app.service  # all services using secrets
   ```

3. **Remove system components:**
   ```bash
   # Remove scripts
   sudo rm /usr/local/bin/decrypt-secrets.sh

   # Remove systemd unit
   sudo rm /etc/systemd/system/secrets-decrypt.service
   sudo systemctl daemon-reload

   # Remove secrets
   sudo rm -rf /etc/secrets.encrypted/
   sudo rm -rf /run/secrets/
   ```

4. **Clean GPG keys** (optional):
   ```bash
   gpg --delete-secret-key secrets@host
   gpg --delete-key secrets@host
   ```

5. **Reboot system** to clear RAM:
   ```bash
   sudo reboot
   ```

---

## 7. Appendices

### 7.1 Glossary

| Term | Definition |
|------|------------|
| **Secret** | Confidential information (password, API key, token) |
| **GPG** | GNU Privacy Guard - public key encryption system |
| **tmpfs** | Virtual filesystem in RAM |
| **systemd credentials** | Mechanism for securely delivering secrets to services |
| **DynamicUser** | Automatic creation of isolated systemd users |
| **POSIX ACL** | Portable Operating System Interface access control system |

### 7.2 Abbreviations

| Abbreviation | Full Form |
|--------------|-----------|
| ACL | Access Control List |
| API | Application Programming Interface |
| CPU | Central Processing Unit |
| GPG | GNU Privacy Guard |
| HTTP | HyperText Transfer Protocol |
| RAM | Random Access Memory |
| UUID | Universally Unique Identifier |

### 7.3 Index

- **Installation:** [3. Installation and Configuration](#3-installation-and-configuration)
- **Usage:** [4. Usage Procedures](#4-usage-procedures)
- **Troubleshooting:** [5. Troubleshooting](#5-troubleshooting)
- **Security:** [2.3 Architecture](#13-architecture)
- **Docker:** [Examples](#examples)
- **Secret Rotation:** [4.1 Adding Secrets](#41-adding-secrets)

---

## Documentation

- **📖 Complete Administrator Guide:** `docs/unix-secrets-manager-guide.md`
- **⚙️ Scripts Documentation:** `scripts/README.md`
- **🚀 Telegram Bot Example:** `examples/telegram-bot/README.md`

## Usage Examples

- **🐳 Docker Containers:** `examples/telegram-bot/`
  - Telegram bot with 50+ secrets
  - Full Docker Compose integration
  - Health checks and monitoring

- **🔧 Systemd Services:** `systemd-units/`
  - Example systemd configurations
  - LoadCredential integration

## License

This project is distributed under the MIT License and may be freely used for commercial and non-commercial purposes.

---

*Unix Secrets Manager v1.0.0 - Enterprise-grade secret management on Linux* 🎉
