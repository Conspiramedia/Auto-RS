// ============================================================
// AUTO.RS — Экран «Избранное». Список закладок пользователя через
// VIEW favorites_with_car_details. Тап → детали авто; сердечко убирает
// из избранного.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../core/theme/app_brand.dart';
import '../../../data/models/favorite_with_car_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/favorites_repository.dart';
import '../../catalog/widgets/car_card.dart';
import '../../../shared/utils/app_snack.dart';
import '../../../shared/widgets/app_search_header.dart';
import '../../../shared/widgets/local_search_field.dart';
import '../../../shared/widgets/pill_back_button.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _repo = FavoritesRepository();
  final _auth = AuthRepository();

  late Future<List<FavoriteWithCarModel>> _future;

  // Локальный поиск по избранному (общая шапка).
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchMyFavorites();
  }

  // Фильтрация загруженного списка по тексту (марка/модель/город).
  List<FavoriteWithCarModel> _filter(List<FavoriteWithCarModel> items) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((f) {
      final hay =
          '${f.brand} ${f.model} ${f.city} ${f.year ?? ''}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  void _reload() {
    setState(() {
      _future = _repo.fetchMyFavorites();
    });
  }

  // Убрать из избранного (toggle вернёт false)
  Future<void> _remove(String carId) async {
    try {
      await _repo.toggle(carId);
      _reload();
    } catch (_) {
      if (mounted) {
        showAppSnack(context, context.t.catalogFavoriteFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return Scaffold(
        backgroundColor: AppBrandColors.bg,
        appBar: AppBar(
          leading: const PillBackButton(),
          title: Text(
            context.t.favoritesTitle,
            style: AppBrandText.h3.copyWith(color: AppBrandColors.neutral100),
          ),
        ),
        body: Center(
          child: Text(
            'Войдите, чтобы видеть избранное',
            style: AppBrandText.body
                .copyWith(color: AppBrandColors.neutral60),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppBrandColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const AppSearchHeader(),

            // Поиск по уже загруженным закладкам — локальный, на сервер
            // не ходит. Экрана фильтров у избранного нет, поэтому поле
            // остаётся здесь, в теле экрана.
            LocalSearchField(
              value: _query,
              onChanged: (v) => setState(() => _query = v),
              hint: context.t.filterSearchHint,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<FavoriteWithCarModel>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        '${snapshot.error}',
                        style: AppBrandText.body
                            .copyWith(color: AppBrandColors.neutral60),
                      ),
                    );
                  }
                  final all = snapshot.data ?? [];
                  final items = _filter(all);
                  if (items.isEmpty) {
                    return _EmptyFavorites(
                      // Совсем пусто и «ничего не нашлось по поиску» — разные
                      // состояния: в первом нужен путь в каталог, во втором
                      // достаточно сказать, что запрос ничего не дал.
                      isSearchResult: all.isNotEmpty,
                      onRefresh: () async => _reload(),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: _FavoritesGrid(
                      items: items,
                      onRemove: _remove,
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

// ============================================================
// СЕТКА ИЗБРАННОГО
// ============================================================
// Та же карточка и та же геометрия, что в каталоге: закладка — это то же
// объявление, и выглядеть оно должно одинаково. Раньше здесь был список
// ListTile с миниатюрой 56x56, из-за чего избранное не походило на выдачу.
class _FavoritesGrid extends StatelessWidget {
  const _FavoritesGrid({required this.items, required this.onRemove});

  final List<FavoriteWithCarModel> items;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Параметры сетки повторяют каталог: поля px-4 и зазор gap-4 сайта.
      const outerPad = AppBrandSpacing.md;
      const gap = AppBrandSpacing.md;
      const cols = 2;
      final cardW =
          (constraints.maxWidth - outerPad * 2 - gap * (cols - 1)) / cols;

      // Высота ячейки считается из шкалы и масштаба текста — тот же расчёт,
      // что в каталоге. Константа здесь означала бы overflow при крупном
      // системном шрифте.
      final scaler = MediaQuery.textScalerOf(context);
      final lineBody = scaler.scale(AppBrandText.body.fontSize!) *
          AppBrandText.body.height!;
      final lineCaption = scaler.scale(AppBrandText.caption.fontSize!) *
          AppBrandText.caption.height!;
      const blockPadding = 12.0 * 2;
      final extent =
          cardW * 3 / 4 + lineBody * 2 + lineCaption * 2 + blockPadding;

      return GridView.builder(
        padding: const EdgeInsets.all(outerPad),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          mainAxisExtent: extent,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final fav = items[i];
          return CarCard(
            car: fav.toCarModel(),
            // В избранном сердечко всегда активно — тап его снимает.
            isFavorite: true,
            isViewed: false,
            onOpen: () => context.push('/car/${fav.carId}'),
            onToggleFavorite: () => onRemove(fav.carId),
            // Фото уже пришло вместе с закладкой: карточка не пойдёт в сеть.
            photoUrl: fav.carPhoto,
          );
        },
      );
    });
  }
}

// ============================================================
// ПУСТОЕ ИЗБРАННОЕ
// ============================================================
// Паттерн EmptyState: причина + действие. Пустой экран без выхода —
// тупик, поэтому из совсем пустого избранного ведём в каталог.
class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites({
    required this.isSearchResult,
    required this.onRefresh,
  });

  final bool isSearchResult;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    // ListView, а не Column: RefreshIndicator требует прокручиваемого
    // потомка, иначе жест «потянуть вниз» на пустом экране не сработает.
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
        children: [
          Icon(
            isSearchResult ? Icons.search_off : Icons.favorite_border,
            size: 64,
            color: AppBrandColors.neutral30,
          ),
          const SizedBox(height: AppBrandSpacing.md),
          Text(
            isSearchResult ? t.catalogEmptyTitle : t.favoritesEmpty,
            textAlign: TextAlign.center,
            style: AppBrandText.h3.copyWith(color: AppBrandColors.neutral100),
          ),
          const SizedBox(height: AppBrandSpacing.sm),
          Text(
            isSearchResult ? t.catalogEmptyBody : t.favoritesEmptyBody,
            textAlign: TextAlign.center,
            style: AppBrandText.body
                .copyWith(color: AppBrandColors.neutral60),
          ),
          // Путь в каталог нужен только когда избранное пусто целиком:
          // при пустом поиске объявления есть, достаточно изменить запрос.
          if (!isSearchResult) ...[
            const SizedBox(height: AppBrandSpacing.lg),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: () => context.go('/catalog'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppBrandColors.green,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppBrandRadius.controlAll,
                  ),
                ),
                icon: const Icon(Icons.grid_view_outlined, size: 20),
                label: Text(
                  t.navCatalog,
                  style: AppBrandText.caption
                      .copyWith(fontWeight: AppBrandFont.semibold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
