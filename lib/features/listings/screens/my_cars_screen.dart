// ============================================================
// AUTO.RS — Экран «Мои объявления» (для продавца/vendor).
// Список своих авто со статусами (модерация/активно/отклонено/…).
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/enums/car_status.dart';
import '../../../data/models/car_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/cars_repository.dart';
import '../../../shared/widgets/pill_back_button.dart';

class MyCarsScreen extends StatefulWidget {
  const MyCarsScreen({super.key});

  @override
  State<MyCarsScreen> createState() => _MyCarsScreenState();
}

class _MyCarsScreenState extends State<MyCarsScreen> {
  final _repo = CarsRepository();
  final _auth = AuthRepository();

  late Future<List<CarModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<CarModel>> _load() {
    final uid = _auth.currentUser?.id ?? '';
    return _repo.fetchMyCars(uid);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const PillBackButton(), title: const Text('Мои объявления')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await context.push<String>('/create-car');
          if (created != null) _reload();
        },
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
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
                  Center(child: Text('У вас пока нет объявлений')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              itemCount: cars.length,
              itemBuilder: (context, i) => _MyCarCard(car: cars[i]),
            ),
          );
        },
      ),
    );
  }
}

// Карточка своего объявления со статусом
class _MyCarCard extends StatelessWidget {
  const _MyCarCard({required this.car});
  final CarModel car;

  @override
  Widget build(BuildContext context) {
    final price = car.isForRent && car.rentPriceDaily != null
        ? '${car.rentPriceDaily!.toStringAsFixed(0)} ${car.currency.value}/сутки'
        : car.salePrice != null
            ? '${car.salePrice!.toStringAsFixed(0)} ${car.currency.value}'
            : '—';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        onTap: () => context.push('/car/${car.id}'),
        title: Text('${car.brand} ${car.model}, ${car.year}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${car.city} · $price'),
            // Для отклонённых показываем причину модератора
            if (car.status == CarStatus.rejected &&
                car.moderationComment != null)
              Text('Причина: ${car.moderationComment}',
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
        trailing: _StatusChip(status: car.status),
      ),
    );
  }
}

// Цветной чип статуса объявления
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final CarStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      CarStatus.draft => ('Черновик', Colors.grey),
      CarStatus.moderation => ('На модерации', Colors.orange),
      CarStatus.active => ('Активно', Colors.green),
      CarStatus.rejected => ('Отклонено', Colors.red),
      CarStatus.archived => ('В архиве', Colors.blueGrey),
      CarStatus.sold => ('Продано', Colors.teal),
    };
    return Chip(
      label: Text(label,
          style: const TextStyle(fontSize: 11, color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
