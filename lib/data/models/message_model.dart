// ============================================================
// AUTO.RS — Модель MessageModel (зеркало таблицы public.messages).
// ============================================================

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final bool isRead;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.isRead,
    required this.createdAt,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] as String,
      chatId: map['chat_id'] as String,
      senderId: map['sender_id'] as String,
      text: map['text'] as String,
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // true, если сообщение отправлено текущим пользователем (для выравнивания пузыря)
  bool isMine(String currentUserId) => senderId == currentUserId;
}
