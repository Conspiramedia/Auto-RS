// ============================================================
// AUTO.RS — Модель FavoriteWithCarModel (зеркало VIEW favorites_with_car_details).
// Для экрана «Избранное»: закладка + данные машины + первое фото.
// ============================================================

import '../enums/car_status.dart';
import '../enums/currency_code.dart';

class FavoriteWithCarModel {
  final String id;
  final String userId;
  final String carId;
  final DateTime createdAt;

  // Данные объявления
  final String brand;
  final String model;
  final int? year;
  final String city;
  final bool isForSale;
  final bool isForRent;
  final double? salePrice;
  final double? rentPriceDaily;
  final CurrencyCode currency;
  final double ratingAvg;
  final int reviewsCount;
  final CarStatus status;
  final String? carPhoto;

  const FavoriteWithCarModel({
    required this.id,
    required this.userId,
    required this.carId,
    required this.createdAt,
    required this.brand,
    required this.model,
    this.year,
    required this.city,
    required this.isForSale,
    required this.isForRent,
    this.salePrice,
    this.rentPriceDaily,
    required this.currency,
    required this.ratingAvg,
    required this.reviewsCount,
    required this.status,
    this.carPhoto,
  });

  factory FavoriteWithCarModel.fromMap(Map<String, dynamic> map) {
    return FavoriteWithCarModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      carId: map['car_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      brand: map['brand'] as String,
      model: map['model'] as String,
      year: map['year'] as int?,
      city: map['city'] as String,
      isForSale: map['is_for_sale'] as bool? ?? false,
      isForRent: map['is_for_rent'] as bool? ?? false,
      salePrice: _toDouble(map['sale_price']),
      rentPriceDaily: _toDouble(map['rent_price_daily']),
      currency: CurrencyCode.fromValue(map['currency'] as String?),
      ratingAvg: _toDouble(map['rating_avg']) ?? 0.0,
      reviewsCount: map['reviews_count'] as int? ?? 0,
      status: CarStatus.fromValue(map['status'] as String?),
      carPhoto: map['car_photo'] as String?,
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
