# Документация скриптов Unix Secrets Manager

**Версия:** 1.0.0
**Дата:** Декабрь 2025
**Статус:** Production Ready

---

## Обзор

Этот документ описывает вспомогательные скрипты для управления системой Unix Secrets Manager.

**Назначение скриптов:**
- Автоматизация рутинных операций
- Обеспечение безопасности операций
- Упрощение администрирования системы

### Совместимость

| Скрипт | Linux | macOS | Docker | Требует root |
|--------|-------|-------|--------|--------------|
| `decrypt-secrets.sh` | ✅ | ❌ | ⚠️ (адаптация) | ✅ |
| `generate-test-secrets.sh` | ✅ | ✅ | ✅ | ❌ |
| `rotate-secret.sh` | ✅ | ❌ | ⚠️ (адаптация) | ✅ |

### Системные требования

- **Bash** 4.0+
- **GPG** 2.2+ (для шифрования)
- **systemd** (для сервисов)
- **OpenSSL** (альтернатива GPG)

## Скрипты

### decrypt-secrets.sh

**Назначение:** Дешифрация секретов в tmpfs для systemd сервисов

**Использование:**
```bash
# Автоматически запускается systemd
sudo systemctl start secrets-decrypt.service

# Ручной запуск (для отладки)
sudo /usr/local/bin/decrypt-secrets.sh
```

**Что делает:**
- Создает tmpfs в `/run/secrets`
- Дешифрует все `.gpg` файлы из `/etc/secrets.encrypted`
- Устанавливает правильные права доступа
- Работает только с root правами

**Требования:**
- GPG ключ должен быть доступен
- Директория `/etc/secrets.encrypted` должна существовать
- Systemd должен быть запущен

### generate-test-secrets.sh

**Назначение:** Генерация тестовых секретов для разработки

**Использование:**
```bash
./generate-test-secrets.sh
```

**Что делает:**
- Создает тестовые файлы секретов в `samples/`
- Создает зашифрованные версии в `secrets.encrypted/`
- Генерирует примеры для всех типов секретов

**Безопасность:** Только для разработки! Не использовать в production.

### rotate-secret.sh

**Назначение:** Ротация секретов без downtime

**Использование:**
```bash
./rotate-secret.sh <secret_name> "<new_value>"
```

**Примеры:**
```bash
./rotate-secret.sh db_password "new_secure_password_123"
./rotate-secret.sh api_key "sk-new-api-key-here"
```

**Что делает:**
- Шифрует новое значение секрета
- Атомарно заменяет файл в `/etc/secrets.encrypted`
- Перезапускает сервис дешифрации
- Перезапускает зависимые сервисы

**Особенности:**
- Атомарная операция (без промежуточных состояний)
- Автоматический перезапуск сервисов
- Логирование в syslog

## Установка

```bash
# Копирование скриптов
sudo cp scripts/*.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/*.sh

# Настройка systemd
sudo cp systemd-units/secrets-decrypt.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable secrets-decrypt.service
```

## Мониторинг

### Логи systemd
```bash
# Логи сервиса дешифрации
sudo journalctl -u secrets-decrypt.service -f

# Логи ротации секретов
sudo journalctl -t secrets-manager -f
```

### Проверка состояния
```bash
# Статус сервиса
sudo systemctl status secrets-decrypt.service

# Проверка секретов
ls -la /run/secrets/
```

## Troubleshooting

### Сервис не запускается
```bash
# Проверить статус
sudo systemctl status secrets-decrypt.service

# Посмотреть логи
sudo journalctl -u secrets-decrypt.service -n 50

# Возможные проблемы:
# - Отсутствует GPG ключ
# - Неправильные права на /etc/secrets.encrypted
# - Поврежденные .gpg файлы
```

### Секреты не дешифруются
```bash
# Проверить GPG
gpg --list-keys secrets@host

# Проверить файлы
ls -la /etc/secrets.encrypted/

# Ручная дешифрация для теста
gpg --decrypt /etc/secrets.encrypted/test.gpg
```

### Ротация не работает
```bash
# Проверить аргументы
./rotate-secret.sh db_password "new_password"

# Проверить логи
sudo journalctl -t secrets-manager -n 20

# Возможные проблемы:
# - Отсутствует GPG ключ
# - Неправильные права на файлы
# - Сервис не может перезапуститься
```

## Безопасность

- Все скрипты проверяют наличие root прав
- Секреты никогда не логируются
- Временные файлы безопасно удаляются
- Аудит всех операций через syslog

## Production использование

### Автоматизация
```bash
# Cron для автоматической ротации (пример)
0 2 * * 1 /usr/local/bin/rotate-secret.sh api_key "$(generate-new-key)"
```

### Мониторинг
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
# Резервное копирование секретов
tar -czf secrets-backup-$(date +%Y%m%d).tar.gz /etc/secrets.encrypted/
```

## Docker интеграция

Для Docker окружений используйте модифицированные версии скриптов из `examples/telegram-bot/`:
- `decrypt-secrets-docker.sh` - версия для контейнеров
- `docker-deploy.sh` - управление Docker stack

## Contributing

При добавлении новых скриптов:
1. Добавьте shebang `#!/bin/bash`
2. Используйте `set -e` для fail-fast
3. Добавьте документацию в этот файл
4. Протестируйте с различными сценариями
5. Добавьте проверки безопасности
