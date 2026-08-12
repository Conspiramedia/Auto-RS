// ============================================================
// AUTO.RS — Экран каталога. Список активных объявлений через
// серверную RPC search_cars_advanced (фильтр по типу + поиск).
// ============================================================

import 'dart:math';

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

  // ---------- Бесконечная лента («крутилка», миграция 0030) ----------
  static const int _pageSize = 20;
  // Верхняя граница seed: < 2^31, чтобы влезало в integer на сервере.
  static const int _maxSeed = 1 << 30;
  final _random = Random();
  final _scrollCtrl = ScrollController();

  // Загруженные объявления (растут по мере скролла).
  List<CarModel> _cars = [];
  // Состояние первой загрузки / ошибки.
  bool _loading = true;
  Object? _error;

  // Есть ли что подгружать. false ТОЛЬКО когда по фильтру совсем пусто
  // (0 объявлений) — иначе лента бесконечна и крутится по кругу.
  bool _hasMore = true;
  // Идёт ли подгрузка следующей страницы (защита от двойных вызовов).
  bool _isLoadingMore = false;

  // Состояние текущего «круга»:
  int _lapSeed = 0;    // seed круга (стабильный порядок на все его страницы)
  int _lapOffset = 0;  // серверный offset внутри круга
  bool _looping = false; // круги 2+: полная перетасовка (p_shuffle_all=true)

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _reload();
    _loadFavorites();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Триггер подгрузки при приближении к концу списка.
  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 600) {
      _loadMore();
    }
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

  // Проверка авторизации для действий, требующих аккаунта.
  bool _requireAuth(String message) {
    if (_auth.currentUser != null) return true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    return false;
  }

  // «Не интересует это объявление» — скрыть конкретную карточку.
  // Оптимистично убираем из списка, затем сохраняем на сервере.
  Future<void> _hideCar(CarModel car) async {
    if (!_requireAuth('Войдите, чтобы скрывать объявления')) return;
    setState(() => _cars.removeWhere((c) => c.id == car.id));
    try {
      await _repo.hideCar(car.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось скрыть объявление')),
        );
      }
    }
  }

  // «Не подходит город или регион» — скрыть все объявления города.
  // Оптимистично убираем из списка все карточки этого города.
  Future<void> _hideCity(CarModel car) async {
    if (!_requireAuth('Войдите, чтобы скрывать города')) return;
    setState(() => _cars.removeWhere((c) => c.city == car.city));
    try {
      await _repo.hideCity(car.city);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось скрыть город')),
        );
      }
    }
  }

  // Запрос одной страницы каталога с текущими фильтрами и параметрами круга.
  Future<List<CarModel>> _fetchPage({
    required int offset,
    required int limit,
    required bool shuffleAll,
  }) {
    return _repo.searchAdvanced(
      listingType: _listingType,
      brand: _filters.brand,
      model: _filters.model,
      city: _filters.city,
      yearFrom: _filters.yearFrom,
      yearTo: _filters.yearTo,
      mileageMax: _filters.mileageMax,
      priceFrom: _filters.priceFrom,
      priceTo: _filters.priceTo,
      bodyType: _filters.bodyType,
      transmission: _filters.transmission,
      fuel: _filters.fuel,
      seed: _lapSeed,
      offset: offset,
      limit: limit,
      shuffleAll: shuffleAll,
    );
  }

  // Загружает очередную страницу с учётом «крутилки»: если объявления
  // текущего круга кончились, тут же начинает новый (новый seed, offset=0,
  // полный шафл) и добирает страницу из него — без шва. За один вызов
  // начинаем максимум ОДИН новый круг (иначе на почти пустой выдаче —
  // вечный цикл запросов).
  Future<List<CarModel>> _fetchLoopedPage() async {
    final collected = <CarModel>[];
    var startedNewLap = false;

    while (collected.length < _pageSize) {
      final want = _pageSize - collected.length;
      final page = await _fetchPage(
        offset: _lapOffset,
        limit: want,
        shuffleAll: _looping,
      );

      // Двигаем серверный offset на реально отданное число строк.
      _lapOffset += page.length;

      // На стыке кругов последний элемент старого круга может совпасть
      // с ранним элементом нового — убираем дубль в пределах страницы.
      final seen = collected.map((c) => c.id).toSet();
      collected.addAll(page.where((c) => !seen.contains(c.id)));

      // Сервер отдал меньше, чем просили — круг исчерпан.
      if (page.length < want) {
        if (startedNewLap) break; // второй круг за вызов не начинаем
        startedNewLap = true;
        _looping = true;                       // со 2-го круга — полный шафл
        _lapSeed = _random.nextInt(_maxSeed);  // новый порядок круга
        _lapOffset = 0;
      }
    }

    return collected;
  }

  // Полная перезагрузка ленты с первого круга (новый seed, offset=0).
  // Вызывается при старте, смене типа сделки/фильтров и pull-to-refresh.
  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _lapSeed = _random.nextInt(_maxSeed);
      _lapOffset = 0;
      _looping = false;
      _hasMore = true;
    });
    try {
      final page = await _fetchLoopedPage();
      if (!mounted) return;
      setState(() {
        _cars = page;
        // Пусто даже после нового круга = по фильтру объявлений нет вовсе.
        _hasMore = page.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  // Подгрузка следующей страницы при скролле вниз (без сброса списка).
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _loading) return;
    _isLoadingMore = true;
    try {
      final page = await _fetchLoopedPage();
      if (!mounted) return;
      setState(() {
        _hasMore = page.isNotEmpty;
        _cars = [..._cars, ...page];
      });
    } catch (_) {
      // Молча: старые данные не теряем, следующий скролл повторит попытку.
    } finally {
      _isLoadingMore = false;
    }
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
      _filters = result;
      _reload();
    }
  }

  // Применить фильтры / сменить тип сделки — перезагрузка с первого круга
  void _apply() => _reload();

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

  // Рендер тела списка по состоянию: загрузка / ошибка / пусто / грид.
  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorState(message: _friendlyError(_error), onRetry: _apply);
    }
    // Пустой список = по фильтру объявлений нет вовсе (крутить нечего) —
    // единственный случай заглушки при бесконечной ленте.
    if (_cars.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('Пока нет объявлений по этому фильтру')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(5),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,      // 2 карточки в ряд
                mainAxisSpacing: 5,     // отступ между рядами
                crossAxisSpacing: 5,    // отступ между колонками
                childAspectRatio: 0.80, // пропорции карточки
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _CarCard(
                  car: _cars[i],
                  isFavorite: _favoriteIds.contains(_cars[i].id),
                  onToggleFavorite: () => _toggleFavorite(_cars[i].id),
                  onHide: () => _hideCar(_cars[i]),
                  onHideCity: () => _hideCity(_cars[i]),
                ),
                childCount: _cars.length,
              ),
            ),
          ),
          // Подвал: спиннер подгрузки следующего «круга»/страницы.
          if (_hasMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
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
          Expanded(child: _buildList()),
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
    required this.onHide,
    required this.onHideCity,
  });
  final CarModel car;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onHide;      // «Не интересует это объявление»
  final VoidCallback onHideCity;  // «Не подходит город или регион»

  // Километраж — отдельной строкой.
  String _mileageLine(CarModel c) =>
      c.mileage != null ? '${c.mileage} км' : '—';

  // Описание: кузов · КПП · топливо (что задано) — отдельной строкой.
  String _descLine(CarModel c) {
    final parts = <String>[
      if (c.bodyType != null) c.bodyType!.value,
      if (c.transmission != null) c.transmission!.value,
      if (c.fuel != null) c.fuel!.value,
    ];
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  // Меню «три точки» — «Скрыть рекомендацию» (как на Avito).
  void _openHideMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Скрыть рекомендацию',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            ListTile(
              title: const Text('Не интересует это объявление'),
              onTap: () {
                Navigator.pop(ctx);
                onHide();
              },
            ),
            ListTile(
              title: const Text('Не подходит город или регион'),
              onTap: () {
                Navigator.pop(ctx);
                onHideCity();
              },
            ),
          ],
        ),
      ),
    );
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
            // Фото на всю ширину (4:3). Сердечко и «три точки» перенесены
            // в текстовый блок ниже (как на Avito).
            AspectRatio(
              aspectRatio: 4 / 3,
              child: _CarThumb(carId: car.id),
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
                  // Заголовок + год (слева) и сердечко (справа) — как на Avito
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '${car.brand} ${car.model}, ${car.year}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      InkWell(
                        onTap: onToggleFavorite,
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 22,
                            color: isFavorite ? Colors.red : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Километраж — отдельной строкой
                  Text(
                    _mileageLine(car),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  // Описание (кузов · КПП · топливо) — отдельной строкой ниже
                  Text(
                    _descLine(car),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  // Прижимаем цену и город к низу карточки
                  const Spacer(),
                  const SizedBox(height: 4),
                  // Цена (слева, крупно) и «три точки» (справа) — под
                  // километражом/описанием, как просили
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          priceText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _openHideMenu(context),
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.more_horiz,
                              size: 22, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Город (+ рейтинг), мелко серым — последним
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
