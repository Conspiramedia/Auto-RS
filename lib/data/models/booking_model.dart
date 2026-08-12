// ============================================================
// AUTO.RS — Модель BookingModel (зеркало таблицы public.bookings).
// ВАЖНО: финансовые поля (rent_subtotal, platform_commission,
// total_price) вычисляются ТРИГГЕРОМ на сервере. Клиент их читает,
// но при создании брони НЕ отправляет (защита от подмены цены).
// ============================================================

import '../enums/booking_status.dart';
import '../enums/currency_code.dart';

class BookingModel {
  final String id;
  final String carId;
  final String customerId;

  final DateTime startDate;
  final DateTime endDate;

  // Финансы (только чтение с сервера)
  final double rentSubtotal;
  final double platformCommission;
  final double depositAmount;
  final double totalPrice;
  final CurrencyCode currency;

  final BookingStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BookingModel({
    required this.id,
    required this.carId,
    required this.customerId,
    required this.startDate,
    required this.endDate,
    required this.rentSubtotal,
    required this.platformCommission,
    required this.depositAmount,
    required this.totalPrice,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  // Сумма к оплате клиентом = итог + залог (депозит показывается отдельной строкой)
  double get grandTotalWithDeposit => totalPrice + depositAmount;

  factory BookingModel.fromMap(Map<String, dynamic> map) {
    return BookingModel(
      id: map['id'] as String,
      carId: map['car_id'] as String,
      customerId: map['customer_id'] as String,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      rentSubtotal: _toDouble(map['rent_subtotal']) ?? 0,
      platformCommission: _toDouble(map['platform_commission']) ?? 0,
      depositAmount: _toDouble(map['deposit_amount']) ?? 0,
      totalPrice: _toDouble(map['total_price']) ?? 0,
      currency: CurrencyCode.fromValue(map['currency'] as String?),
      status: BookingStatus.fromValue(map['status'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // Сериализация для INSERT. Отправляем ТОЛЬКО то, что вправе задать клиент.
  // Денежные поля намеренно отсутствуют — их считает триггер на сервере.
  // Формат дат — 'YYYY-MM-DD' (тип date в PostgreSQL).
  Map<String, dynamic> toInsertMap() {
    return {
      'car_id': carId,
      'customer_id': customerId,
      'start_date': _dateOnly(startDate),
      'end_date': _dateOnly(endDate),
    };
  }

  static String _dateOnly(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
