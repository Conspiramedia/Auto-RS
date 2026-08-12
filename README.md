# Auto.RS — авто-маркетплейс (Сербия)

Мобильный маркетплейс-посредник для **продажи** и **посуточной аренды** автомобилей.
Платформа своих машин не имеет — связывает продавцов/арендодателей и покупателей/арендаторов.

## Технический стек

- **Фронтенд:** FlutterFlow (Low-code, сборка под iOS + Android) / Flutter (Dart) при экспорте.
- **Бэкенд + БД:** Supabase (PostgreSQL). Архитектура «толстого бэкенда» — вся бизнес-логика на сервере (SQL/RPC/триггеры).

## Два бизнес-блока

1. **Купля/Продажа** — классифайд с жёсткой фильтрацией.
2. **Посуточная аренда** — прокат с календарём свободных дат (модель «Заявка → Ручное подтверждение владельцем»).

## Структура репозитория

```
Auto.RS/
├── supabase/
│   └── migrations/                 # SQL-миграции (применять по порядку)
│       ├── 0001_extensions_and_enums.sql
│       ├── 0002_table_profiles.sql
│       ├── 0003_table_cars.sql
│       ├── 0004_table_car_images.sql
│       ├── 0005_table_bookings.sql
│       ├── 0006_functions_and_triggers.sql
│       └── 0007_rls_policies.sql
├── lib/
│   ├── main.dart                   # точка входа, init Supabase
│   ├── core/config/                # supabase_config, app_constants
│   └── data/
│       ├── enums/                  # зеркала ENUM-типов БД
│       ├── models/                 # зеркала таблиц
│       └── repositories/           # доступ к Supabase (cars, bookings)
├── pubspec.yaml
├── .env.example                    # шаблон секретов
└── .gitignore
```

## Развёртывание бэкенда (Supabase)

1. Создайте проект на [supabase.com](https://supabase.com).
2. В **SQL Editor** выполните миграции из `supabase/migrations/` **строго по порядку** (0001 → 0007).
3. Скопируйте `Project URL` и `anon public` ключ (Settings → API).

## Настройка клиента (Flutter)

1. Скопируйте `.env.example` в `.env` и заполните `SUPABASE_URL`, `SUPABASE_ANON_KEY`.
2. Положите шрифты `Inter-*.ttf` в `assets/fonts/` (поддержка кириллицы + латиницы).
3. Установите зависимости и запустите:

```bash
flutter pub get
flutter run
```

## Ключевые архитектурные решения

- **Финансы считает сервер.** `total_price`, `platform_commission` (10%) вычисляет триггер `calc_booking_totals` — клиент цену подменить не может.
- **Антиовербукинг.** Даты блокирует только `confirmed`-бронь. Гарантия — `EXCLUDE`-констрейнт (GiST) + RPC `is_car_available` для UX.
- **Депозит** (`deposit_amount`) хранится в объявлении, комиссией не облагается, показывается в чеке отдельной строкой.
- **RLS включён на всех таблицах.** Доступ по `auth.uid()`.
- **Валюта БД — EUR.** Показ в RSD — на клиенте (конвейер отображения).
- **Двуалфавитность.** Нормализация текста (`unaccent` + `pg_trgm`) для поиска по кириллице/латинице; PostGIS для поиска «рядом».
