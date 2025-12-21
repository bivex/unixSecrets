#!/usr/bin/env python3
"""
Локальное тестирование production health checks без Docker
Запускает FastAPI сервер локально для проверки функциональности
"""

import asyncio
import json
import sys
import os
from datetime import datetime

# Добавляем текущую директорию в путь
sys.path.insert(0, '/Volumes/External/unixSecrets/examples/telegram-bot')

try:
    from telegram_bot import app, FASTAPI_AVAILABLE, PSUTIL_AVAILABLE
    import uvicorn
    
    if FASTAPI_AVAILABLE:
        print("✅ FastAPI доступен - запускаем локальный тест-сервер")
        print("🚀 Тестирование production health checks локально")
        print("=" * 60)
        
        print("📊 Статус зависимостей:")
        print(f"   FastAPI: {'✅' if FASTAPI_AVAILABLE else '❌'}")
        print(f"   psutil: {'✅' if PSUTIL_AVAILABLE else '❌'}")
        print(f"   Telegram Bot: ❌ (не требуется для health checks)")
        
        print("\n🌐 Запуск FastAPI сервера на http://localhost:8080")
        print("   Health endpoints:")
        print("   - GET /health")
        print("   - GET /health/detailed")
        print("\n   Нажмите Ctrl+C для остановки сервера\n")
        
        # Запуск сервера
        uvicorn.run(app, host="127.0.0.1", port=8080, log_level="info")
        
    else:
        print("❌ FastAPI не установлен - установите зависимости:")
        print("   pip install fastapi uvicorn")
        
except ImportError as e:
    print(f"❌ Ошибка импорта: {e}")
    print("Установите зависимости: pip install -r requirements.txt")
except KeyboardInterrupt:
    print("\n🛑 Сервер остановлен пользователем")
except Exception as e:
    print(f"❌ Ошибка запуска сервера: {e}")
