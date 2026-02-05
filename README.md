# FiYou AI
FiYou AI — це розумний додаток для відстеження харчування, розроблений, щоб допомогти користувачам контролювати свій раціон та досягати цілей у сфері здоров'я. Додаток поєднує мобільний фронтенд на базі Flutter із бекендом на Python FastAPI, використовуючи AI для таких передових функцій, як аналіз страв по фото та генерація персоналізованих рецептів.

## Key Features

* **AI Meal Analysis**: Зробіть фото вашої страви, і AI проаналізує її, щоб надати оцінку калорій, білків, жирів та вуглеводів.
* **Intelligent Recipe Generation**: Отримуйте персоналізовані рецепти, згенеровані AI на основі ваших залишкових денних калорій та дієтичних цілей, разом із зображенням, створеним AI.
* **Comprehensive Food Tracking**:
    * **Food Search**: Знаходьте продукти в гібридній базі даних, яка поєднує локальний список продуктів із глобальною базою OpenFoodFacts.
    * **Manual Entry**: Логуйте прийоми їжі вручну, вказуючи їхню харчову цінність.
* **Daily Health Dashboard**: Відстежуйте щоденне споживання калорій, макронутрієнтів (білків, жирів, вуглеводів) та споживання води відповідно до ваших особистих цілей.
* **In-App Stories**: Переглядайте динамічний, цікавий контент (історії), який керується через спеціальну адмін-панель.
* **Progress Analytics**: Візуалізуйте щотижневе споживання калорій за допомогою динамічних графіків та отримуйте щотижневі підсумки й поради на основі ваших харчових звичок за допомогою AI.
* **User Profile Customization**: Керуйте своїми особистими даними, включаючи вагу, зріст, вік та рівень активності. Ви також можете завантажити власний аватар профілю.
* **Web Admin Panel**: Вбудований веб-інтерфейс для системних адміністраторів для моніторингу активності користувачів, перегляду статистики та керування історіями в додатку.

## Technology Stack

* **Backend**:
    * **Framework**: FastAPI
    * **Database & Auth**: Supabase
    * **AI**: OpenAI (GPT-4o для аналізу та тексту рецептів, DALL-E 3 для зображень рецептів)
    * **Deployment**: Docker, Uvicorn
    * **Libraries**: Pydantic, Jinja2, Rich, `python-jose`

* **Frontend (Mobile App)**:
    * **Framework**: Flutter
    * **Language**: Dart
    * **Key Packages**: `http`, `camera`, `fl_chart`, `shared_preferences`, `image_picker`

## Repository Structure

Проєкт організований у дві основні директорії:

* `backend/`: Містить додаток на Python FastAPI. Сюди входять усі API endpoints, логіка взаємодії з базою даних, інтеграції з AI-сервісами та шаблони адмін-панелі.
* `flutter_app/`: Вихідний код мобільного додатка на Flutter, який виступає клієнтською частиною для користувача.

## Setup and Installation

### Prerequisites

* Flutter SDK
* Docker та Docker Compose

### Backend Setup

1.  **Перейдіть до директорії backend:**
    ```bash
    cd backend
    ```

2.  **Створіть файл оточення:**
    Створіть файл `.env` у директорії `backend` і додайте наступні змінні оточення. Вони необхідні для підключення до Supabase, OpenAI та налаштування адмін-панелі.
    ```env
    # Supabase credentials
    SUPABASE_URL=YOUR_SUPABASE_URL
    SUPABASE_SERVICE_ROLE_KEY=YOUR_SUPABASE_SERVICE_KEY
    SUPABASE_JWT_SECRET=YOUR_SUPABASE_JWT_SECRET

    # OpenAI API Key
    OPENAI_API_KEY=YOUR_OPENAI_API_KEY

    # Admin Panel credentials
    ADMIN_USERNAME=admin
    ADMIN_PASSWORD=admin
    ```

3.  **Запустіть за допомогою Docker Compose:**
    ```bash
    docker-compose up --build
    ```
    Бекенд-сервер буде доступний за адресою `http://localhost:8000`. Доступ до адмін-панелі можна отримати за адресою `http://localhost:8000/`.

### Flutter App Setup

1.  **Перейдіть до директорії додатка:**
    ```bash
    cd flutter_app
    ```

2.  **Встановіть залежності:**
    ```bash
    flutter pub get
    ```

3.  **Налаштуйте API Base URL:**
    Базовий URL для API налаштовується у `flutter_app/lib/services/auth_service.dart`. За замовчуванням він вказує на розгорнуту версію (`https://fiyouai.onrender.com`).
    Для локальної розробки змініть змінну `baseUrl`, щоб вона вказувала на IP-адресу вашої локальної машини та порт `8000`.
    ```dart
    // У lib/services/auth_service.dart
    static const String baseUrl = 'http://<YOUR_LOCAL_IP_ADDRESS>:8000';
    ```
    

4.  **Запустіть додаток:**
    Підключіть пристрій або запустіть емулятор і виконайте:
    ```bash
    flutter run
    ```

### Сетап для розробки:
1.0 Локальний запуск backend
  ```bash
    uvicorn main:app --host 0.0.0.0 --port 8000
  ```
  1.1 Глобальний запуск backend
  ```bash
    Через Render
  ```

2.0 Локальний запуск frontend
  ```bash
    flutter run
  ```
2.1 Глобальний запуск frontend
  ```bash
    flutter run --release
  ```

3. Подивитися статус (що змінено)	
```
git status
```
4. Переключитися на розробку	
```
git checkout develop
```
5. Зберегти зміни 
```
git add . 
git commit -m "text"
```
6. Залити на сервер (без деплою)	
```
git push origin develop
```
7. Оновити Продакшн 
```
git checkout main
git merge develop
git push origin main
```
