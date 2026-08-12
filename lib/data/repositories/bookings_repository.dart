// ============================================================
// AUTO.RS — Репозиторий броней. Инкапсулирует все запросы к Supabase,
// связанные с bookings, включая вызов серверной RPC is_car_available.
// Экраны обращаются к БД ТОЛЬКО через этот слой (слоистая архитектура).
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/booking_model.dart';
import '../models/booking_with_car_model.dart';

class BookingsRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // ----------------------------------------------------------
  // Проверка доступности машины на даты (серверная RPC).
  // Возвращает true, если нет пересечений с confirmed-бронями.
  // Даты передаём в формате 'YYYY-MM-DD'.
  // ----------------------------------------------------------
  Future<bool> isCarAvailable({
    required String carId,
    required DateTime start,
    required DateTime end,
  }) async {
    final result = await _client.rpc('is_car_available', params: {
      'p_car_id': carId,
      'p_start': _dateOnly(start),
      'p_end': _dateOnly(end),
    });
    // RPC возвращает boolean
    return result as bool;
  }

  // ----------------------------------------------------------
  // Создание брони (статус pending по умолчанию).
  // Денежные поля НЕ передаём — их считает триггер на сервере.
  // ----------------------------------------------------------
  Future<BookingModel> createBooking({
    required String carId,
    required String customerId,
    required DateTime start,
    required DateTime end,
  }) async {
    final inserted = await _client
        .from('bookings')
        .insert({
          'car_id': carId,
          'customer_id': customerId,
          'start_date': _dateOnly(start),
          'end_date': _dateOnly(end),
        })
        .select()
        .single();

    return BookingModel.fromMap(inserted);
  }

  // ----------------------------------------------------------
  // СТАТУСНАЯ МАШИНА БРОНЕЙ (серверные RPC, миграция 0008).
  // Все проверки прав и защита от гонок — на стороне БД.
  // ----------------------------------------------------------

  // Подтверждение брони владельцем машины (pending → confirmed).
  // Бросит исключение, если нет прав, статус не pending или даты заняты.
  Future<BookingModel> confirmBooking(String bookingId) async {
    final row = await _client.rpc('confirm_booking', params: {
      'booking_id': bookingId,
    });
    return BookingModel.fromMap(row as Map<String, dynamic>);
  }

  // Отклонение брони владельцем машины (pending → rejected).
  Future<BookingModel> rejectBooking(String bookingId) async {
    final row = await _client.rpc('reject_booking', params: {
      'booking_id': bookingId,
    });
    return BookingModel.fromMap(row as Map<String, dynamic>);
  }

  // Отмена брони её создателем-клиентом (pending/confirmed → cancelled).
  // При отмене confirmed <24ч сервер сам создаст транзакцию-штраф,
  // иначе — возврат ранее проведённых оплат (см. миграцию 0009).
  Future<BookingModel> cancelBooking(String bookingId) async {
    final row = await _client.rpc('cancel_booking', params: {
      'booking_id': bookingId,
    });
    return BookingModel.fromMap(row as Map<String, dynamic>);
  }

  // Оплата брони её создателем-клиентом (confirmed → paid).
  // Сервер создаёт transactions: payment (клиент) + pending payout (владелец),
  // комиссия платформы остаётся у платформы (см. миграцию 0011).
  Future<BookingModel> payBooking(String bookingId) async {
    final row = await _client.rpc('pay_booking', params: {
      'booking_id': bookingId,
    });
    return BookingModel.fromMap(row as Map<String, dynamic>);
  }

  // Завершение аренды владельцем машины (paid → completed).
  // Сервер разблокирует выплату: pending payout → completed (см. миграцию 0012).
  Future<BookingModel> completeBooking(String bookingId) async {
    final row = await _client.rpc('complete_booking', params: {
      'booking_id': bookingId,
    });
    return BookingModel.fromMap(row as Map<String, dynamic>);
  }

  // ----------------------------------------------------------
  // Мои брони как клиента (RLS сам ограничит выборку своими).
  // ----------------------------------------------------------
  Future<List<BookingModel>> fetchMyBookings(String customerId) async {
    final rows = await _client
        .from('bookings')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((e) => BookingModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ----------------------------------------------------------
  // Входящие заявки владельцу по конкретной машине.
  // RLS разрешает владельцу видеть брони на свои авто.
  // ----------------------------------------------------------
  Future<List<BookingModel>> fetchBookingsForCar(String carId) async {
    final rows = await _client
        .from('bookings')
        .select()
        .eq('car_id', carId)
        .order('start_date', ascending: true);

    return (rows as List)
        .map((e) => BookingModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ----------------------------------------------------------
  // КАБИНЕТ БРОНЕЙ через VIEW bookings_with_car (0013).
  // VIEW создана с security_invoker — RLS сам ограничит выборку.
  // ----------------------------------------------------------

  // Мои брони как клиента (арендатора).
  Future<List<BookingWithCarModel>> fetchClientBookings(String customerId) async {
    final rows = await _client
        .from('bookings_with_car')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((e) => BookingWithCarModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // Входящие брони на мои машины (как владельца).
  Future<List<BookingWithCarModel>> fetchOwnerBookings(String ownerId) async {
    final rows = await _client
        .from('bookings_with_car')
        .select()
        .eq('owner_id', ownerId)
        .order('start_date', ascending: true);

    return (rows as List)
        .map((e) => BookingWithCarModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // ----------------------------------------------------------
  // Занятые даты машины для календаря: разворачиваем confirmed/paid брони
  // в перечень отдельных дней [start_date .. end_date]. Именно эти статусы
  // блокируют календарь (pending — нет). RLS вернёт брони только тем, кто их
  // видит, поэтому используем это как справочные диапазоны занятости.
  // ----------------------------------------------------------
  Future<List<DateTime>> fetchBlockedDates(String carId) async {
    final rows = await _client
        .from('bookings')
        .select('start_date, end_date, status')
        .eq('car_id', carId)
        .inFilter('status', ['confirmed', 'paid']);

    final blocked = <DateTime>[];
    for (final row in (rows as List)) {
      final map = row as Map<String, dynamic>;
      final start = DateTime.parse(map['start_date'] as String);
      final end = DateTime.parse(map['end_date'] as String);
      // Разворачиваем диапазон в отдельные дни (границы включительно)
      var cursor = DateTime(start.year, start.month, start.day);
      final last = DateTime(end.year, end.month, end.day);
      while (!cursor.isAfter(last)) {
        blocked.add(cursor);
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    return blocked;
  }

  // Формат даты для типа date в PostgreSQL
  static String _dateOnly(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
