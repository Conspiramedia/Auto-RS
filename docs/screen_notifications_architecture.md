# Экран уведомлений (Notifications Screen) — архитектура для FlutterFlow

Лента системных уведомлений с Realtime-обновлением, бэйджем непрочитанных и
диспетчером переходов по тапу. Опирается на миграцию 0024: таблица
`notifications` (RLS свои, репликация в supabase_realtime), поля
`type` / `action_id` / `is_read`.

Custom Function: `getUnreadNotificationsCount(list)` →
`lib/features/notifications/utils/get_unread_count.dart`.

---

## 1. Экран списка уведомлений

### 1.1. Источник — Supabase Realtime Stream Query на ListView

- Table: `notifications`
- **Enable Realtime / Streaming: ON** (репликация из 0024)
- Filter: `user_id` **Equal to** `currentUser.uid`
- Order by: `created_at` **Descending** (свежие сверху)

RLS `notifications_select_own` (0024) и так вернёт только свои — фильтр по
`user_id` для явности и совместимости с UI. Realtime: новые уведомления
(созданные триггерами) появляются в ленте сразу.

### 1.2. Карточка уведомления

```
NotificationItem (Row, tap → §3)
├── LeadingIcon           // иконка по type:
│     'chat_message'            → Icons.chat_bubble
│     'booking_status_changed'  → Icons.directions_car
│     'kyc_status_changed'      → Icons.verified_user
│     иначе                     → Icons.notifications
├── Column (Expanded)
│   ├── Text title (bold если !is_read)
│   ├── Text body (обрезка до 2 строк)
│   └── Text времени (created_at → "5 мин назад" / "вчера" / дата)
└── UnreadDot                 // маленькая точка, visible if is_read == false
```

**Выделение непрочитанных:** фон карточки — Conditional:
```
background = is_read ? transparent : primary.withOpacity(0.06)
```
Плюс жирный `title` и точка-индикатор при `is_read == false`.

Иконка по типу — через условное выражение по `type` или Custom Function
`notificationIcon(type) → IconData`. Способ проще — заранее свёрстанные
иконки + Conditional Visibility по `type`.

### 1.3. Кнопка «Прочитать все»

В AppBar экрана: Action → Supabase Update `notifications`
`set is_read=true where user_id = uid and is_read = false`
(это `markAllRead()` из `notifications_repository.dart`).

---

## 2. Бэйдж колокольчика (App-level Navigation Badge)

### 2.1. Источник данных для бэйджа

Иконка «Колокольчик» в главной навигации несёт цифру непрочитанных.
Два способа:
- **A (Realtime, реактивно):** повесить на глобальную навигацию Stream Query
  к `notifications` (filter uid), и цифру бэйджа считать через
  `getUnreadNotificationsCount(streamRows)`. Обновляется сама при новых
  уведомлениях (Realtime).
- **B (RPC-счётчик):** если стрим на уровне навигации неудобен — периодически
  вызывать серверный count непрочитанных (можно сделать RPC по аналогии с
  total_unread_count для чатов) и обновлять при заходе на вкладки.

Рекомендуется A — цифра живая, без ручного обновления.

### 2.2. Custom Function getUnreadNotificationsCount

```dart
int getUnreadNotificationsCount(List<dynamic>? notifications) {
  if (notifications == null || notifications.isEmpty) return 0;
  int count = 0;
  for (final item in notifications) {
    if (item is Map && (item['is_read'] == false || item['is_read'] == null)) {
      count++;
    }
  }
  return count;
}
```

- Return Type: **int**.
- Argument: `notifications : List<dynamic>` (строки из Query/Stream).
- Бэйдж: visible if `getUnreadNotificationsCount(list) > 0`, текст = это число
  (при `> 99` показывать «99+»).

---

## 3. Диспетчер переходов (Notification Router) по тапу

```
ТАП по карточке уведомления:

Шаг 1. Пометить прочитанным:
   Supabase Update notifications
     set is_read = true
     where id = notificationItem.id
   // RLS notifications_update_own разрешает менять только своё

Шаг 2. Разветвление по notificationItem.type (Conditional Action / Switch):

   ├─ 'chat_message'
   │     action_id = chat_id
   │     Navigate To  ChatRoomScreen
   │        params: chatId = notificationItem.action_id
   │
   ├─ 'booking_status_changed'
   │     action_id = booking_id
   │     Navigate To  BookingDetailScreen (или BookingsScreen с выделением)
   │        params: bookingId = notificationItem.action_id
   │
   ├─ 'kyc_status_changed'
   │     action_id = обычно null (или user_id)
   │     Navigate To  KYCScreen
   │        // экран сам покажет актуальный verification_status
   │
   └─ default (неизвестный тип)
         остаёмся на экране уведомлений (только пометили прочитанным)
```

### Важно про action_id

- `chat_message` → `action_id` содержит `chat_id` (триггер notify_on_message).
- `booking_status_changed` → `action_id` содержит `booking_id`
  (триггер notify_on_booking_status).
- `kyc_status_changed` → тип В МИГРАЦИИ 0024 ПОКА НЕ ГЕНЕРИРУЕТСЯ. Роутер
  готов его обработать, но чтобы такие уведомления реально создавались,
  нужен триггер на смену profiles.verification_status (см. §4). До этого
  ветка kyc_status_changed просто не будет встречаться.

---

## 4. Примечание: тип 'kyc_status_changed' пока не генерируется

Триггеры 0024 создают только `chat_message` и `booking_status_changed`.
Чтобы появились KYC-уведомления, нужен триггер на profiles:

```sql
-- (для отдельной миграции, если нужны KYC-уведомления)
create or replace function public.notify_on_kyc_status()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.verification_status is distinct from old.verification_status
     and new.verification_status in ('verified','rejected') then
    insert into public.notifications (user_id, title, body, type, action_id)
    values (
      new.id,
      case when new.verification_status = 'verified'
           then 'Верификация пройдена' else 'Верификация отклонена' end,
      case when new.verification_status = 'verified'
           then 'Ваш аккаунт подтверждён. Аренда доступна.'
           else coalesce(new.verification_comment, 'Проверьте документы и подайте повторно.') end,
      'kyc_status_changed',
      new.id
    );
  end if;
  return new;
end; $$;

create trigger tg_notify_on_kyc_status
  after update of verification_status on public.profiles
  for each row execute function public.notify_on_kyc_status();
```

Роутер выше уже готов к этому типу — добавление триггера включит ветку без
изменений на клиенте.

---

## 5. Сводка

| Блок | Механизм | Опора |
|---|---|---|
| Лента | Realtime Stream по user_id, order created_at DESC | 0024 (репликация, RLS) |
| Иконка/фон карточки | по type / is_read | — |
| Бэйдж | getUnreadNotificationsCount(stream) | Custom Function |
| Тап | Update is_read + Switch(type) → Navigate(action_id) | RLS update, action_id |
| KYC-уведомления | требуют доп. триггера (§4) | — |
```
