// ============================================================
// AUTO.RS — Экран деталей автомобиля.
// Фото-галерея + характеристики + цена. Для аренды: календарь выбора
// дат (занятые дни заблокированы) + кнопка «Забронировать»
// (проверка is_car_available → создание брони pending).
// ============================================================

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/car_image_model.dart';
import '../../../data/models/car_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/bookings_repository.dart';
import '../../../data/repositories/cars_repository.dart';
import '../../../data/repositories/chat_repository.dart';
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
  final _chatRepo = ChatRepository();
  final _auth = AuthRepository();

  bool _startingChat = false;

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

  // Начать чат с продавцом (RPC start_chat) и перейти в комнату
  Future<void> _startChat(CarModel car) async {
    if (_auth.currentUser == null) {
      _snack('Войдите, чтобы написать продавцу');
      return;
    }
    setState(() => _startingChat = true);
    try {
      final chatId = await _chatRepo.startChat(car.id);
      if (mounted) {
        context.push('/chat/$chatId', extra: '${car.brand} ${car.model}');
      }
    } catch (e) {
      // Напр.: «Нельзя начать чат с самим собой»
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _startingChat = false);
    }
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

              // ---------- Цены (нет цены → «Договорная») ----------
              if (car.isForSale)
                _PriceLine(
                  label: 'Цена продажи',
                  value: car.salePrice != null
                      ? '${_money(car.salePrice!)} ${car.currency.value}'
                      : 'Договорная',
                ),
              if (car.isForRent)
                _PriceLine(
                  label: 'Аренда в сутки',
                  value: car.rentPriceDaily != null
                      ? '${_money(car.rentPriceDaily!)} ${car.currency.value}'
                      : 'Договорная',
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
                    value: _selTotal != null
                        ? '${_money(_selTotal!)} ${car.currency.value}'
                        : '-',
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
                    onPressed: _startingChat ? null : () => _startChat(car),
                    child: _startingChat
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Написать продавцу'),
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
      // Нет фото — та же заглушка-лого, что в карточках каталога.
      return Container(
        height: 300,
        color: const Color(0xFFFFFFFF),
        alignment: Alignment.center,
        child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
      );
    }
    return SizedBox(
      height: 300,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, i) => _GalleryItem(url: images[i].imageUrl),
      ),
    );
  }
}

// Один кадр галереи. Форматы фото у клиентов разные (вертикальные,
// квадратные, широкие), поэтому подгоняем универсально:
//   • фон — то же фото, растянутое на весь кадр (cover) и РАЗМЫТОЕ;
//   • поверх — то же фото ЦЕЛИКОМ (contain).
// Так фото видно полностью, без обрезки, а пустые поля по бокам залиты
// размытой копией — без «чёрных полос». Ничего не нужно знать о пропорциях.
class _GalleryItem extends StatelessWidget {
  const _GalleryItem({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    // Фото не загрузилось — та же заглушка-лого.
    final placeholder = Container(
      color: const Color(0xFFFFFFFF),
      alignment: Alignment.center,
      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        // Фон: размытая растянутая копия фото
        Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(color: Colors.black.withValues(alpha: 0.15)),
        ),
        // Само фото — целиком, по центру
        Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      ],
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
      if (car.mileage != null)
        MapEntry('Пробег', '${_money(car.mileage!)} км'),
      if (car.bodyType != null) MapEntry('Кузов', car.bodyType!.value),
      if (car.transmission != null)
        MapEntry('КПП', car.transmission!.value),
      if (car.fuel != null) MapEntry('Топливо', car.fuel!.value),
    ];
    if (specs.isEmpty) return const SizedBox.shrink();

    // По 2 характеристики в ряд, ячейки равной ширины (Expanded).
    // Разбиваем список на пары и рендерим строками.
    final rows = <Widget>[];
    for (int i = 0; i < specs.length; i += 2) {
      final left = specs[i];
      final right = (i + 1 < specs.length) ? specs[i + 1] : null;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(child: _specChip(left)),
            const SizedBox(width: 8),
            // Пустая ячейка, если характеристика без пары — ширина колонок ровная.
            Expanded(
              child: right != null
                  ? _specChip(right)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }

  // Ячейка характеристики фиксированного вида (одинаковая высота/оформление).
  Widget _specChip(MapEntry<String, String> e) {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${e.key}: ${e.value}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
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

// Число с разделителем разрядов пробелом: 1000000 → «1 000 000».
String _money(num v) {
  final s = v.toStringAsFixed(0);
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}
