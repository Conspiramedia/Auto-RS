// ============================================================
// AUTO.RS — Модель ChatWithDetailsModel (зеркало VIEW chats_with_details).
// Для экрана «Мои диалоги»: чат + собеседник + машина + счётчик непрочитанных.
// ============================================================

class ChatWithDetailsModel {
  final String id;
  final String carId;
  final String buyerId;
  final String sellerId;
  final DateTime createdAt;

  // Собеседник (вычислен в VIEW относительно текущего пользователя)
  final String opponentId;
  final String? opponentName;
  final String? opponentAvatar;

  // Данные объявления
  final String brand;
  final String model;
  final int? year;
  final String? carPhoto;    // первое фото галереи

  final int unreadCount;     // непрочитанные входящие
  final DateTime? lastMessageAt;

  const ChatWithDetailsModel({
    required this.id,
    required this.carId,
    required this.buyerId,
    required this.sellerId,
    required this.createdAt,
    required this.opponentId,
    this.opponentName,
    this.opponentAvatar,
    required this.brand,
    required this.model,
    this.year,
    this.carPhoto,
    required this.unreadCount,
    this.lastMessageAt,
  });

  // true, если есть непрочитанные (для показа бэйджа)
  bool get hasUnread => unreadCount > 0;

  factory ChatWithDetailsModel.fromMap(Map<String, dynamic> map) {
    return ChatWithDetailsModel(
      id: map['id'] as String,
      carId: map['car_id'] as String,
      buyerId: map['buyer_id'] as String,
      sellerId: map['seller_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      opponentId: map['opponent_id'] as String,
      opponentName: map['opponent_name'] as String?,
      opponentAvatar: map['opponent_avatar'] as String?,
      brand: map['brand'] as String,
      model: map['model'] as String,
      year: map['year'] as int?,
      carPhoto: map['car_photo'] as String?,
      unreadCount: map['unread_count'] as int? ?? 0,
      lastMessageAt: map['last_message_at'] == null
          ? null
          : DateTime.parse(map['last_message_at'] as String),
    );
  }
}
