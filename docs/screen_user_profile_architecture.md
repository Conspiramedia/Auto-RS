# Экран профиля пользователя (User Profile Screen) — архитектура для FlutterFlow

Профиль: KYC-статус, финансовый блок (баланс вендора + история транзакций),
навигация, выход. Опирается на:
- `profiles` (verification_status, is_admin) — миграции 0015/0019;
- RPC `get_vendor_balance(p_user_id)` — миграция 0021;
- `transactions` + RLS «свои» — миграция 0009.

**On Page Load:** Backend Query (Single Row) `profiles` по `id = currentUser.uid`
→ `myProfile`; Backend Call `get_vendor_balance(currentUser.uid)` → `balance`.

---

## 1. Widget Tree

```
UserProfileScreen (Column / ScrollView)
├── HeaderBlock
│   ├── Avatar (myProfile.avatar_url)
│   ├── Text myProfile.full_name
│   └── Text myProfile.email
│
├── KYCStatusBlock              // плашка с динамическим цветом/текстом (см. §2)
│
├── FinanceBlock
│   ├── BalanceCard
│   │     Text "Баланс" + Text "{balance} EUR"      // из get_vendor_balance
│   │     (Опц.) Button "Вывести средства" (заглушка выплаты)
│   └── TransactionsList (ListView)
│         Query transactions (RLS вернёт только свои), order created_at DESC
│         → TxRow: тип (payment/refund/penalty/payout), сумма, дата, статус
│
├── NavBlock
│   ├── Tile "Мои объявления"     → MyCarsScreen
│   ├── Tile "Мои брони"          → BookingsScreen
│   ├── Tile "Мои диалоги"        → MyChatsScreen
│   ├── Tile "Верификация"        → KYCScreen
│   ├── Tile "Панель администратора" ← Conditional Visibility: myProfile.is_admin == true
│   │        → AdminModerationScreen / AdminKYCScreen
│   └── Tile "Настройки"          → SettingsScreen
│
└── Button "Выйти из аккаунта"    → Action Flow §3
```

---

## 2. KYCStatusBlock — динамический цвет и текст

Плашка меняет вид по `myProfile.verification_status`:

| Статус | Цвет плашки | Текст | Действие по тапу |
|---|---|---|---|
| `unverified` | серый | «Не верифицирован» | → KYCScreen |
| `pending` | оранжевый | «Документы на проверке» | — (ожидание) |
| `verified` | зелёный | «Аккаунт верифицирован» ✓ | — |
| `rejected` | красный | «Верификация отклонена» | → KYCScreen (перезагрузить) |

Реализация во FlutterFlow:
- цвет фона плашки — через условное выражение по `verification_status`
  (4 ветки) либо Custom Function `kycBadgeColor(status) → Color`;
- текст — аналогично условным выражением;
- для `rejected` можно дополнительно показать `verification_comment`.

> Быстрый способ: заранее свёрстанные 4 плашки + Conditional Visibility
> по статусу (видна ровно одна). Нагляднее в редакторе FlutterFlow.

---

## 3. Финансовый блок

### Баланс
- Backend Call `get_vendor_balance(currentUser.uid)` → `balance` (double).
- Показ: `{balance} EUR` (валюта расчётов). Баланс = сумма завершённых
  выплат (`payout`/`completed`) — реально заработанное после завершённых аренд.
- Обновление: при On Page Load + после `complete_booking` (когда выплата
  переходит в completed) — сделать Refresh при возврате на профиль.

### История транзакций
- ListView ← Query `transactions` (RLS `transactions_select_own` из 0009
  отдаёт только свои).
- Order by `created_at` **Descending**.
- Строка: иконка+подпись типа, сумма (со знаком по смыслу), дата, статус.
  | type | подпись | знак суммы |
  |---|---|---|
  | `payment` | Оплата | −  (списание клиента) |
  | `refund` | Возврат | + |
  | `penalty` | Штраф | − |
  | `payout` | Выплата | + (доход владельца) |

---

## 4. Панель администратора (Conditional Visibility)

Плитка «Панель администратора» видна СТРОГО при `myProfile.is_admin == true`:
```
Conditional Visibility:  myProfile.is_admin == true
```
Это UX-скрытие. Реальную защиту админ-экранов держит сервер (RPC-гейт
`is_admin()` + RLS), поэтому даже при обходе плитки не-админ ничего не сделает.

---

## 5. Action Flow «Выйти из аккаунта»

```
1. (Опц.) Confirm Dialog "Выйти из аккаунта?"

2. Action: Supabase Auth → Log Out
   (встроенный экшен FlutterFlow — завершает сессию Supabase)

3. Очистка App State / Page State (если хранили данные пользователя,
   кэш профиля, счётчики непрочитанных и т.п.) → сбросить в дефолт,
   чтобы данные прошлого юзера не «протекли» в следующую сессию.

4. Navigate To  LoginScreen
     Replace Route = ON  (Clear Route Stack — жёсткий редирект,
     чтобы кнопкой Back нельзя было вернуться в авторизованную зону)
```

---

## 6. Сводка

| Блок | Источник данных | Опора |
|---|---|---|
| KYC-плашка | myProfile.verification_status | 0019 |
| Баланс | RPC get_vendor_balance | 0021 |
| История транзакций | Query transactions (свои) | 0009 (RLS) |
| Кнопка админ-панели | myProfile.is_admin | 0015 |
| Выход | Supabase Log Out + Clear Stack | — |

**Обновление баланса:** т.к. payout переходит в completed при завершении
аренды владельцем (complete_booking, 0012), баланс растёт именно тогда —
делайте Refresh профиля при возврате на экран.
```
