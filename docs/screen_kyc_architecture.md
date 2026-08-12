# Экран верификации документов (KYC Screen) — архитектура для FlutterFlow

Пользователь загружает паспорт и водительское удостоверение в ПРИВАТНЫЙ бакет
`user-documents`, отправляет на проверку. Опирается на миграцию 0019:
приватный бакет + RLS (владелец/админ), RPC `submit_verification`,
поле `profiles.verification_status`.

**Источник состояния:** Backend Query (Single Row) `profiles` по `id = currentUser.uid`
на On Page Load → `myProfile`. Ключевое поле — `verification_status`.

---

## 1. Widget Tree по трём состояниям (Conditional Visibility)

Три взаимоисключающих блока, видимость по `myProfile.verification_status`.

```
KYCScreen (Column)
│
├── UploadBlock            ← visible if status == 'unverified' OR status == 'rejected'
│   ├── (если rejected) RejectBanner:
│   │       красная плашка + Text = myProfile.verification_comment  // причина отказа
│   ├── Text "Загрузите документы для верификации"
│   ├── DocTile "Паспорт"
│   │     ├── Preview (если passportUrl загружен в сессии)
│   │     └── Button "Загрузить паспорт"   → Action Flow §2
│   ├── DocTile "Водительское удостоверение"
│   │     ├── Preview (если licenseUrl загружен)
│   │     └── Button "Загрузить права"     → Action Flow §2
│   └── Button "Отправить на проверку"     → Action Flow §3
│                                              disabled, пока не загружены оба
│
├── PendingBlock           ← visible if status == 'pending'
│   ├── Icon (часы)
│   ├── Text "Документы на проверке"
│   └── Text "Обычно занимает до 24 часов"
│
└── VerifiedBlock          ← visible if status == 'verified'
    ├── Icon (зелёная галочка)
    └── Text "Ваш аккаунт верифицирован"
```

**Логика видимости:**
| Статус | Виден блок |
|---|---|
| `unverified` | UploadBlock (без баннера) |
| `rejected` | UploadBlock + RejectBanner с причиной (повторная подача) |
| `pending` | PendingBlock (заглушка ожидания) |
| `verified` | VerifiedBlock (успех) |

---

## 2. Action Flow загрузки документа (Media Picker → приватный бакет)

Page State для экрана:
| Переменная | Тип | Назначение |
|---|---|---|
| `passportUrl` | String? | путь/URL загруженного паспорта |
| `licenseUrl` | String? | путь/URL загруженных прав |
| `isUploading` | bool | идёт загрузка файла |

### Кнопка «Загрузить паспорт» (аналогично для прав)

```
1. Action: Upload/Save Media (или Upload to Supabase)
     Источник: галерея/камера (image_picker)

2. Bucket: user-documents
   Upload Path (КЛЮЧЕВОЙ момент — путь ДОЛЖЕН начинаться с auth.uid()):
     [currentUser.uid] / passport_[timestamp].jpg
   // во FlutterFlow: Folder/Path = "${currentUserUid}"
   // имя файла добавится автоматически; можно задать префикс passport_/license_

3. isUploading = true (спиннер на плитке)

4. On Upload Success:
     - для паспорта → passportUrl = полученный путь/URL
     - для прав     → licenseUrl  = полученный путь/URL
     isUploading = false

5. On Upload Failure:
     isUploading = false
     SnackBar "Не удалось загрузить файл"
```

### Почему путь ДОЛЖЕН начинаться с auth.uid()

RLS-политика бакета `user_docs_insert_own` (0019):
```
(storage.foldername(name))[1] = auth.uid()::text
```
Первый сегмент пути = папка верхнего уровня — она обязана равняться uid.
Если путь начнётся с чего-то другого — INSERT в бакет будет отклонён политикой.
Структура: `<auth.uid()>/passport_....jpg`.

### Важно: приватный бакет и показ превью

`user-documents` создан с `public = false` → прямых ссылок нет. Чтобы показать
превью загруженного документа ВЛАДЕЛЬЦУ, нужен **signed URL** (Create Signed URL
Action / метод `createSignedUrl` из `verification_repository.dart`). Для самого
процесса загрузки/отправки на проверку превью не обязательно — достаточно хранить
путь. Но если показываете миниатюру — получайте signed URL, не публичный.

---

## 3. Action Flow «Отправить на проверку»

```
1. Валидация: passportUrl == null OR licenseUrl == null ?
   └─ ДА → SnackBar "Загрузите оба документа" → STOP

2. Set isSubmitting = true
   Show Loader (модальный спиннер)

3. Backend Call → Supabase RPC submit_verification
     Params:
       p_passport_url       = pageState.passportUrl
       p_driver_license_url = pageState.licenseUrl
     // сервер: статус → pending, очистка verification_comment

4a. On Success:
      - Hide Loader / isSubmitting = false
      - SnackBar "Документы отправлены на проверку"
      - Refresh: перечитать myProfile (Backend Query profiles по uid)
        → verification_status станет 'pending'
        → Conditional Visibility автоматически покажет PendingBlock

4b. On Failure:
      - Hide Loader / isSubmitting = false          // критично против зависания
      - SnackBar( Action Error Message )
        // напр. "Загрузите хотя бы один документ для верификации"
        //       "Требуется авторизация"
```

### Обновление состояния экрана после отправки

После успеха ГЛАВНОЕ — перечитать профиль (`myProfile`), т.к. вся видимость
блоков завязана на `verification_status`. Способы:
- Refresh Database Request того Query, что грузил `myProfile` на On Page Load;
- либо повторный Backend Query profiles по uid → перезаписать `myProfile`.

Как только `myProfile.verification_status == 'pending'` — UploadBlock скрывается,
PendingBlock показывается. Дополнительной навигации не требуется.

---

## 4. Сводка

| Состояние | UI | Действие |
|---|---|---|
| unverified | форма загрузки | загрузить оба → submit |
| rejected | форма + причина отказа | перезагрузить → submit заново |
| pending | заглушка ожидания | ждать модерации |
| verified | зелёный статус | доступ к аренде разблокирован |

**Безопасность документов:**
- приватный бакет: чтение только владельцу/админу (RLS 0019);
- путь загрузки начинается с `auth.uid()` (иначе INSERT отклонён);
- показ документов — через signed URL;
- смену статуса делает только сервер (`submit_verification` / admin RPC),
  клиент `verification_status` напрямую не пишет.
```
