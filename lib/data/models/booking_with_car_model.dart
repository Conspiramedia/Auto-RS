// ============================================================
// AUTO.RS — Модель BookingWithCarModel (зеркало VIEW bookings_with_car, 0013).
// Бронь + данные машины + owner_id — для кабинета броней.
// ============================================================

import '../enums/booking_status.dart';
import '../enums/currency_code.dart';

class BookingWithCarModel {
  final String id;
  final String carId;
  final String customerId;
  final String ownerId;      // владелец машины (cars.user_id)
  final String brand;
  final String model;
  final int? year;
  final String? city;
  final DateTime startDate;
  final DateTime endDate;
  final double rentSubtotal;
  final double platformCommission;
  final double depositAmount;
  final double totalPrice;
  final CurrencyCode currency;
  final BookingStatus status;
  final DateTime createdAt;

  const BookingWithCarModel({
    required this.id,
    required this.carId,
    required this.customerId,
    required this.ownerId,
    required this.brand,
    required this.model,
    required this.year,
    required this.city,
    required this.startDate,
    required this.endDate,
    required this.rentSubtotal,
    required this.platformCommission,
    required this.depositAmount,
    required this.totalPrice,
    required this.currency,
    required this.status,
    required this.createdAt,
  });

  // Сумма к оплате клиентом = итог + залог (депозит показывается отдельно)
  double get grandTotalWithDeposit => totalPrice + depositAmount;

  factory BookingWithCarModel.fromMap(Map<String, dynamic> map) {
    return BookingWithCarModel(
      id: map['id'] as String,
      carId: map['car_id'] as String,
      customerId: map['customer_id'] as String,
      ownerId: map['owner_id'] as String,
      brand: map['brand'] as String,
      model: map['model'] as String,
      year: map['year'] as int?,
      city: map['city'] as String?,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      rentSubtotal: _toDouble(map['rent_subtotal']),
      platformCommission: _toDouble(map['platform_commission']),
      depositAmount: _toDouble(map['deposit_amount']),
      totalPrice: _toDouble(map['total_price']),
      currency: CurrencyCode.fromValue(map['currency'] as String?),
      status: BookingStatus.fromValue(map['status'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
