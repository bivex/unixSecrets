# 🐳 Тестирование Health Checks в Docker

## Быстрый старт

```bash
# 1. Запустите Docker Desktop (или daemon)
# На macOS/Linux: Docker Desktop приложение
# На Linux: sudo systemctl start docker

# 2. Запустите тестирование
./test-health-docker.sh

# 3. Ожидайте результатов
```

## Ручное тестирование

### Шаг 1: Запуск контейнеров
```bash
cd examples/telegram-bot

# Очистка предыдущих
docker-compose -f docker-compose.test.yml down -v

# Сборка и запуск
docker-compose -f docker-compose.test.yml up -d --build

# Проверка статуса
docker-compose -f docker-compose.test.yml ps
```

### Шаг 2: Тестирование Health Checks

#### Базовый Health Check
```bash
curl -s http://localhost:8080/health | jq .
```

Ожидаемый ответ:
```json
{
  "status": "healthy",
  "timestamp": "2025-12-21T18:57:49.123456",
  "version": "1.0.0"
}
```

#### Детальный Health Check
```bash
curl -s http://localhost:8080/health/detailed | jq .
```

Ожидаемый ответ:
```json
{
  "status": "healthy",
  "timestamp": "2025-12-21T18:57:49.123456",
  "version": "1.0.0",
  "uptime": 123.45,
  "components": {
    "telegram_bot": {"status": "healthy"}
  },
  "secrets": {
    "status": "healthy",
    "loaded_count": 41,
    "critical_secrets": {
      "telegram-bot-token": "present",
      "health-check-token": "present"
    }
  },
  "system": {
    "cpu_percent": 15.2,
    "memory": {
      "total": 8589934592,
      "available": 4294967296,
      "percent": 50.0
    },
    "disk": {
      "total": 100000000000,
      "free": 50000000000,
      "percent": 50.0
    }
  },
  "performance": {
    "cpu_times": {"user": 1.23, "system": 0.45},
    "memory_info": {"rss": 12345678, "vms": 23456789},
    "num_threads": 4,
    "num_fds": 10
  },
  "dependencies": {
    "python-telegram-bot": "missing",
    "fastapi": "available",
    "psutil": "missing"
  }
}
```

### Шаг 3: Проверка логов

```bash
# Логи контейнера
docker-compose -f docker-compose.test.yml logs -f telegram-bot-test

# Логи секретов
docker-compose -f docker-compose.test.yml logs secrets-decrypt-test
```

### Шаг 4: Очистка

```bash
# Остановка и очистка
docker-compose -f docker-compose.test.yml down -v

# Удаление образов (опционально)
docker image rm telegram-bot-telegram-bot-test secrets-decrypt-test
```

## Диагностика проблем

### Контейнер не запускается
```bash
# Подробные логи сборки
docker-compose -f docker-compose.test.yml build --no-cache

# Проверка образа
docker run --rm telegram-bot-telegram-bot-test python --version
```

### Health check возвращает ошибку
```bash
# Проверка доступности порта
netstat -tlnp | grep :8080

# Тест изнутри контейнера
docker exec telegram-bot-test curl http://localhost:8080/health

# Проверка переменных окружения
docker exec telegram-bot-test env | grep -E "(ENVIRONMENT|SECRETS_DIR)"
```

### Секреты не загружаются
```bash
# Проверка volume монтирования
docker exec telegram-bot-test ls -la /app/secrets/

# Проверка секретов в контейнере
docker exec telegram-bot-test cat /app/secrets/telegram-bot-token 2>/dev/null || echo "Secret not found"

# Логи SecretsManager
docker-compose -f docker-compose.test.yml logs telegram-bot-test | grep -i secret
```

## Ожидаемые результаты тестирования

### ✅ Успешный тест
- **Status**: `healthy`
- **Secrets**: `healthy` или `degraded`
- **Components**: Все компоненты `healthy`
- **Dependencies**: FastAPI `available`
- **System metrics**: Доступны (если psutil установлен)

### ⚠️ Частично успешный тест
- **Status**: `healthy` (работает с дефолтными значениями)
- **Secrets**: `degraded` (критические секреты отсутствуют)
- **Dependencies**: Некоторые `missing` (graceful fallback работает)

### ❌ Неудачный тест
- Контейнер не запускается
- Порт 8080 недоступен
- Health check возвращает `unhealthy` или ошибки

## Производительность

- **Время сборки**: ~2-3 минуты
- **Время запуска**: ~10-15 секунд
- **Память**: ~200-300 MB на контейнер
- **CPU**: Минимальная нагрузка

## Безопасность

- Контейнеры запускаются без root прав
- Secrets монтируются read-only
- Нет exposed портов наружу (кроме 8080 для health checks)
- Минимальный attack surface
