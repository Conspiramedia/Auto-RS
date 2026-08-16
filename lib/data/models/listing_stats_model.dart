// ============================================================
// AUTO.RS — Модели статистики объявлений (Пакет B).
//
// ListingStatsModel   — строка RPC get_my_listings_stats: объявление + метрики
//                       (одним запросом, без доборов по каждой карточке).
// ListingStatsTotals  — итог RPC get_my_stats_totals для плашки кабинета.
//
// Счётчики ведёт исключительно сервер: просмотры и контакты — через
// track_listing_event, избранное — триггерами на favorites. Клиент их
// только читает.
// ============================================================

class ListingStatsModel {
  final String carId;
  final String brand;
  final String model;
  final int year;
  final String city;
  final String status;            // moderation | active | archived | rejected | sold
  final double? salePrice;
  final double? rentPriceDaily;
  final String currency;
  final String? photoUrl;         // первое фото объявления

  final int views;                // просмотры (дедуп: 1/сутки/пользователь)
  final int favorites;            // сейчас в избранном
  final int contacts;             // запросов контакта

  // Продвижение. isPromoted считает сервер (флаг + непросроченный срок),
  // поэтому на клиенте сравнивать даты не нужно.
  final bool isPromoted;
  final DateTime? boostedUntil;

  final DateTime createdAt;

  const ListingStatsModel({
    required this.carId,
    required this.brand,
    required this.model,
    required this.year,
    required this.city,
    required this.status,
    this.salePrice,
    this.rentPriceDaily,
    required this.currency,
    this.photoUrl,
    this.views = 0,
    this.favorites = 0,
    this.contacts = 0,
    this.isPromoted = false,
    this.boostedUntil,
    required this.createdAt,
  });

  // Продано — карточка исчезает из каталога, но остаётся в кабинете
  // и открывается по прямой ссылке с плашкой «Продано».
  bool get isSold => status == 'sold';
  bool get isActive => status == 'active';
  bool get isOnModeration => status == 'moderation';

  factory ListingStatsModel.fromMap(Map<String, dynamic> map) {
    return ListingStatsModel(
      carId: map['car_id'] as String,
      brand: map['brand'] as String? ?? '',
      model: map['model'] as String? ?? '',
      year: _toInt(map['year']),
      city: map['city'] as String? ?? '',
      status: map['status'] as String? ?? 'moderation',
      salePrice: _toDouble(map['sale_price']),
      rentPriceDaily: _toDouble(map['rent_price_daily']),
      currency: map['currency'] as String? ?? 'EUR',
      photoUrl: map['photo_url'] as String?,
      views: _toInt(map['views']),
      favorites: _toInt(map['favorites']),
      contacts: _toInt(map['contacts']),
      isPromoted: map['is_promoted'] as bool? ?? false,
      boostedUntil: map['boosted_until'] == null
          ? null
          : DateTime.parse(map['boosted_until'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

// ------------------------------------------------------------
// Итоговая статистика по всем объявлениям продавца.
// ------------------------------------------------------------
class ListingStatsTotals {
  final int listingsCount;
  final int views;
  final int favorites;
  final int contacts;

  const ListingStatsTotals({
    this.listingsCount = 0,
    this.views = 0,
    this.favorites = 0,
    this.contacts = 0,
  });

  // Пустой итог — для первого кадра, пока запрос не вернулся.
  static const ListingStatsTotals empty = ListingStatsTotals();

  factory ListingStatsTotals.fromMap(Map<String, dynamic> map) {
    return ListingStatsTotals(
      listingsCount: ListingStatsModel._toInt(map['listings_count']),
      views: ListingStatsModel._toInt(map['views']),
      favorites: ListingStatsModel._toInt(map['favorites']),
      contacts: ListingStatsModel._toInt(map['contacts']),
    );
  }
}
