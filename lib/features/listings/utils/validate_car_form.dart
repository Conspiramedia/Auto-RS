// ============================================================
// AUTO.RS — Custom Function для FlutterFlow: validateCarForm
// ============================================================
// Валидация полей формы «Подать объявление» ПЕРЕД вызовом create_car_v2.
// Возвращает готовый текст ошибки (String) или null, если всё корректно.
//
// -----------------------------------------------------------------
// НАСТРОЙКА В ИНТЕРФЕЙСЕ FLUTTERFLOW (Custom Function):
//
// Имя: validateCarForm
// Return Type: String  (Nullable = ДА)
//   * null            → форма валидна, можно публиковать;
//   * непустая строка → текст ошибки для показа в SnackBar.
//
// Arguments:
//   brand      : String   (Nullable)
//   model      : String   (Nullable)
//   year       : int      (Nullable)
//   price      : double   (Nullable)
//   city       : String   (Nullable)
//   photoUrls  : List<String>  (Nullable)
//
// Примечание: возвращаем именно текст ошибки (а не bool), потому что
// одна Custom Function во FlutterFlow отдаёт одно значение. Так удобнее:
// в Action Flow проверяем "результат == null" и берём этот же текст в SnackBar.
// -----------------------------------------------------------------

String? validateCarForm(
  String? brand,
  String? model,
  int? year,
  double? price,
  String? city,
  List<String>? photoUrls,
) {
  // Текущий год для проверки корректности года выпуска
  final int currentYear = DateTime.now().year;

  // ---------- Марка ----------
  if (brand == null || brand.trim().isEmpty) {
    return 'Укажите марку автомобиля';
  }

  // ---------- Модель ----------
  if (model == null || model.trim().isEmpty) {
    return 'Укажите модель автомобиля';
  }

  // ---------- Год выпуска ----------
  if (year == null) {
    return 'Укажите год выпуска';
  }
  if (year < 1900) {
    return 'Год выпуска не может быть раньше 1900';
  }
  // Допускаем текущий год и следующий (новые модели), но не дальше в будущее
  if (year > currentYear + 1) {
    return 'Год выпуска не может быть в будущем';
  }

  // ---------- Цена ----------
  if (price == null || price <= 0) {
    return 'Цена должна быть больше нуля';
  }

  // ---------- Город ----------
  if (city == null || city.trim().isEmpty) {
    return 'Укажите город';
  }

  // ---------- Фотографии ----------
  if (photoUrls == null || photoUrls.isEmpty) {
    return 'Добавьте хотя бы одно фото автомобиля';
  }

  // Всё в порядке — ошибок нет
  return null;
}
