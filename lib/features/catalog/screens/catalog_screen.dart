// ============================================================
// AUTO.RS — Экран каталога. Список активных объявлений через
// серверную RPC search_cars_advanced (фильтр по типу + поиск).
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/car_model.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/cars_repository.dart';
import '../../../data/repositories/favorites_repository.dart';
import '../../../data/repositories/notifications_repository.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _repo = CarsRepository();
  final _favRepo = FavoritesRepository();
  final _auth = AuthRepository();
  final _searchCtrl = TextEditingController();

  // 'sale' — купить, 'rent' — аренда
  String _listingType = 'sale';

  // Множество ID машин в избранном (для сердечек). Обновляется оптимистично.
  Set<String> _favoriteIds = {};

  late Future<List<CarModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadFavorites();
  }

  // Подтягиваем избранное одним запросом (только для залогиненного)
  Future<void> _loadFavorites() async {
    if (_auth.currentUser == null) return;
    try {
      final ids = await _favRepo.favoriteCarIds();
      if (mounted) setState(() => _favoriteIds = ids);
    } catch (_) {
      // молча — сердечки просто будут пустыми
    }
  }

  // Переключение избранного с оптимистичным обновлением UI.
  Future<void> _toggleFavorite(String carId) async {
    if (_auth.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Войдите, чтобы добавить в избранное')),
      );
      return;
    }
    final wasFav = _favoriteIds.contains(carId);
    // Оптимистично меняем состояние СРАЗУ
    setState(() {
      if (wasFav) {
        _favoriteIds.remove(carId);
      } else {
        _favoriteIds.add(carId);
      }
    });
    try {
      final nowFav = await _favRepo.toggle(carId);
      // Сверяем с серверным фактом (защита от рассинхрона)
      if (mounted) {
        setState(() {
          if (nowFav) {
            _favoriteIds.add(carId);
          } else {
            _favoriteIds.remove(carId);
          }
        });
      }
    } catch (_) {
      // Откат при ошибке
      if (mounted) {
        setState(() {
          if (wasFav) {
            _favoriteIds.add(carId);
          } else {
            _favoriteIds.remove(carId);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось обновить избранное')),
        );
      }
    }
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
          // Колокольчик уведомлений с бэйджем непрочитанных (для залогиненного)
          if (_auth.currentUser != null) const _NotifBell(),
          // Избранное
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: 'Избранное',
            onPressed: () async {
              await context.push('/favorites');
              _loadFavorites(); // вернулись — обновим сердечки в каталоге
            },
          ),
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
                    itemBuilder: (context, i) => _CarCard(
                      car: cars[i],
                      isFavorite: _favoriteIds.contains(cars[i].id),
                      onToggleFavorite: () => _toggleFavorite(cars[i].id),
                    ),
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
  const _CarCard({
    required this.car,
    required this.isFavorite,
    required this.onToggleFavorite,
  });
  final CarModel car;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    // Показываем цену по типу назначения
    final priceText = car.isForRent && car.rentPriceDaily != null
        ? '${car.rentPriceDaily!.toStringAsFixed(0)} ${car.currency.value}/сутки'
        : car.salePrice != null
            ? '${car.salePrice!.toStringAsFixed(0)} ${car.currency.value}'
            : '—';

    // Рейтинг в подзаголовке (если есть отзывы)
    final rating = car.reviewsCount > 0
        ? ' · ⭐ ${car.ratingAvg.toStringAsFixed(1)}'
        : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        onTap: () => context.push('/car/${car.id}'),
        leading: const CircleAvatar(child: Icon(Icons.directions_car)),
        title: Text('${car.brand} ${car.model}, ${car.year}'),
        subtitle: Text('${car.city} · $priceText$rating'),
        trailing: IconButton(
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? Colors.red : null,
          ),
          onPressed: onToggleFavorite,
        ),
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

// Колокольчик уведомлений с живым бэйджем непрочитанных (Realtime-стрим)
class _NotifBell extends StatefulWidget {
  const _NotifBell();

  @override
  State<_NotifBell> createState() => _NotifBellState();
}

class _NotifBellState extends State<_NotifBell> {
  final _repo = NotificationsRepository();
  late final Stream<List<NotificationModel>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _repo.stream();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NotificationModel>>(
      stream: _stream,
      builder: (context, snapshot) {
        // Считаем непрочитанные из потока
        final unread =
            (snapshot.data ?? []).where((n) => !n.isRead).length;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none),
              tooltip: 'Уведомления',
              onPressed: () => context.push('/notifications'),
            ),
            // Красный бэйдж с числом (если есть непрочитанные)
            if (unread > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
