// ============================================================
// AUTO.RS — Экран модерации (админ). Очередь объявлений в статусе
// moderation + одобрить / отклонить (с причиной). Всё через RPC
// approve_car / reject_car (права проверяет сервер через is_admin()).
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/models/car_image_model.dart';
import '../../../data/models/car_model.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../data/repositories/cars_repository.dart';
import '../../../shared/utils/app_snack.dart';
import '../../../shared/widgets/pill_back_button.dart';

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  final _repo = AdminRepository();

  late Future<List<CarModel>> _future;
  bool _busy = false; // блокировка на время approve/reject

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchModerationQueue();
  }

  void _reload() {
    setState(() => _future = _repo.fetchModerationQueue());
  }

  void _snack(String msg) {
    if (!mounted) return;
    showAppSnack(context, msg);
  }

  // Одобрить объявление
  Future<void> _approve(CarModel car) async {
    setState(() => _busy = true);
    try {
      await _repo.approveCar(car.id);
      _snack('Объявление опубликовано');
      _reload();
    } catch (e) {
      _snack(_humanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Отклонить с причиной (диалог ввода)
  Future<void> _reject(CarModel car) async {
    final comment = await _askReason();
    if (comment == null) return; // отменили диалог
    if (comment.trim().isEmpty) {
      _snack('Укажите причину отклонения');
      return;
    }

    setState(() => _busy = true);
    try {
      await _repo.rejectCar(car.id, comment.trim());
      _snack('Объявление отклонено');
      _reload();
    } catch (e) {
      _snack(_humanError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Готовые причины отклонения (типовые для авто-маркетплейса). Модератор
  // выбирает из списка; «Другое» открывает поле свободного ввода. Возвращаемая
  // строка уходит в reject_car как комментарий и показывается продавцу.
  static const List<String> _rejectReasons = [
    'Фото не соответствуют: чужие снимки, не тот автомобиль или плохое качество',
    'Недостоверная цена (заниженная/ложная для привлечения внимания)',
    'Некорректное описание: оскорбления, спам или реклама сторонних сайтов',
    'Данные не совпадают с фото (марка, модель, год или состояние)',
    'Запрещённый объект: не легковой автомобиль, авто в розыске/аресте/залоге',
    'Дубликат: такое же объявление уже размещено',
    'Контакты в описании или на фото (укажите телефон в отдельном поле)',
    'Признаки мошенничества (предоплата, «пригон под заказ», подозрительная схема)',
  ];

  // Диалог выбора причины отклонения из списка + вариант «Другое».
  Future<String?> _askReason() {
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Причина отклонения'),
        children: [
          for (final reason in _rejectReasons)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, reason),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(reason),
              ),
            ),
          const Divider(height: 1),
          // «Другое» — свободный ввод для нетиповых случаев.
          SimpleDialogOption(
            onPressed: () async {
              final custom = await _askCustomReason();
              if (!ctx.mounted) return;
              // Пустой ввод — не закрываем выбор, остаёмся в диалоге.
              if (custom != null && custom.trim().isNotEmpty) {
                Navigator.pop(ctx, custom.trim());
              }
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Другое (указать причину вручную)…'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx), // отмена — null
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Отмена'),
            ),
          ),
        ],
      ),
    );
  }

  // Свободный ввод причины (вариант «Другое»).
  Future<String?> _askCustomReason() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Своя причина'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Опишите, что не так с объявлением',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Отклонить'),
          ),
        ],
      ),
    );
  }

  String _humanError(Object e) {
    final s = e.toString();
    if (s.contains('прав') || s.contains('privilege')) {
      return 'Доступ только для администраторов';
    }
    return humanizeError(e);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const PillBackButton(), title: const Text('Модерация')),
      body: FutureBuilder<List<CarModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final cars = snapshot.data ?? [];
          if (cars.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Очередь модерации пуста')),
                ],
              ),
            );
          }
          return AbsorbPointer(
            absorbing: _busy,
            child: RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.builder(
                itemCount: cars.length,
                itemBuilder: (context, i) => _ModerationCard(
                  car: cars[i],
                  onApprove: () => _approve(cars[i]),
                  onReject: () => _reject(cars[i]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Карточка объявления в очереди модерации
class _ModerationCard extends StatelessWidget {
  const _ModerationCard({
    required this.car,
    required this.onApprove,
    required this.onReject,
  });

  final CarModel car;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    // Цена по назначению
    final price = car.isForRent && car.rentPriceDaily != null
        ? '${car.rentPriceDaily!.toStringAsFixed(0)} ${car.currency.value}/сутки'
        : car.salePrice != null
            ? '${car.salePrice!.toStringAsFixed(0)} ${car.currency.value}'
            : '—';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Фото объявления (лежат в отдельной таблице car_images) —
            // подтягиваем по id, чтобы админ видел, что одобряет.
            _ModerationPhotos(carId: car.id),
            const SizedBox(height: 8),
            Text(
              '${car.brand} ${car.model}, ${car.year}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('${car.city} · $price'),
            if (car.description != null &&
                car.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                car.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: onReject,
                  child: const Text('Отклонить'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onApprove,
                  child: const Text('Одобрить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Лента фото объявления в карточке модерации. Фото хранятся в таблице
// car_images (не в самом cars), поэтому подтягиваем их отдельным запросом
// по id. Тап по миниатюре открывает фото на весь экран.
class _ModerationPhotos extends StatefulWidget {
  const _ModerationPhotos({required this.carId});
  final String carId;

  @override
  State<_ModerationPhotos> createState() => _ModerationPhotosState();
}

class _ModerationPhotosState extends State<_ModerationPhotos> {
  final _repo = CarsRepository();
  late final Future<List<CarImageModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchImages(widget.carId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CarImageModel>>(
      future: _future,
      builder: (context, snapshot) {
        // Пока грузятся — плашка-заглушка, чтобы карточка не «прыгала».
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 90,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final images = snapshot.data ?? [];
        if (images.isEmpty) {
          return Container(
            height: 90,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Без фото'),
          );
        }
        return SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final url = images[i].imageUrl;
              return GestureDetector(
                onTap: () => _openFull(context, url),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    width: 120,
                    height: 90,
                    fit: BoxFit.cover,
                    // Битая ссылка — не роняем карточку, показываем значок.
                    errorBuilder: (_, __, ___) => Container(
                      width: 120,
                      color: Colors.black12,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Полноэкранный просмотр фото с возможностью зума.
  void _openFull(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(child: Image.network(url)),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
