#!/bin/bash
# Скрипт установки Telegram бота с Unix Secrets Manager

set -e

echo "=== Установка Telegram бота с Unix Secrets Manager ==="

# Проверка зависимостей
echo "Проверка зависимостей..."
if ! command -v python3 &> /dev/null; then
    echo "Python3 не установлен. Установите его:"
    echo "sudo apt update && sudo apt install -y python3 python3-pip"
    exit 1
fi

if ! command -v gpg &> /dev/null; then
    echo "GPG не установлен. Установите его:"
    echo "sudo apt update && sudo apt install -y gnupg"
    exit 1
fi

# Создание директорий
echo "Создание директорий..."
sudo mkdir -p /opt/telegram-bot
sudo mkdir -p /etc/secrets.encrypted
sudo mkdir -p /var/log/telegram-bot
sudo chown -R root:root /etc/secrets.encrypted
sudo chmod 700 /etc/secrets.encrypted

# Установка Python зависимостей
echo "Установка Python зависимостей..."
pip3 install python-telegram-bot sentry-sdk

# Копирование файлов
echo "Копирование файлов..."
sudo cp telegram_bot.py /opt/telegram-bot/
sudo cp telegram-bot.service /etc/systemd/system/
sudo cp convert-env-to-secrets.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/convert-env-to-secrets.sh

# Настройка GPG ключа
echo "Проверка GPG ключа..."
if ! gpg --list-keys secrets@host &> /dev/null; then
    echo "GPG ключ 'secrets@host' не найден!"
    echo "Создайте его командой:"
    echo "gpg --full-generate-key"
    echo "Используйте идентификатор: secrets@host"
    echo ""
    echo "Или укажите существующего получателя в скрипте convert-env-to-secrets.sh"
    exit 1
fi

echo ""
echo "=== Шаг 1: Подготовка .env файла ==="
echo "Создайте файл .env с вашими секретами на основе env-example.txt"
echo "Пример:"
echo "cp env-example.txt .env"
echo "nano .env  # отредактируйте реальные значения"
echo ""

echo "=== Шаг 2: Конвертация секретов ==="
echo "Запустите конвертацию:"
echo "sudo ./convert-env-to-secrets.sh .env secrets@host"
echo ""

echo "=== Шаг 3: Запуск сервисов ==="
echo "sudo systemctl daemon-reload"
echo "sudo systemctl enable secrets-decrypt.service"
echo "sudo systemctl start secrets-decrypt.service"
echo "sudo systemctl enable telegram-bot.service"
echo "sudo systemctl start telegram-bot.service"
echo ""

echo "=== Шаг 4: Проверка ==="
echo "sudo systemctl status telegram-bot.service"
echo "sudo journalctl -u telegram-bot.service -f"
echo ""

echo "=== Команды управления ==="
echo "Просмотр логов: sudo journalctl -u telegram-bot.service -n 50"
echo "Перезапуск: sudo systemctl restart telegram-bot.service"
echo "Остановка: sudo systemctl stop telegram-bot.service"
echo ""

echo "=== Ротация секретов ==="
echo "sudo ./scripts/rotate-secret.sh telegram-bot-token 'new_token_here'"
echo ""

echo "Установка завершена! 🎉"
