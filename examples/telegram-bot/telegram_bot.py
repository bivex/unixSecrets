
# Copyright (c) 2025 Bivex
#
# Author: Bivex
# Available for contact via email: support@b-b.top
# For up-to-date contact information:
# https://github.com/bivex
#
# Created: 2025-12-21T16:22:06
# Last Updated: 2025-12-21T17:28:05
#
# Licensed under the MIT License.
# Commercial licensing available upon request.
"""
Telegram бот для Docker контейнера с Unix Secrets Manager
Секреты загружаются через systemd credentials или Docker volumes
"""
import os
import logging
import signal
import sys
import time
from datetime import datetime
from typing import Dict, Any, Optional
import asyncio
from contextlib import asynccontextmanager

# System monitoring
try:
    import psutil
    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False
    psutil = None

# Web framework для health checks
try:
    from fastapi import FastAPI, HTTPException
    import uvicorn
    FASTAPI_AVAILABLE = True
except ImportError:
    FASTAPI_AVAILABLE = False
    FastAPI = None
    HTTPException = None
    uvicorn = None

# Telegram bot
try:
    from telegram import Update
    from telegram.ext import Application, CommandHandler, ContextTypes
    TELEGRAM_AVAILABLE = True
except ImportError:
    TELEGRAM_AVAILABLE = False
    Update = None
    Application = None
    CommandHandler = None
    ContextTypes = None

# Monitoring
try:
    import sentry_sdk
    SENTRY_AVAILABLE = True
except ImportError:
    SENTRY_AVAILABLE = False

# Database
try:
    import psycopg2
    import redis
    DB_AVAILABLE = True
except ImportError:
    DB_AVAILABLE = False

