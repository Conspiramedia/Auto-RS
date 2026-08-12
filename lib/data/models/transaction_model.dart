// ============================================================
// AUTO.RS — Модель TransactionModel (зеркало таблицы public.transactions).
// Только чтение на клиенте: записи создаёт сервер (SECURITY DEFINER).
// Поля type/status — простые строки (в БД это text с CHECK-ограничением),
// поэтому дублируем допустимые значения константами для удобства UI.
// ============================================================

class TransactionModel {
  final String id;
  final String? bookingId;   // может быть null (бронь удалена → ON DELETE SET NULL)
  final String userId;
  final double amount;
  final String currency;     // по умолчанию 'RSD'
  final String type;         // payment | refund | penalty | payout
  final String status;       // pending | completed | failed
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    this.bookingId,
    required this.userId,
    required this.amount,
    required this.currency,
    required this.type,
    required this.status,
    required this.createdAt,
  });

  // Допустимые значения type (синхронизированы с CHECK-ограничением в БД)
  static const String typePayment = 'payment';
  static const String typeRefund = 'refund';
  static const String typePenalty = 'penalty';
  static const String typePayout = 'payout';

  // Допустимые значения status
  static const String statusPending = 'pending';
  static const String statusCompleted = 'completed';
  static const String statusFailed = 'failed';

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      bookingId: map['booking_id'] as String?,
      userId: map['user_id'] as String,
      amount: _toDouble(map['amount']) ?? 0,
      currency: map['currency'] as String? ?? 'RSD',
      type: map['type'] as String,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
