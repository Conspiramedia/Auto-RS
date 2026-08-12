# Гейт верификации (Verification Gate) на кнопке «Забронировать» — архитектура FlutterFlow

Блокирует создание брони для неверифицированных пользователей. Опирается на
миграцию 0019 (`profiles.verification_status`, `verification_comment`) и экран
KYC. Custom Function: `canUserBookCar(verificationStatus)` →
`lib/features/rent/utils/can_user_book_car.dart`.

> ВАЖНО: гейт на клиенте — это UX. Реальную защиту даёт СЕРВЕР (см. §4).
> Клиентская проверка не заменяет серверную — её можно обойти в обход UI.

---

## 1. Action Flow кнопки «Забронировать» (разветвление)

Предпосылка: на Car Detail Screen в On Page Load загружен профиль текущего
пользователя `myProfile` (Backend Query profiles по `id = currentUser.uid`),
из него доступен `verification_status`.

```
КНОПКА «Забронировать»:

1. Проверка авторизации:
   currentUser == null (гость) ?
   └─ ДА → SnackBar "Войдите, чтобы забронировать"
           → Navigate To LoginScreen → STOP

2. Проверка выбранных дат (из календаря):
   selStart == null OR selEnd == null ?
   └─ ДА → SnackBar "Выберите даты аренды" → STOP

3. Проверка верификации — Conditional Action по myProfile.verification_status:

   ├─ 'verified'
   │     → canUserBookCar(status) == true
   │     → ПРОПУСК на бронирование:
   │        RPC is_car_available → Insert bookings (pending)  // как в car_detail flow
   │
   ├─ 'pending'
   │     → БЛОКИРОВКА (мягкая):
   │        SnackBar / Dialog "Ваши документы на проверке.
   │        Бронирование станет доступно после верификации."
   │        → STOP  (KYC-шит НЕ открываем — юзер уже подал документы)
   │
   └─ 'unverified' OR 'rejected'
         → БЛОКИРОВКА (с призывом к действию):
            Open Bottom Sheet  KYCGateBottomSheet
              params: status = myProfile.verification_status
                      comment = myProfile.verification_comment
            → STOP
```

### Быстрый кондишен через canUserBookCar

`canUserBookCar(myProfile.verification_status)` возвращает bool — удобно для
Conditional Visibility самой кнопки или для первичной проверки. Но для трёх
РАЗНЫХ сценариев (verified / pending / unverified+rejected) нужен именно
Conditional Action по значению статуса — bool различает только «verified vs нет»,
а нам нужно отличить `pending` (мягкая блокировка) от `unverified/rejected`
(открыть KYC-шит). Схема:
- `canUserBookCar == true` → пропуск;
- иначе → ветвление по конкретному статусу (`pending` vs остальные).

### (Опц.) Визуальный вид кнопки по статусу

- `verified` → кнопка «Забронировать» (активна, основной цвет).
- `pending` → кнопка «На проверке» (приглушённая) или подпись под кнопкой.
- `unverified`/`rejected` → кнопка «Пройти верификацию для аренды».
Это UX-подсказка; логика клика всё равно по §1.

---

## 2. Компонент KYCGateBottomSheet

### Входные параметры
| Component Parameter | Тип | Источник |
|---|---|---|
| `status` | String | `myProfile.verification_status` |
| `comment` | String? | `myProfile.verification_comment` |

### Widget Tree

```
KYCGateBottomSheet (Column, padding)
├── Icon (замок 🔒, крупная)
├── Text "Аренда доступна после верификации" (заголовок, bold)
├── Text "Чтобы арендовать автомобиль, подтвердите личность —
│         загрузите паспорт и водительское удостоверение." (инфо-текст)
│
├── RejectReasonBlock          ← Conditional Visibility: status == 'rejected'
│     Container (красная плашка):
│       Text "Причина отклонения:" (bold)
│       Text = comment            // verification_comment из profiles
│
└── Row(
     ├── Button "Позже"            → Close Bottom Sheet
     └── Button "Пройти верификацию" → Action Flow §2.1
    )
```

Блок причины показывается ТОЛЬКО при `status == 'rejected'` — чтобы пользователь
понял, что исправить перед повторной подачей. Для `unverified` блок скрыт.

### 2.1. Action Flow кнопки «Пройти верификацию»

```
1. Close Bottom Sheet (закрыть текущий компонент)
2. Navigate To  KYCScreen   // экран верификации документов (0019)
```

На KYCScreen пользователь загрузит документы и вызовет `submit_verification`
(статус → pending). Вернувшись к карточке авто, при следующей попытке брони
он получит ветку `pending` (мягкая блокировка) до решения админа.

---

## 3. Custom Function canUserBookCar

Файл: `lib/features/rent/utils/can_user_book_car.dart`.

```dart
bool canUserBookCar(String? verificationStatus) {
  return verificationStatus == 'verified';
}
```

- Return Type: **bool**.
- Argument: `verificationStatus : String?`.
- `true` только для `'verified'`; любой иной статус (включая `null`) → `false`.

Применение:
- быстрый кондишен «пропустить/не пропустить» в Action Flow;
- Conditional Visibility активной кнопки «Забронировать»;
- как первый фильтр перед детальным ветвлением по статусу.

---

## 4. ОБЯЗАТЕЛЬНО: серверная защита (вторая линия обороны)

Клиентский гейт легко обойти (прямой вызов Insert в bookings). Чтобы аренда
была реально закрыта для неверифицированных, нужен СЕРВЕРНЫЙ запрет. Вариант —
триггер на bookings, отклоняющий вставку, если клиент не verified:

```sql
-- Отклоняет создание брони, если у клиента нет пройденной верификации.
create or replace function public.enforce_verified_booking()
returns trigger
language plpgsql
as $$
declare
  v_status verification_status_type;
begin
  select verification_status into v_status
  from public.profiles
  where id = new.customer_id;

  if v_status is distinct from 'verified' then
    raise exception 'Бронирование доступно только верифицированным пользователям'
      using errcode = 'insufficient_privilege';
  end if;

  return new;
end;
$$;

create trigger trg_enforce_verified_booking
  before insert on public.bookings
  for each row execute function public.enforce_verified_booking();
```

С этим триггером даже обход UI не создаст бронь: сервер вернёт исключение,
а FlutterFlow покажет его текст через Action Error Message. Клиентский гейт
остаётся для UX (не гонять пользователя до ошибки), сервер — для безопасности.

> Рекомендуется вынести этот триггер в отдельную миграцию 0020, если продукту
> нужна жёсткая блокировка аренды по верификации.

---

## 5. Сводка

| Статус | Поведение кнопки «Забронировать» |
|---|---|
| гость (null user) | → Login |
| `verified` | пропуск → is_car_available → бронь |
| `pending` | мягкая блокировка «на проверке» |
| `unverified` | KYC Gate Sheet → «Пройти верификацию» |
| `rejected` | KYC Gate Sheet + причина отказа → повторная подача |

Клиент = UX-гейт; сервер (триггер §4) = реальная защита.
```