class SecretsManager:
    """Менеджер секретов для Docker контейнера с поддержкой Unix Secrets Manager"""

    def __init__(self):
        # Приоритеты источников секретов
        self.sources = [
            # 1. Docker volumes (монтированные секреты)
            '/app/secrets',
            # 2. Systemd credentials (если доступно)
            os.environ.get('CREDENTIALS_DIR', '/run/credentials/telegram-bot.service'),
            # 3. Переменные окружения (fallback для разработки)
            os.environ
        ]
        self._secrets_cache: Dict[str, str] = {}
        self._load_strategies = {
            'file': self._load_from_file,
            'env': self._load_from_env
        }

        # Отладка источников в тестовой среде
        if os.environ.get('ENVIRONMENT') == 'test':
            print("=== SECRETS DEBUG ===")
            print("ENVIRONMENT:", os.environ.get('ENVIRONMENT'))
            print("Sources:", self.sources)
            for i, source in enumerate(self.sources):
                if isinstance(source, str):
                    if os.path.exists(source):
                        if os.path.isdir(source):
                            try:
                                files = os.listdir(source)
                                print(f"Source {i} ({source}): {len(files)} files - {files}")
                                # Покажем содержимое первых файлов
                                for file in files[:3]:  # только первые 3
                                    try:
                                        with open(os.path.join(source, file), 'r') as f:
                                            content = f.read().strip()
                                            print(f"  {file}: {content[:20]}...")
                                    except Exception as e:
                                        print(f"  {file}: ERROR reading - {e}")
                            except Exception as e:
                                print(f"Source {i} ({source}): ERROR listing - {e}")
                        else:
                            print(f"Source {i} ({source}): is file, not dir")
                    else:
                        print(f"Source {i} ({source}): does not exist")
                else:
                    print(f"Source {i}: {type(source).__name__} (env dict)")
            print("=== END SECRETS DEBUG ===")

    def _load_from_file(self, source: str, name: str) -> Optional[str]:
        """Загрузить секрет из файла"""
        secret_file = os.path.join(source, name)
        if os.path.exists(secret_file):
            try:
                with open(secret_file, 'r') as f:
                    return f.read().strip()
            except Exception as e:
                logging.warning(f"Error reading secret file {secret_file}: {e}")
        return None

    def _load_from_env(self, source: Dict[str, str], name: str) -> Optional[str]:
        """Загрузить секрет из переменных окружения"""
        env_name = name.upper().replace('-', '_')
        return source.get(env_name)

    def get_secret(self, name: str, required: bool = True) -> Optional[str]:
        """Получить секрет по имени"""
        if name in self._secrets_cache:
            return self._secrets_cache[name]

        for source in self.sources:
            if isinstance(source, str) and os.path.isdir(source):
                # Источник - директория с файлами
                secret = self._load_from_file(source, name)
                if secret is not None:
                    self._secrets_cache[name] = secret
                    logging.debug(f"Loaded secret '{name}' from file in {source}")
                    return secret
            elif isinstance(source, dict):
                # Источник - переменные окружения
                secret = self._load_from_env(source, name)
                if secret is not None:
                    self._secrets_cache[name] = secret
                    logging.debug(f"Loaded secret '{name}' from environment")
                    return secret

        if required:
            raise ValueError(f"Required secret '{name}' not found in any source")

        # Тихое логирование для не-critical секретов в Docker среде
        if os.environ.get('ENVIRONMENT') == 'test':
            print(f"DEBUG: Secret '{name}' not found, using default")
        else:
            logging.warning(f"Secret '{name}' not found, using default")

        return None

    def get_config(self) -> Dict[str, Any]:
        """Загрузить всю конфигурацию из секретов"""
        config = {}

        # Определяем список всех секретов
        secrets_mapping = {
            # Telegram
            'telegram_bot_token': ('telegram-bot-token', str),
            'telegram_bot_username': ('telegram-bot-username', str),
            'telegram_webhook_url': ('telegram-webhook-url', str),
            'telegram_webhook_secret': ('telegram-webhook-secret', str),

            # Database
            'database_url': ('database-url', str),
            'database_host': ('database-host', str),
            'database_port': ('database-port', int),
            'database_name': ('database-name', str),
            'database_user': ('database-user', str),
            'database_password': ('database-password', str),
            'database_ssl_mode': ('database-ssl-mode', str),
            'database_connection_pool_size': ('database-connection-pool-size', int),
            'database_connection_timeout': ('database-connection-timeout', int),

            # Redis
            'redis_url': ('redis-url', str),
            'redis_host': ('redis-host', str),
            'redis_port': ('redis-port', int),
            'redis_db': ('redis-db', int),
            'redis_password': ('redis-password', str),

            # API Keys
            'openai_api_key': ('openai-api-key', str),
            'google_maps_api_key': ('google-maps-api-key', str),
            'stripe_secret_key': ('stripe-secret-key', str),
            'sendgrid_api_key': ('sendgrid-api-key', str),
            'twilio_account_sid': ('twilio-account-sid', str),
            'twilio_auth_token': ('twilio-auth-token', str),

            # Monitoring
            'sentry_dsn': ('sentry-dsn', str),
            'log_level': ('log-level', str),
            'health_check_token': ('health-check-token', str),

            # Feature Flags
            'enable_analytics': ('enable-analytics', lambda x: x.lower() == 'true'),
            'enable_notifications': ('enable-notifications', lambda x: x.lower() == 'true'),
            'enable_cache': ('enable-cache', lambda x: x.lower() == 'true'),
            'enable_rate_limiting': ('enable-rate-limiting', lambda x: x.lower() == 'true'),

            # Cache Configuration
            'cache_ttl_seconds': ('cache-ttl-seconds', int),
            'cache_max_size_mb': ('cache-max-size-mb', int),
            'cache_redis_prefix': ('cache-redis-prefix', str),

            # Rate Limiting
            'rate_limit_requests_per_minute': ('rate-limit-requests-per-minute', int),
            'rate_limit_burst_size': ('rate-limit-burst-size', int),
            'rate_limit_window_seconds': ('rate-limit-window-seconds', int),

            # Performance
            'max_concurrent_requests': ('max-concurrent-requests', int),
            'request_timeout_seconds': ('request-timeout-seconds', int),
            'memory_limit_mb': ('memory-limit-mb', int),
            'cpu_limit': ('cpu-limit', float),
        }

        for config_key, (secret_name, converter) in secrets_mapping.items():
            try:
                value = self.get_secret(secret_name, required=False)
                if value is not None:
                    config[config_key] = converter(value)
                else:
                    logging.warning(f"Secret '{secret_name}' not found, using default")
                    config[config_key] = self._get_default_value(config_key)
            except Exception as e:
                logging.error(f"Error loading config '{config_key}': {e}")
                config[config_key] = self._get_default_value(config_key)

        return config

    def _get_default_value(self, key: str) -> Any:
        """Получить значение по умолчанию для конфигурации"""
        defaults = {
            # Database
            'database_port': 5432,
            'redis_port': 6379,
            'redis_db': 0,

            # Logging
            'log_level': 'INFO',

            # Feature Flags
            'enable_analytics': False,
            'enable_notifications': False,
            'enable_cache': True,
            'enable_rate_limiting': True,

            # Cache
            'cache_ttl_seconds': 3600,
            'cache_max_size_mb': 100,
            'cache_redis_prefix': 'telegram_bot:',

            # Rate Limiting
            'rate_limit_requests_per_minute': 60,
            'rate_limit_burst_size': 10,
            'rate_limit_window_seconds': 60,

            # Performance
            'max_concurrent_requests': 100,
            'request_timeout_seconds': 30,
            'memory_limit_mb': 512,
            'cpu_limit': 1.0,
        }
        return defaults.get(key)

