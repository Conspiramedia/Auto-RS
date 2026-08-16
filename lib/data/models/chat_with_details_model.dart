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
  final String? lastMessage; // текст последнего сообщения (превью в списке)

  // Личные настройки диалога (миграция 0041)
  final bool pinned;         // закреплён текущим пользователем
  final DateTime? pinnedAt;  // момент закрепления (сортировка закреплённых)
  final bool peerBlocked;    // текущий пользователь заблокировал собеседника

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
    this.lastMessage,
    this.pinned = false,
    this.pinnedAt,
    this.peerBlocked = false,
  });

  // true, если есть непрочитанные (для показа бэйджа)
  bool get hasUnread => unreadCount > 0;

  // Заголовок объявления для подписи строки диалога.
  String get carTitle => '$brand $model';

  // Инициалы собеседника для аватара-заглушки (когда фото нет).
  String get opponentInitials {
    final name = (opponentName ?? '').trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

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
      lastMessage: map['last_message'] as String?,
      pinned: map['pinned'] as bool? ?? false,
      pinnedAt: map['pinned_at'] == null
          ? null
          : DateTime.parse(map['pinned_at'] as String),
      peerBlocked: map['peer_blocked'] as bool? ?? false,
    );
  }
}
