# Экран «Очередь модерации админа» (Admin Moderation Screen) — архитектура для FlutterFlow

Экран `AdminModerationScreen` доступен только администраторам. Показывает
объявления на модерации, позволяет одобрить (`approve_car`) или отклонить
(`reject_car`) с указанием причины. Опирается на миграцию 0015:
- `profiles.is_admin` + хелпер-RPC `is_admin()`;
- RLS `cars_select_admin_moderation` (админ видит `moderation`/`rejected`);
- RPC `approve_car(car_id)` и `reject_car(car_id, comment)`.

---

## 1. Очередь модерации + ролевая защита (RBAC)

### 1.1. Supabase-запрос списка

- Table: `cars`
- Filter: `status` **Equal to** `moderation`
- Order by: `created_at` **Ascending** (первыми — самые старые заявки: FIFO)

RLS `cars_select_admin_moderation` уже гарантирует, что эти строки вернутся
ТОЛЬКО админу. Для не-админа запрос вернёт пустой список даже без клиентской
проверки — но мы всё равно делаем жёсткий редирект (защита UX + не показываем
пустой админ-экран обычному юзеру).

> Можно использовать один экран с фильтром-табами:
> «На модерации» (`status = moderation`) и «Отклонённые» (`status = rejected`).
> Второй таб полезен, чтобы пересмотреть/переодобрить отклонённые.

### 1.2. Action Flow On Page Load (ролевая защита)

**Рекомендуемый способ — через RPC `is_admin()` (надёжнее и уже готова):**

```
1. (Опц.) Set Page State checkingAccess = true  // показать полноэкранный спиннер

2. Backend Call → Supabase RPC is_admin()
     → результат: bool isAdminResult (Action Output)

3. Условие: isAdminResult == true ?
   ├─ ДА  → checkingAccess = false
   │        → (страница остаётся, список грузится штатным Query)
   │
   └─ НЕТ → SnackBar "Доступ только для администраторов"
            → Navigate To  HomeScreen
                (Replace Route = ON — жёсткий редирект, без возврата Back)
            → STOP
```

**Альтернатива — прямое чтение профиля** (если не хотите RPC):

```
1. Backend Query (Single Row) profiles
     Filter: id = currentUser.uid
     → adminRow
2. Условие: adminRow.is_admin == true ?
   ├─ ДА  → остаёмся
   └─ НЕТ → Navigate To HomeScreen (Replace Route)
```

> Почему предпочтителен RPC `is_admin()`: он `SECURITY DEFINER`, не зависит от
> нюансов RLS-политик `profiles` на клиенте и переиспользуется во всём приложении.
> Также этой же проверкой стоит закрывать саму КНОПКУ входа в админ-раздел
> (Conditional Visibility по результату is_admin), чтобы обычный юзер вообще
> не видел вход. Редирект в On Page Load — вторая линия обороны.

**Важно:** клиентский редирект — это UX-защита. Реальную безопасность
обеспечивает сервер: даже если не-админ откроет экран, RPC `approve_car` /
`reject_car` внутри проверяют `is_admin()` и бросят исключение
«Недостаточно прав». Данные тоже закрыты RLS. Клиент лишь не показывает лишнее.

---

## 2. Компонент отклонения (Reject Reason — Bottom Sheet)

Отдельный Component `RejectReasonSheet`, открывается снизу (Bottom Sheet)
по кнопке «Отклонить» у карточки/детального экрана.

### 2.1. Параметры и состояние компонента

| Элемент | Тип | Назначение |
|---|---|---|
| Component Parameter `carId` | String | какое объявление отклоняем |
| Local/Component State `inputRejectReason` | String | текст причины (bind к TextField) |
| Local State `isSubmitting` | bool | идёт отправка |

### 2.2. Структура UI

```
RejectReasonSheet (Column, padding)
├── Text "Причина отклонения"
├── TextField  → bind: inputRejectReason        // multiline, hint "Опишите причину"
├── (Опц.) Text-счётчик символов
└── Row(
     ├── Button "Отмена"   → Close Bottom Sheet
     └── Button "Отправить" → Action Flow (ниже)  // disabled при isSubmitting
    )
```

