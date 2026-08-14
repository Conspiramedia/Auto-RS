// ============================================================
// AUTO.RS — Экран модерации (админ). Две вкладки-папки:
//   • «Новые»       — объявления в статусе moderation;
//   • «Отклонённые» — в статусе rejected (с причиной, можно одобрить).
// Действия: одобрить / отклонить (с причиной) через RPC approve_car /
// reject_car (права проверяет сервер через is_admin()). В карточке видно
// автора (имя/телефон) и фото.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/models/car_image_model.dart';
import '../../../data/models/car_model.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../data/repositories/cars_repository.dart';
import '../../../shared/utils/app_snack.dart';
import '../../../shared/utils/serbian_phone.dart';
import '../../../shared/widgets/pill_back_button.dart';

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  final _repo = AdminRepository();

  late Future<List<ModerationItem>> _newFuture;      // статус moderation
  late Future<List<ModerationItem>> _rejectedFuture; // статус rejected
  bool _busy = false; // блокировка на время approve/reject

  @override
  void initState() {
    super.initState();
    _loadBoth();
  }

  void _loadBoth() {
    _newFuture = _repo.fetchModerationQueue('moderation');
    _rejectedFuture = _repo.fetchModerationQueue('rejected');
  }

  // Перезагрузка обеих папок (после одобрения/отклонения объявление
  // переходит между статусами, поэтому обновляем оба списка).
  void _reload() {
    setState(_loadBoth);
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: const PillBackButton(),
          title: const Text('Модерация'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Новые'),
              Tab(text: 'Отклонённые'),
            ],
          ),
        ),
        body: AbsorbPointer(
          absorbing: _busy,
          child: TabBarView(
            children: [
              _buildList(_newFuture, 'Новых объявлений нет', isRejected: false),
              _buildList(_rejectedFuture, 'Отклонённых объявлений нет',
                  isRejected: true),
            ],
          ),
        ),
      ),
    );
  }

  // Список одной папки. isRejected меняет доступные действия: у отклонённых
  // показываем причину и кнопку «Одобрить» (без «Отклонить» — уже отклонено).
  Widget _buildList(
    Future<List<ModerationItem>> future,
    String emptyText, {
    required bool isRejected,
  }) {
    return FutureBuilder<List<ModerationItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        final items = snapshot.data ?? [];
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: items.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 120),
                    Center(child: Text(emptyText)),
                  ],
                )
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) => _ModerationCard(
                    item: items[i],
                    isRejected: isRejected,
                    onApprove: () => _approve(items[i].car),
                    onReject:
                        isRejected ? null : () => _reject(items[i].car),
                  ),
                ),
        );
      },
    );
  }
}

// Карточка объявления в очереди модерации
class _ModerationCard extends StatelessWidget {
  const _ModerationCard({
    required this.item,
    required this.isRejected,
    required this.onApprove,
    required this.onReject,
  });

  final ModerationItem item;
  final bool isRejected;         // папка «Отклонённые»
  final VoidCallback onApprove;
  final VoidCallback? onReject;  // null — кнопку «Отклонить» не показываем

  @override
  Widget build(BuildContext context) {
    final car = item.car;
    // Цена по назначению
    final price = car.isForRent && car.rentPriceDaily != null
        ? '${car.rentPriceDaily!.toStringAsFixed(0)} ${car.currency.value}/сутки'
        : car.salePrice != null
            ? '${car.salePrice!.toStringAsFixed(0)} ${car.currency.value}'
            : '—';

    // «От кого»: имя продавца (если задано) + телефон в читаемом виде.
    final sellerName = (item.authorName?.trim().isNotEmpty ?? false)
        ? item.authorName!.trim()
        : 'Без имени';
    final sellerPhone = (car.contactPhone?.trim().isNotEmpty ?? false)
        ? serbianPhoneDisplay(car.contactPhone!)
        : null;

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

            // ---- От кого (продавец) ----
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    sellerPhone != null
                        ? '$sellerName · $sellerPhone'
                        : sellerName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),

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

            // ---- Причина отклонения (только в папке «Отклонённые») ----
            if (isRejected &&
                (car.moderationComment?.trim().isNotEmpty ?? false)) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0x1AE01E23), // бренд-красный, прозрачный
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Причина: ${car.moderationComment!.trim()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onReject != null) ...[
                  OutlinedButton(
                    onPressed: onReject,
                    child: const Text('Отклонить'),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton(
                  onPressed: onApprove,
                  // В «Отклонённых» одобрение = повторная публикация.
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
