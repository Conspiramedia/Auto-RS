# Личный кабинет бронирований — архитектура для FlutterFlow

Два списка на одном экране `BookingsScreen` через TabBar:
- **Вкладка «Мои поездки»** — брони, где пользователь клиент (арендатор).
- **Вкладка «Мой автопарк»** — брони на машины, которыми пользователь владеет.

Вся смена статусов и движение средств — на сервере (RPC). Экран только
показывает списки и вызывает RPC, перехватывая ошибки в SnackBar.

---

## 1. Supabase-запросы для списков

### 1.1. Вкладка Клиента — брони, где `customer_id = auth.uid()`

**Способ (рекомендуемый): View Query по таблице `bookings`.**

- Table: `bookings`
- Filter: `customer_id` **Equal to** `Authenticated User → id` (`auth.uid()`)
- Order by: `created_at` **Descending**

RLS-политика `bookings_select_involved` уже разрешает клиенту видеть свои брони,
поэтому фильтр по `customer_id` безопасен и однозначен.

**Данные машины для карточки** (brand/model/фото). Два варианта:
- **A (просто):** в списке показываем базовое из `bookings` (даты, суммы, статус),
  а `brand/model` подтягиваем отдельным запросом `cars` по `car_id` внутри
  компонента-строки (Component с параметром `carId`).
- **B (одним запросом):** создать в Supabase **VIEW** `bookings_with_car`,
  которая уже содержит JOIN `bookings → cars`, и запрашивать её.
  Рекомендуется для производительности (см. раздел 4 — SQL View).

### 1.2. Вкладка Владельца — брони на машины, где `cars.user_id = auth.uid()`

Проблема: во FlutterFlow базовый Supabase-Query не делает произвольный JOIN
с фильтром по чужой таблице. Решается одним из способов:

**Способ 1 (рекомендуемый) — SQL VIEW с JOIN (раздел 4).**
Создаём VIEW `bookings_with_car`, где есть колонка `owner_id` (= `cars.user_id`).
Тогда во FlutterFlow:
- Table/View: `bookings_with_car`
- Filter: `owner_id` **Equal to** `Authenticated User → id`
- Order by: `start_date` **Ascending** (ближайшие заезды сверху)

**Способ 2 — RPC-функция** `get_owner_bookings()` возвращает `setof bookings_with_car`
(фильтрует по `auth.uid()` внутри). Вызывается как Backend Call.

**Почему это работает по безопасности:** RLS `bookings_select_involved` уже
ограничивает выборку владельцем машины, поэтому даже без фильтра на клиенте
владелец не увидит чужие брони. Фильтр `owner_id` — для удобства и явности.

---

## 2. Условная видимость кнопок (по статусу брони)

Значение статуса — поле `status` строки брони.

### Вкладка Клиента

| Кнопка | Видна при статусе | RPC |
|---|---|---|
| **Оплатить** | `confirmed` | `pay_booking` |
| **Отменить бронь** | `pending`, `confirmed`, `paid` | `cancel_booking` |

Conditional Visibility:
- «Оплатить»: `booking.status == 'confirmed'`
- «Отменить бронь»: `booking.status == 'pending' OR == 'confirmed' OR == 'paid'`

Статусы `rejected` / `cancelled` / `completed` — кнопок нет (терминальные),
показываем только бейдж статуса.

### Вкладка Владельца

| Кнопка | Видна при статусе | RPC |
|---|---|---|
| **Подтвердить** | `pending` | `confirm_booking` |
| **Отклонить** | `pending` | `reject_booking` |
| **Завершить аренду** | `paid` | `complete_booking` |

Conditional Visibility:
- «Подтвердить»: `booking.status == 'pending'`
- «Отклонить»: `booking.status == 'pending'`
- «Завершить аренду»: `booking.status == 'paid'`

---

## 3. Action Flow кнопок (с обработкой ошибок)

Общий шаблон для ВСЕХ кнопок ниже. Ключевой приём: RPC-вызов оборачиваем так,
чтобы при EXCEPTION на сервере (например, овербукинг в `confirm_booking`)
показать пользователю текст ошибки.

### Общий шаблон обработки ошибок во FlutterFlow

Для каждой RPC-кнопки:
1. (Опц.) Set Page State `isLoading = true` (заблокировать кнопку/показать спиннер).
2. **Backend Call → Supabase RPC** (нужная функция), параметр `booking_id = booking.id`.
   - У Action-ноды Backend Call включить обработку результата:
     ветки **On Success** и **On Failure** (в FlutterFlow — через
     "Action Output" + проверка, либо через отдельную обработку ошибки).
3. **On Success:**
   - Set `isLoading = false`
   - SnackBar с сообщением об успехе (см. тексты ниже)
   - **Refresh** списка (Refresh Database Request текущего Query),
     чтобы кнопки перерисовались под новый статус.