### 2.3. Action Flow кнопки «Отправить»

```
1. Валидация: inputRejectReason пуст/только пробелы ?
   └─ ДА → SnackBar "Укажите причину отклонения" → STOP

2. Set isSubmitting = true
   Show Loader (или заблокировать кнопку + спиннер на ней)

3. Backend Call → Supabase RPC reject_car
     Params:
       car_id  = component.carId
       comment = inputRejectReason (trimmed)

4a. On Success:
      - Hide Loader / isSubmitting = false
      - Close Bottom Sheet
      - SnackBar "Объявление отклонено"
      - Refresh родительского списка модерации
        (Refresh Database Request у Query экрана AdminModerationScreen)
        — объявление уйдёт из выборки moderation

4b. On Failure:
      - Hide Loader / isSubmitting = false          // не даём UI зависнуть
      - SnackBar( Action Error Message )
        // напр. "Недостаточно прав: модерация доступна только администратору"
        //       "Объявление нельзя отклонить: текущий статус = ..."
```

> Как обновить родительский список из закрывающегося Bottom Sheet:
> вариант А — после Close Bottom Sheet на РОДИТЕЛЬСКОМ экране вызвать Refresh
> (последовательность действий продолжается на вызывающей стороне);
> вариант Б — родитель подписан на Query и делает Refresh в On Page Load
> при возврате фокуса. Проще всего: в Action Flow кнопки «Отклонить» на родителе
> сначала Open Bottom Sheet (ждём результат), затем Refresh Database Request.

---

## 3. Action Flow кнопки «Одобрить» (детальный просмотр админа)

Экран `AdminCarDetailScreen` (Page Parameter `carId`) — админ смотрит фото,
характеристики, текущий статус и `moderation_comment` (если был отклонён ранее).

```
1. (Опц.) Confirm Dialog "Одобрить и опубликовать объявление?"

2. Set Page State isApproving = true
   Show Loader (модальный спиннер)

3. Backend Call → Supabase RPC approve_car
     Params: car_id = carId
     → результат: обновлённая строка cars (status = active)

4a. On Success:
      - Hide Loader / isApproving = false
      - SnackBar "Объявление опубликовано"
      - Refresh Database Request родительского списка модерации
        (чтобы одобренная машина исчезла из очереди moderation)
      - Navigate Back  (вернуться к списку очереди)

4b. On Failure:
      - Hide Loader / isApproving = false           // критично против зависания
      - SnackBar( Action Error Message )
        // напр. "Объявление нельзя одобрить: текущий статус = active"
        //       "Недостаточно прав: ..."
```

### Обновление родительского списка

- Если «Одобрить» нажата НА детальном экране: перед Navigate Back поставить
  Refresh Database Request того Query, что питает список очереди
  (во FlutterFlow Refresh можно адресовать конкретному запросу на предыдущем
  экране, либо родитель сам делает Refresh в On Page Load при возврате).
- Если «Одобрить» нажата ПРЯМО в списке (без захода в детали): после Success
  сразу Refresh Database Request текущего Query — карточка исчезнет из выборки.

---

## 4. Сводка «действие → RPC → результат»

| Действие | RPC | Переход статуса | Что делаем в UI |
|---|---|---|---|
| Одобрить | `approve_car(car_id)` | moderation/rejected → active | Refresh очереди, Snackbar, Back |
| Отклонить | `reject_car(car_id, comment)` | moderation → rejected | Close Sheet, Refresh очереди, Snackbar |

**Общий принцип обработки ошибок:** у каждого Backend Call — ветки Success/Failure;
Hide Loader и сброс флага (`isApproving`/`isSubmitting`) выполняются в ОБЕИХ ветках;
текст серверного исключения берём из **Action Error Message** и показываем в SnackBar.

**Двухслойная защита доступа:**
1. Клиент — редирект в On Page Load + скрытие входа (UX).
2. Сервер — `is_admin()` внутри RPC + RLS (реальная безопасность).
