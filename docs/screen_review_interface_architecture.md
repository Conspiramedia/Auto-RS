# Интерфейс отзывов (Review Interface) — архитектура для FlutterFlow

Клиент оценивает завершённую аренду. Опирается на миграцию 0022: таблица
`reviews` (1 отзыв на бронь, только completed), триггеры `check_review_allowed`
(гейт) и `update_car_rating` (авто-пересчёт рейтинга машины).

Репозиторий: `reviews_repository.dart` (`createReview`, `existsForBooking`,
`reviewedBookingIds`).

---

## 1. Кнопка «Оценить поездку» на списке броней клиента

### 1.1. Двухслойная условная видимость

Кнопка видна, только если выполнены ОБА условия:
1. `booking.status == 'completed'` — аренда завершена;
2. по этой броне ещё НЕТ отзыва (иначе повторный INSERT упрётся в
   `booking_id UNIQUE`).

**Способ реализации проверки «нет отзыва» — важно (против N+1):**

- **Рекомендуется — batch через App/Page State `reviewedBookingIds`:**
  На On Page Load экрана «Мои брони» один раз тянем множество booking_id,
  по которым отзыв уже есть:
  ```
  reviewedBookingIds = reviewsRepository.reviewedBookingIds()  // Set<String>
  ```
  Тогда видимость кнопки:
  ```
  booking.status == 'completed'
    AND  NOT reviewedBookingIds.contains(booking.id)
  ```
  Один запрос на весь список — карточки не дёргают БД по отдельности.

- **Альтернатива (проще, но N+1) — existsForBooking на карточку:**
  вызывать `existsForBooking(booking.id)` для каждой строки. Работает, но
  при длинном списке это много запросов. Для MVP допустимо, для роста — batch.

### 1.2. Action Flow кнопки «Оценить поездку»

```
1. Open Bottom Sheet  ReviewRatingSheet
     params:
       bookingId = booking.id
       carId     = booking.car_id
     (Await = ON — ждём закрытия, чтобы затем обновить список)

2. (после закрытия Bottom Sheet) Refresh Database Request → Query "Мои брони"
   + (если используем batch) обновить reviewedBookingIds
   → кнопка «Оценить» исчезнет для этой брони
```

---

## 2. Компонент формы отзыва (ReviewRatingSheet)

### 2.1. Параметры и состояние

| Элемент | Тип | Назначение |
|---|---|---|
| Component Parameter `bookingId` | String | по какой броне отзыв |
| Component Parameter `carId` | String | машина (сервер всё равно перепроверит из брони) |
| Component State `selectedRating` | int | выбранный рейтинг 1..5 (дефолт 5 или 0) |
| Component State `inputComment` | String | текст комментария (bind к TextField) |
| Component State `isSubmitting` | bool | идёт отправка |

### 2.2. Widget Tree

```
ReviewRatingSheet (Column, padding)
├── Text "Оцените поездку" (заголовок)
├── RatingBar (1..5 звёзд)  → bind selectedRating
│      // пакет: RatingBar из FlutterFlow или flutter_rating_bar
│      allowHalfRating = false; initialRating = 0
├── TextField "Комментарий (необязательно)"  → bind inputComment
│      multiline, hint "Расскажите о поездке"
└── Button "Отправить"       → Action Flow §3
       disabled if isSubmitting == true
```

---

## 3. Action Flow кнопки «Отправить»

```
1. Валидация: selectedRating < 1 ?
   └─ ДА → SnackBar "Поставьте оценку от 1 до 5 звёзд" → STOP

2. Set isSubmitting = true
   Show Loader (или спиннер на кнопке)

3. Backend Call → Supabase Insert  reviews
     values:
       booking_id  = component.bookingId
       car_id      = component.carId     // сервер перезапишет корректным из брони
       customer_id = currentUser.uid
       rating      = selectedRating
       comment     = inputComment (nullable)
   // Триггер check_review_allowed проверит: бронь completed + автор.
   // Триггер update_car_rating пересчитает rating_avg/reviews_count машины.

4a. On Success:
      - Hide Loader / isSubmitting = false
      - Close Bottom Sheet
      - SnackBar "Спасибо за отзыв!"
      - (родитель) Refresh Database Request "Мои брони"
        + обновить reviewedBookingIds → кнопка «Оценить» исчезает

4b. On Failure:
      - Hide Loader / isSubmitting = false        // критично против зависания UI
      - SnackBar( Action Error Message )
        // возможные тексты серверных проверок:
        //  "Отзыв можно оставить только по завершённой аренде (статус completed)"
        //  "Отзыв может оставить только автор брони"
        //  дубль (booking_id UNIQUE) → ошибка уникальности от БД
```

### 3.1. Гарантированное обновление родительского списка

Чтобы кнопка «Оценить» мгновенно исчезла после отправки, список броней надо
перезапросить. Надёжный паттерн — Refresh делаем НА РОДИТЕЛЕ после закрытия шита:

```
На экране «Мои брони», в Action кнопки «Оценить поездку»:
1. Open Bottom Sheet ReviewRatingSheet (Await = ON)
2. (после закрытия) Refresh Database Request → Query "Мои брони"
3. (если batch) reviewedBookingIds = reviewsRepository.reviewedBookingIds()
```

Так после успешной вставки (шит закрылся) список перечитается, `reviewedBookingIds`
пополнится этим booking_id → двухслойное условие видимости даст false → кнопка
исчезнет. Отзыв уже виден в рейтинге машины (триггер update_car_rating).

---

## 4. Сводка

| Элемент | Механизм | Опора |
|---|---|---|
| Видимость кнопки | status == completed AND нет отзыва | 0022 (UNIQUE), reviewedBookingIds |
| Форма | RatingBar + comment + submit | — |
| Отправка | Insert reviews (сервер проверит гейт) | триггер check_review_allowed |
| Пересчёт рейтинга | автоматически | триггер update_car_rating |
| Обновление списка | Refresh на родителе после Close | — |

**Защита:** отзыв только по своей completed-броне (триггер + RLS);
рейтинг машины пересчитывается сервером, клиент его не трогает.
```
