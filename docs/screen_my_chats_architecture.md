# Экран «Мои диалоги» (My Chats Screen) — архитектура для FlutterFlow

Список всех чатов пользователя с данными машины, профилем собеседника и
счётчиком непрочитанных. Опирается на миграцию 0018: VIEW `chats_with_details`
(`security_invoker`) + RPC `total_unread_count` / `unread_count_for_chat`.

---

## 1. Источник данных (Supabase Query на ListView)

- View: `chats_with_details`
- Filter: `buyer_id` **Equal to** `currentUser.uid`
  **OR** `seller_id` **Equal to** `currentUser.uid`
  (во FlutterFlow — Filter Group с OR)
- Order by: `last_message_at` **Descending** (`nulls last` — пустые чаты внизу)

VIEW создана с `security_invoker = true`, поэтому RLS `chats_select_participant`
(0016) уже гарантирует, что вернутся только чаты пользователя. Фильтр
`buyer/seller = uid` — для явности и совместимости с UI FlutterFlow.

> VIEW уже отдаёт всё для карточки: `opponent_name`, `opponent_avatar`,
> `brand`, `model`, `car_photo`, `unread_count`, `last_message_at`.
> Собеседник вычислен в самой VIEW (не нужно на клиенте разбирать buyer/seller).

---

## 2. Widget Tree карточки диалога

```
ChatListItem (Row, tap → §3)
├── Stack
│   ├── Avatar (opponent_avatar)         // фото собеседника; плейсхолдер если null
│   └── UnreadBadge (Positioned, top-right)   ← Conditional Visibility
│         visible if  unread_count > 0
│         Container (красный кружок)
│           Text = unread_count.toString()
│
├── Column (Expanded)
│   ├── Text opponent_name               // имя собеседника (или "Пользователь")
│   ├── Text "{brand} {model}"           // о какой машине чат
│   └── (Опц.) Text превью последнего сообщения
│
├── CarThumb (car_photo)                 // маленькое фото авто (опц.)
└── Text времени (last_message_at → "HH:mm" / "вчера" / дата)
```

### Красный бэйдж непрочитанных (Conditional Visibility)

- Условие видимости: `chatItem.unread_count > 0`.
- Стиль: красный кружок (`Colors.red`), белый текст, число = `unread_count`.
- При `unread_count == 0` бэйдж скрыт полностью.
- (Опц.) при `unread_count > 99` показывать «99+».

Имя/аватар собеседника берём НАПРЯМУЮ из VIEW (`opponent_name`,
`opponent_avatar`) — они уже относятся к собеседнику, а не к себе.

---

## 3. Action Flow по тапу на карточку

```
1. Navigate To  ChatRoomScreen
     params:
       chatId   = chatItem.id
       peerName = chatItem.opponent_name   // для AppBar комнаты
```

При открытии `ChatRoomScreen` его On Page Load пометит входящие
прочитанными (markRead, см. архитектуру чат-комнаты). После возврата
на список — обновить его (см. §4), чтобы бэйдж пересчитался.

---

## 4. Обновление списка и счётчиков

- **Realtime (рекомендуется):** сделать Query к `chats_with_details` в режиме
  стрима/подписки — тогда при новом сообщении список и бэйджи обновятся сами
  (таблица `messages` реплицируется, VIEW пересчитает `unread_count`).
  > Примечание: стрим по VIEW во FlutterFlow может быть ограничен; если стрим
  > по VIEW недоступен, используйте обычный Query + Refresh (ниже).
- **Refresh при возврате:** на `On Page Load` экрана списка (срабатывает и при
  возврате из комнаты) вызывать Refresh Database Request → бэйджи пересчитаются.
- **Бэйдж на иконке навигации «Чаты»:** RPC `total_unread_count()` →
  показать общий счётчик; обновлять при заходе на вкладку и после чтения чата.

---

## 5. Пустое состояние

Если список пуст → EmptyState:
«У вас пока нет диалогов. Напишите продавцу со страницы объявления.»

---

## 6. Сводка полей VIEW → UI

| Поле VIEW | Где в UI |
|---|---|
| `opponent_name` | заголовок карточки |
| `opponent_avatar` | аватар |
| `brand`, `model` | подзаголовок (о какой машине) |
| `car_photo` | миниатюра авто |
| `unread_count` | красный бэйдж (visible if > 0) |
| `last_message_at` | время + сортировка |
| `id` | параметр перехода в ChatRoomScreen |

Вся безопасность — на сервере (RLS через `security_invoker`).
Клиент не разбирает, кто buyer/seller — VIEW уже отдаёт данные собеседника.
