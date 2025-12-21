#!/bin/bash
# Скрипт развертывания Telegram бота в Docker с Unix Secrets Manager

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка зависимостей
check_dependencies() {
    log_info "Проверка зависимостей..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker не установлен"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose не установлен"
        exit 1
    fi

    if ! command -v gpg &> /dev/null; then
        log_error "GPG не установлен на хосте"
        exit 1
    fi

    log_info "Все зависимости установлены"
}

# Настройка секретов
setup_secrets() {
    log_info "Настройка секретов..."

    # Проверка наличия .env файла
    if [ ! -f ".env" ]; then
        log_warn ".env файл не найден. Копирую пример..."
        cp env-example.txt .env
        log_warn "Отредактируйте .env файл с реальными значениями секретов!"
        log_warn "Затем запустите скрипт снова."
        exit 1
    fi

    # Проверка и создание GPG ключа
    if ! gpg --list-keys secrets@host &> /dev/null; then
        log_warn "GPG ключ 'secrets@host' не найден. Создаю..."
        gpg --batch --generate-key <<EOF
Key-Type: RSA
Key-Length: 4096
Name-Real: Secrets Manager
Name-Email: secrets@host
Expire-Date: 0
%no-protection
%commit
EOF
        log_info "GPG ключ создан"
    fi

    # Конвертация .env в секреты
    log_info "Конвертация секретов..."
    sudo mkdir -p /etc/secrets.encrypted
    sudo chmod 700 /etc/secrets.encrypted

    ./convert-env-to-secrets.sh .env secrets@host

    log_info "Секреты настроены"
}

# Сборка и запуск
deploy() {
    log_info "Сборка Docker образов..."

    # Сборка образов
    docker-compose build --no-cache

    log_info "Запуск сервисов..."

    # Запуск с пересборкой
    docker-compose up -d --force-recreate

    log_info "Ожидание запуска сервисов..."
    sleep 10

    # Проверка статуса
    check_status
}

# Проверка статуса
check_status() {
    log_info "Проверка статуса сервисов..."

    # Проверка контейнеров
    if ! docker-compose ps | grep -q "Up"; then
        log_error "Не все сервисы запущены"
        docker-compose logs
        exit 1
    fi

    # Проверка health checks
    log_info "Проверка health checks..."
    if curl -f http://localhost:8080/health &> /dev/null; then
        log_info "✅ Бот запущен и здоров"
    else
        log_error "❌ Бот не отвечает на health check"
        exit 1
    fi

    # Вывод статуса
    echo ""
    log_info "🚀 Развертывание завершено успешно!"
    echo ""
    echo "Доступные сервисы:"
    echo "• Telegram бот: работает"
    echo "• Health check: http://localhost:8080/health"
    echo "• Detailed health: http://localhost:8080/health/detailed"
    echo "• PostgreSQL: localhost:5432"
    echo "• Redis: localhost:6379"
    echo ""
    echo "Команды управления:"
    echo "• Просмотр логов: docker-compose logs -f telegram-bot"
    echo "• Остановка: docker-compose down"
    echo "• Перезапуск: docker-compose restart"
}

# Остановка сервисов
stop() {
    log_info "Остановка сервисов..."
    docker-compose down
    log_info "Сервисы остановлены"
}

# Очистка
cleanup() {
    log_info "Очистка Docker ресурсов..."
    docker-compose down -v --rmi all
    docker system prune -f
    log_info "Очистка завершена"
}

# Ротация секретов
rotate_secret() {
    if [ $# -ne 2 ]; then
        log_error "Использование: $0 rotate <secret_name> <new_value>"
        exit 1
    fi

    SECRET_NAME="$1"
    NEW_VALUE="$2"

    log_info "Ротация секрета $SECRET_NAME..."

    # Создание нового зашифрованного секрета
    echo -n "$NEW_VALUE" | gpg --encrypt --recipient secrets@host \
        --output "/tmp/${SECRET_NAME}.gpg"

    # Копирование в хранилище
    sudo cp "/tmp/${SECRET_NAME}.gpg" "/etc/secrets.encrypted/"

    # Очистка
    shred -u "/tmp/${SECRET_NAME}.gpg"

    # Перезапуск сервисов
    docker-compose restart secrets-decrypt
    sleep 5
    docker-compose restart telegram-bot

    log_info "Секрет $SECRET_NAME обновлен"
}

# Просмотр логов
logs() {
    docker-compose logs -f telegram-bot
}

# Главная функция
main() {
    case "${1:-deploy}" in
        "check")
            check_dependencies
            ;;
        "secrets")
            setup_secrets
            ;;
        "deploy")
            check_dependencies
            setup_secrets
            deploy
            ;;
        "start")
            docker-compose up -d
            check_status
            ;;
        "stop")
            stop
            ;;
        "restart")
            docker-compose restart
            check_status
            ;;
        "status")
            check_status
            ;;
        "logs")
            logs
            ;;
        "cleanup")
            cleanup
            ;;
        "rotate")
            shift
            rotate_secret "$@"
            ;;
        *)
            echo "Использование: $0 [command]"
            echo ""
            echo "Команды:"
            echo "  deploy    - Полное развертывание (по умолчанию)"
            echo "  check     - Проверка зависимостей"
            echo "  secrets   - Настройка секретов"
            echo "  start     - Запуск сервисов"
            echo "  stop      - Остановка сервисов"
            echo "  restart   - Перезапуск сервисов"
            echo "  status    - Проверка статуса"
            echo "  logs      - Просмотр логов"
            echo "  cleanup   - Очистка всех ресурсов"
            echo "  rotate <name> <value> - Ротация секрета"
            exit 1
            ;;
    esac
}

main "$@"
