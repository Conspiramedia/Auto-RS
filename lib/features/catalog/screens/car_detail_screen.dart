// ============================================================
// AUTO.RS — Экран деталей автомобиля.
// Фото-галерея + характеристики + цена. Для аренды: календарь выбора
// дат (занятые дни заблокированы) + кнопка «Забронировать»
// (проверка is_car_available → создание брони pending).
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/models/car_image_model.dart';
import '../../../data/models/car_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/bookings_repository.dart';
import '../../../data/repositories/cars_repository.dart';
import '../../rent/widgets/car_booking_calendar.dart';

class CarDetailScreen extends StatefulWidget {
  const CarDetailScreen({super.key, required this.carId});

  final String carId;

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  final _carsRepo = CarsRepository();
  final _bookingsRepo = BookingsRepository();
  final _auth = AuthRepository();

  late Future<_DetailData> _future;

  // Выбранный в календаре диапазон и предварительная стоимость
  DateTime? _selStart;
  DateTime? _selEnd;
  double? _selTotal;
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // Грузим машину + фото + (для аренды) занятые даты
  Future<_DetailData> _load() async {
    final car = await _carsRepo.fetchById(widget.carId);
    if (car == null) {
      throw Exception('Объявление не найдено');
    }
    final images = await _carsRepo.fetchImages(widget.carId);
    final blocked = car.isForRent
        ? await _bookingsRepo.fetchBlockedDates(widget.carId)
        : <DateTime>[];
    return _DetailData(car: car, images: images, blocked: blocked);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Создание брони после выбора дат
  Future<void> _book(CarModel car) async {
    // Гость — просим войти
    final user = _auth.currentUser;
    if (user == null) {
      _snack('Войдите, чтобы забронировать');
      return;
    }
    if (_selStart == null || _selEnd == null) {
      _snack('Выберите даты аренды');
      return;
    }

    setState(() => _booking = true);
    try {
      // 1) Проверка доступности на сервере (UX-фидбек)
      final available = await _bookingsRepo.isCarAvailable(
        carId: car.id,
        start: _selStart!,
        end: _selEnd!,
      );
      if (!available) {
        _snack('К сожалению, эти даты уже заняты');
        return;
      }

      // 2) Создание брони (статус pending; финансы считает триггер на сервере).
      // Серверный гейт (миграция 0020) отклонит бронь неверифицированным —
      // текст ошибки покажем в снекбаре.
      await _bookingsRepo.createBooking(
        carId: car.id,
        customerId: user.id,
        start: _selStart!,
        end: _selEnd!,
      );
      _snack('Заявка отправлена. Ожидайте подтверждения владельца.');
    } catch (e) {
      _snack(_humanError(e));
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  String _humanError(Object e) {
    final s = e.toString();
    if (s.contains('верифицированным')) {
      return 'Бронирование доступно только верифицированным пользователям';
    }
    return 'Ошибка: $s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Объявление')),
      body: FutureBuilder<_DetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final data = snapshot.data!;
          return _buildContent(data);
        },
      ),
    );
  }

  Widget _buildContent(_DetailData data) {
    final car = data.car;

    return ListView(
      children: [
        // ---------- Галерея фото ----------
        _Gallery(images: data.images),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок
              Text(
                '${car.brand} ${car.model}, ${car.year}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16),
                  Text(car.city),
                  if (car.reviewsCount > 0) ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    Text('${car.ratingAvg.toStringAsFixed(1)} '
                        '(${car.reviewsCount})'),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // ---------- Характеристики ----------
              _SpecsGrid(car: car),
              const SizedBox(height: 16),

              // ---------- Цены ----------
              if (car.isForSale && car.salePrice != null)
                _PriceLine(
                  label: 'Цена продажи',
                  value: '${car.salePrice!.toStringAsFixed(0)} '
                      '${car.currency.value}',
                ),
              if (car.isForRent && car.rentPriceDaily != null)
                _PriceLine(
                  label: 'Аренда в сутки',
                  value: '${car.rentPriceDaily!.toStringAsFixed(0)} '
                      '${car.currency.value}',
                ),

              // ---------- Описание ----------
              if (car.description != null &&
                  car.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Описание',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(car.description!),
              ],

              // ---------- Блок аренды: календарь + бронь ----------
              if (car.isForRent && car.rentPriceDaily != null) ...[
                const Divider(height: 32),
                Text('Выберите даты аренды',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                CarBookingCalendar(
                  blockedDates: data.blocked,
                  pricePerDay: car.rentPriceDaily!,
                  onDatesSelected: (start, end, total) async {
                    setState(() {
                      _selStart = start;
                      _selEnd = end;
                      _selTotal = total;
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (_selStart != null && _selEnd != null)
                  _PriceLine(
                    label: 'Предварительно',
                    value: '${_selTotal?.toStringAsFixed(0) ?? '-'} '
                        '${car.currency.value}',
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: (_booking || _selStart == null)
                        ? null
                        : () => _book(car),
                    child: _booking
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Забронировать'),
                  ),
                ),
              ],

              // ---------- Блок продажи: контакты (заглушка) ----------
              if (car.isForSale) ...[
                const Divider(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () => _snack('Чат с продавцом — в следующем шаге'),
                    child: const Text('Написать продавцу'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// Данные экрана
class _DetailData {
  final CarModel car;
  final List<CarImageModel> images;
  final List<DateTime> blocked;
  const _DetailData({
    required this.car,
    required this.images,
    required this.blocked,
  });
}

// Галерея фото (горизонтальная прокрутка). Плейсхолдер, если фото нет.
class _Gallery extends StatelessWidget {
  const _Gallery({required this.images});
  final List<CarImageModel> images;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Container(
        height: 220,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: Icon(Icons.directions_car, size: 72, color: Colors.grey),
        ),
      );
    }
    return SizedBox(
      height: 220,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, i) => Image.network(
          images[i].imageUrl,
          fit: BoxFit.cover,
          // Плейсхолдер при ошибке загрузки
          errorBuilder: (_, __, ___) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(child: Icon(Icons.broken_image, size: 48)),
          ),
        ),
      ),
    );
  }
}

// Сетка характеристик
class _SpecsGrid extends StatelessWidget {
  const _SpecsGrid({required this.car});
  final CarModel car;

  @override
  Widget build(BuildContext context) {
    final specs = <MapEntry<String, String>>[
      if (car.mileage != null) MapEntry('Пробег', '${car.mileage} км'),
      if (car.bodyType != null) MapEntry('Кузов', car.bodyType!.value),
      if (car.transmission != null)
        MapEntry('КПП', car.transmission!.value),
      if (car.fuel != null) MapEntry('Топливо', car.fuel!.value),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: specs
          .map((e) => Chip(label: Text('${e.key}: ${e.value}')))
          .toList(),
    );
  }
}

// Строка «метка — значение» для цен
class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
