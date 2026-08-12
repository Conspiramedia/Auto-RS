// ============================================================
// AUTO.RS — Модель ReviewModel (зеркало таблицы public.reviews).
// ============================================================

class ReviewModel {
  final String id;
  final String bookingId;
  final String carId;
  final String customerId;
  final int rating;        // 1..5
  final String? comment;
  final DateTime createdAt;

  const ReviewModel({
    required this.id,
    required this.bookingId,
    required this.carId,
    required this.customerId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromMap(Map<String, dynamic> map) {
    return ReviewModel(
      id: map['id'] as String,
      bookingId: map['booking_id'] as String,
      carId: map['car_id'] as String,
      customerId: map['customer_id'] as String,
      rating: map['rating'] as int,
      comment: map['comment'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // Для INSERT. car_id проставит триггер check_review_allowed из брони,
  // но передаём его и с клиента для совместимости (сервер перезапишет корректным).
  Map<String, dynamic> toInsertMap() {
    return {
      'booking_id': bookingId,
      'car_id': carId,
      'customer_id': customerId,
      'rating': rating,
      'comment': comment,
    };
  }
}
