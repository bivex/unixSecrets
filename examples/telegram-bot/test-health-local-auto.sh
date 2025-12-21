#!/bin/bash
# Автоматизированное тестирование health checks локально

set -e

echo "🏠 Локальное тестирование production health checks"
echo "================================================="

# Проверка Python
if ! python3 --version >/dev/null 2>&1; then
    echo "❌ Python3 не найден"
    exit 1
fi

echo "✅ Python3 доступен"

# Проверка зависимостей
echo "📦 Проверка зависимостей..."
python3 -c "
import sys
sys.path.insert(0, '/Volumes/External/unixSecrets/examples/telegram-bot')

try:
    from telegram_bot import FASTAPI_AVAILABLE, PSUTIL_AVAILABLE
    print(f'   FastAPI: {\"✅\" if FASTAPI_AVAILABLE else \"❌\"}')
    print(f'   psutil: {\"✅\" if PSUTIL_AVAILABLE else \"❌\"}')
    
    if not FASTAPI_AVAILABLE:
        print('❌ FastAPI не установлен')
        print('   Установите: pip install fastapi uvicorn')
        sys.exit(1)
        
except ImportError as e:
    print(f'❌ Ошибка импорта: {e}')
    sys.exit(1)
"

echo ""

# Запуск сервера в фоне
echo "🚀 Запуск FastAPI сервера..."
python3 test-health-local.py &
SERVER_PID=$!

# Ожидание запуска
echo "⏳ Ожидание запуска сервера..."
sleep 5

# Функция для тестирования
test_endpoint() {
    local endpoint=$1
    local description=$2
    
    echo "🔍 Тестирование $description ($endpoint):"
    
    if curl -s --max-time 5 http://localhost:8080$endpoint >/dev/null 2>&1; then
        response=$(curl -s http://localhost:8080$endpoint 2>/dev/null)

        if echo "$response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    status = data.get('status', 'unknown')
    print(f'   ✅ Status: {status}')

    if 'timestamp' in data:
        timestamp = data['timestamp'][:19] if len(data['timestamp']) > 19 else data['timestamp']
        print(f'   📅 Timestamp: {timestamp}')

    if 'version' in data:
        print(f'   🏷️  Version: {data[\"version\"]}')

    if 'hostname' in data:
        print(f'   🖥️  Hostname: {data[\"hostname\"]}')

    if 'python_version' in data:
        print(f'   🐍 Python: {data[\"python_version\"]}')

    if 'process_id' in data:
        print(f'   🔢 PID: {data[\"process_id\"]}')

    if 'uptime' in data:
        uptime_val = data["uptime"]
        if uptime_val is not None:
            print(f'   ⏰ Uptime: {uptime_val:.1f}s')
        else:
            print(f'   ⏰ Uptime: N/A')

    if 'secrets' in data:
        secrets = data['secrets']
        print(f'   🔐 Secrets: {secrets.get(\"status\", \"unknown\")} ({secrets.get(\"loaded_count\", \"?\")} loaded)')

    if 'system' in data:
        system = data['system']
        if 'cpu_percent' in system:
            print(f'   💻 CPU: {system[\"cpu_percent\"]:.1f}%')
        if 'memory' in system and 'percent' in system['memory']:
            print(f'   🧠 Memory: {system[\"memory\"][\"percent\"]:.1f}%')

    if 'dependencies' in data:
        deps = data['dependencies']
        available = [k for k, v in deps.items() if v == 'available']
        missing = [k for k, v in deps.items() if v == 'missing']
        print(f'   📚 Dependencies: {len(available)} available, {len(missing)} missing')

    if 'checks' in data:
        checks = data['checks']
        print(f'   🔍 Health Checks:')
        for check_name, check_status in checks.items():
            status_icon = "✅" if check_status in ["ok", "online", "valid"] else "⚠️" if check_status in ["low", "offline"] else "❌"
            print(f'      {check_name}: {status_icon} {check_status}')

except Exception as e:
    print(f'   ❌ Ошибка парсинга ответа: {e}')
    print(f'   Raw response: {response[:200]}...')
" 2>/dev/null; then
        echo "   ✅ Ответ получен и обработан"
    else
        echo "   ❌ Ответ получен, но содержит ошибки"
    fi
    else
        echo "   ❌ Эндпоинт недоступен (timeout или ошибка соединения)"
    fi
    echo ""
}

# Тестирование эндпоинтов
test_endpoint "/health" "базового health check"
test_endpoint "/health/detailed" "детального health check"

# Остановка сервера
echo "🛑 Остановка сервера..."
kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

echo ""
echo "✅ Локальное тестирование завершено!"
echo ""
echo "💡 Для production тестирования в Docker запустите:"
echo "   ./test-health-docker.sh"
