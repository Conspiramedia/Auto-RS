// ============================================================
// AUTO.RS — Модель выбранных фильтров каталога.
// Хранит состояние фильтров между главным экраном и экраном фильтров.
// ============================================================

class CarFilters {
  final String? brand;
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
    this.brand,
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

  // Пустые фильтры (ничего не выбрано)
  static const CarFilters empty = CarFilters();

  // Сколько фильтров активно (для бэйджа на кнопке «Фильтры»)
  int get activeCount {
    var n = 0;
    if (brand != null) n++;
    if (city != null) n++;
    if (yearFrom != null || yearTo != null) n++;
    if (mileageMax != null) n++;
    if (priceFrom != null || priceTo != null) n++;
    if (bodyType != null) n++;
    if (transmission != null) n++;
    if (fuel != null) n++;
    return n;
  }

  CarFilters copyWith({
    String? brand,
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
      brand: brand ?? this.brand,
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
