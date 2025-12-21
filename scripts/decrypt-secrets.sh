#!/bin/bash
# Скрипт для дешифрации секретов в tmpfs
# Используется в systemd юните secrets-decrypt.service
# Для Docker версии см. examples/telegram-bot/decrypt-secrets-docker.sh

set -e

# Директории
ENCRYPTED_DIR="/etc/secrets.encrypted"
SECRETS_DIR="/run/secrets"

# Создаем tmpfs для секретов (только в RAM)
mount -t tmpfs -o size=10M,mode=0700 tmpfs "$SECRETS_DIR"

# Дешифруем каждый секрет
for encrypted_file in "$ENCRYPTED_DIR"/*.gpg; do
    if [[ -f "$encrypted_file" ]]; then
        secret_name=$(basename "$encrypted_file" .gpg)
        secret_path="$SECRETS_DIR/$secret_name"

        # Дешифруем и сохраняем в RAM
        gpg --batch --yes --decrypt "$encrypted_file" > "$secret_path"

        # Устанавливаем права только для чтения
        chmod 0400 "$secret_path"

        echo "Secret $secret_name decrypted to $secret_path"
    fi
done

echo "All secrets decrypted successfully"
