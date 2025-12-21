# Руководство администратора Unix Secrets Manager

**Версия:** 1.0.0
**Дата:** Декабрь 2025
**Статус:** Production Ready

---

## Обзор документа

Это руководство предназначено для системных администраторов, DevOps инженеров и разработчиков, отвечающих за развертывание и эксплуатацию системы Unix Secrets Manager.

**Целевая аудитория:**
- Системные администраторы Linux
- DevOps инженеры
- Разработчики приложений
- Специалисты по безопасности

**Предварительные знания:**
- Администрирование Linux систем
- Основы systemd
- Работа с GPG
- Docker (для контейнерных развертываний)

### История изменений

| Версия | Дата | Автор | Описание изменений |
|--------|------|-------|-------------------|
| 1.0.0 | 2025-12 | Команда разработки | Первоначальный выпуск |

---

## 1. Введение

### 1.1 Цель документа

Настоящее руководство предназначено для администраторов систем и разработчиков, которым необходимо развернуть и использовать систему управления секретами на базе внутренних средств Linux. Документ описывает архитектуру, процедуры установки, настройки и эксплуатации системы Unix Secrets Manager.

### 1.2 Область применения

Система Unix Secrets Manager предоставляет безопасное хранение и управление секретами (паролями, ключами, токенами) с использованием только внутренних примитивов Linux без внешних зависимостей типа HashiCorp Vault или облачных KMS. Система подходит для:

- Изолированных (air-gapped) сред
- Встроенных систем и appliances
- Регулируемых сред с ограничениями на внешние зависимости
- Сценариев с минимальной поверхностью атаки

### 1.3 Целевая аудитория

- **Системные администраторы:** ответственные за установку и настройку системы
- **Разработчики приложений:** интегрирующие секреты в свои сервисы
- **Операторы безопасности:** управляющие доступом и аудитом
- **DevOps инженеры:** автоматизирующие развертывание и ротацию

**Предварительные знания:** Знание Linux системного администрирования, systemd, GPG, базовые навыки безопасности.

### 1.4 Ссылки на документы

