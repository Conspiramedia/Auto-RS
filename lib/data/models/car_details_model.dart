// ============================================================
// AUTO.RS — Модель CarDetailsModel (результат RPC get_car_details).
//
// Расширенная карточка объявления: сама машина + то, чего нет в таблице cars
// и что нельзя получить прямым SELECT:
//   siteUrl  — канонический адрес объявления на сайте ({домен}/car/{id});
//              используется кнопкой «Поделиться» и как цель deep link;
//   isPromoted — действует ли продвижение прямо сейчас (считает сервер);
//   seller*  — витрина продавца для перехода на страницу дилера.
//
// Проданное объявление сервер отдаёт по прямой ссылке (в каталоге его нет) —
// экран показывает плашку «Продано». Объявления на модерации, отклонённые и
// архивные доступны только владельцу и администратору.
// ============================================================

class CarDetailsModel {
  final String id;
  final String userId;

  final bool isForSale;
  final bool isForRent;

  final String brand;
  final String model;
  final int year;
  final int? mileage;
  final String? bodyType;
  final String? transmission;
  final String? fuel;

  final String currency;
  final double? salePrice;
  final double? rentPriceDaily;
  final double depositAmount;

  final String city;
  final String? description;
  final String? contactPhone;

  final double ratingAvg;
  final int reviewsCount;

  final String status;
  final bool isVip;
  final DateTime? boostedUntil;
  final bool isPromoted;

  // Канонический адрес объявления на сайте.
  final String siteUrl;

  // Витрина продавца.
  final String sellerKind;      // 'private' | 'dealer'
  final String sellerName;      // название салона либо имя частника
  final String? sellerLogoUrl;
  final String? sellerAvatarUrl;
  final DateTime sellerSince;   // «на площадке с…»

  final DateTime createdAt;
  final DateTime updatedAt;

  const CarDetailsModel({
    required this.id,
    required this.userId,
    required this.isForSale,
    required this.isForRent,
    required this.brand,
    required this.model,
    required this.year,
    this.mileage,
    this.bodyType,
    this.transmission,
    this.fuel,
    required this.currency,
    this.salePrice,
    this.rentPriceDaily,
    this.depositAmount = 0,
    required this.city,
    this.description,
    this.contactPhone,
    this.ratingAvg = 0,
    this.reviewsCount = 0,
    required this.status,
    this.isVip = false,
    this.boostedUntil,
    this.isPromoted = false,
    required this.siteUrl,
    required this.sellerKind,
    required this.sellerName,
    this.sellerLogoUrl,
    this.sellerAvatarUrl,
    required this.sellerSince,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isSold => status == 'sold';
  bool get isDealer => sellerKind == 'dealer';

  // Картинка витрины продавца: у дилера логотип, у частника аватар.
  String? get sellerImageUrl =>
      isDealer ? (sellerLogoUrl ?? sellerAvatarUrl) : sellerAvatarUrl;

  factory CarDetailsModel.fromMap(Map<String, dynamic> map) {
    return CarDetailsModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      isForSale: map['is_for_sale'] as bool? ?? false,
      isForRent: map['is_for_rent'] as bool? ?? false,
      brand: map['brand'] as String? ?? '',
      model: map['model'] as String? ?? '',
      year: _toInt(map['year']),
      mileage: map['mileage'] as int?,
      bodyType: map['body_type'] as String?,
      transmission: map['transmission'] as String?,
      fuel: map['fuel'] as String?,
      currency: map['currency'] as String? ?? 'EUR',
      salePrice: _toDouble(map['sale_price']),
      rentPriceDaily: _toDouble(map['rent_price_daily']),
      depositAmount: _toDouble(map['deposit_amount']) ?? 0,
      city: map['city'] as String? ?? '',
      description: map['description'] as String?,
      contactPhone: map['contact_phone'] as String?,
      ratingAvg: _toDouble(map['rating_avg']) ?? 0,
      reviewsCount: _toInt(map['reviews_count']),
      status: map['status'] as String? ?? 'active',
      isVip: map['is_vip'] as bool? ?? false,
      boostedUntil: map['boosted_until'] == null
          ? null
          : DateTime.parse(map['boosted_until'] as String),
      isPromoted: map['is_promoted'] as bool? ?? false,
      siteUrl: map['site_url'] as String? ?? '',
      sellerKind: map['seller_kind'] as String? ?? 'private',
      sellerName: map['seller_name'] as String? ?? '',
      sellerLogoUrl: map['seller_logo_url'] as String?,
      sellerAvatarUrl: map['seller_avatar_url'] as String?,
      sellerSince: DateTime.parse(map['seller_since'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
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
