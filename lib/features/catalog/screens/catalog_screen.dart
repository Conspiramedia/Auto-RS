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
import '../../../data/repositories/viewed_cars_repository.dart';
import '../../../shared/widgets/dark_pill_button.dart';
import '../../../shared/widgets/metal_toggle.dart';
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
  // Локальный реестр просмотренных объявлений (плашка «Просмотрено»).
  final _viewed = ViewedCarsRepository.instance;

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

  // Видимость переключателя Prodaja/Najam: прячется при скролле вниз,
  // показывается при скролле вверх (накопленных ~50px).
  bool _toggleVisible = true;
  double _lastScrollPx = 0;   // позиция на прошлом событии
  double _scrollUpAccum = 0;  // сколько «вверх» накопили подряд

  // Язык интерфейса: 'sr' | 'ru'. Пока только UI-переключатель (переводы
  // строк подключим позже через локализацию).
  String _lang = 'sr';

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _reload();
    _loadFavorites();
    _loadViewed();
  }

  // Подтягиваем просмотренные id с диска и перерисовываем плашки.
  Future<void> _loadViewed() async {
    await _viewed.load();
    if (mounted) setState(() {});
  }

  // Открыть карточку объявления, затем пометить её просмотренной.
  // Метку ставим ПОСЛЕ возврата — «Просмотрено» появляется, когда
  // пользователь реально заходил в объявление и вернулся в каталог.
  Future<void> _openCar(CarModel car) async {
    await context.push('/car/${car.id}');
    final isNew = await _viewed.markViewed(car.id);
    if (isNew && mounted) setState(() {});
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Триггер подгрузки при приближении к концу списка + управление
  // видимостью переключателя Prodaja/Najam по направлению скролла.
  void _onScroll() {
    final px = _scrollCtrl.position.pixels;

    // Подгрузка следующей страницы у конца списка.
    if (px >= _scrollCtrl.position.maxScrollExtent - 600) {
      _loadMore();
    }

    final delta = px - _lastScrollPx;
    _lastScrollPx = px;

    if (delta > 0) {
      // Скролл ВНИЗ — прячем переключатель, сбрасываем счётчик «вверх».
      _scrollUpAccum = 0;
      if (_toggleVisible && px > 20) {
        setState(() => _toggleVisible = false);
      }
    } else if (delta < 0) {
      // Скролл ВВЕРХ — копим; после ~50px показываем переключатель.
      _scrollUpAccum += -delta;
      if (!_toggleVisible && (_scrollUpAccum >= 50 || px <= 0)) {
        setState(() => _toggleVisible = true);
      }
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
    // Высота карточки считается динамически от ширины экрана:
    //   фото (4:3 от ширины карточки) + текстовый блок + запас снизу.
    // Так на любом экране запас минимальный (~10px), без «пустоты».
    return LayoutBuilder(builder: (context, constraints) {
      const outerPad = 5.0;   // SliverPadding.all(5)
      const crossGap = 5.0;   // crossAxisSpacing
      const cols = 2;
      // Ширина одной карточки при 2 колонках.
      final cardW =
          (constraints.maxWidth - outerPad * 2 - crossGap * (cols - 1)) / cols;
      // Высота инфо-блока под фото: paddings(16) + название(40) + gaps(12)
      // + 3 мелкие строки(~16) + цена(~20) ≈ 140 (небольшой запас, чтобы при
      // особенностях шрифта не было overflow). + маленький запас снизу.
      const textBlockH = 140.0;
      const bottomPad = 8.0;
      final extent = cardW * 3 / 4 + textBlockH + bottomPad;

      return RefreshIndicator(
        onRefresh: _reload,
        child: CustomScrollView(
          controller: _scrollCtrl,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(outerPad),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: crossGap,
                  mainAxisExtent: extent, // точная высота вместо соотношения
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _CarCard(
                    car: _cars[i],
                    isFavorite: _favoriteIds.contains(_cars[i].id),
                    isViewed: _viewed.isViewed(_cars[i].id),
                    onOpen: () => _openCar(_cars[i]),
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar убран: логотип и поиск — в самом верху тела (SafeArea).
      // Создание объявления — центральная «+» в нижней навигации (home_shell).
      // «Брони» — кнопка в ряду с «Фильтры» ниже.
      body: SafeArea(
        child: Column(
        children: [
          // ФИКСИРОВАННАЯ шапка (не уезжает при скролле):
          // логотип + Filteri + Rezervacije + колокольчик.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Image.asset('assets/images/logo.png', height: 60),
                const SizedBox(width: 10),
                Expanded(
                  child: DarkPillButton(
                    icon: Icons.tune,
                    expand: true,
                    label: _filters.activeCount > 0
                        ? 'Filteri (${_filters.activeCount})'
                        : 'Filteri',
                    onTap: _openFilters,
                  ),
                ),
                const SizedBox(width: 10),
                // Rezervacije — только иконка календаря (без текста, компактно)
                _IconPillButton(
                  icon: Icons.calendar_month_outlined,
                  tooltip: 'Rezervacije',
                  onTap: () => context.push('/bookings'),
                ),
                const SizedBox(width: 8),
                // Переключатель языка RU / SR
                _LangToggle(
                  value: _lang,
                  onChanged: (v) => setState(() => _lang = v),
                ),
                if (_auth.currentUser != null) const _NotifBell(),
              ],
            ),
          ),

          // Переключатель Prodaja/Najam — на всю ширину карточек, прячется
          // при скролле вниз и выезжает при скролле вверх (~50px).
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _toggleVisible
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(5, 10, 5, 6),
                    child: MetalToggle(
                      value: _listingType,
                      segments: const [('sale', 'Prodaja'), ('rent', 'Najam')],
                      onChanged: (v) {
                        setState(() => _listingType = v);
                        _apply();
                      },
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),

          // Список результатов
          Expanded(child: _buildList()),
        ],
        ),
      ),
    );
  }
}

// ============================================================
// Элементы шапки в стиле макета (золотой акцент + металлик)
// ============================================================

// Бренд-красный (активные сердечки, колокольчик с уведомлениями)
const Color _kRed = Color(0xFFE01E23);
// Квадратная кнопка-иконка (только иконка, без текста) — светлая с обводкой.
class _IconPillButton extends StatelessWidget {
  const _IconPillButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(16));
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius,
          border: Border.all(color: const Color(0xFF2B2B2E), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: 52,
                height: 49, // как у остальных плашек (52 − 2×1.5 рамки)
                child: Icon(icon, color: const Color(0xFF2B2B2E), size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Кнопка-тумблер языка: показывает текущий (RS/RU), по тапу переключает.
// Первая буква R — бренд-красная, вторая (S/U) — белая, фон тёмный.
class _LangToggle extends StatelessWidget {
  const _LangToggle({required this.value, required this.onChanged});
  final String value; // 'sr' | 'ru'
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(16));
    // Показываем текущий язык; тап переключает на другой.
    final isSr = value == 'sr';
    final second = isSr ? 'S' : 'U'; // RS — сербский, RU — русский
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF2B2B2E),
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(isSr ? 'ru' : 'sr'),
            child: SizedBox(
              width: 52,
              height: 49,
              child: Center(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    children: [
                      const TextSpan(
                        text: 'R',
                        style: TextStyle(color: _kRed),
                      ),
                      TextSpan(
                        text: second,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
    required this.isViewed,
    required this.onOpen,
    required this.onToggleFavorite,
    required this.onHide,
    required this.onHideCity,
  });
  final CarModel car;
  final bool isFavorite;
  final bool isViewed;            // true → показываем плашку «Просмотрено»
  final VoidCallback onOpen;      // открыть карточку (и пометить просмотренной)
  final VoidCallback onToggleFavorite;
  final VoidCallback onHide;      // «Не интересует это объявление»
  final VoidCallback onHideCity;  // «Не подходит город или регион»

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

  // Километраж — отдельной строкой.
  String _mileageLine(CarModel c) =>
      c.mileage != null ? '${_money(c.mileage!)} км' : '—';

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
    // Показываем цену по типу назначения. Нет цены → «Договорная».
    // Сумма форматируется с разделителем разрядов: «1 000».
    final priceText = car.isForRent && car.rentPriceDaily != null
        ? '${_money(car.rentPriceDaily!)} ${car.currency.value}/сутки'
        : car.salePrice != null
            ? '${_money(car.salePrice!)} ${car.currency.value}'
            : 'Договорная';

    // Рейтинг в подзаголовке (если есть отзывы)
    final rating = car.reviewsCount > 0
        ? ' · ⭐ ${car.ratingAvg.toStringAsFixed(1)}'
        : '';

    return InkWell(
      onTap: onOpen,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(3), // радиус 3px
          // Тонкая серая обводка, чтобы карточка не сливалась с фоном
          border: Border.all(color: const Color(0xFFCCCCCC)),
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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CarThumb(carId: car.id),
                  // Плашка «Просмотрено» в левом верхнем углу фото —
                  // тёмная полупрозрачная, как на Avito.
                  if (isViewed)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Просмотрено',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
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
                  // Заголовок + год (слева) и сердечко (справа) — как на Avito.
                  // Высота фиксирована под 2 строки ВСЕГДА: даже если название
                  // в одну строку, место под вторую резервируется — тогда
                  // километраж/цена/город у всех карточек на одном уровне.
                  SizedBox(
                    height: 40,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${car.brand} ${car.model}, ${car.year}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: onToggleFavorite,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 22,
                              color: isFavorite ? _kRed : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
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
    // Плейсхолдер на всю область (фото нет или ещё грузится) — логотип Auto.RS.
    // cover — заполняет область как реальное фото, без полей по краям, чтобы
    // карточка-заглушка выглядела так же, как карточка с фото-логотипом.
    final placeholder = Container(
      color: const Color(0xFFFFFFFF),
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
        final hasUnread = unread > 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              // Есть непрочитанные — красный залитый колокольчик, иначе обычный.
              icon: Icon(
                hasUnread ? Icons.notifications : Icons.notifications_none,
                color: hasUnread ? _kRed : null,
              ),
              tooltip: 'Уведомления',
              onPressed: () => context.push('/notifications'),
            ),
            // Красный бэйдж с числом (если есть непрочитанные)
            if (hasUnread)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: _kRed,
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
