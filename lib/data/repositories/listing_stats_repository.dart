// ============================================================
// AUTO.RS — Репозиторий статистики объявлений (Пакет B).
//
// Всё считает сервер: клиент лишь сообщает о событии (открыли карточку,
// запросили контакт) и читает готовые цифры. Прямая запись в listing_stats
// закрыта RLS — накрутить счётчик с клиента невозможно.
//
// Владелец свои объявления «не просматривает»: сервер отбрасывает такие
// события сам, клиенту не нужно проверять авторство перед вызовом.
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/listing_stats_model.dart';

class ListingStatsRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // Событие «открыли карточку». Сервер дедуплицирует: повторные открытия того
  // же объявления тем же пользователем в течение суток счётчик не увеличивают,
  // поэтому вызывать можно при каждом открытии экрана без опаски.
  //
  // Возвращает true, если просмотр был засчитан (для отладки; UI это не нужно).
  // Ошибку сети намеренно ГЛУШИМ: статистика — фоновое действие, она не должна
  // мешать пользователю смотреть объявление.
  Future<bool> trackView(String carId) => _track(carId, 'view');

  // Событие «запросили контакт» — нажатие «Позвонить» или «Написать».
  // Не дедуплицируется: повторный звонок это отдельный сигнал интереса.
  Future<bool> trackContact(String carId) => _track(carId, 'contact');

  Future<bool> _track(String carId, String event) async {
    try {
      final result = await _client.rpc('track_listing_event', params: {
        'p_car_id': carId,
        'p_event': event,
      });
      return result == true;
    } catch (_) {
      // Счётчик не сохранился — для пользователя это незаметно и неважно.
      return false;
    }
  }

  // Мои объявления со статистикой для кабинета продавца (одним запросом).
  Future<List<ListingStatsModel>> fetchMyListingsStats() async {
    final rows = await _client.rpc('get_my_listings_stats');

    return (rows as List)
        .map((e) => ListingStatsModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // Суммарные метрики по всем объявлениям — итоговая плашка кабинета.
  Future<ListingStatsTotals> fetchTotals() async {
    final rows = await _client.rpc('get_my_stats_totals');

    // RPC возвращает setof из одной строки; пустой ответ трактуем как нули.
    final list = rows as List;
    if (list.isEmpty) return ListingStatsTotals.empty;
    return ListingStatsTotals.fromMap(list.first as Map<String, dynamic>);
  }

  // Непрочитанные сообщения для бейджа таба «Сообщения».
  // В отличие от старой total_unread_count, не учитывает сообщения от
  // пользователей, которых текущий заблокировал.
  Future<int> getUnreadCount() async {
    try {
      final result = await _client.rpc('get_unread_count');
      if (result is int) return result;
      if (result is num) return result.toInt();
      return int.tryParse(result.toString()) ?? 0;
    } catch (_) {
      // Бейдж не критичен: при ошибке показываем ноль, а не роняем экран.
      return 0;
    }
  }
}
