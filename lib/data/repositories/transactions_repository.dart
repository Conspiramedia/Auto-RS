// ============================================================
// AUTO.RS — Репозиторий транзакций (только чтение).
// Записи создаёт сервер; клиент читает свою историю (RLS ограничит).
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/transaction_model.dart';

class TransactionsRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // История транзакций текущего пользователя (RLS вернёт только свои).
  Future<List<TransactionModel>> fetchMyTransactions() async {
    final rows = await _client
        .from('transactions')
        .select()
        .order('created_at', ascending: false);

    return (rows as List)
        .map((e) => TransactionModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // Доступный баланс вендора (RPC get_vendor_balance, миграция 0021):
  // сумма завершённых выплат payout/completed. userId — обычно currentUser.uid.
  Future<double> getVendorBalance(String userId) async {
    final result = await _client.rpc('get_vendor_balance', params: {
      'p_user_id': userId,
    });
    // numeric из Supabase приходит как num/String — приводим к double
    if (result is num) return result.toDouble();
    return double.tryParse(result.toString()) ?? 0.0;
  }

  // Транзакции по конкретной броне (штрафы/возвраты/оплаты).
  Future<List<TransactionModel>> fetchByBooking(String bookingId) async {
    final rows = await _client
        .from('transactions')
        .select()
        .eq('booking_id', bookingId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((e) => TransactionModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
