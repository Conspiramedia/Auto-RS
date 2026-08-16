// ============================================================
// AUTO.RS — Модель WalletTransactionModel (зеркало public.wallet_transactions).
//
// Кошелёк пользователя — отдельная сущность от арендных transactions
// (те обслуживают брони: payment/refund/penalty/payout). Здесь только
// движение личного баланса: пополнения, подарки и списания за услуги.
//
// Только чтение на клиенте: строки создают SECURITY DEFINER RPC
// (credit_gift / spend_balance), прямая запись закрыта RLS.
//
// Знак amount задаётся типом операции и гарантируется CHECK в БД:
// начисления > 0, списания (spend) < 0. Поэтому баланс — простая сумма.
// ============================================================

class WalletTransactionModel {
  final String id;
  final String type;          // topup | bonus | gift | spend | refund
  final double amount;        // EUR; списания приходят отрицательными
  final String? description;  // человекочитаемое описание для истории
  final String? carId;        // объявление, если операция связана с ним
  final DateTime createdAt;

  const WalletTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    this.description,
    this.carId,
    required this.createdAt,
  });

  // Допустимые значения type — синхронизированы с chk_wallet_type в БД.
  static const String typeTopup = 'topup';   // пополнение через провайдера (пока не используется)
  static const String typeBonus = 'bonus';   // начисление платформы
  static const String typeGift = 'gift';     // ручной подарок администратора
  static const String typeSpend = 'spend';   // списание за услугу
  static const String typeRefund = 'refund'; // возврат списанного

  // Начисление это или списание — для цвета суммы и знака в истории.
  bool get isCredit => amount > 0;

  factory WalletTransactionModel.fromMap(Map<String, dynamic> map) {
    return WalletTransactionModel(
      id: map['id'] as String,
      type: map['type'] as String,
      amount: _toDouble(map['amount']) ?? 0,
      description: map['description'] as String?,
      carId: map['car_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // numeric из Supabase приходит как num или String — приводим единообразно.
  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
