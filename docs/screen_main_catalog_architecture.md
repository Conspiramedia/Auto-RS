# Главный экран каталога (Main Catalog Screen) — архитектура для FlutterFlow

Экран `MainCatalogScreen` — витрина объявлений с фильтрами: поиск по тексту,
тип сделки (купить/арендовать), радиус гео-поиска. Данные тянет RPC
`search_cars_advanced` (миграция 0017). Гостям доступен (grant anon).

Опорные Custom Functions:
- `normalizeQuery(query)` → String? (пустая строка → null)
- `normalizeRadiusKm(radiusKm, hasCoords)` → double? (0/нет координат → null)

---

## 1. Page State (переменные состояния)

| Переменная | Тип | Дефолт | Назначение |
|---|---|---|---|
| `searchQuery` | String? | null | текст поиска |
| `listingType` | String | `'sale'` | `'sale'` / `'rent'` |
| `radiusKm` | double | 0 | радиус слайдера (0 = гео выкл.) |
| `userLat` | double? | null | широта устройства |
| `userLng` | double? | null | долгота устройства |
| `hasCoords` | bool | false | удалось ли определить гео |
| `isLoading` | bool | false | идёт запрос |

---

## 2. Widget Tree верхней панели фильтров

```
MainCatalogScreen (Column)
├── FilterBar (Container, padding)
│   ├── SearchField (Row)
│   │   ├── TextField  → bind searchQuery
│   │   │     * onSubmitted (On Submit) → Action: применить фильтры (см. §4)
│   │   │     * suffixIcon "✕" (кнопка очистки):
│   │   │         visible if searchQuery != null && searchQuery != ''
│   │   │         onTap → searchQuery = '' → применить фильтры
│   │   └── (Опц.) IconButton "Найти" → применить фильтры
│   │
│   ├── ChoiceChips "Тип сделки"  → bind listingType
│   │     Опции: [Купить → 'sale'], [Арендовать → 'rent']
│   │     onChanged → listingType = выбор → применить фильтры
│   │
│   └── RadiusSlider (Column)   ← Conditional Visibility (см. ниже)
│         ├── Text "Радиус: {radiusKm.round()} км"
│         └── Slider  min=0 max=100 divisions=20 → bind radiusKm
│               onChangeEnd → применить фильтры
│               // onChangeEnd, НЕ onChanged: не дёргаем БД на каждый пиксель
│
└── ResultsList (ListView)
    └── Backend Query search_cars_advanced → CarCard (компонент строки)
```

### Условная видимость слайдера радиуса

По ТЗ слайдер виден, только когда:
```
hasCoords == true   AND   listingType == 'rent'
```
- `hasCoords` — координаты определены (иначе гео-фильтр невозможен);
- `listingType == 'rent'` — продуктовое решение из ТЗ (радиус для аренды).

> Примечание: гео-фильтр в RPC работает и для 'sale'. Ограничение слайдера
> типом 'rent' — это выбор ТЗ, а не техническое ограничение. Если позже
> захотите радиус и для покупки — достаточно убрать условие `== 'rent'`.

---

## 3. On Page Load — инициализация и геолокация

```
1. Set isLoading = true

2. Action: Request Location Permission (встроенный экшен FlutterFlow
   "Request Permissions" → Location)  ИЛИ  Get Current Device Location
   с флагом запроса прав.

3. Условие: разрешение получено И координаты вернулись?
   ├─ ДА (успех):
   │     userLat = deviceLocation.latitude
   │     userLng = deviceLocation.longitude
   │     hasCoords = true
   │
   └─ НЕТ (пользователь запретил GPS / гео недоступно):
         // ВАРИАНТ A (рекомендуется для MVP): гео-фильтр просто выключен.
         userLat = null
         userLng = null
         hasCoords = false
         radiusKm = 0            // слайдер скрыт (hasCoords=false), гео в RPC = null
         // → выдача без гео-фильтра, объявления НЕ ломаются
         //   (normalizeRadiusKm вернёт null при hasCoords=false).

4. Первичный запрос каталога (Refresh Database Request / загрузка ListView)
   с текущими фильтрами (см. §5 маппинг параметров).

5. Set isLoading = false
```

