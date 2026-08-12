# Экран «Подать объявление» (Create Car Screen) — архитектура для FlutterFlow

Экран `CreateCarScreen` собирает данные объявления, загружает фото в Storage
и вызывает RPC `create_car_v2` (миграция 0014). Объявление создаётся со статусом
`moderation` — далее его проверяет админ.

Опирается на миграцию 0014:
- бакет `car-images` (RLS: запись только в папку `auth.uid()`);
- RPC `create_car_v2(listing_type, brand, model, year, mileage, price, currency,
  city, lat, lng, photo_urls[])` → возвращает `uuid`.

---

## 1. Схема загрузки медиафайлов

### Ключевое правило пути (RLS бакета)

Политика бакета требует, чтобы **первый сегмент пути = `auth.uid()`**:

```
<auth.uid()> / <tempCarUuid> / <имя_файла>
   папка юзера      папка машины       файл
```

- `auth.uid()` — **первым** (иначе RLS `car_images_insert_own` отклонит загрузку);
- `tempCarUuid` — временный UUID, сгенерированный на клиенте (Custom Function
  `generateTempUuid`), т.к. реальный `car_id` появится только после RPC;
- файлы загружаются ДО вызова `create_car_v2`, их публичные URL собираются
  в список и передаются в параметр `photo_urls`.

### Page State для экрана

| Переменная | Тип | Назначение |
|---|---|---|
| `tempCarUuid` | String | временный UUID папки машины (генерируется в On Page Load) |
| `uploadedUrls` | List<String> | публичные URL загруженных фото (для RPC) |
| `isUploading` | bool | идёт загрузка фото |
| `isPublishing` | bool | идёт публикация (вызов RPC) |
| `listingType` | String | `'sale'` / `'rent'` / `'both'` (переключатель) |
| `lat`, `lng` | double? | координаты (из гео-пикера/карты, опционально) |

### On Page Load

1. Проверка авторизации: если `currentUser == null` → Navigate `LoginScreen`, STOP.
2. `tempCarUuid = generateTempUuid()` (Custom Function) → в Page State.

### Пошаговая логика Image/Media Picker

1. Кнопка «Добавить фото» → Action **Upload/Save Media** (или **Upload to Supabase**).
2. Источник: галерея/камера (`image_picker` под капотом).
3. **Upload Path** настраиваем как выражение:
   ```
   [currentUser.uid] / [pageState.tempCarUuid] / [uploadedFileName]
   ```
   Бакет: `car-images`.
   > Во FlutterFlow это задаётся в настройках Supabase Upload:
   > Bucket = `car-images`, Path/Folder =
   > `${currentUserUid}/${pageState.tempCarUuid}` (имя файла добавится само).
4. Пока грузится: `isUploading = true` (показать спиннер на плитке фото).
5. On Upload Success: полученный публичный URL → **Add to** `pageState.uploadedUrls`.
6. `isUploading = false`.
7. Повторить для нескольких фото (лимит — `AppConstants.maxCarImages = 15`).
8. Удаление фото из списка: Remove from `uploadedUrls` (+ по желанию Delete из Storage).

> Порядок элементов в `uploadedUrls` = порядок фото в галерее: RPC разложит их
> в `car_images.order_index` (0,1,2...) ровно в этом порядке.

---

## 2. Custom Function валидации

Файл: `lib/features/listings/utils/validate_car_form.dart` → `validateCarForm`.

- Return Type: **String? (nullable)** — `null` = валидно; иначе текст ошибки.
- Arguments: `brand, model, year, price, city, photoUrls`.
- Проверяет: непустые марка/модель/город, год в диапазоне 1900..текущий+1
  (защита от «будущего»), цена > 0, минимум одно фото.

Custom Function `generateTempUuid` (файл `generate_temp_uuid.dart`) —
для имени папки машины (зависимость `uuid`).

---

## 3. Action Flow кнопки «Опубликовать»

```
1. Валидация формы (Custom Function validateCarForm)
   errText = validateCarForm(brand, model, year, price, city, uploadedUrls)

2. Условие: errText != null ?
   └─ ДА → SnackBar(errText) → STOP   // форма невалидна, RPC не зовём

3. Условие: pageState.isUploading == true ?
   └─ ДА → SnackBar("Дождитесь загрузки фото") → STOP

4. Set pageState.isPublishing = true
   Показать Loader-диалог (Show Loading Indicator / модальный спиннер),
   чтобы UI не выглядел «зависшим» во время сетевого вызова.

5. Backend Call → Supabase RPC create_car_v2
     Params:
       listing_type = pageState.listingType
       brand        = brandField
       model        = modelField
       year         = yearField (int)
       mileage      = mileageField (int, nullable)
       price        = priceField (double)
       currency     = 'EUR'                 // дефолт рынка Сербии
       city         = cityField
       lat          = pageState.lat         // nullable
       lng          = pageState.lng         // nullable
       photo_urls   = pageState.uploadedUrls
     Сохранить результат в Action Output → newCarId (String, uuid)

6. Обработка результата Backend Call:

   6a. On Success (ошибки нет, newCarId получен):
        - Hide Loader
        - Set isPublishing = false
        - SnackBar "Объявление отправлено на модерацию"
        - Navigate to  MyCarsScreen  (или CarDetail с newCarId)
        - (Опц.) Reset формы / очистить Page State

   6b. On Failure (RPC вернул ошибку / EXCEPTION):
        - Hide Loader                       // КРИТИЧНО: иначе интерфейс зависнет
        - Set isPublishing = false
        - SnackBar( Action Error Message )  // текст из RAISE EXCEPTION сервера
        // типичные тексты:
        //  "Требуется авторизация для создания объявления"
        //  "Некорректный listing_type = ..."
        //  нарушение CHECK (например, цена/год) — придёт как ошибка БД
```

### Как не дать интерфейсу зависнуть при сбое

Главное правило: **скрытие Loader и сброс `isPublishing` должны выполняться
в ОБЕИХ ветках** — и Success, и Failure. Если Loader скрывается только в Success,
то при ошибке RPC модальный спиннер останется на экране навсегда.

Механизм во FlutterFlow:
- у ноды Backend Call есть разветвление по результату
  (**Action Output** + условие, либо ветки On Success / On Failure);
- текст серверной ошибки доступен как **Action Error Message**
  (Set Variable → Action Outputs → [нода RPC] → Error Message);
- в ветке ошибки ПЕРВЫМ действием ставим Hide Loader + `isPublishing = false`,
  затем SnackBar с текстом ошибки.

> Дополнительно можно обернуть публикацию в таймаут/проверку сети
> (`connectivity_plus`), чтобы при отсутствии интернета сразу показать
> сообщение, а не ждать сетевой таймаут с висящим Loader.

---

## 4. Итоговая последовательность (сводка)

```
On Page Load → tempCarUuid = generateTempUuid()
   │
   ▼
Пользователь заполняет поля + грузит фото
   (Upload Path: uid/tempCarUuid/file → uploadedUrls[])
   │
   ▼
Кнопка «Опубликовать»
   → validateCarForm (null?) 
   → Loader ON + isPublishing=true
   → RPC create_car_v2(..., photo_urls=uploadedUrls) 
        ├─ Success → newCarId → Loader OFF → «на модерации» → MyCars
        └─ Failure → Loader OFF → SnackBar(Action Error Message)
```

Объявление создаётся со статусом `moderation`; далее — админ-модерация
(`approve_car` / `reject_car`, миграция 0015).
