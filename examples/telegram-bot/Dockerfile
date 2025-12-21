# Dockerfile для Telegram бота с Unix Secrets Manager
FROM python:3.11-slim

# Установка системных зависимостей
RUN apt-get update && apt-get install -y --no-install-recommends \
    gnupg \
    systemd \
    curl \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Создание пользователя для бота
RUN useradd --create-home --shell /bin/bash botuser

# Установка рабочей директории
WORKDIR /app

# Копирование зависимостей
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копирование кода приложения
COPY telegram_bot.py .

# Создание директорий для логов
RUN mkdir -p /var/log/telegram-bot && \
    chown -R botuser:botuser /var/log/telegram-bot

# Переключение на непривилегированного пользователя
USER botuser

# Метки для контейнера
LABEL maintainer="Unix Secrets Manager Example"
LABEL description="Telegram Bot with secure secrets management"
LABEL version="1.0"

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Запуск бота
CMD ["python", "telegram_bot.py"]
