#!/bin/sh
# Скрипт дешифрации секретов для Docker контейнера
# Работает аналогично systemd сервису, но в Docker среде

set -e

# Директории
ENCRYPTED_DIR="/etc/secrets.encrypted"
SECRETS_DIR="/run/secrets"
GPG_RECIPIENT="${GPG_RECIPIENT:-secrets@host}"

# Проверка зависимостей
if ! command -v gpg >/dev/null 2>&1; then
    echo "Error: GPG not found"
    exit 1
fi

# Создание директории для секретов (tmpfs volume)
mkdir -p "$SECRETS_DIR"

# Проверка GPG ключа
if ! gpg --list-keys "$GPG_RECIPIENT" >/dev/null 2>&1; then
    echo "Warning: GPG key '$GPG_RECIPIENT' not found"
    echo "Make sure the key is available in the container"
    # В Docker мы можем принимать, что ключ будет смонтирован
fi

echo "Starting secrets decryption for Docker..."

# Дешифрация каждого секрета
if [ -d "$ENCRYPTED_DIR" ]; then
    for encrypted_file in "$ENCRYPTED_DIR"/*.gpg; do
        if [ -f "$encrypted_file" ]; then
            secret_name=$(basename "$encrypted_file" .gpg)
            secret_path="$SECRETS_DIR/$secret_name"

            echo "Decrypting $secret_name..."

            # Дешифрация с автоматическим подтверждением
            if gpg --batch --yes --decrypt "$encrypted_file" > "$secret_path" 2>/dev/null; then
                # Установка правильных прав
                chmod 0400 "$secret_path"
                echo "✓ Secret $secret_name decrypted successfully"
            else
                echo "✗ Failed to decrypt $secret_name"
                # Не прерываем выполнение, продолжаем с другими секретами
            fi
        fi
    done
else
    echo "Warning: Encrypted secrets directory $ENCRYPTED_DIR not found"
fi

# Проверка что хотя бы один секрет расшифрован
if [ -z "$(ls -A "$SECRETS_DIR" 2>/dev/null)" ]; then
    echo "Error: No secrets were decrypted"
    exit 1
fi

echo "Secrets decryption completed. Monitoring for changes..."

# Мониторинг изменений (опционально)
# В продакшене можно добавить inotify для автоматической ротации
while true; do
    sleep 300  # Проверка каждые 5 минут

    # Здесь можно добавить логику проверки изменений в секретах
    # и их повторной дешифрации при необходимости
done
