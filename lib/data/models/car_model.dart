// ============================================================
// AUTO.RS — Модель CarModel (зеркало таблицы public.cars).
// Сериализация в/из Map для работы с Supabase (JSON).
// ============================================================

import '../enums/body_type.dart';
import '../enums/car_status.dart';
import '../enums/currency_code.dart';
import '../enums/fuel_type.dart';
import '../enums/transmission_type.dart';

class CarModel {
  final String id;
  final String userId;

  // Назначение объявления
  final bool isForSale;
  final bool isForRent;

  // Характеристики
  final String brand;
  final String model;
  final int year;
  final int? mileage;
  final BodyType? bodyType;
  final TransmissionType? transmission;
  final FuelType? fuel;

  // Финансы
  final CurrencyCode currency;
  final double? salePrice;
  final double? rentPriceDaily;

  // Локация и контент
  final String city;
  final String? description;

  // Контактный телефон продавца (сербский мобильный, вид +3816XXXXXXXX)
  final String? contactPhone;

  // Рейтинг (пересчитывается триггером на сервере)
  final double ratingAvg;
  final int reviewsCount;

  // Служебное
  final CarStatus status;
  final String? moderationComment;  // причина отклонения модератором (если status = rejected)
  final DateTime createdAt;
  final DateTime updatedAt;

  const CarModel({
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
    required this.city,
    this.description,
    this.contactPhone,
    this.ratingAvg = 0.0,
    this.reviewsCount = 0,
    required this.status,
    this.moderationComment,
    required this.createdAt,
    required this.updatedAt,
  });

  // Парсинг строки из Supabase (JSON → модель)
  factory CarModel.fromMap(Map<String, dynamic> map) {
    return CarModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      isForSale: map['is_for_sale'] as bool? ?? false,
      isForRent: map['is_for_rent'] as bool? ?? false,
      brand: map['brand'] as String,
      model: map['model'] as String,
      year: map['year'] as int,
      mileage: map['mileage'] as int?,
      bodyType: BodyType.fromValue(map['body_type'] as String?),
      transmission: TransmissionType.fromValue(map['transmission'] as String?),
      fuel: FuelType.fromValue(map['fuel'] as String?),
      currency: CurrencyCode.fromValue(map['currency'] as String?),
      // numeric из Supabase может прийти как num — приводим к double безопасно
      salePrice: _toDouble(map['sale_price']),
      rentPriceDaily: _toDouble(map['rent_price_daily']),
      city: map['city'] as String,
      description: map['description'] as String?,
      contactPhone: map['contact_phone'] as String?,
      ratingAvg: _toDouble(map['rating_avg']) ?? 0.0,
      reviewsCount: map['reviews_count'] as int? ?? 0,
      status: CarStatus.fromValue(map['status'] as String?),
      moderationComment: map['moderation_comment'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // Сериализация для INSERT/UPDATE в Supabase.
  // Служебные и вычисляемые поля (id, created_at, updated_at, status)
  // не отправляем — их проставляет БД по умолчанию.
  Map<String, dynamic> toInsertMap() {
    return {
      'user_id': userId,
      'is_for_sale': isForSale,
      'is_for_rent': isForRent,
      'brand': brand,
      'model': model,
      'year': year,
      'mileage': mileage,
      'body_type': bodyType?.value,
      'transmission': transmission?.value,
      'fuel': fuel?.value,
      'currency': currency.value,
      'sale_price': salePrice,
      'rent_price_daily': rentPriceDaily,
      'city': city,
      'description': description,
    };
  }

  // Приведение numeric/num из Supabase к double
  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
