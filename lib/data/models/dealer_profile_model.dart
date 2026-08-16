// ============================================================
// AUTO.RS — Модель DealerProfileModel (результат RPC get_dealer_profile).
//
// Публичная карточка продавца для страницы дилера: только те поля, которые
// разрешено видеть постороннему. Приватные данные (email, телефон профиля,
// is_admin) сервер не отдаёт намеренно — телефон показывается из
// cars.contact_phone конкретного объявления.
//
// Работает и для частника: displayName тогда содержит имя человека, а logoUrl
// пуст — экран рисует аватар вместо логотипа.
// ============================================================

class DealerProfileModel {
  final String id;
  final String sellerKind;    // 'private' | 'dealer'
  final String displayName;   // название салона либо имя частника
  final String? logoUrl;      // логотип салона
  final String? avatarUrl;    // аватар (запасной вариант для частника)
  final DateTime memberSince; // profiles.created_at — «на площадке с…»
  final int activeCars;       // сколько активных объявлений
  final int soldCars;         // сколько продано (блок «недавно проданные»)

  const DealerProfileModel({
    required this.id,
    required this.sellerKind,
    required this.displayName,
    this.logoUrl,
    this.avatarUrl,
    required this.memberSince,
    this.activeCars = 0,
    this.soldCars = 0,
  });

  bool get isDealer => sellerKind == 'dealer';

  // Картинка витрины: у дилера логотип, у частника аватар.
  String? get imageUrl => isDealer ? (logoUrl ?? avatarUrl) : avatarUrl;

  factory DealerProfileModel.fromMap(Map<String, dynamic> map) {
    return DealerProfileModel(
      id: map['id'] as String,
      sellerKind: map['seller_kind'] as String? ?? 'private',
      displayName: map['display_name'] as String? ?? '',
      logoUrl: map['logo_url'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      memberSince: DateTime.parse(map['member_since'] as String),
      activeCars: _toInt(map['active_cars']),
      soldCars: _toInt(map['sold_cars']),
    );
  }

  // count(*) в Postgres — bigint; через PostgREST приходит как int либо String.
  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}

// ============================================================
// Объявление в витрине продавца (результат RPC get_seller_listings).
//
// Отдельная модель, а не CarModel: сервер отдаёт урезанный набор полей
// (без описания, телефона и характеристик) плюс два вычисляемых —
// site_url и is_promoted, которых в таблице cars нет.
// ============================================================
class SellerListingModel {
  final String id;
  final String brand;
  final String model;
  final int year;
  final int? mileage;
  final String city;
  final String currency;
  final double? salePrice;
  final double? rentPriceDaily;
  final bool isForSale;
  final bool isForRent;
  final String status;
  final bool isPromoted;
  final String siteUrl;
  final String? photoUrl;
  final DateTime createdAt;

  const SellerListingModel({
    required this.id,
    required this.brand,
    required this.model,
    required this.year,
    this.mileage,
    required this.city,
    required this.currency,
    this.salePrice,
    this.rentPriceDaily,
    this.isForSale = false,
    this.isForRent = false,
    required this.status,
    this.isPromoted = false,
    this.siteUrl = '',
    this.photoUrl,
    required this.createdAt,
  });

  bool get isSold => status == 'sold';

  // Цена по назначению объявления: у аренды суточная ставка, иначе цена
  // продажи. Тот же принцип, что в каталоге и предикате подписок.
  double? get price => isForRent && !isForSale ? rentPriceDaily : salePrice;

  factory SellerListingModel.fromMap(Map<String, dynamic> map) {
    return SellerListingModel(
      id: map['id'] as String,
      brand: map['brand'] as String? ?? '',
      model: map['model'] as String? ?? '',
      year: DealerProfileModel._toInt(map['year']),
      mileage: map['mileage'] as int?,
      city: map['city'] as String? ?? '',
      currency: map['currency'] as String? ?? 'EUR',
      salePrice: _toDouble(map['sale_price']),
      rentPriceDaily: _toDouble(map['rent_price_daily']),
      isForSale: map['is_for_sale'] as bool? ?? false,
      isForRent: map['is_for_rent'] as bool? ?? false,
      status: map['status'] as String? ?? 'active',
      isPromoted: map['is_promoted'] as bool? ?? false,
      siteUrl: map['site_url'] as String? ?? '',
      photoUrl: map['photo_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