# FastAPI приложение для health checks
if FASTAPI_AVAILABLE:
    app = FastAPI(title="Telegram Bot Health Check")
else:
    app = None

class TelegramBot:
    """Основной класс Telegram бота для Docker"""

    def __init__(self):
        self.secrets = SecretsManager()
        self.config = self.secrets.get_config()
        self.logger = self._setup_logging()
        self._init_sentry()
        self._init_database()
        self._init_cache()
        self.application: Optional[Application] = None
        self.running = False

        # Graceful shutdown
        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)

    def _setup_logging(self) -> logging.Logger:
        """Настройка логирования для Docker"""
        # В тестовой среде всегда DEBUG для отладки
        if os.environ.get('ENVIRONMENT') == 'test':
            log_level = logging.DEBUG
        else:
            log_level = getattr(logging, self.config.get('log_level', 'INFO').upper(), logging.INFO)

        # Настройка для Docker (stdout/stderr)
        logging.basicConfig(
            level=log_level,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.StreamHandler(sys.stdout),
                logging.StreamHandler(sys.stderr)
            ]
        )

        logger = logging.getLogger(__name__)
        logger.info("Logging initialized")
        return logger

    def _init_sentry(self):
        """Инициализация Sentry для мониторинга"""
        if not SENTRY_AVAILABLE:
            self.logger.warning("Sentry SDK not available")
            return

        sentry_dsn = self.config.get('sentry_dsn')
        if sentry_dsn:
            sentry_sdk.init(
                dsn=sentry_dsn,
                environment=os.environ.get('ENVIRONMENT', 'production'),
                release=os.environ.get('VERSION', '1.0.0')
            )
            self.logger.info("Sentry initialized")
        else:
            self.logger.info("Sentry DSN not configured")

    def _init_database(self):
        """Инициализация подключения к базе данных"""
        if not DB_AVAILABLE:
            self.logger.warning("Database libraries not available")
            return

        try:
            # PostgreSQL connection
            db_config = {
                'host': self.config.get('database_host'),
                'port': self.config.get('database_port'),
                'database': self.config.get('database_name'),
                'user': self.config.get('database_user'),
                'password': self.config.get('database_password'),
                'sslmode': self.config.get('database_ssl_mode', 'require')
            }

            self.db_connection = psycopg2.connect(**db_config)
            self.logger.info("Database connection established")

        except Exception as e:
            self.logger.error(f"Database connection failed: {e}")
            self.db_connection = None

    def _init_cache(self):
        """Инициализация Redis кэша"""
        if not DB_AVAILABLE:
            self.logger.warning("Redis library not available")
            return

        try:
            redis_config = {
                'host': self.config.get('redis_host', 'localhost'),
                'port': self.config.get('redis_port', 6379),
                'db': self.config.get('redis_db', 0),
                'password': self.config.get('redis_password'),
                'decode_responses': True
            }

            self.redis_client = redis.Redis(**redis_config)
            self.redis_client.ping()  # Test connection
            self.logger.info("Redis connection established")

        except Exception as e:
            self.logger.error(f"Redis connection failed: {e}")
            self.redis_client = None

    def _signal_handler(self, signum, frame):
        """Обработчик сигналов для graceful shutdown"""
        self.logger.info(f"Received signal {signum}, shutting down gracefully...")
        self.running = False
        if self.application:
            asyncio.create_task(self.application.stop())

    async def start_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Обработчик команды /start"""
        try:
            username = self.config.get('telegram_bot_username', 'Bot')
            await update.message.reply_text(
                f'🚀 Привет! Я {username}!\n\n'
                '🔐 Мои секреты защищены Unix Secrets Manager\n'
                '🐳 Я работаю в Docker контейнере\n\n'
                'Используй /help для списка команд.'
            )
        except Exception as e:
            self.logger.error(f"Error in start_command: {e}")
            await update.message.reply_text("❌ Произошла ошибка")

    async def help_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Обработчик команды /help"""
        help_text = (
            "🤖 Доступные команды:\n\n"
            "/start - Приветствие\n"
            "/help - Эта справка\n"
            "/info - Информация о боте\n"
            "/health <token> - Проверка здоровья\n"
            "/stats - Статистика работы\n"
            "/ping - Проверка отклика"
        )
        await update.message.reply_text(help_text)

    async def info_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Обработчик команды /info"""
        try:
            info_parts = [
                f'🤖 Бот: {self.config.get("telegram_bot_username", "Unknown")}',
                '🐳 Контейнер: Docker',
                f'🔐 Секреты: {"загружены" if self.secrets else "ошибка"}',
                f'🗄️ БД: {"подключена" if getattr(self, "db_connection", None) else "недоступна"}',
                f'⚡ Кэш: {"работает" if getattr(self, "redis_client", None) else "недоступен"}',
                f'📊 Аналитика: {"включена" if self.config.get("enable_analytics") else "выключена"}',
                f'🔔 Уведомления: {"включены" if self.config.get("enable_notifications") else "выключены"}'
            ]

            await update.message.reply_text('\n'.join(info_parts))
        except Exception as e:
            self.logger.error(f"Error in info_command: {e}")
            await update.message.reply_text("❌ Ошибка получения информации")

    async def health_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Обработчик команды /health"""
        try:
            # Проверка токена здоровья
            health_token = self.config.get('health_check_token')
            if not health_token or not context.args or context.args[0] != health_token:
                await update.message.reply_text('❌ Неверный токен здоровья')
                return

            # Проверка компонентов
            checks = []

            # Database check
            if hasattr(self, 'db_connection') and self.db_connection:
                try:
                    with self.db_connection.cursor() as cursor:
                        cursor.execute("SELECT 1")
                    checks.append("✅ База данных")
                except:
                    checks.append("❌ База данных")
            else:
                checks.append("⚠️ База данных не настроена")

            # Redis check
            if hasattr(self, 'redis_client') and self.redis_client:
                try:
                    self.redis_client.ping()
                    checks.append("✅ Redis кэш")
                except:
                    checks.append("❌ Redis кэш")
            else:
                checks.append("⚠️ Redis не настроен")

            # Secrets check
            if self.secrets and self.config.get('telegram_bot_token'):
                checks.append("✅ Секреты загружены")
            else:
                checks.append("❌ Проблема с секретами")

            await update.message.reply_text(
                "🏥 Статус здоровья:\n" + "\n".join(checks)
            )

        except Exception as e:
            self.logger.error(f"Error in health_command: {e}")
            await update.message.reply_text("❌ Ошибка проверки здоровья")

    async def ping_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Обработчик команды /ping"""
        await update.message.reply_text("🏓 Pong!")

    async def run_bot(self):
        """Запуск Telegram бота"""
        if not TELEGRAM_AVAILABLE:
            self.logger.error("Telegram bot library not available")
            return

        try:
            bot_token = self.config.get('telegram_bot_token')
            if not bot_token:
                raise ValueError("Telegram bot token not configured")

            self.logger.info("Starting Telegram bot...")
            self.application = Application.builder().token(bot_token).build()

            # Добавление обработчиков команд
            self.application.add_handler(CommandHandler("start", self.start_command))
            self.application.add_handler(CommandHandler("help", self.help_command))
            self.application.add_handler(CommandHandler("info", self.info_command))
            self.application.add_handler(CommandHandler("health", self.health_command))
            self.application.add_handler(CommandHandler("ping", self.ping_command))

            self.running = True
            self.logger.info("Bot started successfully")

            # Запуск бота
            await self.application.run_polling(
                close_loop=False,
                stop_signals=()
            )

        except Exception as e:
            self.logger.error(f"Error running bot: {e}")
            raise
        finally:
            self.running = False

# Production-ready health check endpoints для Docker
if FASTAPI_AVAILABLE:
    @app.get("/health")
    async def health_check():
        """Production health check endpoint для Docker"""
        try:
            # Базовые проверки - создаем свой SecretsManager
            from telegram_bot import SecretsManager
            secrets_manager = SecretsManager()
            config = secrets_manager.get_config()

            # Проверяем наличие критических секретов
            bot_token = secrets_manager.get_secret('telegram-bot-token', required=False)
            secrets_loaded = len(config) > 0
            critical_secrets_present = bool(bot_token)

            # Определяем статус
            if secrets_loaded and critical_secrets_present:
                status = "healthy"
            elif secrets_loaded:
                status = "degraded"
            else:
                status = "unhealthy"

            return {
                "status": status,
                "timestamp": datetime.now().isoformat(),
                "version": "1.0.0"
            }
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            return {
                "status": "unhealthy",
                "error": str(e),
                "timestamp": datetime.now().isoformat()
            }

    @app.get("/health/detailed")
    async def detailed_health():
        """Comprehensive health check with component status"""
        logger = logging.getLogger(__name__)
        health_data = {
            "status": "healthy",
            "timestamp": datetime.now().isoformat(),
            "version": "1.0.0",
            "hostname": os.uname().nodename if hasattr(os, 'uname') else None,
            "python_version": f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
            "process_id": os.getpid(),
            "components": {},
            "system": {},
            "secrets": {},
            "performance": {},
            "dependencies": {},
            "checks": {}
        }

        # Uptime calculation
        if PSUTIL_AVAILABLE:
            try:
                health_data["uptime"] = time.time() - psutil.Process().create_time()
            except:
                health_data["uptime"] = None
        else:
            health_data["uptime"] = None

        try:
            # Проверка SecretsManager - создаем свой экземпляр для health check
            try:
                from telegram_bot import SecretsManager
                secrets_manager = SecretsManager()
                # Получаем полную конфигурацию для подсчета загруженных секретов
                full_config = secrets_manager.get_config()
                secrets_loaded_count = len(full_config) if full_config else 0

                # Проверяем наличие основных секретов
                critical_secrets = ['telegram-bot-token', 'health-check-token']
                secrets_status = {}
                for secret_name in critical_secrets:
                    secret_value = secrets_manager.get_secret(secret_name, required=False)
                    secrets_status[secret_name] = "present" if secret_value else "missing"

                health_data["secrets"] = {
                    "status": "healthy" if all(s == "present" for s in secrets_status.values()) else "degraded",
                    "loaded_count": secrets_loaded_count,
                    "critical_secrets": secrets_status
                }
            except Exception as e:
                health_data["secrets"] = {"status": "unhealthy", "error": f"SecretsManager error: {str(e)}"}

            # Проверка Telegram Bot - проверяем через SecretsManager
            try:
                bot_token = secrets_manager.get_secret('telegram-bot-token', required=False)
                logger.debug(f"[Detailed Health] Telegram Bot Token (partial): {str(bot_token)[:10]}... Length: {len(str(bot_token)) if bot_token else 0}")

                if bot_token and len(str(bot_token)) > 10:  # Базовая валидация токена
                    bot_status = "configured"
                else:
                    bot_status = "no_token"
                logger.debug(f"[Detailed Health] Telegram Bot Status: {bot_status}")

            except Exception as e:
                bot_status = f"error: {str(e)}"
                logger.error(f"[Detailed Health] Error checking Telegram Bot: {e}")

            health_data["components"]["telegram_bot"] = {
                "status": "healthy" if bot_status in ["configured", "initialized"] else "unhealthy",
                "state": bot_status
            }

            # Системные метрики
            if PSUTIL_AVAILABLE:
                try:
                    memory = psutil.virtual_memory()
                    disk = psutil.disk_usage('/')

                    health_data["system"] = {
                        "cpu_percent": psutil.cpu_percent(interval=0.1),
                        "memory": {
                            "total": memory.total,
                            "available": memory.available,
                            "percent": memory.percent
                        },
                        "disk": {
                            "total": disk.total,
                            "free": disk.free,
                            "percent": disk.percent
                        }
                    }

                    # Производительность
                    process = psutil.Process()
                    health_data["performance"] = {
                        "cpu_times": dict(process.cpu_times()._asdict()),
                        "memory_info": dict(process.memory_info()._asdict()),
                        "num_threads": process.num_threads(),
                        "num_fds": len(process.open_files()) if hasattr(process, 'open_files') else None
                    }
                except Exception as e:
                    health_data["system"] = {"error": f"psutil unavailable: {e}"}
                    health_data["performance"] = {"error": f"psutil unavailable: {e}"}
            else:
                health_data["system"] = {"status": "psutil_not_available"}
                health_data["performance"] = {"status": "psutil_not_available"}

            # Проверка зависимостей
            health_data["dependencies"] = {
                "python-telegram-bot": "available" if TELEGRAM_AVAILABLE else "missing",
                "fastapi": "available" if FASTAPI_AVAILABLE else "missing",
                "psutil": "available" if PSUTIL_AVAILABLE else "missing"
            }

            # Дополнительные проверки здоровья
            health_data["checks"] = {
                "network_connectivity": "unknown",  # Можно расширить для проверки интернет-соединения
                "disk_space_ok": "unknown",
                "memory_pressure": "unknown",
                "config_valid": "unknown"
            }

            # Проверка дискового пространства
            if PSUTIL_AVAILABLE:
                try:
                    disk = psutil.disk_usage('/')
                    # Предупреждать если меньше 1GB свободного места
                    disk_space_ok = disk.free > (1024 * 1024 * 1024)  # 1GB
                    health_data["checks"]["disk_space_ok"] = "ok" if disk_space_ok else "low"
                except:
                    health_data["checks"]["disk_space_ok"] = "check_failed"

                # Проверка давления на память
                try:
                    memory = psutil.virtual_memory()
                    # Предупреждать если используется больше 90% памяти
                    memory_pressure = "high" if memory.percent > 90 else "normal" if memory.percent > 75 else "low"
                    health_data["checks"]["memory_pressure"] = memory_pressure
                except:
                    health_data["checks"]["memory_pressure"] = "check_failed"
            else:
                health_data["checks"]["disk_space_ok"] = "psutil_required"
                health_data["checks"]["memory_pressure"] = "psutil_required"

            # Проверка конфигурации
            config_valid = True
            if bot_instance:
                required_configs = ['telegram-bot-username']
                for config_key in required_configs:
                    if not bot_instance.config.get(config_key):
                        config_valid = False
                        break
            health_data["checks"]["config_valid"] = "valid" if config_valid else "invalid"

            # Проверка сетевого подключения (базовая)
            try:
                import socket
                socket.create_connection(("8.8.8.8", 53), timeout=1)
                health_data["checks"]["network_connectivity"] = "online"
            except:
                health_data["checks"]["network_connectivity"] = "offline"

            # Финальный статус - более гибкая логика
            component_statuses = [comp.get("status", "unknown") for comp in health_data.get("components", {}).values()]
            secrets_status = health_data.get("secrets", {}).get("status", "unknown")

            # Определяем статус на основе компонентов
            if secrets_status == "healthy" and all(status in ["healthy", "configured", "initialized"] for status in component_statuses):
                health_data["status"] = "healthy"
            elif secrets_status in ["healthy", "degraded"] or any(status in ["configured", "initialized"] for status in component_statuses):
                health_data["status"] = "degraded"
            else:
                health_data["status"] = "unhealthy"

        except Exception as e:
            logger.error(f"Detailed health check failed: {e}")
            health_data["status"] = "error"
            health_data["error"] = str(e)

        return health_data

# Глобальный экземпляр бота
bot_instance: Optional[TelegramBot] = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan manager для FastAPI"""
    global bot_instance

    # Startup
    try:
        bot_instance = TelegramBot()
        # Запускаем бота в фоне
        bot_task = asyncio.create_task(bot_instance.run_bot())
        yield
    except Exception as e:
        logging.error(f"Failed to start bot: {e}")
        raise
    finally:
        # Shutdown
        if bot_instance and bot_instance.running:
            logging.info("Shutting down bot...")
            if bot_instance.application:
                await bot_instance.application.stop()
            bot_task.cancel()
            try:
                await bot_task
            except asyncio.CancelledError:
                pass

if FASTAPI_AVAILABLE:
    app.router.lifespan_context = lifespan

def main():
    """Главная функция для запуска в Docker"""
    if not FASTAPI_AVAILABLE:
        print("FastAPI not available. Install required dependencies:")
        print("pip install -r requirements.txt")
        sys.exit(1)

    # Запуск FastAPI сервера с ботом
    uvicorn.run(
        "telegram_bot:app",
        host="0.0.0.0",
        port=8080,
        log_level="info",
        access_log=True
    )

if __name__ == '__main__':
    main()
