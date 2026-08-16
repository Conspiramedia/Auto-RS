# Deep links (App Links / Universal Links) — Auto.RS

Файлы в этой папке подтверждают связь домена и приложения. Без них ссылка
`https://ВАШ-ДОМЕН/car/{id}` откроется в браузере, а не в приложении.

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
https://ВАШ-ДОМЕН/.well-known/apple-app-site-association
https://ВАШ-ДОМЕН/.well-known/assetlinks.json
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
curl -i https://ВАШ-ДОМЕН/.well-known/assetlinks.json
```

iOS (обратите внимание: без `.json` на конце):

```bash
curl -i https://ВАШ-ДОМЕН/.well-known/apple-app-site-association
```

В обоих случаях ожидается `HTTP/2 200`, заголовок
`content-type: application/json` и содержимое файла без HTML-обёртки.

Официальный валидатор Google для Android:

```bash
curl "https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://ВАШ-ДОМЕН&relation=delegate_permission/common.handle_all_urls"
```

Ответ должен содержать `"maxAge"` и ваш package name. Если видите
`ERROR_FETCHING_STATEMENT` — файл недоступен или отдаётся с редиректом.

Проверка на устройстве после установки приложения (Android):

```bash
adb shell am start -a android.intent.action.VIEW -d "https://ВАШ-ДОМЕН/car/00000000-0000-0000-0000-000000000000"
```

## Что настроить в самом приложении

Серверная часть готова: RPC `get_car_details` и `search_cars_with_links`
возвращают `site_url` вида `https://ВАШ-ДОМЕН/car/{id}`, а роут `/car/:id`
в приложении уже существует.

Осталось (делается после получения Team ID и отпечатка):

1. **Android** — в `android/app/src/main/AndroidManifest.xml` к активити
   добавляется `intent-filter` с `android:autoVerify="true"` и хостом вашего
   домена.
2. **iOS** — в Xcode: Signing & Capabilities → Associated Domains →
   `applinks:ВАШ-ДОМЕН`.
3. Обработка входящей ссылки в приложении: разбор пути `/car/{id}` и переход
   на существующий роут.

## Смена домена

Базовый адрес хранится на сервере в одной строке — менять его в коде
приложения не нужно. Из-под администратора:

```sql
select public.set_site_base_url('https://ВАШ-ДОМЕН');
```

Все `site_url` начнут отдаваться с новым доменом сразу, без пересборки
приложения.
