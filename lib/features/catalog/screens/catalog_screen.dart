// ============================================================
// AUTO.RS — Экран каталога. Список активных объявлений через
// серверную RPC search_cars_advanced (фильтр по типу + поиск).
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/car_model.dart';
import '../../../data/repositories/cars_repository.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _repo = CarsRepository();
  final _searchCtrl = TextEditingController();

  // 'sale' — купить, 'rent' — аренда
  String _listingType = 'sale';

  late Future<List<CarModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Загрузка каталога с текущими фильтрами
  Future<List<CarModel>> _load() {
    final q = _searchCtrl.text.trim();
    return _repo.searchAdvanced(
      listingType: _listingType,
      query: q.isEmpty ? null : q,
    );
  }

  // Применить фильтры и перезапросить
  void _apply() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Каталог'),
        actions: [
          // Вход в диалоги (для гостя роутер уведёт на логин)
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Диалоги',
            onPressed: () => context.push('/chats'),
          ),
        ],
      ),
      // Кнопка «подать объявление». Для гостя роутер перенаправит на логин.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Ждём возврата с экрана создания; при успехе обновляем каталог
          final created = await context.push<String>('/create-car');
          if (created != null) _apply();
        },
        icon: const Icon(Icons.add),
        label: const Text('Объявление'),
      ),
      body: Column(
        children: [
          // Панель фильтров
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _apply(),
                  decoration: InputDecoration(
                    hintText: 'Марка, модель или город',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        _apply();
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                // Переключатель типа сделки
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'sale', label: Text('Купить')),
                    ButtonSegment(value: 'rent', label: Text('Аренда')),
                  ],
                  selected: {_listingType},
                  onSelectionChanged: (s) {
                    setState(() => _listingType = s.first);
                    _apply();
                  },
                ),
              ],
            ),
          ),

          // Список результатов
          Expanded(
            child: FutureBuilder<List<CarModel>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorState(
                    message: '${snapshot.error}',
                    onRetry: _apply,
                  );
                }
                final cars = snapshot.data ?? [];
                if (cars.isEmpty) {
                  return const Center(
                    child: Text('Пока нет объявлений по этому фильтру'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _apply(),
                  child: ListView.builder(
                    itemCount: cars.length,
                    itemBuilder: (context, i) => _CarCard(car: cars[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Карточка объявления в списке
class _CarCard extends StatelessWidget {
  const _CarCard({required this.car});
  final CarModel car;

  @override
  Widget build(BuildContext context) {
    // Показываем цену по типу назначения
    final priceText = car.isForRent && car.rentPriceDaily != null
        ? '${car.rentPriceDaily!.toStringAsFixed(0)} ${car.currency.value}/сутки'
        : car.salePrice != null
            ? '${car.salePrice!.toStringAsFixed(0)} ${car.currency.value}'
            : '—';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        onTap: () => context.push('/car/${car.id}'),
        leading: const CircleAvatar(child: Icon(Icons.directions_car)),
        title: Text('${car.brand} ${car.model}, ${car.year}'),
        subtitle: Text('${car.city} · $priceText'),
        trailing: car.reviewsCount > 0
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  Text(car.ratingAvg.toStringAsFixed(1)),
                ],
              )
            : null,
      ),
    );
  }
}

// Состояние ошибки с кнопкой повтора
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}
