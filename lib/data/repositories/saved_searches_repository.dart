// ============================================================
// AUTO.RS — Репозиторий сохранённых поисков (Пакет C).
//
// Подписки создаются только через RPC save_search_from_filters: она чистит
// фильтры от посторонних ключей, канонизирует их и считает хэш. Прямая
// вставка в saved_searches закрыта RLS именно поэтому — записанный вручную
// хэш сломал бы дедупликацию, и пользователь получал бы дубли пушей.
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/saved_search_model.dart';

class SavedSearchesRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // Создать подписку или реактивировать существующую с теми же фильтрами.
  // Повторный вызов дубль не создаёт — сервер делает upsert по хэшу.
  //
  // filters — результат CarFilters.toSearchFilters(). Пустой набор сервер
  // отклонит с ошибкой: подписка «на всё» это гарантированный спам.
  Future<SavedSearchModel> saveFromFilters(
    Map<String, dynamic> filters, {
    String? title,
  }) async {
    final row = await _client.rpc('save_search_from_filters', params: {
      'p_filters': filters,
      'p_title': title,
    });
    return SavedSearchModel.fromMap(row as Map<String, dynamic>);
  }

  // Мои подписки, свежие сверху — список «Сообщить, когда появится» в профиле.
  Future<List<SavedSearchModel>> fetchMySearches() async {
    final rows = await _client.rpc('get_my_saved_searches');

    return (rows as List)
        .map((e) => SavedSearchModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // Включить/выключить рассылку по подписке, не удаляя её фильтры.
  Future<SavedSearchModel> toggle(String id) async {
    final row = await _client.rpc('toggle_saved_search', params: {
      'p_id': id,
    });
    return SavedSearchModel.fromMap(row as Map<String, dynamic>);
  }

  // Удалить подписку. RLS сам не даст удалить чужую.
  Future<void> delete(String id) async {
    await _client.from('saved_searches').delete().eq('id', id);
  }

  // ---------- PUSH-ТОКЕНЫ ----------
  // Вызывается после выдачи разрешения на уведомления и при каждом обновлении
  // токена. Полноценная интеграция с firebase_messaging добавится, когда будут
  // конфиги Firebase; серверный контракт готов уже сейчас.

  Future<void> registerPushToken(String token, {String platform = 'android'}) async {
    await _client.rpc('register_push_token', params: {
      'p_token': token,
      'p_platform': platform,
    });
  }

  // Отвязать токен при выходе из аккаунта, иначе следующий владелец
  // устройства получал бы чужие уведомления.
  Future<void> unregisterPushToken(String token) async {
    await _client.rpc('unregister_push_token', params: {
      'p_token': token,
    });
  }
}
