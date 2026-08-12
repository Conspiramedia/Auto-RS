// ============================================================
// AUTO.RS — Репозиторий администрирования (модерация объявлений).
// Все методы работают только у пользователей с is_admin = true —
// права проверяет сервер внутри RPC (approve_car / reject_car).
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/car_model.dart';

class AdminRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // Проверка, что текущий пользователь — админ (серверная RPC is_admin).
  // Удобно для показа/скрытия админ-раздела в UI.
  Future<bool> isAdmin() async {
    final result = await _client.rpc('is_admin');
    return result as bool? ?? false;
  }

  // Очередь модерации: объявления на модерации (и отклонённые для пересмотра).
  // RLS-политика cars_select_admin_moderation отдаёт эти строки только админу.
  Future<List<CarModel>> fetchModerationQueue() async {
    final rows = await _client
        .from('cars')
        .select()
        .inFilter('status', ['moderation', 'rejected'])
        .order('created_at', ascending: true);

    return (rows as List)
        .map((e) => CarModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // Одобрить объявление (moderation/rejected → active).
  Future<CarModel> approveCar(String carId) async {
    final row = await _client.rpc('approve_car', params: {
      'car_id': carId,
    });
    return CarModel.fromMap(row as Map<String, dynamic>);
  }

  // Отклонить объявление с причиной (moderation → rejected).
  Future<CarModel> rejectCar(String carId, String comment) async {
    final row = await _client.rpc('reject_car', params: {
      'car_id': carId,
      'comment': comment,
    });
    return CarModel.fromMap(row as Map<String, dynamic>);
  }
}
