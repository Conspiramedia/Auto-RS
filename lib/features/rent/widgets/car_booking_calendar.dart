// ============================================================
// AUTO.RS — Custom Widget для FlutterFlow: CarBookingCalendar
// ============================================================
// Интерактивный календарь выбора дат аренды на карточке автомобиля.
// Занятые даты (confirmed/paid) блокируются и подсвечиваются серым.
// Выбранный диапазон подсвечивается основным цветом приложения.
//
// -----------------------------------------------------------------
// НАСТРОЙКА В ИНТЕРФЕЙСЕ FLUTTERFLOW:
//
// Parameters (входные):
//   * blockedDates : List<DateTime>  — занятые даты (из БД: статусы confirmed/paid)
//   * pricePerDay  : double          — цена аренды за сутки
//
// Callback (Action Trigger, задать в разделе Callbacks виджета):
//   * onDatesSelected : Action с параметрами
//       - start      : DateTime
//       - end        : DateTime
//       - totalPrice : double
//     Вызывается, когда пользователь выбрал диапазон (обе границы).
//
// Зависимость: table_calendar (добавить в pubspec проекта FlutterFlow).
// -----------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class CarBookingCalendar extends StatefulWidget {
  const CarBookingCalendar({
    super.key,
    this.width,
    this.height,
    required this.blockedDates,
    required this.pricePerDay,
    required this.onDatesSelected,
  });

  // Ширина/высота задаёт FlutterFlow при вставке виджета
  final double? width;
  final double? height;

  // Входные параметры
  final List<DateTime> blockedDates;   // занятые даты
  final double pricePerDay;            // цена за сутки

  // Callback наружу: (дата начала, дата конца, итоговая стоимость)
  final Future<dynamic> Function(
    DateTime start,
    DateTime end,
    double totalPrice,
  ) onDatesSelected;

  @override
  State<CarBookingCalendar> createState() => _CarBookingCalendarState();
}

class _CarBookingCalendarState extends State<CarBookingCalendar> {
  // Границы выбранного пользователем диапазона
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  // Текущий "фокус" календаря (какой месяц показан)
  DateTime _focusedDay = DateTime.now();

  // Множество занятых дат в нормализованном виде (без времени) для O(1)-проверки
  late final Set<DateTime> _blockedSet;

  @override
  void initState() {
    super.initState();
    // Нормализуем занятые даты к «полуночи», чтобы сравнивать только год-месяц-день
    _blockedSet = widget.blockedDates.map(_dateOnly).toSet();
  }

  // Приведение даты к дате без времени (00:00) для корректного сравнения
  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  // Проверка, занята ли дата
  bool _isBlocked(DateTime day) => _blockedSet.contains(_dateOnly(day));

  // Проверка, что весь выбранный диапазон [start; end] не задевает занятые даты.
  // Если внутри есть хоть одна занятая — диапазон невалиден.
  bool _rangeHasNoBlocked(DateTime start, DateTime end) {
    var cursor = _dateOnly(start);
    final last = _dateOnly(end);
    while (!cursor.isAfter(last)) {
      if (_blockedSet.contains(cursor)) return false;
      cursor = cursor.add(const Duration(days: 1));
    }
    return true;
  }

  // Кол-во суток в диапазоне (границы включительны: с 1 по 5 = 5 суток)
  int _daysInclusive(DateTime start, DateTime end) {
    return _dateOnly(end).difference(_dateOnly(start)).inDays + 1;
  }

  // Обработка выбора диапазона в table_calendar
  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focused) {
    setState(() {
      _rangeStart = start;
      _rangeEnd = end;
      _focusedDay = focused;
    });

    // Реагируем только когда выбраны ОБЕ границы
    if (start == null || end == null) return;

    // Защита: если пользователь захватил занятую дату — сбрасываем и предупреждаем
    if (!_rangeHasNoBlocked(start, end)) {
      _showSnack('В выбранном диапазоне есть занятые даты. Выберите другой период.');
      setState(() {
        _rangeStart = null;
        _rangeEnd = null;
      });
      return;
    }

    // Считаем предварительную стоимость: суток × цена за сутки.
    // Это ПРЕДВАРИТЕЛЬНЫЙ расчёт для UI; итог всё равно посчитает сервер.
    final days = _daysInclusive(start, end);
    final totalPrice = days * widget.pricePerDay;

    // Отдаём результат наружу во FlutterFlow
    widget.onDatesSelected(_dateOnly(start), _dateOnly(end), totalPrice);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Основной цвет приложения — берём из темы (в FlutterFlow это Primary Color)
    final primaryColor = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    // Итоговая строка стоимости под календарём (если диапазон выбран корректно)
    Widget priceSummary = const SizedBox.shrink();
    if (_rangeStart != null && _rangeEnd != null) {
      final days = _daysInclusive(_rangeStart!, _rangeEnd!);
      final total = days * widget.pricePerDay;
      priceSummary = Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          'Выбрано суток: $days · Итого: ${total.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TableCalendar(
            // Локаль берём динамически из контекста приложения: календарь
            // сам переключится на сербский/английский/русский по настройкам телефона.
            locale: Localizations.localeOf(context).toString(),
            // Диапазон доступных для навигации месяцев: с сегодня на 1 год вперёд
            firstDay: _dateOnly(DateTime.now()),
            lastDay: _dateOnly(DateTime.now().add(const Duration(days: 365))),
            focusedDay: _focusedDay,

            // Включаем режим выбора диапазона дат
            rangeSelectionMode: RangeSelectionMode.enforced,
            rangeStartDay: _rangeStart,
            rangeEndDay: _rangeEnd,

            // Занятые даты полностью недоступны для нажатия
            enabledDayPredicate: (day) => !_isBlocked(day),

            onRangeSelected: _onRangeSelected,

            // ---------- ВНЕШНИЙ ВИД ----------
            calendarStyle: CalendarStyle(
              // Начало и конец диапазона — основной цвет
              rangeStartDecoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              rangeEndDecoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              rangeStartTextStyle: TextStyle(color: onPrimary),
              rangeEndTextStyle: TextStyle(color: onPrimary),

              // Заливка середины диапазона — полупрозрачный основной цвет
              withinRangeDecoration: const BoxDecoration(shape: BoxShape.circle),
              rangeHighlightColor: primaryColor.withValues(alpha: 0.20),

              // Сегодняшний день
              todayDecoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.40),
                shape: BoxShape.circle,
              ),

              // Занятые/недоступные даты — серым и зачёркнуто-приглушённым цветом
              disabledDecoration: const BoxDecoration(
                color: Color(0xFFE0E0E0),
                shape: BoxShape.circle,
              ),
              disabledTextStyle: const TextStyle(
                color: Color(0xFF9E9E9E),
                decoration: TextDecoration.lineThrough,
              ),
            ),

            headerStyle: const HeaderStyle(
              formatButtonVisible: false, // прячем переключатель формата
              titleCentered: true,
            ),
          ),

          priceSummary,
        ],
      ),
    );
  }
}
