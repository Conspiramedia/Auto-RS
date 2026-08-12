// ============================================================
// AUTO.RS — Репозиторий избранного.
// «Лайк» одной кнопкой через RPC toggle_favorite (без ветвления на клиенте).
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/favorite_with_car_model.dart';

class FavoritesRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // Переключить избранное. Возвращает true (добавлено) / false (убрано).
  Future<bool> toggle(String carId) async {
    final result = await _client.rpc('toggle_favorite', params: {
      'p_car_id': carId,
    });
    return result as bool;
  }

  // Список моего избранного с деталями машины (VIEW favorites_with_car_details).
  // RLS вернёт только свои закладки.
  Future<List<FavoriteWithCarModel>> fetchMyFavorites() async {
    final rows = await _client
        .from('favorites_with_car_details')
        .select()
        .order('created_at', ascending: false);

    return (rows as List)
        .map((e) => FavoriteWithCarModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // Проверка, в избранном ли машина (для начального состояния иконки-сердца).
  Future<bool> isFavorite(String carId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final row = await _client
        .from('favorites')
        .select('id')
        .eq('user_id', userId)
        .eq('car_id', carId)
        .maybeSingle();
    return row != null;
  }

  // Множество carId в избранном — удобно для подсветки сердечек в каталоге
  // одним запросом (вместо N проверок isFavorite).
  Future<Set<String>> favoriteCarIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return <String>{};
    final rows = await _client
        .from('favorites')
        .select('car_id')
        .eq('user_id', userId);

    return (rows as List)
        .map((e) => (e as Map<String, dynamic>)['car_id'] as String)
        .toSet();
  }
}
