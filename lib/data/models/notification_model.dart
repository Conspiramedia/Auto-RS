// ============================================================
// AUTO.RS — Модель NotificationModel (зеркало таблицы public.notifications).
// ============================================================

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String? body;
  final String type;        // 'chat_message' | 'booking_status_changed' | ...
  final String? actionId;   // chat_id / booking_id для перехода по тапу
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    this.body,
    required this.type,
    this.actionId,
    required this.isRead,
    required this.createdAt,
  });

  // Категории уведомлений (синхронизированы с type в триггерах/RPC)
  static const String typeChatMessage = 'chat_message';
  static const String typeBookingStatus = 'booking_status_changed';
  static const String typeCarRejected = 'car_rejected';   // объявление отклонено
  static const String typeCarApproved = 'car_approved';   // объявление одобрено

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      body: map['body'] as String?,
      type: map['type'] as String,
      actionId: map['action_id'] as String?,
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
