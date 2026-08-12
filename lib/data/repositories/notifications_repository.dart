// ============================================================
// AUTO.RS — Репозиторий уведомлений.
// Запись создаёт сервер (триггеры). Клиент читает свои, помечает прочитанными,
// слушает Realtime-поток для живого бэйджа.
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/notification_model.dart';

class NotificationsRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // Мои уведомления, свежие сверху (RLS вернёт только свои).
  Future<List<NotificationModel>> fetchMine() async {
    final rows = await _client
        .from('notifications')
        .select()
        .order('created_at', ascending: false);

    return (rows as List)
        .map((e) => NotificationModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // Realtime-поток уведомлений текущего пользователя (для ленты и бэйджа).
  Stream<List<NotificationModel>> stream() {
    final userId = _client.auth.currentUser?.id;
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId ?? '')
        .order('created_at', ascending: false)
        .map((rows) => rows.map(NotificationModel.fromMap).toList());
  }

  // Пометить одно уведомление прочитанным.
  Future<void> markRead(String id) async {
    await _client.from('notifications').update({'is_read': true}).eq('id', id);
  }

  // Пометить все свои уведомления прочитанными.
  Future<void> markAllRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }
}
