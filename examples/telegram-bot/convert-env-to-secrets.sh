#!/bin/bash
# Скрипт для конвертации .env файла в зашифрованные секреты Unix Secrets Manager
# Использование: ./convert-env-to-secrets.sh <env_file> [gpg_recipient]

set -e

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <env_file> [gpg_recipient]"
    echo "Example: $0 .env secrets@host"
    exit 1
fi

ENV_FILE="$1"
GPG_RECIPIENT="${2:-secrets@host}"
ENCRYPTED_DIR="/etc/secrets.encrypted"

# Проверить существование .env файла
if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: $ENV_FILE not found"
    exit 1
fi

# Проверить GPG ключ
if ! gpg --list-keys "$GPG_RECIPIENT" > /dev/null 2>&1; then
    echo "Error: GPG key '$GPG_RECIPIENT' not found"
    echo "Create it with: gpg --full-generate-key"
    exit 1
fi

# Создать директорию для секретов если не существует
sudo mkdir -p "$ENCRYPTED_DIR"
sudo chmod 700 "$ENCRYPTED_DIR"

echo "Converting $ENV_FILE to encrypted secrets..."

# Прочитать .env файл и обработать каждую строку
while IFS='=' read -r key value || [[ -n "$key" ]]; do
    # Пропустить комментарии и пустые строки
    [[ $key =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue

    # Убрать пробелы вокруг ключа
    key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Пропустить если ключ пустой или содержит пробелы
    [[ -z "$key" ]] && continue

    # Создать временный файл с секретом
    temp_file=$(mktemp)
    echo -n "$value" > "$temp_file"

    # Зашифровать секрет
    secret_name=$(echo "$key" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
    encrypted_file="$ENCRYPTED_DIR/${secret_name}.gpg"

    echo "Encrypting $key -> $secret_name.gpg"
    gpg --batch --yes --encrypt --recipient "$GPG_RECIPIENT" \
        --output "$encrypted_file" "$temp_file"

    # Установить правильные права
    sudo chmod 600 "$encrypted_file"

    # Безопасно удалить временный файл
    shred -u "$temp_file"

done < "$ENV_FILE"

echo "Conversion completed!"
echo "Encrypted secrets saved to $ENCRYPTED_DIR"
echo ""
echo "To use in systemd service, add to your .service file:"
echo "LoadCredential=telegram-bot-token:/run/secrets/telegram-bot-token"
echo "LoadCredential=database-password:/run/secrets/database-password"
echo "# ... and so on for each secret"
echo ""
echo "Restart secrets service:"
echo "sudo systemctl restart secrets-decrypt.service"
