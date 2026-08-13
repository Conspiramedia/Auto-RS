// ============================================================
// AUTO.RS — Экран модерации (админ). Очередь объявлений в статусе
// moderation + одобрить / отклонить (с причиной). Всё через RPC
// approve_car / reject_car (права проверяет сервер через is_admin()).
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/models/car_model.dart';
import '../../../data/repositories/admin_repository.dart';
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

  // Диалог ввода причины отклонения
  Future<String?> _askReason() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Причина отклонения'),
        content: TextField(
          controller: ctrl,
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
