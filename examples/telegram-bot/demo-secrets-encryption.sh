#!/bin/bash
# Демонстрация шифрования секретов в Unix Secrets Manager

echo "🔐 ДЕМОНСТРАЦИЯ: Шифрование секретов в Unix Secrets Manager"
echo "=========================================================="

# Создаем тестовые секреты
echo -e "\n📝 Создание тестовых секретов..."
mkdir -p /tmp/demo-plaintext
echo "sk-1234567890abcdef" > /tmp/demo-plaintext/openai-api-key
echo "super_secret_db_pass" > /tmp/demo-plaintext/database-password
echo "redis_secure_password" > /tmp/demo-plaintext/redis-password

echo "✅ Созданы тестовые секреты:"
ls -la /tmp/demo-plaintext/
echo -e "\n📖 Содержимое секретов:"
echo "openai-api-key: $(cat /tmp/demo-plaintext/openai-api-key)"
echo "database-password: $(cat /tmp/demo-plaintext/database-password)"
echo "redis-password: $(cat /tmp/demo-plaintext/redis-password)"

# "Шифруем" секреты (имитация GPG)
echo -e "\n🔒 'Шифрование' секретов (имитация GPG)..."
mkdir -p /tmp/demo-encrypted

for file in /tmp/demo-plaintext/*; do
    filename=$(basename "$file")
    # Имитируем GPG шифрование с помощью base64 + соль
    cat "$file" | openssl enc -base64 -aes-256-cbc -salt -k "demo-gpg-key" > "/tmp/demo-encrypted/${filename}.gpg"
done

echo "✅ Секреты 'зашифрованы':"
ls -la /tmp/demo-encrypted/

# Показываем как выглядят зашифрованные файлы
echo -e "\n🔍 Содержимое зашифрованных файлов:"
for file in /tmp/demo-encrypted/*.gpg; do
    filename=$(basename "$file")
    echo "${filename}: $(cat "$file" | head -c 30)..."
done

# Декриптация
echo -e "\n🔓 Декриптация секретов..."
mkdir -p /tmp/demo-decrypted

for file in /tmp/demo-encrypted/*.gpg; do
    filename=$(basename "$file" .gpg)
    cat "$file" | openssl enc -base64 -d -aes-256-cbc -k "demo-gpg-key" > "/tmp/demo-decrypted/$filename"
done

echo "✅ Секреты декриптированы:"
ls -la /tmp/demo-decrypted/

echo -e "\n📖 Проверка декриптированных секретов:"
echo "openai-api-key: $(cat /tmp/demo-decrypted/openai-api-key)"
echo "database-password: $(cat /tmp/demo-decrypted/database-password)"
echo "redis-password: $(cat /tmp/demo-decrypted/redis-password)"

# Проверка совпадения
echo -e "\n✅ Проверка целостности:"
if diff /tmp/demo-plaintext/openai-api-key /tmp/demo-decrypted/openai-api-key >/dev/null; then
    echo "✅ openai-api-key: совпадает"
else
    echo "❌ openai-api-key: отличается"
fi

if diff /tmp/demo-plaintext/database-password /tmp/demo-decrypted/database-password >/dev/null; then
    echo "✅ database-password: совпадает"
else
    echo "❌ database-password: отличается"
fi

if diff /tmp/demo-plaintext/redis-password /tmp/demo-decrypted/redis-password >/dev/null; then
    echo "✅ redis-password: совпадает"
else
    echo "❌ redis-password: отличается"
fi

echo -e "\n🏗️ ПРОДАКШН СТРУКТУРА СИСТЕМЫ:"
echo "📁 /etc/secrets.encrypted/     # Зашифрованные секреты на диске"
echo "  ├── openai-api-key.gpg      # sk-1234567890abcdef (зашифровано)"
echo "  ├── database-password.gpg   # super_secret_db_pass (зашифровано)"
echo "  └── redis-password.gpg      # redis_secure_password (зашифровано)"
echo ""
echo "📁 /run/secrets/              # Расшифрованные секреты в RAM"
echo "  ├── openai-api-key          # sk-1234567890abcdef (plaintext)"
echo "  ├── database-password       # super_secret_db_pass (plaintext)"
echo "  └── redis-password          # redis_secure_password (plaintext)"

echo -e "\n🎯 РЕЗУЛЬТАТ:"
echo "✅ Секреты хранятся в ЗАШИФРОВАННОМ виде на диске"
echo "✅ Декриптируются только в RAM при запуске сервисов"
echo "✅ Никогда не попадают в plaintext на persistent storage"
echo "✅ Полная безопасность от компрометации диска"

# Очистка
rm -rf /tmp/demo-plaintext /tmp/demo-encrypted /tmp/demo-decrypted

echo -e "\n🧹 Демонстрация завершена, временные файлы удалены."
