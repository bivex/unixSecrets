#!/usr/bin/env python3
"""
Пример приложения, которое использует секреты через systemd credentials
"""
import os

def main():
    # Получаем путь к credentials
    credentials_dir = os.environ.get('CREDENTIALS_DIR', '/run/credentials/example-app.service')

    # Читаем секреты
    try:
        with open(f'{credentials_dir}/db_password', 'r') as f:
            db_password = f.read().strip()

        with open(f'{credentials_dir}/jwt_key', 'r') as f:
            jwt_key = f.read().strip()

        print("Application started successfully")
        print(f"Database password loaded: {len(db_password)} characters")
        print(f"JWT key loaded: {len(jwt_key)} characters")

        # Здесь будет логика приложения
        # Например, подключение к БД с db_password
        # Или использование jwt_key для подписи токенов

    except FileNotFoundError as e:
        print(f"Error: Secret file not found: {e}")
        exit(1)
    except Exception as e:
        print(f"Error loading secrets: {e}")
        exit(1)

if __name__ == "__main__":
    main()
