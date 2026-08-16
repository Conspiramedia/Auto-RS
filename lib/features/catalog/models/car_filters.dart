// ============================================================
// AUTO.RS — Модель выбранных фильтров каталога.
// Хранит состояние фильтров между главным экраном и экраном фильтров.
// ============================================================

// Вид фильтра — что именно снимает «×» на чипсе. Год и цена одним значением:
// они показаны диапазоном и снимаются целиком.
enum CarFilterKind {
  listingType,
  brand,
  model,
  city,
  year,
  mileage,
  price,
  bodyType,
  transmission,
  fuel,
}

class CarFilters {
  // Тип объявления: 'sale' | 'rent' | null (любой — продажа и аренда вместе).
  final String? listingType;
  final String? brand;
  final String? model;
  final String? city;
  final int? yearFrom;
  final int? yearTo;
  final int? mileageMax;
  final double? priceFrom;
  final double? priceTo;
  final String? bodyType;
  final String? transmission;
  final String? fuel;

  const CarFilters({
    this.listingType,
    this.brand,
    this.model,
    this.city,
    this.yearFrom,
    this.yearTo,
    this.mileageMax,
    this.priceFrom,
    this.priceTo,
    this.bodyType,
    this.transmission,
    this.fuel,
  });

  static const CarFilters empty = CarFilters();

  // Сколько фильтров активно (для бэйджа на кнопке «Фильтры»)
  int get activeCount {
    var n = 0;
    if (listingType != null) n++;
    if (brand != null) n++;
    if (model != null) n++;
    if (city != null) n++;
    if (yearFrom != null || yearTo != null) n++;
    if (mileageMax != null) n++;
    if (priceFrom != null || priceTo != null) n++;
    if (bodyType != null) n++;
    if (transmission != null) n++;
    if (fuel != null) n++;
    return n;
  }

  // Фильтры в формате jsonb для сохранённого поиска (RPC
  // save_search_from_filters). Ключи совпадают с предикатом
  // car_matches_filters на сервере — подписка проверяется ровно по тем же
  // условиям, по которым каталог отбирает объявления, поэтому пуш не может
  // прийти про машину, которой нет в результатах поиска.
  //
  // Пустые значения не включаем: сервер трактует отсутствие ключа как
  // «фильтр не задан».
  Map<String, dynamic> toSearchFilters() {
    final map = <String, dynamic>{};
    if (listingType != null) map['listing_type'] = listingType;
    if (brand != null) map['brand'] = brand;
    if (model != null) map['model'] = model;
    if (city != null) map['city'] = city;
    if (fuel != null) map['fuel'] = fuel;
    if (bodyType != null) map['body_type'] = bodyType;
    if (transmission != null) map['transmission'] = transmission;
    if (mileageMax != null) map['mileage_max'] = mileageMax;
    if (priceFrom != null) map['price_from'] = priceFrom;
    if (priceTo != null) map['price_to'] = priceTo;
    if (yearFrom != null) map['year_from'] = yearFrom;
    if (yearTo != null) map['year_to'] = yearTo;
    return map;
  }

  // ----------------------------------------------------------
  // Снятие одного фильтра (тап по «×» на чипсе).
  //
  // Через copyWith это не сделать: там `value ?? this.value`, то есть
  // передача null означает «не менять», а не «сбросить». Поэтому собираем
  // новый объект явно, обнуляя нужное поле.
  //
  // Год и цена сбрасываются ПАРОЙ (от и до): на чипсе они показаны одним
  // диапазоном «2015–2020», и снимать половину диапазона по тапу на × —
  // не то, чего ждёт пользователь.
  // ----------------------------------------------------------
  CarFilters removeFilter(CarFilterKind kind) {
    return CarFilters(
      listingType: kind == CarFilterKind.listingType ? null : listingType,
      brand: kind == CarFilterKind.brand ? null : brand,
      // Снимая марку, снимаем и модель: модель без марки бессмысленна
      // («3 серия» без BMW ничего не найдёт).
      model: (kind == CarFilterKind.model || kind == CarFilterKind.brand)
          ? null
          : model,
      city: kind == CarFilterKind.city ? null : city,
      yearFrom: kind == CarFilterKind.year ? null : yearFrom,
      yearTo: kind == CarFilterKind.year ? null : yearTo,
      mileageMax: kind == CarFilterKind.mileage ? null : mileageMax,
      priceFrom: kind == CarFilterKind.price ? null : priceFrom,
      priceTo: kind == CarFilterKind.price ? null : priceTo,
      bodyType: kind == CarFilterKind.bodyType ? null : bodyType,
      transmission: kind == CarFilterKind.transmission ? null : transmission,
      fuel: kind == CarFilterKind.fuel ? null : fuel,
    );
  }

  // Можно ли сохранить эти фильтры как подписку: сервер отклонит пустой
  // набор («уведомлять обо всех объявлениях» = спам), поэтому кнопку
  // «Сообщить, когда появится» показываем только при заданном фильтре.
  bool get canSaveAsSearch => toSearchFilters().isNotEmpty;

  CarFilters copyWith({
    String? listingType,
    String? brand,
    String? model,
    String? city,
    int? yearFrom,
    int? yearTo,
    int? mileageMax,
    double? priceFrom,
    double? priceTo,
    String? bodyType,
    String? transmission,
    String? fuel,
  }) {
    return CarFilters(
      listingType: listingType ?? this.listingType,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      city: city ?? this.city,
      yearFrom: yearFrom ?? this.yearFrom,
      yearTo: yearTo ?? this.yearTo,
      mileageMax: mileageMax ?? this.mileageMax,
      priceFrom: priceFrom ?? this.priceFrom,
      priceTo: priceTo ?? this.priceTo,
      bodyType: bodyType ?? this.bodyType,
      transmission: transmission ?? this.transmission,
      fuel: fuel ?? this.fuel,
    );
  }
}
