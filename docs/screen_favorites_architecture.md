# Модуль «Избранное» (Favorites) — архитектура FlutterFlow с Optimistic Update

Экран избранного + кнопка-сердечко в каталоге с мгновенным откликом
(оптимистичное обновление) и откатом при ошибке. Опирается на миграцию 0023:
VIEW `favorites_with_car_details` (RLS свои) + RPC `toggle_favorite`.

Репозиторий: `favorites_repository.dart` (`toggle`, `favoriteCarIds`).

---

## 1. App State

| Переменная (App State) | Тип | Назначение |
|---|---|---|
| `myFavoriteCarIds` | List<String> | ID машин в избранном текущего пользователя |

Заполняется при старте сессии / входе: Backend Query `favorites` (select car_id)
→ список car_id → `myFavoriteCarIds`. Это единый источник правды для состояния
всех сердечек в приложении (каталог, карточка, избранное).

> Почему App State, а не Page State: сердечко есть на РАЗНЫХ экранах (каталог,
> детальная, избранное). Общий App State держит их синхронными — лайк в каталоге
> сразу отражается на карточке и в списке избранного.

---

## 2. Экран избранного (Favorites Screen)

### Источник — Supabase Query к VIEW

- View: `favorites_with_car_details`
- Filter: `user_id` **Equal to** `currentUser.uid`
- Order by: `created_at` **Descending**

VIEW (`security_invoker = true`) наследует RLS `favorites` — вернёт только свои.
Отдаёт всё для карточки: brand/model/year/city/цены/rating_avg/car_photo.

### Widget Tree

```
FavoritesScreen (Column)
├── (пусто) EmptyState "В избранном пока пусто"   if список пуст
└── ListView ← Query favorites_with_car_details
    └── FavoriteCard (tap → CarDetailScreen(carId))
        ├── CarPhoto (car_photo)
        ├── Text "{brand} {model}, {year}"
        ├── Text цена (по is_for_sale/is_for_rent)
        ├── RatingChip (rating_avg ⭐ + reviews_count)
        └── HeartButton (всегда «залайкано» здесь) → §3
              // на экране избранного сердечко активно; тап убирает из избранного
```

---

## 3. Кнопка-сердечко — Action Flow с Optimistic Update

Сердечко есть в каталоге, на детальной карточке и в избранном. Логика единая.

**Состояние сердечка (визуал):**
`myFavoriteCarIds.contains(carId)` → залито (❤️) / контур (🤍).

### Оптимистичный алгоритм

```
ТАП по сердечку (carId):

1. Определяем текущее состояние ДО изменения:
   wasFavorite = myFavoriteCarIds.contains(carId)

2. ОПТИМИСТИЧНО меняем App State СРАЗУ (до сети):
   ├─ если wasFavorite   → Remove carId from myFavoriteCarIds
   └─ если !wasFavorite  → Add carId to myFavoriteCarIds
   // UI перерисуется мгновенно — сердечко откликается без задержки

3. Backend Call → Supabase RPC toggle_favorite(p_car_id = carId)
      → результат: bool serverState (true=добавлено, false=убрано)

4a. On Success:
      // Сверяем серверное состояние с оптимистичным (обычно совпадает).
      // Приводим App State к серверному факту — защита от рассинхрона:
      ├─ serverState == true  и carId НЕ в списке → Add carId
      └─ serverState == false и carId В списке     → Remove carId
      // (если всё совпало — действий не требуется)
      // (Опц.) если открыт Экран избранного — Refresh, чтобы удалённая
      //  карточка исчезла из списка.

4b. On Failure (RPC упал: сеть/сервер):
      // ОТКАТ (Rollback): возвращаем App State в состояние ДО тапа
      ├─ если wasFavorite   → Add carId (вернуть, т.к. на шаге 2 удалили)
      └─ если !wasFavorite  → Remove carId (убрать, т.к. на шаге 2 добавили)
      SnackBar "Не удалось обновить избранное. Попробуйте ещё раз."
```

### Схема состояний

```
        тап
         │
   [шаг 2: оптимистично меняем App State] ──► UI обновился мгновенно
         │
   [шаг 3: RPC toggle_favorite]
         ├── Success ──► сверить с serverState, закрепить
         └── Failure ──► ОТКАТ к состоянию до тапа + SnackBar
```

**Суть паттерна:** пользователь видит реакцию мгновенно (шаг 2), а сеть работает
в фоне. Если запрос упал — состояние откатывается (шаг 4b), как будто тапа не было.
Так UI не «залипает» на спиннере и остаётся отзывчивым даже при плохой сети.

### Почему сверка на Success (шаг 4a) нужна

`toggle_favorite` возвращает ФАКТИЧЕСКОЕ состояние на сервере. В редком случае
(параллельный тап с другого устройства, гонка) оптимистичное предположение может
разойтись с сервером — шаг 4a приводит App State к серверной правде. Это дешёвая
страховка от рассинхрона между устройствами.

---

## 4. Инициализация состояния сердечек

При входе / старте: Backend Query `favorites` (select `car_id`, filter uid)
→ записать список в `myFavoriteCarIds`. Дальше все сердечки в каталоге и на
карточках читают состояние из App State (без запроса на каждую карточку).

> Репозиторный аналог: `favoritesRepository.favoriteCarIds()` возвращает
> Set<String> одним запросом — ровно для этой инициализации.

---

## 5. Гость (неавторизованный)

Тап по сердечку без авторизации → SnackBar «Войдите, чтобы добавить в избранное»
→ Navigate LoginScreen. RPC не вызываем (он требует auth.uid()).

---

## 6. Сводка

| Элемент | Механизм | Опора |
|---|---|---|
| Экран избранного | Query VIEW favorites_with_car_details (uid) | 0023, RLS |
| Состояние сердечек | App State myFavoriteCarIds | — |
| Тап (оптимистично) | локальное изменение App State → RPC toggle_favorite | 0023 RPC |
| Откат | On Failure возврат App State к состоянию до тапа | — |
| Инициализация | Query favorites (car_id) при входе | favoriteCarIds() |

**Плюс паттерна:** мгновенный отклик UI, устойчивость к плохой сети.
**Защита:** RPC серверный (RLS свои); при сбое — чистый откат без «залипания».
```
