#!/bin/bash
# Скрипт для ротации секретов
# Использование: ./rotate-secret.sh <secret_name> <new_value>
# Для Docker см. examples/telegram-bot/docker-deploy.sh rotate

set -e

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <secret_name> <new_value>"
    echo "Example: $0 db_password 'newpassword123'"
    exit 1
fi

SECRET_NAME="$1"
NEW_VALUE="$2"
ENCRYPTED_DIR="/etc/secrets.encrypted"
TEMP_FILE=$(mktemp)

# Сохраняем новое значение во временный файл
echo -n "$NEW_VALUE" > "$TEMP_FILE"

# Шифруем новое значение
gpg --batch --yes --encrypt --recipient secrets@host "$TEMP_FILE"

# Перемещаем зашифрованный файл на место
mv "${TEMP_FILE}.gpg" "$ENCRYPTED_DIR/${SECRET_NAME}.gpg"

# Удаляем временный файл
rm -f "$TEMP_FILE"

# Перезапускаем сервис дешифрации
systemctl restart secrets-decrypt.service

# Перезапускаем все сервисы, которые используют этот секрет
# В реальной системе здесь будет логика для поиска зависимых сервисов
systemctl restart example-app.service

echo "Secret $SECRET_NAME rotated successfully"
logger -t secrets-manager "Secret $SECRET_NAME rotated"