### Про дефолтные координаты (альтернатива варианту A)

Если продукту важно ВСЕГДА иметь точку отсчёта (например, показывать
«Белград по умолчанию»), в ветке отказа можно подставить центр Белграда:

```
userLat = 44.7866    // Белград, широта
userLng = 20.4489    // Белград, долгота
hasCoords = true
```

**Различие подходов:**
- **Вариант A (null):** честнее — без разрешения гео не фильтруем вовсе,
  показываем все активные объявления. Слайдер скрыт.
- **Вариант B (Белград):** всегда есть точка, слайдер доступен, но выдача
  «привязана» к Белграду, что может ввести в заблуждение пользователя из
  Нови-Сада. Рекомендуется A для MVP; B — если нужен гарантированный гео-контекст.

---

## 4. «Применить фильтры» — общий Action (переиспользуемый)

Вызывается из каждого фильтра (On Submit поиска, смена чипа, onChangeEnd слайдера,
очистка поиска). Суть — пересобрать параметры и перезапросить каталог.

```
1. (Опц.) isLoading = true
2. Refresh Database Request  →  Query "search_cars_advanced"
     (Query перечитается с актуальными Page State — маппинг в §5)
3. (Опц.) isLoading = false
```

> Во FlutterFlow ListView питается от Backend Query. Меняя Page State и вызывая
> Refresh Database Request этого запроса, мы автоматически перерисовываем список.
> Отдельный ре-рендер писать не нужно.

---

## 5. Маппинг Page State → параметры RPC search_cars_advanced

Настраивается в параметрах Backend Query. Ключевой момент — предобработка
через Custom Functions, чтобы «пустые» значения превратились в NULL:

| Параметр RPC | Значение (через Custom Function) |
|---|---|
| `p_listing_type` | `pageState.listingType` (`'sale'`/`'rent'`) |
| `p_search_query` | `normalizeQuery(pageState.searchQuery)` → null если пусто |
| `p_user_lat` | `pageState.hasCoords ? pageState.userLat : null` |
| `p_user_lng` | `pageState.hasCoords ? pageState.userLng : null` |
| `p_radius_km` | `normalizeRadiusKm(pageState.radiusKm, pageState.hasCoords)` → null если 0/нет гео |

### Зачем нужны Custom Functions (ответ на вопрос ТЗ)

**Да, предобработка нужна.** Слайдер физически не может отдать «null» — в нулевом
положении он отдаёт `0.0`. Если передать `0.0` в `p_radius_km`, RPC применит
`ST_DWithin(..., 0)` и вернёт пустой список (нет машин в радиусе 0 метров).
Поэтому `normalizeRadiusKm` конвертирует `0.0` (и случай «нет координат») в `null`,
и тогда RPC ОТКЛЮЧАЕТ гео-фильтр (ветка `p_radius_km <= 0 → фильтр не применяется`).

Аналогично `normalizeQuery` превращает пустую строку в null, чтобы не запускать
триграммный поиск по пустому запросу.

Обе функции — в `lib/features/catalog/utils/`:
- `normalize_query.dart` → `normalizeQuery`
- `normalize_search_params.dart` → `normalizeRadiusKm`

---

## 6. Реакция каждого фильтра (сводка триггеров)

| Действие пользователя | Обновляет Page State | Триггер |
|---|---|---|
| Ввод текста + Enter | `searchQuery` | On Submit → Применить фильтры |
| Кнопка «✕» очистки | `searchQuery = ''` | onTap → Применить фильтры |
| Смена чипа Купить/Арендовать | `listingType` | onChanged → Применить фильтры + пересчёт видимости слайдера |
| Движение слайдера | `radiusKm` | onChangeEnd → Применить фильтры |
| On Page Load / гео | `userLat/Lng`, `hasCoords` | автозапрос каталога |

**Debounce (рекомендация):** для поиска «на лету» (если делать не по Enter,
а по каждому символу) добавьте задержку 300–500 мс, чтобы не слать запрос на
каждую букву. Для MVP достаточно триггера On Submit (по Enter) — без debounce.