4. **On Failure (ошибка RPC):**
   - Set `isLoading = false`
   - SnackBar с текстом ошибки: значение **`Action Error Message`**
     (комбайн-переменная, куда FlutterFlow кладёт текст исключения PostgreSQL,
     например «Даты уже заняты другой подтверждённой бронью на эту машину»).

> Где взять текст ошибки: в SnackBar → Message → Set from Variable →
> **Action Outputs → [имя Backend Call ноды] → Error Message**.
> Именно туда прокидывается `RAISE EXCEPTION ... USING errcode/message` из RPC.

---

### 3.1. Клиент → «Оплатить» (`pay_booking`)

```
1. isLoading = true
2. RPC pay_booking(booking_id = booking.id)
3a. Success:
      isLoading = false
      SnackBar "Бронь оплачена. Ожидайте начала аренды."
      Refresh Query "Мои поездки"
3b. Failure:
      isLoading = false
      SnackBar (Action Error Message)
      // типичные тексты: "Бронь нельзя оплатить: текущий статус = ...",
      //                  "Недостаточно прав: оплатить бронь может только её создатель"
```

### 3.2. Клиент → «Отменить бронь» (`cancel_booking`)

```
0. (Реком.) Confirm Dialog "Отменить бронь? Возможен штраф при поздней отмене."
1. isLoading = true
2. RPC cancel_booking(booking_id = booking.id)
3a. Success:
      isLoading = false
      SnackBar "Бронь отменена."
      Refresh Query "Мои поездки"
      // сервер сам создаст refund/penalty-транзакции по правилам <24ч/>24ч
3b. Failure:
      isLoading = false
      SnackBar (Action Error Message)
      // напр. "Бронь нельзя отменить: текущий статус = completed"
```

### 3.3. Владелец → «Подтвердить» (`confirm_booking`)

```
1. isLoading = true
2. RPC confirm_booking(booking_id = booking.id)
3a. Success:
      isLoading = false
      SnackBar "Бронь подтверждена. Даты заблокированы."
      Refresh Query "Мой автопарк"
3b. Failure:
      isLoading = false
      SnackBar (Action Error Message)
      // ГЛАВНЫЙ кейс овербукинга:
      // "Даты уже заняты другой подтверждённой бронью на эту машину"
      // также: "Бронь нельзя подтвердить: текущий статус = ...",
      //        "Недостаточно прав: подтвердить бронь может только владелец машины"
```

### 3.4. Владелец → «Отклонить» (`reject_booking`)

```
0. (Реком.) Confirm Dialog "Отклонить заявку?"
1. isLoading = true
2. RPC reject_booking(booking_id = booking.id)
3a. Success:
      isLoading = false
      SnackBar "Заявка отклонена."
      Refresh Query "Мой автопарк"
3b. Failure:
      isLoading = false
      SnackBar (Action Error Message)
```

### 3.5. Владелец → «Завершить аренду» (`complete_booking`)

```
1. isLoading = true
2. RPC complete_booking(booking_id = booking.id)
3a. Success:
      isLoading = false
      SnackBar "Аренда завершена. Выплата будет перечислена."
      Refresh Query "Мой автопарк"
      // сервер переведёт payout из pending в completed
3b. Failure:
      isLoading = false
      SnackBar (Action Error Message)
      // напр. "Аренду нельзя завершить: текущий статус = confirmed"
```

---

## 4. SQL VIEW для списков (упрощает запросы во FlutterFlow)

Рекомендуется добавить отдельной миграцией. VIEW отдаёт бронь вместе с данными
машины и владельцем, наследует RLS базовых таблиц (`security_invoker`).

```sql
-- security_invoker = true → VIEW применяет RLS вызывающего пользователя,
-- то есть каждый видит ровно то, что разрешают политики bookings/cars.
create or replace view public.bookings_with_car
with (security_invoker = true)
as
select
  b.id,
  b.car_id,
  b.customer_id,
  c.user_id            as owner_id,       -- владелец машины (для фильтра вкладки владельца)
  c.brand,
  c.model,
  c.year,
  c.city,
  b.start_date,
  b.end_date,
  b.rent_subtotal,
  b.platform_commission,
  b.deposit_amount,
  b.total_price,
  b.currency,
  b.status,
  b.created_at
from public.bookings b
join public.cars c on c.id = b.car_id;
```

Тогда:
- Вкладка Клиента: Query `bookings_with_car`, filter `customer_id = auth.uid()`.
- Вкладка Владельца: Query `bookings_with_car`, filter `owner_id = auth.uid()`.

---

## 5. Резюме по маппингу «статус → доступные действия»

| Статус | Клиент видит | Владелец видит |
|---|---|---|
| `pending` | Отменить | Подтвердить, Отклонить |
| `confirmed` | Оплатить, Отменить | — |
| `paid` | Отменить | Завершить аренду |
| `rejected` | — (бейдж) | — (бейдж) |
| `cancelled` | — (бейдж) | — (бейдж) |
| `completed` | — (бейдж) | — (бейдж) |
