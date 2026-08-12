# Экран чат-комнаты (Chat Room Screen) — архитектура для FlutterFlow

Экран `ChatRoomScreen` — Realtime-переписка внутри одного чата. Опирается на
миграцию 0016: таблицы `chats`/`messages`, RLS (участник видит/пишет),
репликацию `messages` в `supabase_realtime`, RPC `start_chat`.

**Page Parameters:**
| Параметр | Тип | Назначение |
|---|---|---|
| `chatId` | String (uuid) | какой чат открыт |
| `peerName` | String? | имя собеседника для AppBar (опц.) |

Чат открывается так: с карточки авто кнопка «Написать» → RPC `start_chat(car_id)`
→ получаем `chatId` → Navigate to `ChatRoomScreen(chatId: ...)`.

---

## 1. Realtime-лента сообщений

### 1.1. Настройка Supabase Realtime Query (Stream) на ListView

Во FlutterFlow источник ListView — **Supabase Realtime / Query Rows (Stream)**:

- Table: `messages`
- **Enable Realtime / Streaming: ON** (использует репликацию из 0016)
- Filter: `chat_id` **Equal to** `pageParameter.chatId`
- Order by: `created_at` **Ascending** (старые сверху, новые снизу — как в мессенджерах)

RLS `messages_select_participant` (0016) гарантирует, что поток отдаст сообщения
только участнику чата. Даже если подставить чужой `chat_id`, БД ничего не вернёт.

> ListView: `shrinkWrap = false`, `reverse = false` (растёт вниз).
> Держим ScrollController (в FlutterFlow — через именованный ListView + Scroll Action),
> чтобы программно скроллить вниз (см. §2).

### 1.2. Пузыри сообщений: «мои» vs «собеседника»

Внутри строки ListView — компонент `MessageBubble`, который по `sender_id`
решает выравнивание и стиль.

**Условие «моё сообщение»:** `messageItem.sender_id == currentUser.uid`.

```
MessageRow (Row, ширина 100%)
├── [моё]  Align = centerRight:
│     Container (пузырь):
│        color = Primary
│        text color = onPrimary
│        отступ слева большой (мой пузырь прижат вправо)
│
└── [чужое] Align = centerLeft:
      Container (пузырь):
         color = surfaceVariant / серый
         text color = onSurface
         отступ справа большой (пузырь прижат влево)
```

Реализация во FlutterFlow — двумя способами:
- **Способ A (Conditional Visibility):** в строке ДВА заранее свёрстанных пузыря
  (мой справа / чужой слева); показываем нужный по условию
  `sender_id == currentUser.uid`, второй скрыт.
- **Способ B (динамический Alignment):** один Container, у которого свойство
  Alignment/Color заданы через условное выражение по `sender_id`.

Способ A нагляднее для FlutterFlow и проще стилизуется. Внутри пузыря:
текст сообщения + время (`created_at`, формат `HH:mm`) + (для своих) индикатор
`is_read` (✓/✓✓).

---

## 2. Action Flow кнопки «Отправить»

Поле ввода `messageInput` (TextField, bind к Page State или Widget State).

```
1. Валидация: messageInput пуст/только пробелы ?
   └─ ДА → STOP (ничего не отправляем, можно без SnackBar)

2. (Опц.) Заблокировать кнопку на время вставки

3. Supabase Insert → messages
     values:
       chat_id   = pageParameter.chatId
       sender_id = currentUser.uid        // RLS требует sender_id = auth.uid()
       text      = messageInput (trimmed)
     // is_read=false и created_at=now() проставит БД по умолчанию

4. Clear Text Fields (очистить messageInput)

5. Scroll To Bottom (Scroll Action по ListView сообщений)
   // моё сообщение прилетит и через Realtime, но локальный скролл
   // делаем сразу для мгновенного отклика UI
```

> `sender_id` НЕ берём из ввода — только `currentUser.uid`. Иначе RLS-политика
> `messages_insert_participant` (with check `sender_id = auth.uid()`) отклонит вставку.

### 2.1. Авто-скролл при ВХОДЯЩЕМ Realtime-сообщении (ключевой момент)

Проблема: шаг 5 скроллит только при МОЕЙ отправке. Когда сообщение приходит
от собеседника через Realtime, отдельного Action у меня нет — список сам
перерисовался, но не проскроллился.

Решение во FlutterFlow — привязать скролл к ИЗМЕНЕНИЮ количества сообщений:

- **Способ 1 (рекомендуется): триггер «On Data / список изменился».**
  Держим в Page State `lastMessagesCount`. На событии обновления данных
  (или в `On Page Load` + периодическая проверка) сравниваем длину списка:
  ```
  if (currentMessagesCount > lastMessagesCount):
       Scroll To Bottom
       lastMessagesCount = currentMessagesCount
  ```
  Во FlutterFlow это вешается на доступный хук обновления Query/списка.

- **Способ 2 (кастомный виджет): обёртка ListView со слушателем стрима.**
  Если встроенного «on stream update» не хватает, используем Custom Widget
  на базе `chat_repository.messagesStream(chatId)` (см. `chat_repository.dart`),
  который в `StreamBuilder` после каждого билда вызывает
  `WidgetsBinding.instance.addPostFrameCallback` → `scrollController.animateTo(max)`.
  Это гарантирует плавный авто-скролл и на мои, и на входящие сообщения.

Для чистого low-code — Способ 1. Для гарантированного поведения — Способ 2.

---

## 3. Обновление is_read при открытии чата

Задача: при входе в чат все ВХОДЯЩИЕ (чужие) непрочитанные сообщения
пометить `is_read = true`. Разрешено RLS `messages_update_participant` (0016).

### On Page Load Action Flow

```
1. Supabase Update → messages
     Filter:  chat_id  = pageParameter.chatId
       AND    sender_id != currentUser.uid     // только чужие (входящие)
       AND    is_read   = false                // только ещё не прочитанные
     Set:     is_read = true
```

Это ровно логика метода `markRead()` из `chat_repository.dart`:
```dart
await _client.from('messages')
  .update({'is_read': true})
  .eq('chat_id', chatId)
  .neq('sender_id', userId)   // не свои
  .eq('is_read', false);      // только непрочитанные
```

> Почему только чужие: свои сообщения помечает прочитанными собеседник,
> когда откроет чат у себя. Мы обновляем статус ВХОДЯЩИХ для СЕБЯ.

> Реактивность галочек: т.к. `messages` в Realtime, смена `is_read` у собеседника
> прилетит и мне — индикатор ✓✓ на моих сообщениях обновится автоматически,
> без ручного перезапроса.

### Когда ещё вызывать markRead

- On Page Load — обязательно.
- (Опц.) при получении нового входящего, пока экран открыт — чтобы входящие
  сразу считались прочитанными (можно повесить на тот же хук обновления списка
  из §2.1, вызывая Update для новых чужих сообщений).

---

## 4. Сводка

| Блок | Механизм | Опора на 0016 |
|---|---|---|
| Лента | Realtime Stream по `chat_id`, order `created_at ASC` | репликация `messages`, RLS select |
| Пузыри | Align по `sender_id == uid` (Conditional Visibility) | — |
| Отправка | Insert (`sender_id = uid`) → Clear → Scroll | RLS insert (`sender_id = auth.uid()`) |
| Авто-скролл входящих | триггер по росту кол-ва сообщений / StreamBuilder | Realtime |
| is_read | On Page Load Update чужих непрочитанных | RLS update participant |

Вся защита — на сервере (RLS 0016). Клиент лишь отображает и отправляет;
подставить чужой `sender_id` или прочитать чужой чат нельзя.
