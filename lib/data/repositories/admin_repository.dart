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

  // Очередь модерации по статусу ('moderation' — новые, 'rejected' —
  // отклонённые). Джойним профиль автора (имя), чтобы показать «от кого»:
  // политика profiles_select_admin (0019) даёт админу читать чужие профили.
  // RLS cars_select_admin_moderation отдаёт сами объявления только админу.
  Future<List<ModerationItem>> fetchModerationQueue(String status) async {
    final rows = await _client
        .from('cars')
        .select('*, author:profiles!user_id(full_name)')
        .eq('status', status)
        .order('created_at', ascending: true);

    return (rows as List).map((e) {
      final map = e as Map<String, dynamic>;
      final author = map['author'] as Map<String, dynamic>?;
      return ModerationItem(
        car: CarModel.fromMap(map),
        authorName: author?['full_name'] as String?,
      );
    }).toList();
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

// Элемент очереди модерации: объявление + имя автора (из профиля).
class ModerationItem {
  final CarModel car;
  final String? authorName; // имя продавца (может быть не задано)
  const ModerationItem({required this.car, this.authorName});
}
