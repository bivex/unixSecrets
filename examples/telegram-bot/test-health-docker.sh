#!/bin/bash
# Скрипт для тестирования health checks в Docker контейнерах

set -e

echo "🚀 Тестирование production health checks в Docker"
echo "================================================="

# Проверка Docker
if ! docker --version >/dev/null 2>&1; then
    echo "❌ Docker не установлен"
    exit 1
fi

# Проверка Docker daemon
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker daemon не запущен"
    echo "Запустите Docker Desktop или выполните: sudo systemctl start docker"
    exit 1
fi

echo "✅ Docker доступен"

# Очистка предыдущих контейнеров
echo "🧹 Очистка предыдущих контейнеров..."
docker-compose -f docker-compose.test.yml down -v 2>/dev/null || true

# Запуск контейнеров
echo "🏗️ Сборка и запуск контейнеров..."
docker-compose -f docker-compose.test.yml up -d --build

# Ожидание запуска
echo "⏳ Ожидание запуска сервисов..."
sleep 10

# Проверка статуса
echo "📊 Статус контейнеров:"
docker-compose -f docker-compose.test.yml ps

# Тестирование health checks
echo ""
echo "🏥 Тестирование health check эндпоинтов:"
echo ""

# Базовый health check
echo "1. Базовый health check (/health):"
curl -s http://localhost:8080/health | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(f'   Status: {data.get(\"status\", \"unknown\")}')
    print(f'   Version: {data.get(\"version\", \"unknown\")}')
    print(f'   Timestamp: {data.get(\"timestamp\", \"unknown\")[:19]}')
except:
    print('   ❌ Не удалось распарсить ответ')
" 2>/dev/null || echo "   ❌ Сервис недоступен"

echo ""

# Детальный health check
echo "2. Детальный health check (/health/detailed):"
curl -s http://localhost:8080/health/detailed | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(f'   Overall Status: {data.get(\"status\", \"unknown\")}')
    print(f'   Uptime: {data.get(\"uptime\", \"unknown\")}')
    
    secrets = data.get('secrets', {})
    print(f'   Secrets Status: {secrets.get(\"status\", \"unknown\")}')
    print(f'   Secrets Count: {secrets.get(\"loaded_count\", \"unknown\")}')
    
    components = data.get('components', {})
    for comp_name, comp_data in components.items():
        print(f'   {comp_name}: {comp_data.get(\"status\", \"unknown\")}')
        
    deps = data.get('dependencies', {})
    available_deps = [k for k, v in deps.items() if v == 'available']
    missing_deps = [k for k, v in deps.items() if v == 'missing']
    print(f'   Available deps: {len(available_deps)}')
    print(f'   Missing deps: {len(missing_deps)}')
    
except Exception as e:
    print(f'   ❌ Ошибка: {e}')
" 2>/dev/null || echo "   ❌ Детальный health check недоступен"

echo ""

# Просмотр логов
echo "📋 Последние логи контейнера:"
docker-compose -f docker-compose.test.yml logs --tail=10 telegram-bot-test 2>/dev/null || echo "Логи недоступны"

echo ""
echo "🧹 Очистка после тестирования..."
docker-compose -f docker-compose.test.yml down -v 2>/dev/null || true

echo ""
echo "✅ Тестирование завершено!"
