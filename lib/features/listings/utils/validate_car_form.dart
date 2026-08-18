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
// Arguments (порядок проверок = порядок полей на экране):
//   brand      : String   (Nullable)
//   model      : String   (Nullable)
//   year       : int      (Nullable)
//   price      : double   (Nullable)
//   city       : String   (Nullable)
//   photoUrls  : List<String>  (Nullable)
//   phone      : String   (Nullable)
//
// Примечание: возвращаем именно текст ошибки (а не bool), потому что
// одна Custom Function во FlutterFlow отдаёт одно значение. Так удобнее:
// в Action Flow проверяем "результат == null" и берём этот же текст в SnackBar.
// -----------------------------------------------------------------

import '../../../core/i18n/app_strings.dart';

String? validateCarForm(
  String? brand,
  String? model,
  int? year,
  double? price,
  String? city,
  List<String>? photoUrls,
  String? phone, {
  // Словарь передаётся параметром: функция чистая и не имеет доступа к
  // BuildContext, а тексты ошибок обязаны быть на языке интерфейса.
  required AppStrings t,
}) {
  // Текущий год для проверки корректности года выпуска
  final int currentYear = DateTime.now().year;

  // Порядок проверок соответствует порядку полей на экране «Подать
  // объявление»: Город → Марка → Модель → Год → Цена → Телефон → Фото.
  // Так первая же ошибка указывает на верхнее незаполненное поле.

  // ---------- Город ----------
  if (city == null || city.trim().isEmpty) {
    return t.validateCityRequired;
  }

  // ---------- Марка ----------
  if (brand == null || brand.trim().isEmpty) {
    return t.validateBrandRequired;
  }

  // ---------- Модель ----------
  if (model == null || model.trim().isEmpty) {
    return t.validateModelRequired;
  }

  // ---------- Год выпуска ----------
  if (year == null) {
    return t.validateYearRequired;
  }
  if (year < 1900) {
    return t.validateYearTooOld;
  }
  // Допускаем текущий год и следующий (новые модели), но не дальше в будущее
  if (year > currentYear + 1) {
    return t.validateYearFuture;
  }

  // ---------- Цена ----------
  // Цена опциональна («Договорная»): на экране сюда передаётся фиктивная
  // валидная величина, а фактическая проверка введённой цены выполняется
  // отдельно в _publish. Блок оставлен для консистентности порядка полей.
  if (price == null || price <= 0) {
    return t.validatePricePositive;
  }

  // ---------- Телефон (сербский, обязательный) ----------
  if (phone == null || phone.trim().isEmpty) {
    return t.validatePhoneRequired;
  }
  // Оставляем только цифры (убираем +, пробелы, скобки, дефисы)
  final phoneDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  // Приводим к национальному виду без кода страны и ведущего 0:
  //   +381 6X… → 3816XXXXXXX → 6XXXXXXX
  //   00381…   → тоже отбрасываем
  String national = phoneDigits;
  if (national.startsWith('00381')) {
    national = national.substring(5);
  } else if (national.startsWith('381')) {
    national = national.substring(3);
  } else if (national.startsWith('0')) {
    national = national.substring(1);
  }
  // Принимаем два вида сербских номеров:
  //   • мобильный:  6 + 7…8 цифр  (06X → +3816…), напр. 641234567
  //   • городской:  код зоны 1…3 + абонент, всего 8…9 цифр,
  //                 напр. Белград 11 XXXXXXX, Нови-Сад 21 XXXXXX.
  final isMobile = RegExp(r'^6\d{7,8}$').hasMatch(national);
  final isLandline = RegExp(r'^[1-3]\d{7,8}$').hasMatch(national);
  if (!isMobile && !isLandline) {
    return t.validatePhoneFormat;
  }

  // ---------- Фотографии (последнее поле формы) ----------
  if (photoUrls == null || photoUrls.isEmpty) {
    return t.validatePhotoRequired;
  }

  // Всё в порядке — ошибок нет
  return null;
}
