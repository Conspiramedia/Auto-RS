// ============================================================
// AUTO.RS — Модель ChatModel (зеркало таблицы public.chats).
// ============================================================

class ChatModel {
  final String id;
  final String carId;
  final String buyerId;   // покупатель (инициатор)
  final String sellerId;  // продавец (владелец авто)
  final DateTime createdAt;

  const ChatModel({
    required this.id,
    required this.carId,
    required this.buyerId,
    required this.sellerId,
    required this.createdAt,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map) {
    return ChatModel(
      id: map['id'] as String,
      carId: map['car_id'] as String,
      buyerId: map['buyer_id'] as String,
      sellerId: map['seller_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // Собеседник относительно текущего пользователя
  String peerId(String currentUserId) =>
      currentUserId == buyerId ? sellerId : buyerId;
}
