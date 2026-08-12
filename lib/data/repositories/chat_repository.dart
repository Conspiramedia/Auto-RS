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
  Future<List<ChatWithDetailsModel>> fetchMyChatsDetailed() async {
    final rows = await _client
        .from('chats_with_details')
        .select()
        .order('last_message_at', ascending: false, nullsFirst: false);

    return (rows as List)
        .map((e) => ChatWithDetailsModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // Суммарный счётчик непрочитанных (для бэйджа навигации).
  Future<int> totalUnread() async {
    final result = await _client.rpc('total_unread_count');
    return result as int? ?? 0;
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
}
