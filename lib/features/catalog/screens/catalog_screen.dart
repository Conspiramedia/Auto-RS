// ============================================================
// AUTO.RS — Экран каталога. Список активных объявлений через
// серверную RPC search_cars_advanced (фильтр по типу + поиск).
// ============================================================

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/car_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../core/i18n/app_strings.dart';
import '../../../core/theme/app_brand.dart';
import '../../../data/repositories/cars_repository.dart';
import '../../../data/repositories/favorites_repository.dart';
import '../../../data/repositories/saved_searches_repository.dart';
import '../../../data/repositories/viewed_cars_repository.dart';
import '../../onboarding/screens/onboarding_screen.dart';
import '../../onboarding/widgets/push_permission_sheet.dart';
import '../../../shared/utils/app_snack.dart';
import '../../../shared/widgets/app_search_header.dart';
import '../models/car_filters.dart';
import '../widgets/car_card.dart';
import '../widgets/catalog_empty_state.dart';
import '../widgets/filter_chips_bar.dart';
import 'filters_screen.dart';
import '../../../shared/widgets/app_close_button.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _repo = CarsRepository();
  final _favRepo = FavoritesRepository();
  final _auth = AuthRepository();
  final _searchesRepo = SavedSearchesRepository();

  // Подписка на смену состояния авторизации: нужна, чтобы создать
  // отложенные подписки гостя сразу после входа.
  StreamSubscription<dynamic>? _authSub;
  // Локальный реестр просмотренных объявлений (плашка «Просмотрено»).
  final _viewed = ViewedCarsRepository.instance;

  // Выбранные фильтры (город, марка, год, пробег, цена, ТИП объявления).
  // Тип объявления теперь тоже часть фильтров (_filters.listingType):
  // отдельного переключателя Prodaja/Najam в каталоге больше нет — лента
  // показывает продажу и аренду вперемешку, а тип выбирается в фильтрах.
  CarFilters _filters = CarFilters.empty;

  // Порядок выдачи (p_sort, миграция 0061). Значения и подписи совпадают
  // с SORT_OPTIONS сайта.
  String _sort = 'fresh';

  // Общее количество объявлений под фильтрами (RPC get_search_total_count).
  // null — ещё не получено или запрос не удался: строку «Найдено» не рисуем.
  int? _totalCount;

  // Поколение запроса счётчика: защищает от гонки, когда ответ на старые
  // фильтры приходит позже нового запроса.
  int _countGeneration = 0;

  // Текстовый запрос из строки поиска (двуалфавитный поиск на бэке).
  // Пустая строка = поиск не задан. Применяется с дебаунсом.
  String _query = '';
  Timer? _searchDebounce;

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
    _loadViewed();
    _applyPendingSearches();

    // Вход мог произойти уже после открытия каталога (гость нажал
    // «Сообщить, когда появится» или открыл защищённый экран). Тогда
    // отложенные подписки нужно создать в момент авторизации.
    _authSub = _auth.authStateChanges.listen((_) {
      if (_auth.currentUser != null) _applyPendingSearches();
    });
  }

  // Отложенные подписки гостя из онбординга.
  //
  // Вызывается в ДВУХ случаях: при старте приложения (гость прошёл онбординг,
  // вошёл, но закрыл приложение до применения) и при входе внутри сессии.
  // Оба пути ведут сюда, чтобы логика не разъезжалась по экранам.
  //
  // Порядок проверок важен: сначала дешёвая проверка диска, и только потом
  // обращение к сети — на обычном запуске применять нечего.
  Future<void> _applyPendingSearches() async {
    if (_auth.currentUser == null) return;
    if (!await OnboardingPrefs.hasPending()) return;

    final applied = await OnboardingPrefs.applyPending(_searchesRepo);
    if (!applied || !mounted) return;

    // Снэкбар только когда реально что-то применили — молчаливые вызовы
    // при каждом запуске ничего не сообщают.
    showAppSnack(context, context.t.onboardingSearchesEnabled, success: true);
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
    _searchDebounce?.cancel();
    _authSub?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Триггер подгрузки при приближении к концу списка.
  void _onScroll() {
    final px = _scrollCtrl.position.pixels;

    // Подгрузка следующей страницы у конца списка.
    if (px >= _scrollCtrl.position.maxScrollExtent - 600) {
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
      showAppSnack(context, context.t.authRequiredFavorite);
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

      // Запасной запрос разрешения на пуши — для тех, кто пропустил
      // онбординг. Спрашиваем только при ДОБАВЛЕНИИ (nowFav): при снятии
      // сердечка предлагать уведомления бессмысленно.
      //
      // Момент подходящий: по избранному приходят уведомления о снижении
      // цены, то есть разрешение здесь напрямую связано с только что
      // совершённым действием. Повторов не будет — внутри проверяется
      // wasPushAsked.
      if (nowFav && mounted) await maybeAskPushPermission(context);
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
        showAppSnack(context, context.t.catalogFavoriteFailed);
      }
    }
  }

  // Проверка авторизации для действий, требующих аккаунта.
  bool _requireAuth(String message) {
    if (_auth.currentUser != null) return true;
    showAppSnack(context, message);
    return false;
  }

  // «Не интересует это объявление» — скрыть конкретную карточку.
  // Оптимистично убираем из списка, затем сохраняем на сервере.
  Future<void> _hideCar(CarModel car) async {
    if (!_requireAuth(context.t.authRequiredHide)) return;
    setState(() => _cars.removeWhere((c) => c.id == car.id));
    try {
      await _repo.hideCar(car.id);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, context.t.catalogHideCarFailed);
      }
    }
  }

  // «Не подходит город или регион» — скрыть все объявления города.
  // Оптимистично убираем из списка все карточки этого города.
  Future<void> _hideCity(CarModel car) async {
    if (!_requireAuth(context.t.authRequiredHide)) return;
    setState(() => _cars.removeWhere((c) => c.city == car.city));
    try {
      await _repo.hideCity(car.city);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, context.t.catalogHideCityFailed);
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
      listingType: _filters.listingType,
      // Пустую строку не шлём — иначе бэк будет искать по «».
      query: _query.trim().isEmpty ? null : _query.trim(),
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
      sort: _sort,
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
      // Прежнее число прячем сразу: показывать счёт от старых фильтров
      // рядом с новой выдачей — хуже, чем не показывать ничего.
      _totalCount = null;
    });
    try {
      final page = await _fetchLoopedPage();
      if (!mounted) return;
      setState(() {
        _cars = page;
        // Лента «бесконечна» только если объявлений хватает на полную
        // страницу. Если пришло меньше _pageSize — это ВСЕ объявления по
        // фильтру, крутить по кругу нечего: спиннер подгрузки не показываем
        // (иначе он висел бы вечно при 1–2 объявлениях).
        _hasMore = page.length >= _pageSize;
        _loading = false;
      });
      // Счётчик — только здесь, при смене фильтров. В _loadMore его нет:
      // подгрузка страницы общее количество не меняет, а count(*) по всей
      // выборке на каждую прокрутку был бы лишней нагрузкой.
      _loadTotalCount();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  // Общее количество под текущими фильтрами. Отдельным запросом и без await
  // в _reload: список не должен ждать счётчик, чтобы появиться на экране.
  Future<void> _loadTotalCount() async {
    // Номер поколения. Пока RPC отвечает, пользователь может успеть сменить
    // фильтр и запустить новый _reload — тогда пришедшее число относится к
    // прошлым фильтрам, и показывать его нельзя.
    final generation = ++_countGeneration;
    final filters = _filters;
    final query = _query.trim();

    try {
      final total = await _repo.searchTotalCount(
        listingType: filters.listingType,
        query: query.isEmpty ? null : query,
        brand: filters.brand,
        model: filters.model,
        city: filters.city,
        yearFrom: filters.yearFrom,
        yearTo: filters.yearTo,
        mileageMax: filters.mileageMax,
        priceFrom: filters.priceFrom,
        priceTo: filters.priceTo,
        bodyType: filters.bodyType,
        transmission: filters.transmission,
        fuel: filters.fuel,
      );
      if (!mounted || generation != _countGeneration) return;
      setState(() => _totalCount = total);
    } catch (_) {
      // Счётчик не критичен: при сбое строка просто не показывается,
      // выдача от этого не страдает.
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
        // Меньше полной страницы — дальше крутить нечего, лента исчерпана.
        _hasMore = page.length >= _pageSize;
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
    // Экран фильтров возвращает и условия отбора, и строку поиска: с
    // переносом поиска в форму фильтров это одно действие пользователя.
    final result = await Navigator.push<FiltersResult>(
      context,
      MaterialPageRoute(
        builder: (_) => FiltersScreen(
          initial: _filters,
          initialQuery: _query,
        ),
      ),
    );
    if (result != null) {
      // Дебаунс поиска больше не нужен — запрос пришёл готовым.
      _searchDebounce?.cancel();
      _filters = result.filters;
      _query = result.query;
      _reload();
    }
  }

  // Снять один фильтр по тапу на «×» в чипсе.
  void _removeFilter(CarFilterKind kind) {
    setState(() => _filters = _filters.removeFilter(kind));
    _reload();
  }

  // Сбросить все фильтры и поисковую строку разом — действие из пустого
  // состояния. Поиск живёт в форме фильтров, поэтому чистим оба поля
  // здесь: следующее открытие фильтров получит уже пустой запрос.
  void _resetFilters() {
    // Отменяем висящий дебаунс: иначе он через 400 мс вернул бы старый
    // запрос обратно в _query и сброс отменился бы сам собой.
    _searchDebounce?.cancel();
    setState(() {
      _filters = CarFilters.empty;
      _query = '';
    });
    _reload();
  }

  // Приводим технические ошибки к понятному пользователю виду.
  // «Failed to fetch» / таймаут обычно = нет связи или сервер «просыпается».
  String _friendlyError(Object? e) {
    final s = e?.toString() ?? '';
    if (s.contains('Failed to fetch') ||
        s.contains('SocketException') ||
        s.contains('timeout') ||
        s.contains('Connection')) {
      return context.t.catalogNoConnection;
    }
    return context.t.catalogLoadError;
  }

  // Рендер тела списка по состоянию: загрузка / ошибка / пусто / грид.
  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorState(message: _friendlyError(_error), onRetry: _reload);
    }
    // Пустой список = по фильтру объявлений нет вовсе (крутить нечего) —
    // единственный случай заглушки при бесконечной ленте. Вместо тупика
    // предлагаем действия: подписаться на поиск или сбросить фильтры.
    if (_cars.isEmpty) {
      return CatalogEmptyState(
        filters: _filters,
        query: _query,
        onResetFilters: _resetFilters,
        onRefresh: _reload,
      );
    }
    // Высота карточки считается динамически: фото 4:3 от ширины карточки
    // плюс фактическая высота текстового блока.
    //
    // Раньше высота текста была константой 140, подобранной на глаз. При
    // другом системном масштабе текста контент переставал помещаться —
    // отсюда «BOTTOM OVERFLOWED BY 2.5 PIXELS». Теперь блок считается из
    // самих токенов и множителя textScaler, поэтому сходится при любом
    // размере шрифта, а сама карточка ужимает фото, если места всё же мало.
    return LayoutBuilder(builder: (context, constraints) {
      // Поля страницы и зазор между карточками — как на сайте: там
      // контейнер каталога имеет px-4, а сетка gap-4, то есть 16 и там,
      // и там. В приложении раньше стояло 5px: карточки лепились друг к
      // другу и к краям экрана, а на сайте дышали.
      const outerPad = AppBrandSpacing.md;   // = 16, px-4 контейнера
      const crossGap = AppBrandSpacing.md;   // = 16, gap-4 сетки
      const cols = 2;
      // Ширина одной карточки при 2 колонках.
      final cardW =
          (constraints.maxWidth - outerPad * 2 - crossGap * (cols - 1)) / cols;

      // Четыре строки текста: заголовок (body), цена (body), мета и город
      // (caption). Высоты берём из шкалы бренда — те же стили стоят в
      // CarCard, поэтому расчёт и разметка не разъезжаются.
      final scaler = MediaQuery.textScalerOf(context);
      final lineBody = scaler.scale(AppBrandText.body.fontSize!) *
          AppBrandText.body.height!;
      final lineCaption = scaler.scale(AppBrandText.caption.fontSize!) *
          AppBrandText.caption.height!;
      // Вертикальные отступы блока: padding 12 сверху и снизу — то же
      // значение, что стоит в CarCard (p-3 сайта). Разъедутся эти числа —
      // вернётся переполнение ячейки.
      const blockPadding = 12.0 * 2;
      final textBlockH = lineBody * 2 + lineCaption * 2 + blockPadding;

      final extent = cardW * 3 / 4 + textBlockH;

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
                  mainAxisSpacing: crossGap,
                  crossAxisSpacing: crossGap,
                  mainAxisExtent: extent, // точная высота вместо соотношения
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => CarCard(
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
      backgroundColor: AppBrandColors.bg,
      // AppBar убран: логотип и поиск — в самом верху тела (SafeArea).
      // Создание объявления — центральная «+» в нижней навигации (home_shell).
      body: SafeArea(
        child: Column(
        children: [
          // ФИКСИРОВАННАЯ шапка (не уезжает при скролле). Тот же
          // AppSearchHeader, что в Избранном и Сообщениях.
          const AppSearchHeader(),

          // Заголовок раздела — h1 сайта («Автомобили в Сербии»).
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppBrandSpacing.md,
              AppBrandSpacing.md,
              AppBrandSpacing.md,
              0,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.t.catalogTitle,
                style: AppBrandText.h2
                    .copyWith(color: AppBrandColors.neutral100),
              ),
            ),
          ),

          // Ряд управления выдачей — как на сайте под заголовком раздела:
          // тёмная кнопка «Фильтры» со значком регуляторов и счётчиком
          // применённых условий. Свободный поиск живёт внутри этой формы.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppBrandSpacing.md,
              AppBrandSpacing.md,
              AppBrandSpacing.md,
              0,
            ),
            child: Row(
              children: [
                _FiltersButton(
                  count: _filters.activeCount,
                  onTap: _openFilters,
                ),
                const Spacer(),
                // Порядок выдачи — справа, как на сайте.
                _SortSelect(
                  value: _sort,
                  onChanged: (v) {
                    if (v == _sort) return;
                    setState(() => _sort = v);
                    _reload();
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Применённые фильтры чипсами. Показывают СОСТАВ фильтра (бейдж с
          // числом на кнопке говорит только «их три»), тап по × снимает
          // фильтр без открытия экрана фильтров.
          FilterChipsBar(
            filters: _filters,
            onRemove: _removeFilter,
            onClearAll: _resetFilters,
          ),

          // «Найдено: N» — сколько объявлений подходит под фильтры целиком,
          // а не сколько уже подгружено лентой. Формулировка и место — как
          // на сайте. Показывается только когда число получено (RPC могла
          // не ответить — тогда строки просто нет).
          if (_totalCount != null && !_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppBrandSpacing.md,
                AppBrandSpacing.sm,
                AppBrandSpacing.md,
                AppBrandSpacing.xs,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.t.foundCount(_totalCount!),
                  style: AppBrandText.caption
                      .copyWith(color: AppBrandColors.neutral60),
                ),
              ),
            ),

          // Список результатов (продажа и аренда вперемешку; тип — в фильтрах)
          Expanded(child: _buildList()),
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
            FilledButton(onPressed: onRetry, child: Text(context.t.commonRetry)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// КНОПКА «ФИЛЬТРЫ»
// ============================================================
// Копия кнопки с сайта: тёмная плашка, подпись, значок регуляторов
// справа от текста и счётчик применённых условий золотым.
class _FiltersButton extends StatelessWidget {
  const _FiltersButton({required this.count, required this.onTap});

  /// Сколько фильтров применено. 0 — счётчик не показывается.
  final int count;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppBrandColors.dark,
      borderRadius: AppBrandRadius.controlAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppBrandRadius.controlAll,
        child: Container(
          // Высота 40 — та же, что у селекта сортировки рядом. На сайте
          // кнопка и поле выровнены по общей высоте, иначе разница в
          // пару пикселей бросается в глаза.
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: AppBrandSpacing.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.t.catalogFilters,
                style: AppBrandText.caption.copyWith(
                  color: Colors.white,
                  fontWeight: AppBrandFont.semibold,
                ),
              ),
              const SizedBox(width: AppBrandSpacing.sm),
              // Значок регуляторов — справа от подписи, как на сайте.
              const Icon(Icons.tune, size: 16, color: Colors.white),
              if (count > 0) ...[
                const SizedBox(width: AppBrandSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppBrandSpacing.sm,
                    vertical: 1,
                  ),
                  decoration: const BoxDecoration(
                    color: AppBrandColors.gold,
                    borderRadius: AppBrandRadius.pillAll,
                  ),
                  child: Text(
                    '$count',
                    style: AppBrandText.small.copyWith(
                      color: Colors.white,
                      fontWeight: AppBrandFont.semibold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ВЫБОР ПОРЯДКА ВЫДАЧИ
// ============================================================
// Копия SortSelect сайта: поле с рамкой neutral15 и стрелкой, по тапу —
// список вариантов. Высота 40 — ровно как у кнопки «Фильтры» рядом:
// на сайте они тоже выровнены по общей высоте.
class _SortSelect extends StatelessWidget {
  const _SortSelect({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  // Ключи 1:1 с SORT_OPTIONS сайта — и в URL сайта, и в p_sort уходит
  // одна и та же строка.
  static List<(String, String)> _options(BuildContext context) {
    final t = context.t;
    return [
      ('fresh', t.sortFresh),
      ('price_asc', t.sortPriceAsc),
      ('price_desc', t.sortPriceDesc),
      ('year_desc', t.sortYearDesc),
      ('year_asc', t.sortYearAsc),
      ('mileage_asc', t.sortMileageAsc),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final options = _options(context);
    final current = options.firstWhere(
      (o) => o.$1 == value,
      orElse: () => options.first,
    );

    return Material(
      color: AppBrandColors.bg,
      borderRadius: AppBrandRadius.controlAll,
      child: InkWell(
        onTap: () => _pick(context, options),
        borderRadius: AppBrandRadius.controlAll,
        child: Container(
          height: 40,
          // Ширина ограничена: шесть подписей разной длины не должны
          // растягивать ряд и выдавливать кнопку фильтров.
          constraints: const BoxConstraints(maxWidth: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: AppBrandRadius.controlAll,
            border: Border.all(color: AppBrandColors.neutral15),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  current.$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppBrandText.caption
                      .copyWith(color: AppBrandColors.neutral100),
                ),
              ),
              const SizedBox(width: AppBrandSpacing.xs),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: AppBrandColors.neutral60,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pick(
    BuildContext context,
    List<(String, String)> options,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppBrandColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppBrandRadius.card),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppBrandSpacing.lg,
                AppBrandSpacing.md,
                AppBrandSpacing.lg,
                AppBrandSpacing.sm,
              ),
              // Заголовок и крестик в одной строке: у листа обязано
              // быть видимое действие закрытия, а не только свайп.
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ctx.t.catalogSort,
                      style: AppBrandText.h4
                          .copyWith(color: AppBrandColors.neutral100),
                    ),
                  ),
                  AppCloseButton(
                    tooltip: ctx.t.commonClose,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            for (final (key, label) in options)
              ListTile(
                onTap: () => Navigator.pop(ctx, key),
                title: Text(
                  label,
                  style: AppBrandText.body.copyWith(
                    color: AppBrandColors.neutral100,
                    fontWeight: key == value
                        ? AppBrandFont.semibold
                        : AppBrandFont.regular,
                  ),
                ),
                trailing: key == value
                    ? const Icon(Icons.check, color: AppBrandColors.green)
                    : null,
              ),
            const SizedBox(height: AppBrandSpacing.sm),
          ],
        ),
      ),
    );

    if (picked != null) onChanged(picked);
  }
}
