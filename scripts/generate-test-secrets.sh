#!/bin/bash
# Скрипт для генерации тестовых зашифрованных секретов
# Требует установки GPG и создания ключа secrets@host

set -e

ENCRYPTED_DIR="/Volumes/External/unixSecrets/secrets.encrypted"
SAMPLES_DIR="/Volumes/External/unixSecrets/samples"

# Создаем директории
mkdir -p "$ENCRYPTED_DIR" "$SAMPLES_DIR"

# Генерируем тестовые секреты
echo "supersecretpassword123" > "$SAMPLES_DIR/db_password"
echo "jwt-signing-key-abcdef123456" > "$SAMPLES_DIR/jwt_signing_key"
echo "api-key-for-service-x-xyz789" > "$SAMPLES_DIR/api_key_service_x"

# Шифруем секреты (предполагаем, что ключ secrets@host существует)
# В реальности: gpg --encrypt --recipient secrets@host "$SAMPLES_DIR/db_password"
# Для демонстрации создаем плейсхолдеры
echo "# В реальной системе здесь будут зашифрованные файлы .gpg" > "$ENCRYPTED_DIR/README"
echo "# Секреты шифруются командой: gpg --encrypt --recipient secrets@host <plaintext_file>" >> "$ENCRYPTED_DIR/README"

echo "Test secrets generated in $SAMPLES_DIR"
echo "To encrypt: gpg --encrypt --recipient secrets@host $SAMPLES_DIR/db_password"
