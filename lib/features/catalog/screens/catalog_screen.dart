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
import '../models/car_filters.dart';
import 'filters_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _repo = CarsRepository();
  final _favRepo = FavoritesRepository();
  final _auth = AuthRepository();

  // 'sale' — купить, 'rent' — аренда
  String _listingType = 'sale';

  // Выбранные фильтры (город, марка, год, пробег, цена и т.д.)
  CarFilters _filters = CarFilters.empty;

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

  // Загрузка каталога с текущими фильтрами
  Future<List<CarModel>> _load() {
    return _repo.searchAdvanced(
      listingType: _listingType,
      brand: _filters.brand,
      city: _filters.city,
      yearFrom: _filters.yearFrom,
      yearTo: _filters.yearTo,
      mileageMax: _filters.mileageMax,
      priceFrom: _filters.priceFrom,
      priceTo: _filters.priceTo,
      bodyType: _filters.bodyType,
      transmission: _filters.transmission,
      fuel: _filters.fuel,
    );
  }

  // Открыть экран фильтров и применить результат
  Future<void> _openFilters() async {
    final result = await Navigator.push<CarFilters>(
      context,
      MaterialPageRoute(
        builder: (_) => FiltersScreen(initial: _filters),
      ),
    );
    if (result != null) {
      setState(() {
        _filters = result;
        _future = _load();
      });
    }
  }

  // Применить фильтры и перезапросить
  void _apply() {
    setState(() => _future = _load());
  }

  // Приводим технические ошибки к понятному пользователю виду.
  // «Failed to fetch» / таймаут обычно = нет связи или сервер «просыпается».
  String _friendlyError(Object? e) {
    final s = e?.toString() ?? '';
    if (s.contains('Failed to fetch') ||
        s.contains('SocketException') ||
        s.contains('timeout') ||
        s.contains('Connection')) {
      return 'Нет связи с сервером.\nПроверьте интернет и попробуйте снова.';
    }
    return 'Не удалось загрузить каталог.\nПопробуйте ещё раз.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar убран: логотип и поиск — в самом верху тела (SafeArea).
      // Уведомления/избранное/диалоги перенесены в нижнюю навигацию.
      // Кнопка «подать объявление» — доступна всем (для гостя роутер уведёт на логин).
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Ждём возврата с экрана создания; при успехе обновляем каталог
          final created = await context.push<String>('/create-car');
          if (created != null) _apply();
        },
        icon: const Icon(Icons.add),
        label: const Text('Объявление'),
      ),
      body: SafeArea(
        child: Column(
        children: [
          // Панель фильтров
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Логотип слева + кнопка «Фильтры» справа — в один ряд
                Row(
                  children: [
                    Image.asset('assets/images/logo.png', height: 56),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openFilters,
                        icon: const Icon(Icons.tune),
                        label: Text(
                          _filters.activeCount > 0
                              ? 'Фильтры (${_filters.activeCount})'
                              : 'Фильтры',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Переключатель типа сделки + колокольчик уведомлений справа
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'sale', label: Text('Продажа')),
                          ButtonSegment(value: 'rent', label: Text('Аренда')),
                        ],
                        selected: {_listingType},
                        onSelectionChanged: (s) {
                          setState(() => _listingType = s.first);
                          _apply();
                        },
                      ),
                    ),
                    // Колокольчик уведомлений (для залогиненного)
                    if (_auth.currentUser != null) const _NotifBell(),
                  ],
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
                    message: _friendlyError(snapshot.error),
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
                  child: GridView.builder(
                    padding: const EdgeInsets.all(5),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,      // 2 карточки в ряд
                      mainAxisSpacing: 5,     // отступ между рядами
                      crossAxisSpacing: 5,    // отступ между колонками
                      childAspectRatio: 0.80, // пропорции карточки (ниже — меньше пустоты снизу)
                    ),
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

  // Собираем строку характеристик из заданных полей: пробег · кузов · КПП · топливо
  String _specsLine(CarModel c) {
    final parts = <String>[
      if (c.mileage != null) '${c.mileage} км',
      if (c.bodyType != null) c.bodyType!.value,
      if (c.transmission != null) c.transmission!.value,
      if (c.fuel != null) c.fuel!.value,
    ];
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

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

    return InkWell(
      onTap: () => context.push('/car/${car.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3), // радиус 3px
          border: Border.all(color: const Color(0xFFE0E0E0)),
          // Тень для эффекта «парения» над фоном
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Фото на всю ширину (4:3) + сердечко поверх
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: _CarThumb(carId: car.id),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: InkWell(
                    onTap: onToggleFavorite,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.black26,
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: isFavorite ? Colors.red : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Инфо-блок под фото — растянут до низа карточки, фон чуть темнее
            Expanded(
              child: Container(
              width: double.infinity,
              color: const Color(0xFFF0F0F0),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок + год (жирным, одна строка)
                  Text(
                    '${car.brand} ${car.model}, ${car.year}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  // Цена (крупно, основным цветом)
                  Text(
                    priceText,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Характеристики: пробег · кузов · КПП (что задано)
                  Text(
                    _specsLine(car),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  // Город (+ рейтинг), мелко серым
                  Text(
                    '${car.city}$rating',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            ),
          ],
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

// Миниатюра первого фото машины (ленивая подгрузка из car_images).
// Пока грузится / если фото нет — иконка машины.
class _CarThumb extends StatefulWidget {
  const _CarThumb({required this.carId});
  final String carId;

  @override
  State<_CarThumb> createState() => _CarThumbState();
}

class _CarThumbState extends State<_CarThumb> {
  final _repo = CarsRepository();
  String? _url;

  @override
  void initState() {
    super.initState();
    _repo.fetchImages(widget.carId).then((imgs) {
      if (mounted && imgs.isNotEmpty) {
        setState(() => _url = imgs.first.imageUrl);
      }
    }).catchError((_) {
      // молча — оставим иконку-плейсхолдер
    });
  }

  @override
  Widget build(BuildContext context) {
    // Плейсхолдер на всю область (фото нет или ещё грузится) — логотип Auto.RS
    // на фоне под цвет логотипа, во всю область фото.
    final placeholder = Container(
      color: const Color(0xFFFEFEFE),
      alignment: Alignment.center,
      child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
    );
    if (_url == null) return placeholder;
    return Image.network(
      _url!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => placeholder,
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