- [systemd документация](https://www.freedesktop.org/wiki/Software/systemd/)
- [GPG руководство](https://www.gnupg.org/documentation/)
- [POSIX ACL спецификация](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap15.html)
- [Linux tmpfs документация](https://www.kernel.org/doc/html/latest/filesystems/tmpfs.html)

---

## 2. Концепция операций

### 2.1 Обзор функций системы

Unix Secrets Manager реализует безопасное управление секретами через:

- **Хранение в зашифрованном виде:** Секреты хранятся на диске только в зашифрованном состоянии
- **Дешифрация в RAM:** Расшифрованные секреты существуют только в оперативной памяти
- **Изоляция через systemd:** Секреты доставляются сервисам через защищенные credentials
- **Аудит и ротация:** Полный аудит доступа и процедуры ротации секретов

### 2.2 Типичные роли пользователей и сценарии

#### Роль: Системный администратор

**Сценарий установки:**
1. Генерация GPG ключей
2. Создание зашифрованных секретов
3. Настройка systemd юнитов
4. Развертывание сервисов

#### Роль: Разработчик приложения

**Сценарий интеграции:**
1. Настройка сервиса для использования credentials
2. Чтение секретов из защищенного каталога
3. Реализация логики приложения

#### Роль: Оператор безопасности

**Сценарий ротации:**
1. Обновление зашифрованных секретов
2. Перезапуск сервисов дешифрации
3. Проверка целостности

### 2.3 Операционная среда и ограничения

**Требования к среде:**
- Linux дистрибутив с systemd
- GPG 2.x или выше
- POSIX ACL поддержка
- Доступ root для начальной настройки

**Ограничения:**
- Секреты не доступны после перезагрузки до повторной дешифрации
- Требуется ручная ротация секретов
- Не поддерживает динамическую генерацию секретов

---

## 3. Установка и конфигурация

### 3.1 Системные требования

| Компонент | Минимальные требования | Рекомендуемые |
|-----------|----------------------|---------------|
| ОС | Linux с systemd | Ubuntu 20.04+, RHEL 8+ |
| Память | 64 MB RAM | 256 MB RAM |
| Диск | 50 MB | 100 MB |
| GPG | 2.2+ | 2.4+ |
| Права | root доступ | root доступ |

### 3.2 Шаги установки

#### Предварительная подготовка

1. Установите необходимые пакеты:
   ```bash
   apt update && apt install -y gnupg systemd
   ```

2. Создайте GPG ключ для шифрования секретов:
   ```bash
   gpg --full-generate-key
   # Выберите: RSA, 4096 бит, "secrets@host"
   ```

#### Установка компонентов системы

3. Создайте директории:
   ```bash
   mkdir -p /etc/secrets.encrypted
   mkdir -p /usr/local/bin
   chmod 700 /etc/secrets.encrypted
   ```

4. Скопируйте скрипты и юниты:
   ```bash
   cp scripts/decrypt-secrets.sh /usr/local/bin/
   cp systemd-units/secrets-decrypt.service /etc/systemd/system/
   chmod +x /usr/local/bin/decrypt-secrets.sh
   ```

5. Создайте зашифрованные секреты:
   ```bash
   # Создайте файл секрета
   echo "mypassword123" > /tmp/secret

   # Зашифруйте
   gpg --encrypt --recipient secrets@host /tmp/secret
   mv /tmp/secret.gpg /etc/secrets.encrypted/db_password.gpg

   # Очистите временные файлы
   shred -u /tmp/secret
   ```

### 3.3 Конфигурация и начальная настройка

#### Настройка systemd

1. Включите и запустите сервис дешифрации:
   ```bash
   systemctl daemon-reload
   systemctl enable secrets-decrypt.service
   systemctl start secrets-decrypt.service
   ```

2. Проверьте статус:
   ```bash
   systemctl status secrets-decrypt.service
   ```

#### Настройка аудита (опционально)

3. Настройте auditd для мониторинга:
   ```bash
   echo "-w /run/secrets -p r -k secrets-access" >> /etc/audit/rules.d/secrets.rules
   systemctl restart auditd
   ```

### 3.4 Проверка после установки

Выполните следующие проверки:

1. **Проверка дешифрации:**
   ```bash
   systemctl status secrets-decrypt.service
   ls -la /run/secrets/
   ```

2. **Проверка секретов:**
   ```bash
   cat /run/secrets/db_password
   ```

3. **Проверка systemd credentials:**
   ```bash
   systemd-run --pty --property=LoadCredential=db_password:/run/secrets/db_password /bin/bash
   ```

---

## 4. Процедуры

### 4.1 Обзор задач

Основные процедуры включают:
- Добавление новых секретов
- Ротация существующих секретов
- Интеграция секретов в приложения
- Мониторинг и аудит

### 4.2 Процедура: Добавление нового секрета

**Цель:** Добавить новый секрет в систему

**Предусловия:**
- Доступ root
- GPG ключ настроен
- Сервис дешифрации запущен

**Шаги:**

1. Создайте файл с секретом:
   ```bash
   echo "newsecretvalue" > /tmp/new_secret
   ```

2. Зашифруйте секрет:
   ```bash
   gpg --encrypt --recipient secrets@host /tmp/new_secret
   ```

3. Переместите в хранилище:
   ```bash
   mv /tmp/new_secret.gpg /etc/secrets.encrypted/api_key.gpg
   ```

4. Перезапустите сервис дешифрации:
   ```bash
   systemctl restart secrets-decrypt.service
   ```

5. Очистите временные файлы:
   ```bash
   shred -u /tmp/new_secret
   ```

**Результат:** Новый секрет доступен в /run/secrets/api_key

### 4.3 Процедура: Ротация секрета

**Цель:** Безопасно обновить значение существующего секрета

**Предусловия:**
- Доступ root
- Приложение может работать без секрета на время ротации

**Шаги:**

1. Подготовьте новое значение:
   ```bash
   echo "newpassword456" > /tmp/updated_secret
   ```

2. Зашифруйте новое значение:
   ```bash
   gpg --encrypt --recipient secrets@host /tmp/updated_secret
   ```

3. Атомарно замените файл:
   ```bash
   mv /tmp/updated_secret.gpg /etc/secrets.encrypted/db_password.gpg
   ```

4. Перезапустите сервисы:
   ```bash
   systemctl restart secrets-decrypt.service
   systemctl restart your-app.service
   ```

5. Очистите временные файлы:
   ```bash
   shred -u /tmp/updated_secret
   ```

**Результат:** Секрет обновлен, сервисы используют новое значение

### 4.4 Процедура: Интеграция секрета в приложение

**Цель:** Настроить systemd сервис для использования секретов

**Предусловия:**
- Приложение готово к использованию credentials
- Секреты существуют

**Шаги:**

1. Создайте systemd юнит сервиса:
   ```ini
   [Service]
   LoadCredential=db_password:/run/secrets/db_password
   DynamicUser=yes
   ```

2. В приложении прочитайте секрет:
   ```python
   with open('/run/credentials/your-service.service/db_password', 'r') as f:
       password = f.read().strip()
   ```

3. Запустите сервис:
   ```bash
   systemctl daemon-reload
   systemctl start your-service.service
   ```

**Результат:** Приложение запущено с доступом к секретам

---

## 5. Устранение неисправностей и обработка ошибок

### 5.1 Общие проблемы и решения

#### Проблема: Сервис дешифрации не запускается

**Симптомы:**
```
secrets-decrypt.service: Failed with result 'exit-code'
```

**Решение:**
1. Проверьте логи: `journalctl -u secrets-decrypt.service`
2. Проверьте GPG ключ: `gpg --list-keys`
3. Проверьте права на директории: `ls -ld /etc/secrets.encrypted`

#### Проблема: Секрет не найден в приложении

**Симптомы:**
```
FileNotFoundError: /run/credentials/service/secret
```

**Решение:**
1. Проверьте статус сервиса дешифрации
2. Проверьте правильность имени в LoadCredential
3. Проверьте переменную CREDENTIALS_DIR

#### Проблема: GPG отказывается расшифровывать

**Симптомы:**
```
gpg: decryption failed: No secret key
```

**Решение:**
1. Импортируйте приватный ключ: `gpg --import private.key`
2. Проверьте доверие к ключу: `gpg --edit-key secrets@host`

### 5.2 Сообщения об ошибках

| Код ошибки | Сообщение | Значение | Действие |
|------------|-----------|----------|----------|
| 1 | mount: tmpfs already mounted | tmpfs уже смонтирован | Проверьте /run/secrets |
| 2 | gpg: decryption failed | Ошибка дешифрации | Проверьте GPG ключ |
| 127 | command not found | Команда не найдена | Установите требуемые пакеты |

### 5.3 Эскалация и поддержка

При невозможности самостоятельного решения:
1. Соберите логи: `journalctl -u secrets-decrypt.service --since yesterday`
2. Проверьте системные ресурсы: `df -h`, `free -h`
3. Обратитесь к системному администратору

---

## 6. Информация для удаления или вывода из эксплуатации

### 6.1 Условия для удаления

Удаление системы требуется при:
- Переходе на другую систему управления секретами
- Выводе сервера из эксплуатации
- Изменении требований безопасности

### 6.2 Шаги удаления

**Предупреждение:** Удаление приведет к потере всех секретов

1. Остановите все сервисы, использующие секреты:
   ```bash
   systemctl stop your-app.service
   ```

2. Остановите сервис дешифрации:
   ```bash
   systemctl stop secrets-decrypt.service
   systemctl disable secrets-decrypt.service
   ```

3. Удалите компоненты:
   ```bash
   rm -rf /run/secrets
   rm -rf /etc/secrets.encrypted
   rm /usr/local/bin/decrypt-secrets.sh
   rm /etc/systemd/system/secrets-decrypt.service
   ```

4. Очистите GPG ключи (опционально):
   ```bash
   gpg --delete-secret-key secrets@host
   gpg --delete-key secrets@host
   ```

5. Перезагрузите систему для очистки RAM

### 6.3 Очистка данных и резервное копирование

**Резервное копирование:**
```bash
tar -czf secrets-backup.tar.gz /etc/secrets.encrypted
```

**Безопасная очистка:**
```bash
shred -u secrets-backup.tar.gz
```

---

## 7. Примеры использования

### 7.1 Telegram бот с 50+ секретами

Unix Secrets Manager идеально подходит для приложений с множеством конфиденциальных настроек, таких как Telegram боты, веб-приложения или микросервисы.

#### Исходная проблема

Традиционный подход с `.env` файлами имеет недостатки:
- Секреты хранятся в plaintext на диске
- Риск случайного коммита в Git
- Сложная ротация без downtime
- Отсутствие аудита доступа

#### Решение с Unix Secrets Manager

Пример в директории `examples/telegram-bot/` показывает полную интеграцию.

##### Структура примера

```
examples/telegram-bot/
├── env-example.txt           # Шаблон .env с 50+ настройками
├── convert-env-to-secrets.sh # Скрипт конвертации
├── telegram_bot.py           # Python код бота
├── telegram-bot.service      # Systemd юнит
├── setup-telegram-bot.sh     # Скрипт установки
└── README.md                 # Подробная документация
```

##### Ключевые настройки в .env файле

Пример включает 50+ реальных настроек:
- **Telegram**: токен бота, webhook, секреты
- **База данных**: PostgreSQL с пулом соединений
- **Кэш**: Redis с паролем и настройками
- **API ключи**: OpenAI, Google Maps, Stripe, SendGrid, Twilio
- **Мониторинг**: Sentry DSN, логирование, метрики
- **Безопасность**: JWT, шифрование, сессии, CSRF
- **Email**: SMTP настройки
- **Хранение**: AWS S3 credentials
- **Производительность**: лимиты, таймауты, ресурсы

##### Процесс миграции

**Вариант A: Systemd (Linux хост)**

1. **Подготовка .env файла:**
   ```bash
   cp env-example.txt .env
   # Заполнить реальными значениями
   ```

2. **Конвертация в секреты:**
   ```bash
   sudo ./convert-env-to-secrets.sh .env secrets@host
   ```

3. **Настройка systemd сервиса:**
   ```ini
   [Service]
   LoadCredential=telegram-bot-token:/run/secrets/telegram-bot-token
   LoadCredential=database-password:/run/secrets/database-password
   # ... 48 других секретов
   Environment=CREDENTIALS_DIR=/run/credentials/%n
   ```

4. **Код приложения:**
   ```python
   class SecretsManager:
       def get_secret(self, name: str) -> str:
           credentials_dir = os.environ['CREDENTIALS_DIR']
           with open(f'{credentials_dir}/{name}', 'r') as f:
               return f.read().strip()

   # Использование
   secrets = SecretsManager()
   bot_token = secrets.get_secret('telegram-bot-token')
   ```

**Вариант B: Docker Compose (рекомендуется)**

1. **Подготовка секретов:**
   ```bash
   cp env-example.txt .env
   sudo ./convert-env-to-secrets.sh .env secrets@host
   ```

2. **Docker развертывание:**
   ```bash
   sudo ./docker-deploy.sh deploy
   ```

3. **Проверка:**
   ```bash
   curl http://localhost:8080/health
   docker-compose logs -f telegram-bot
   ```

4. **Код приложения (автоматическая загрузка):**
   ```python
   # Секреты загружаются автоматически из /app/secrets/
   secrets = SecretsManager()  # Поддерживает Docker volumes
   config = secrets.get_config()  # Все 50+ секретов
   ```

#### Тестирование и QA

Пример прошел комплексное тестирование:

- ✅ **Синтаксис**: Python и Shell код валиден
- ✅ **Функциональность**: SecretsManager работает корректно
- ✅ **Docker compatibility**: Образы собираются и конфигурация валидна
- ✅ **Error handling**: Graceful degradation при отсутствии зависимостей
- ✅ **Security**: Нет уязвимостей, секреты защищены

**Исправленные ошибки:**
- HEALTH_CHECK → HEALTHCHECK в Dockerfile
- Обsolete version в docker-compose.yml
- Обязательные импорты заменены на опциональные
- Добавлены проверки доступности модулей

##### Преимущества решения

- **Безопасность**: Все секреты зашифрованы, никогда не попадают на диск в plaintext
- **Производительность**: Доступ к секретам из RAM, без I/O задержек
- **Масштабируемость**: Легко добавить новые секреты без изменения кода
- **Аудит**: Полное логирование всех операций через systemd и auditd
- **Ротация**: Атомарная замена секретов без перезапуска приложения

##### Команды управления

```bash
# Установка
sudo ./setup-telegram-bot.sh

# Ротация секрета
sudo ./scripts/rotate-secret.sh telegram-bot-token 'new_token'

# Мониторинг
sudo journalctl -u telegram-bot.service -f
sudo systemctl status secrets-decrypt.service
```

### 7.2 Другие сценарии использования

Аналогичный подход применим для:

- **Веб-приложения**: Django/Flask с множеством API ключей
- **Микросервисы**: Каждый сервис со своими секретами БД и API
- **CI/CD пайплайны**: Секреты для развертывания и тестирования
- **Базы данных**: Пароли администраторов и приложений
- **Облачные сервисы**: API ключи для AWS, GCP, Azure

#### Типичные паттерны интеграции

1. **Монолитное приложение**: Один .service файл со всеми секретами
2. **Микросервисы**: Каждый сервис имеет свой набор секретов
3. **Shared секреты**: Общие секреты (API ключи) доступны нескольким сервисам
4. **Environment-specific**: Разные секреты для dev/staging/prod

---

## 8. Обслуживание системы

### 8.1 Мониторинг состояния

#### Проверка работоспособности сервиса
```bash
# Статус systemd сервиса
sudo systemctl status secrets-decrypt.service

# Проверка расшифрованных секретов
ls -la /run/secrets/

# Количество активных секретов
ls /run/secrets/ | wc -l
```

#### Аудит доступа к секретам
```bash
# Логи systemd
sudo journalctl -u secrets-decrypt.service -f

# Аудит логов системы
sudo ausearch -m all | grep secrets
```

#### Метрики производительности
```bash
# Использование RAM сервисом
sudo systemctl show secrets-decrypt.service -p MemoryCurrent

# Время работы сервиса
sudo systemctl show secrets-decrypt.service -p ActiveEnterTimestamp
```

### 8.2 Резервное копирование секретов

#### Создание резервной копии
```bash
# Создание архива с шифрованием
sudo tar -czf secrets-backup-$(date +%Y%m%d).tar.gz /etc/secrets.encrypted/
gpg --encrypt --recipient backup@example.com secrets-backup-*.tar.gz

# Хранение в защищенном месте
sudo mv secrets-backup-*.tar.gz.gpg /var/backups/secrets/
```

#### Восстановление из резервной копии
```bash
# Расшифровка и распаковка
gpg --decrypt secrets-backup-20251221.tar.gz.gpg > secrets-backup.tar.gz
sudo tar -xzf secrets-backup.tar.gz -C /

# Перезапуск сервиса
sudo systemctl restart secrets-decrypt.service
```

### 8.3 Ротация GPG ключей

#### Добавление нового GPG ключа
```bash
# Создание нового ключа
gpg --full-generate-key
# Идентификатор: secrets-new@host

# Перешифровка всех секретов
for file in /etc/secrets.encrypted/*.gpg; do
    secret_name=$(basename "$file" .gpg)
    gpg --decrypt "$file" | gpg --encrypt --recipient secrets-new@host \
        --output "${file}.new"
    sudo mv "${file}.new" "$file"
done

# Обновление systemd сервиса
sudo systemctl restart secrets-decrypt.service
```

#### Удаление старого ключа
```bash
# Только после подтверждения работы с новым ключом
gpg --delete-secret-key secrets@host
gpg --delete-key secrets@host
```

### 8.4 Масштабирование и оптимизация

#### Производительность
```bash
# Мониторинг нагрузки
sudo iotop -o -d 5

# Оптимизация размера tmpfs
sudo mount -o remount,size=50M tmpfs /run/secrets
```

#### Распределенные развертывания
```bash
# Синхронизация секретов между серверами
rsync -avz --delete /etc/secrets.encrypted/ backup-server:/etc/secrets.encrypted/

# Автоматическая ротация на всех серверах
for server in server1 server2 server3; do
    ssh $server sudo systemctl restart secrets-decrypt.service
done
```

---

## Приложения

### Приложение A: Глоссарий

| Термин | Определение |
|--------|-------------|
| Секрет | Конфиденциальная информация (пароль, ключ, токен) |
| tmpfs | Файловая система в оперативной памяти |
| GPG | GNU Privacy Guard - система шифрования |
| systemd credentials | Механизм передачи секретов в сервисы |
| DynamicUser | Автоматическое создание пользователей systemd |

### Приложение B: Акронимы и сокращения

| Акроним | Расшифровка |
|---------|-------------|
| ACL | Access Control List |
| GPG | GNU Privacy Guard |
| KMS | Key Management Service |
| RAM | Random Access Memory |
| SELinux | Security-Enhanced Linux |

### Приложение C: Индекс

- Аудит: 3.3, 8.1
- GPG: 3.2, 5.1, 8.3
- Дешифрация: 2.1, 4.2
- Мониторинг: 8.1
- Обслуживание: 8.0
- Примеры использования: 7.1, 7.2
- Резервное копирование: 8.2
- Ротация: 2.2, 4.3, 8.3
- Секреты: 2.1, 4.1
- systemd: 3.3, 4.4
- Telegram бот: 7.1
- Установка: 3.2
- Устранение неисправностей: 5.1

---

*Конец документа*
