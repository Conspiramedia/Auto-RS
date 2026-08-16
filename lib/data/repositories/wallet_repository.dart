// ============================================================
// AUTO.RS — Репозиторий кошелька (баланс и история операций).
//
// Все обращения идут через SECURITY DEFINER RPC пакета A (миграция 0043):
// прямая запись в wallet_transactions закрыта RLS, поэтому начислить себе
// баланс с клиента невозможно даже при утечке anon-ключа.
//
// ЭТАП 0: реального пополнения нет — платёжный провайдер не подключён.
// Единственный источник средств сейчас — credit_gift, доступный админу.
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/wallet_transaction_model.dart';

class WalletRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // Баланс кошелька = сумма wallet_transactions (считается на сервере).
  // Без userId возвращает баланс текущего пользователя; чужой баланс сервер
  // отдаст только администратору.
  Future<double> getBalance({String? userId}) async {
    final result = await _client.rpc('get_balance', params: {
      'p_user_id': userId,
    });
    if (result is num) return result.toDouble();
    return double.tryParse(result.toString()) ?? 0.0;
  }

  // История операций текущего пользователя, свежие сверху.
  // limit сервер жёстко ограничивает сотней строк — пагинация обязательна
  // для длинной истории.
  Future<List<WalletTransactionModel>> fetchTransactions({
    int limit = 50,
    int offset = 0,
  }) async {
    final rows = await _client.rpc('get_transactions', params: {
      'p_limit': limit,
      'p_offset': offset,
    });

    return (rows as List)
        .map((e) =>
            WalletTransactionModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // Списание за услугу с проверкой достаточности средств на сервере.
  // На Этапе 0 не вызывается (продвижение работает в режиме «подарок») —
  // метод готов под будущий прайс.
  Future<WalletTransactionModel> spend({
    required double amount,
    String? description,
    String? carId,
  }) async {
    final row = await _client.rpc('spend_balance', params: {
      'p_amount': amount,
      'p_description': description,
      'p_car_id': carId,
    });
    return WalletTransactionModel.fromMap(row as Map<String, dynamic>);
  }

  // Ручное начисление администратором (подарок/бонус). Сервер проверит
  // is_admin() и отклонит вызов обычного пользователя.
  Future<WalletTransactionModel> creditGift({
    required String userId,
    required double amount,
    String? description,
    String type = WalletTransactionModel.typeGift,
  }) async {
    final row = await _client.rpc('credit_gift', params: {
      'p_user_id': userId,
      'p_amount': amount,
      'p_description': description,
      'p_type': type,
    });
    return WalletTransactionModel.fromMap(row as Map<String, dynamic>);
  }
}
