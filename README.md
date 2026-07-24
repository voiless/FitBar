# FitBar

[Русский](#русский) | [English](#english)

---

## Русский

FitBar — нативное macOS-приложение для тренировок, написанное на SwiftUI.

### Возможности

- Локальная библиотека упражнений на основе данных ExerciseDB.
- Интерфейс на русском и английском языках.
- Поиск, фильтрация и сортировка каталога упражнений.
- Карточки упражнений, подробные инструкции и пользовательские сборки.
- Тренировка из menu bar: таймер подхода, повторы, вода и прогресс за день.
- Вкладки активности, статистики, дневника, целей, ИИ-помощника и аккаунта.
- Локальный профиль пользователя: рост, вес, пол, тема, язык и цели.
- Опциональный ИИ-помощник через Groq: проверка ключа, обновляемый каталог моделей и выбор активной модели для планов.

### Приватность и хранение

FitBar сейчас работает без серверной базы данных.

- Firebase, Firestore, Supabase и облачная синхронизация не подключены.
- Каталог упражнений поставляется внутри приложения.
- Пользовательские данные хранятся локально в `~/Library/Application Support/FitBar/`.
- Groq API-ключ вводится пользователем во вкладке «ИИ-помощник» и хранится локально отдельно от экспортируемых данных FitBar.
- При полном стирании данных приложения локально сохранённый Groq API-ключ тоже удаляется.
- Репозиторий не содержит API-ключей и пользовательских данных.

### Сборка

Достаточно Command Line Tools, Xcode не требуется.

```bash
./scripts/make_app.sh
open /Applications/FitBar.app
```

Чтобы выбрать другой путь для `.app`:

```bash
FITBAR_APP_PATH=/Applications/FitBar.app ./scripts/make_app.sh
```

### Разработка

```bash
swift build
swift run fitbar-tests
```

### Структура проекта

- `Sources/FitBar` — точка входа приложения.
- `Sources/FitBarKit` — модели, хранение, интерфейс и ресурсы.
- `Tests/FitBarTests` — консольный тестовый раннер.
- `scripts/make_app.sh` — сборка release-версии и упаковка `.app`.

### Источник данных

Данные упражнений основаны на [ExerciseDB](https://oss.exercisedb.dev) через
[exercises-dataset](https://github.com/hasaneyldrm/exercises-dataset).

---

## English

FitBar is a native macOS fitness tracker built with SwiftUI.

### Features

- Local exercise library based on ExerciseDB data.
- Russian and English interface.
- Search, filtering and sorting for the exercise catalog.
- Exercise cards, detailed instructions and custom workout collections.
- Menu bar workout flow with set timer, repetitions, water tracking and daily progress.
- Activity, statistics, diary, goals, AI assistant and account screens.
- Local user profile with height, weight, gender, theme, language and goal values.
- Optional Groq-powered AI assistant with key validation, refreshable model catalog and active model selection for plans.

### Privacy and Storage

FitBar currently works without a server database.

- No Firebase, Firestore, Supabase or cloud sync is included.
- The exercise catalog is bundled with the application.
- User data is stored locally in `~/Library/Application Support/FitBar/`.
- The Groq API key is entered by the user in the AI assistant screen and stored locally outside exported FitBar data.
- Clearing all application data also removes the locally saved Groq API key.
- The repository does not contain API keys or user data.

### Build

Command Line Tools are enough; Xcode is not required.

```bash
./scripts/make_app.sh
open /Applications/FitBar.app
```

To choose another output path:

```bash
FITBAR_APP_PATH=/Applications/FitBar.app ./scripts/make_app.sh
```

### Development

```bash
swift build
swift run fitbar-tests
```

### Project Structure

- `Sources/FitBar` — application entry point.
- `Sources/FitBarKit` — models, storage, UI and bundled resources.
- `Tests/FitBarTests` — command-line test runner.
- `scripts/make_app.sh` — release build and `.app` bundle packaging.

### Data Source

Exercise data is based on [ExerciseDB](https://oss.exercisedb.dev) through
[exercises-dataset](https://github.com/hasaneyldrm/exercises-dataset).
