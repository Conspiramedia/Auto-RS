# Deep links (App Links / Universal Links) — Auto.RS

Файлы в этой папке подтверждают связь домена и приложения. Без них ссылка
`https://rsauto-rs.vercel.app/car/{id}` откроется в браузере, а не в приложении.

## ⚠️ Текущее ограничение: домен на `*.vercel.app`

**Автоматическая верификация на текущем домене не пройдёт** — ни на Android,
ни на iOS. Причина не в конфигурации, а в самом хостинге:

- `vercel.app` входит в **Public Suffix List** — список доменов, субдомены
  которых принадлежат разным независимым владельцам. И Google, и Apple
  отказываются связывать такие субдомены с приложением: иначе любой, кто
  занял субдомен, мог бы перехватывать ссылки чужого приложения.
- В `apple-app-site-association` вместо реального Team ID стоит плейсхолдер
  `TEAM_ID`, а в `assetlinks.json` — `SHA256_FINGERPRINT`.

**Как это выглядит на практике сейчас:** ссылка открывается в браузере
(iOS) либо через диалог «Открыть с помощью» (Android). Приложение не
перехватывает её автоматически.

**Что нужно для полноценной работы** (TODO):

1. Собственный домен вместо `*.vercel.app` (например, `rsauto.rs`) —
   в Vercel он подключается в Settings → Domains.
2. Team ID из Apple Developer → Membership.
3. SHA-256 отпечаток релизного ключа подписи Android.
4. Выложить оба файла на новый домен и пересобрать приложение с обновлённым
   хостом в манифесте и entitlements.

До этого момента конфигурация в приложении уже подготовлена и менять её,
кроме самого домена, не придётся.

---

Оба файла содержат **плейсхолдеры**, которые нужно заменить перед выкладкой:

| Плейсхолдер | Где взять | Файл |
|---|---|---|
| `TEAM_ID` | Apple Developer → Membership → Team ID (10 символов) | `apple-app-site-association` |
| `SHA256_FINGERPRINT` | Отпечаток **релизного** ключа подписи Android | `assetlinks.json` |

Идентификаторы приложения уже подставлены и менять их не нужно:
iOS bundle id `rs.auto.autoRs`, Android package `rs.auto.auto_rs`.

## Как получить SHA-256 отпечаток Android

Из вашего keystore (замените путь и алиас):

```bash
keytool -list -v -keystore release.keystore -alias upload | grep SHA256
```

Если приложение подписывает Google Play (Play App Signing) — берите отпечаток
из консоли: **Play Console → Настройка → Целостность приложения → Подписание
приложений**. Там же указан отпечаток ключа загрузки; в `assetlinks.json`
нужен именно **ключ подписи приложения**, а не загрузки, иначе ссылки не
заработают у пользователей из Play.

Можно указать несколько отпечатков сразу — это удобно, чтобы deep links
работали и в отладочной сборке:

```json
"sha256_cert_fingerprints": [
  "AA:BB:...:отпечаток релиза",
  "CC:DD:...:отпечаток debug"
]
```

## Куда положить файлы

Оба файла размещаются на **сайте** (не в приложении), в папке `/.well-known/`
в корне домена:

```
https://rsauto-rs.vercel.app/.well-known/apple-app-site-association
https://rsauto-rs.vercel.app/.well-known/assetlinks.json
```

Требования, которые чаще всего ломают проверку:

- **HTTPS обязателен**, сертификат валидный. Редирект с http на https
  допустим, но сами файлы должны отдаваться по https напрямую.
- **Никаких редиректов** на сам файл. Apple не следует за перенаправлениями
  при проверке AASA.
- `apple-app-site-association` — **без расширения** `.json`, отдаётся с
  заголовком `Content-Type: application/json`.
- Файлы должны быть доступны **анонимно**, без авторизации и без
  cookie-баннера, перехватывающего запрос.

## Как проверить

Android:

```bash
curl -i https://rsauto-rs.vercel.app/.well-known/assetlinks.json
```

iOS (обратите внимание: без `.json` на конце):

```bash
curl -i https://rsauto-rs.vercel.app/.well-known/apple-app-site-association
```

В обоих случаях ожидается `HTTP/2 200`, заголовок
`content-type: application/json` и содержимое файла без HTML-обёртки.

Официальный валидатор Google для Android:

```bash
curl "https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://rsauto-rs.vercel.app&relation=delegate_permission/common.handle_all_urls"
```

Ответ должен содержать `"maxAge"` и ваш package name. Если видите
`ERROR_FETCHING_STATEMENT` — файл недоступен или отдаётся с редиректом.

Проверка на устройстве после установки приложения (Android):

```bash
adb shell am start -a android.intent.action.VIEW -d "https://rsauto-rs.vercel.app/car/00000000-0000-0000-0000-000000000000"
```

## Что настроить в самом приложении

Серверная часть готова: RPC `get_car_details` и `search_cars_with_links`
возвращают `site_url` вида `https://rsauto-rs.vercel.app/car/{id}`, а роут `/car/:id`
в приложении уже существует.

Клиентская часть тоже настроена:

1. **Android** — в `android/app/src/main/AndroidManifest.xml` есть
   `intent-filter` с `android:autoVerify="true"` на хост
   `rsauto-rs.vercel.app` и путь `/car/*`.
2. **iOS** — `ios/Runner/Runner.entitlements` (Debug) и
   `RunnerRelease.entitlements` (Release/Profile) содержат
   `applinks:rsauto-rs.vercel.app`; оба файла подключены в
   `project.pbxproj` через `CODE_SIGN_ENTITLEMENTS`.

Осталось (после перехода на собственный домен): подставить Team ID и
SHA-256 в файлы этой папки, заменить хост в манифесте и entitlements.

Обработка входящей ссылки отдельного кода не требует: go_router разбирает
путь `/car/{id}` существующим роутом.

## Смена домена

Базовый адрес хранится на сервере в одной строке — менять его в коде
приложения не нужно. Из-под администратора:

```sql
select public.set_site_base_url('https://rsauto-rs.vercel.app');
```

Все `site_url` начнут отдаваться с новым доменом сразу, без пересборки
приложения.
