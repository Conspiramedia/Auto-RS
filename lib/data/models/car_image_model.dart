// ============================================================
// AUTO.RS — Модель CarImageModel (зеркало таблицы public.car_images).
// ============================================================

class CarImageModel {
  final String id;
  final String carId;
  final String imageUrl;   // ссылка на файл в Supabase Storage
  final int orderIndex;    // порядок в галерее
  final DateTime createdAt;

  const CarImageModel({
    required this.id,
    required this.carId,
    required this.imageUrl,
    required this.orderIndex,
    required this.createdAt,
  });

  factory CarImageModel.fromMap(Map<String, dynamic> map) {
    return CarImageModel(
      id: map['id'] as String,
      carId: map['car_id'] as String,
      imageUrl: map['image_url'] as String,
      orderIndex: map['order_index'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'car_id': carId,
      'image_url': imageUrl,
      'order_index': orderIndex,
    };
  }
}
