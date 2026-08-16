// ============================================================
// AUTO.RS — Репозиторий чатов и сообщений.
// Создание чата — через RPC start_chat. Лента сообщений — с Realtime-потоком.
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/chat_model.dart';
import '../models/chat_with_details_model.dart';
import '../models/message_model.dart';

class ChatRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // ----------------------------------------------------------
  // Начать чат по объявлению или получить существующий (RPC start_chat).
  // Возвращает chat_id. Сервер сам определит buyer/seller и защитит
  // от «чата с самим собой».
  // ----------------------------------------------------------
  Future<String> startChat(String carId) async {
    final chatId = await _client.rpc('start_chat', params: {
      'p_car_id': carId,
    });
    return chatId as String;
  }

  // ----------------------------------------------------------
  // Список моих чатов (RLS вернёт только те, где я участник).
  // ----------------------------------------------------------
  Future<List<ChatModel>> fetchMyChats() async {
    final rows = await _client
        .from('chats')
        .select()
        .order('created_at', ascending: false);

    return (rows as List)
        .map((e) => ChatModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ----------------------------------------------------------
  // Список диалогов с деталями (VIEW chats_with_details): собеседник,
  // данные машины, первое фото, счётчик непрочитанных. RLS вернёт только
  // чаты, где пользователь участник. Сортировка: свежие сверху.
  // ----------------------------------------------------------
  // Сортировка: закреплённые сверху (свежие закрепления выше), затем
  // остальные по времени последнего сообщения. Порядок задаём на сервере,
  // чтобы список не пересортировывался на клиенте.
  Future<List<ChatWithDetailsModel>> fetchMyChatsDetailed() async {
    final rows = await _client
        .from('chats_with_details')
        .select()
        .order('pinned_at', ascending: false, nullsFirst: false)
        .order('last_message_at', ascending: false, nullsFirst: false);

    return (rows as List)
        .map((e) => ChatWithDetailsModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // Суммарный счётчик непрочитанных (для бэйджа навигации).
  //
  // Используется get_unread_count (Пакет B), а не прежняя total_unread_count
  // из миграции 0018: старая функция не знала о блокировках, появившихся
  // в 0041, и считала в бейдже сообщения от заблокированных пользователей.
  Future<int> totalUnread() async {
    final result = await _client.rpc('get_unread_count');
    if (result is int) return result;
    if (result is num) return result.toInt();
    return int.tryParse(result?.toString() ?? '') ?? 0;
  }

  // ----------------------------------------------------------
  // Realtime-поток сообщений чата в хронологическом порядке.
  // Обновляется автоматически при вставке новых сообщений (Supabase Realtime).
  // ----------------------------------------------------------
  Stream<List<MessageModel>> messagesStream(String chatId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at')
        .map((rows) =>
            rows.map((e) => MessageModel.fromMap(e)).toList());
  }

  // ----------------------------------------------------------
  // Поток «сигналов» о движении в сообщениях — для живого бейджа на табе.
  //
  // Отдаём именно СИГНАЛ (void), а не число: RLS-поток messages вернёт
  // строки всех чатов пользователя, но посчитать по ним непрочитанные
  // правильно нельзя — в клиентском потоке нет информации о блокировках,
  // которую учитывает get_unread_count. Поэтому по каждому событию
  // потребитель перезапрашивает счётчик у сервера, где логика едина.
  //
  // Начальное событие поток отдаёт сразу при подписке, поэтому первый
  // подсчёт происходит без дополнительного вызова.
  // ----------------------------------------------------------
  Stream<void> unreadSignals() {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .map((_) {});
  }

  // ----------------------------------------------------------
  // Отправить сообщение. sender_id проставляется текущим пользователем
  // (RLS требует sender_id = auth.uid()).
  // ----------------------------------------------------------
  Future<void> sendMessage({
    required String chatId,
    required String text,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Требуется авторизация для отправки сообщения');
    }
    await _client.from('messages').insert({
      'chat_id': chatId,
      'sender_id': userId,
      'text': text,
    });
  }

  // ----------------------------------------------------------
  // Пометить входящие сообщения чата прочитанными.
  // Помечаем только чужие сообщения (не свои) как is_read = true.
  // ----------------------------------------------------------
  Future<void> markRead(String chatId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('messages')
        .update({'is_read': true})
        .eq('chat_id', chatId)
        .neq('sender_id', userId)
        .eq('is_read', false);
  }

  // ==========================================================
  // ЗАКРЕПЛЕНИЕ И БЛОКИРОВКА (миграция 0041)
  // ==========================================================

  // ----------------------------------------------------------
  // Закрепить/открепить диалог. Личная настройка: собеседник её не видит.
  // Upsert в chat_prefs: pinned_at = now() — закреплён, null — откреплён.
  // Конфликт по составному ключу (user_id, chat_id) обновляет строку.
  // ----------------------------------------------------------
  Future<void> setChatPinned({
    required String chatId,
    required bool pinned,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Требуется авторизация');
    }
    await _client.from('chat_prefs').upsert(
      {
        'user_id': userId,
        'chat_id': chatId,
        'pinned_at':
            pinned ? DateTime.now().toUtc().toIso8601String() : null,
      },
      onConflict: 'user_id,chat_id',
    );
  }

  // ----------------------------------------------------------
  // Заблокировать собеседника: он больше не сможет писать текущему
  // пользователю. Запрет работает на уровне RLS-политики INSERT messages —
  // сообщение физически не создаётся, а не просто скрывается в интерфейсе.
  // ----------------------------------------------------------
  Future<void> blockUser(String userId) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) {
      throw Exception('Требуется авторизация');
    }
    await _client.from('user_blocks').upsert(
      {'blocker_id': me, 'blocked_id': userId},
      onConflict: 'blocker_id,blocked_id',
    );
  }

  // ----------------------------------------------------------
  // Снять блокировку с собеседника.
  // ----------------------------------------------------------
  Future<void> unblockUser(String userId) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return;
    await _client
        .from('user_blocks')
        .delete()
        .eq('blocker_id', me)
        .eq('blocked_id', userId);
  }
}
