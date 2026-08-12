# Экран очереди верификации админа (Admin KYC Screen) — архитектура для FlutterFlow

Админ просматривает поданные документы (через временные signed URL) и
подтверждает/отклоняет верификацию. Опирается на миграцию 0019:
- RLS `profiles_select_admin` (админ читает все профили);
- приватный бакет `user-documents` (чтение владельцу/админу);
- RPC `approve_user_verification` / `reject_user_verification`.

Custom Action: `createSignedDocUrl(path, expiresInSec)` →
`lib/features/admin/actions/create_signed_url.dart`.

---

## 1. Экран списка (KYC Queue)

### 1.1. Supabase Query на ListView

- Table: `profiles`
- Filter: `verification_status` **Equal to** `pending`
- Order by: `updated_at` **Ascending** (FIFO — старые заявки первыми)
  > `updated_at` меняется при submit_verification; если нужна строго дата
  > подачи — можно добавить отдельное поле `verification_submitted_at`.

RLS `profiles_select_admin` (0019) отдаёт эти строки только админу.

### 1.2. Защита On Page Load (RBAC)

```
1. Backend Call → Supabase RPC is_admin()
     → bool isAdminResult

2. Условие: isAdminResult == true ?
   ├─ ДА  → остаёмся, список грузится
   └─ НЕТ → SnackBar "Доступ только для администраторов"
            → Navigate To HomeScreen (Replace Route = ON)  // жёсткий редирект
            → STOP
```

Клиентский редирект — UX-защита. Реальную безопасность держит сервер:
RPC модерации внутри проверяют `is_admin()`, а документы закрыты RLS бакета.

### 1.3. Карточка очереди (строка ListView)

```
KYCQueueItem (Row, tap → открыть KYC Review Component)
├── Avatar (profile.avatar_url)
├── Column
│   ├── Text profile.full_name (или email)
│   └── Text "Ожидает проверки"
└── Icon chevron →
```

Тап открывает Bottom Sheet / Dialog `KYCReviewComponent` с параметрами
из строки (см. §2).

---

## 2. Компонент детального просмотра (KYC Review Component)

### 2.1. Входные параметры

| Component Parameter | Тип | Источник |
|---|---|---|
| `userId` | String | `profile.id` |
| `passportPath` | String? | `profile.passport_url` (путь в бакете) |
| `driverLicensePath` | String? | `profile.driver_license_url` |

> Передаём именно ПУТИ (то, что записал submit_verification), а не готовые
> ссылки — signed URL генерируем внутри компонента, чтобы они были свежими.

### 2.2. Component State

| Переменная | Тип | Назначение |
|---|---|---|
| `passportSignedUrl` | String? | временная ссылка на паспорт |
| `licenseSignedUrl` | String? | временная ссылка на права |
| `rejectReason` | String | текст причины отказа (bind к TextField) |
| `isLoadingUrls` | bool | идёт генерация ссылок |
| `isSubmitting` | bool | идёт approve/reject |

### 2.3. Action Flow On Initialization (генерация Signed URL)

```
1. isLoadingUrls = true

2. Custom Action createSignedDocUrl(passportPath, 300)
     → passportSignedUrl (Component State)

3. Custom Action createSignedDocUrl(driverLicensePath, 300)
     → licenseSignedUrl (Component State)

4. isLoadingUrls = false
```

- TTL = 300 секунд (5 минут) — ссылка живёт ровно на время проверки.
- Если путь пуст → Action вернёт null → в UI показываем «Документ не загружен».
- Ссылки НЕ логируем и не передаём наружу — они временные и приватные.

### 2.4. UI компонента

```
KYCReviewComponent (Column)
├── (isLoadingUrls) → CircularProgressIndicator
├── DocViewer "Паспорт"
│     Image.network(passportSignedUrl)   // visible if passportSignedUrl != null
│     иначе Text "Паспорт не загружен"
├── DocViewer "Водительское удостоверение"
│     Image.network(licenseSignedUrl)
│     иначе Text "Права не загружены"
├── TextField "Причина отклонения" → bind rejectReason
│     (нужен только для Отклонить; для Одобрить игнорируется)
└── Row(
     ├── Button "Отклонить" (красная) → Action Flow §3.2
     └── Button "Одобрить"  (зелёная) → Action Flow §3.1
    )
```

---

## 3. Action Flow кнопок модерации

### 3.1. «Одобрить» (approve_user_verification)

```
1. Set isSubmitting = true
   Show Loader

2. Backend Call → Supabase RPC approve_user_verification
     Params: p_user_id = component.userId

3a. On Success:
      - Hide Loader / isSubmitting = false
      - Close Component (Bottom Sheet/Dialog)
      - SnackBar "Пользователь верифицирован"
      - Refresh родительской очереди (см. §3.3)

3b. On Failure:
      - Hide Loader / isSubmitting = false          // против зависания UI
      - SnackBar( Action Error Message )
        // напр. "Недостаточно прав: ...", "Пользователь не найден"
```

### 3.2. «Отклонить» (reject_user_verification)

```
1. Валидация: rejectReason пуст/только пробелы ?
   └─ ДА → SnackBar "Укажите причину отклонения" → STOP

2. Set isSubmitting = true
   Show Loader

3. Backend Call → Supabase RPC reject_user_verification
     Params:
       p_user_id = component.userId
       p_comment = rejectReason (trimmed)

4a. On Success:
      - Hide Loader / isSubmitting = false
      - Close Component
      - SnackBar "Верификация отклонена"
      - Refresh родительской очереди (§3.3)

4b. On Failure:
      - Hide Loader / isSubmitting = false
      - SnackBar( Action Error Message )
```

### 3.3. Гарантированное обновление родительской очереди

Проблема: после закрытия компонента список на родителе не обновится сам —
одобренный/отклонённый профиль должен уйти из выборки `pending`.

Надёжный паттерн во FlutterFlow (Refresh делаем НА РОДИТЕЛЕ):

```
На родительском экране, в Action тапа по карточке очереди:
1. Open Bottom Sheet KYCReviewComponent (ждём закрытия — Await = ON)
2. (после закрытия) Refresh Database Request → Query "KYC Queue"
```

Так Refresh гарантированно выполнится после модерации, и профиль исчезнет
из очереди (его статус больше не `pending`). Альтернатива — Refresh в
On Page Load родителя при возврате фокуса.

---

## 4. Сводка

| Шаг | Механизм | Опора |
|---|---|---|
| Очередь | Query profiles где `verification_status = pending` | RLS profiles_select_admin (0019) |
| Доступ | is_admin() + редирект | RLS + RPC-гейт |
| Просмотр документов | Signed URL (TTL 300с) | приватный бакет + createSignedDocUrl |
| Одобрить/Отклонить | RPC approve/reject | is_admin() внутри RPC |
| Обновление списка | Refresh на родителе после закрытия | — |

**Безопасность:** документы недоступны по прямой ссылке (private bucket);
signed URL короткоживущие (5 мин); смену статуса делает только сервер под
проверкой `is_admin()`; чтение чужих документов админом разрешено RLS-веткой
`is_admin()` в политике бакета.
```
