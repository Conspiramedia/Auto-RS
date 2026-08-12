# Экран «Карточка автомобиля» (гибрид: Продажа + Аренда) — архитектура для FlutterFlow

Единый экран `CarDetailScreen` обслуживает оба бизнес-блока. Что показывать —
решает флаг режима, переданный при открытии, и флаги `is_for_sale` / `is_for_rent`
самого объявления. Вся финансовая логика — на сервере (Thick Backend);
экран только собирает ввод и вызывает RPC.

---

## 1. Параметры страницы (Page Parameters)

| Параметр | Тип | Назначение |
|---|---|---|
| `carId` | `String` (uuid) | ID объявления. По нему грузим carRow, фото и занятые даты. |
| `initialMode` | `String` | С какого каталога пришли: `'sale'` или `'rent'`. Определяет, какой блок раскрыт по умолчанию у объявления с обоими флагами. |

При открытии экрана (On Page Load):
1. **Backend Query** `cars` по `carId` → `carRow` (Page State).
2. **Backend Query** `car_images` по `car_id = carId`, сортировка `order_index` → список фото.
3. Если объявление в аренде (`carRow.is_for_rent`):
   **Backend Query** `bookings` по `car_id = carId` со `status IN ('confirmed','paid')`
   → из результата собрать `blockedDates` (List<DateTime>) для календаря
   (развернуть каждую бронь в перечень дней `start_date..end_date`).

---

## 2. Общие блоки (видны всегда, при любом типе)

```
CarDetailScreen (Scaffold)
└── SingleChildScrollView (Column)
    ├── PhotoGallery (carousel_slider)      // фото из car_images по order_index
    ├── TitleBlock                          // "{brand} {model}, {year}"
    ├── SpecsGrid                           // пробег, кузов, КПП, топливо, город
    ├── DescriptionBlock                    // description
    ├── [ SALE-блок ]   <- Conditional Visibility
    ├── [ RENT-блок ]   <- Conditional Visibility
    └── SellerContactsBar                   // общий низ (см. ниже)
```

---

## 3. Тип 'sale' (Продажа)

**Условие видимости SALE-блока:** `carRow.is_for_sale == true`.

```
SaleBlock (Column)  [visible if carRow.is_for_sale]
├── SalePriceText            // "{sale_price} {currency}"  крупно
├── Row(
│    ├── Button "Позвонить"  // видна если seller.phone != null
│    └── Button "Чат"
│   )
```

Видны: `SalePriceText`, кнопки «Позвонить» / «Чат».
Скрыты (относительно аренды): календарь `CarBookingCalendar`, `PriceBreakdown`,
кнопка «Забронировать» — они принадлежат RENT-блоку.

**Действия кнопок:**
- **«Позвонить»** → Action `Launch URL` со схемой `tel:` + `carRow.seller_phone`
  (телефон продавца тянем join'ом `cars → profiles`; если `null` — кнопку скрыть).
- **«Чат»** → Navigate to `ChatScreen` с параметрами
  `peerId = carRow.user_id`, `carId = carRow.id`
  (экран чата — отдельная фича, реализуется позже; пока это переход-заглушка).

---

## 4. Тип 'rent' (Аренда)

**Условие видимости RENT-блока:** `carRow.is_for_rent == true`.

```
RentBlock (Column)  [visible if carRow.is_for_rent]
├── RentPriceText                 // "{rent_price_daily} {currency} / сутки"
├── CarBookingCalendar            // наш Custom Widget
│      params:
│        blockedDates = pageState.blockedDates
│        pricePerDay  = carRow.rent_price_daily
│      callback onDatesSelected(start, end, totalPrice):
│        -> pageState.selStart = start
│        -> pageState.selEnd   = end
│        -> pageState.selTotal = totalPrice   // предварительный расчёт для UI
├── PriceBreakdown                // [visible if selStart != null]
│      subtotal    = selTotal
│      commission  = selTotal * 0.10          // ТОЛЬКО показ; сервер посчитает точно
│      deposit     = carRow.deposit_amount
│      к оплате    = selTotal + commission + deposit  (депозит строкой отдельно)
└── Button "Забронировать"        // [visible if selStart != null && selEnd != null]
```

Видны: `RentPriceText`, календарь, `PriceBreakdown`, кнопка «Забронировать».
Скрыты (относительно продажи): `SalePriceText`.
Кнопки «Позвонить»/«Чат» из общего `SellerContactsBar` могут оставаться видимыми
и в аренде (связь с арендодателем полезна) — по продуктовому решению.

**Объявление с обоими флагами** (`is_for_sale && is_for_rent`): видны ОБА блока.
Порядок/приоритет раскрытия задаём по `initialMode` (с какого каталога пришёл юзер).

---

## 5. Action Flow кнопки «Забронировать»

Предусловие: пользователь авторизован. Если `currentUser == null` →
Navigate to `LoginScreen` и прервать цепочку.

```
1. Проверка: selStart != null AND selEnd != null
   └─ нет → Snackbar "Выберите даты аренды" → STOP

2. (Опционально) Set loading = true

3. RPC  is_car_available
      params: p_car_id = carId,
              p_start  = selStart (формат 'YYYY-MM-DD'),
              p_end    = selEnd
      → result: bool available

4. Условие по available:
   ├─ FALSE → Snackbar "К сожалению, эти даты уже заняты" 
   │          → (перезагрузить blockedDates) → STOP
   │
   └─ TRUE  → продолжаем:

5. Backend Insert  bookings
      values:
        car_id      = carId
        customer_id = currentUser.uid
        start_date  = selStart
        end_date    = selEnd
        // статус 'pending' проставит БД по умолчанию;
        // rent_subtotal / platform_commission / total_price
        // посчитает триггер calc_booking_totals на сервере —
        // клиент эти поля НЕ передаёт (защита от подмены цены).
      → insertedBooking

6. Set loading = false

7. Успех:
      Snackbar "Заявка отправлена. Ожидайте подтверждения владельца."
      Navigate to  MyBookingsScreen  (или BookingDetail с insertedBooking.id)
```

**Важно про гонки.** Между шагом 3 (проверка) и шагом 5 (вставка) даты могут
занять. Это нормально: `bookings` в статусе `pending` НЕ конфликтует с чужими
бронями (EXCLUDE срабатывает только на `confirmed`), поэтому вставка pending
пройдёт всегда. Реальная защита от овербукинга — на шаге подтверждения владельцем
(`confirm_booking`), где EXCLUDE-констрейнт физически не даст пересечься двум
`confirmed`-броням. Проверка `is_car_available` на шаге 3 нужна для UX —
не дать клиенту подать заявку на заведомо занятые даты.

---

## 6. Итог по маппингу «тип → видимость»

| Блок | sale | rent | sale+rent |
|---|:---:|:---:|:---:|
| Галерея, характеристики, описание | ✅ | ✅ | ✅ |
| SalePriceText | ✅ | ❌ | ✅ |
| Кнопки Позвонить / Чат | ✅ | ✅* | ✅ |
| RentPriceText | ❌ | ✅ | ✅ |
| CarBookingCalendar | ❌ | ✅ | ✅ |
| PriceBreakdown | ❌ | ✅ (после выбора дат) | ✅ |
| Кнопка «Забронировать» | ❌ | ✅ (после выбора дат) | ✅ |

\* Контакты в аренде — по продуктовому решению (обычно оставляют).
