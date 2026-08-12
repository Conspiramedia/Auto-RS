// ============================================================
// AUTO.RS — Репозиторий отзывов.
// Создание отзыва разрешено только автору завершённой брони (проверяет
// сервер: триггер check_review_allowed + RLS). Рейтинг машины пересчитает
// триггер update_car_rating автоматически.
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/review_model.dart';

class ReviewsRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // Список отзывов по машине (публично — RLS reviews_select_public).
  Future<List<ReviewModel>> fetchByCar(String carId) async {
    final rows = await _client
        .from('reviews')
        .select()
        .eq('car_id', carId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((e) => ReviewModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // Оставить отзыв по завершённой броне. car_id можно не знать точно —
  // сервер подставит корректный из брони. Бросит исключение, если бронь
  // не completed или пользователь не её автор.
  Future<ReviewModel> createReview({
    required String bookingId,
    required String carId,
    required int rating,
    String? comment,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Требуется авторизация для отзыва');
    }
    final inserted = await _client
        .from('reviews')
        .insert({
          'booking_id': bookingId,
          'car_id': carId,
          'customer_id': userId,
          'rating': rating,
          'comment': comment,
        })
        .select()
        .single();

    return ReviewModel.fromMap(inserted);
  }

  // Проверка, оставлен ли уже отзыв по этой броне (booking_id UNIQUE).
  Future<bool> existsForBooking(String bookingId) async {
    final row = await _client
        .from('reviews')
        .select('id')
        .eq('booking_id', bookingId)
        .maybeSingle();
    return row != null;
  }

  // Множество booking_id, по которым отзыв УЖЕ оставлен текущим пользователем.
  // Одним запросом для всего списка броней — чтобы не дёргать existsForBooking
  // на каждую карточку (против N+1). Удобно для видимости кнопки «Оценить».
  Future<Set<String>> reviewedBookingIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return <String>{};
    final rows = await _client
        .from('reviews')
        .select('booking_id')
        .eq('customer_id', userId);

    return (rows as List)
        .map((e) => (e as Map<String, dynamic>)['booking_id'] as String)
        .toSet();
  }
}
