// ============================================================
// AUTO.RS — Экран «Избранное». Список закладок пользователя через
// VIEW favorites_with_car_details. Тап → детали авто; сердечко убирает
// из избранного.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/favorite_with_car_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/favorites_repository.dart';
import '../../../shared/utils/app_snack.dart';
import '../../../shared/widgets/app_search_header.dart';
import '../../../shared/widgets/pill_back_button.dart';

// Подсказки поиска по теме экрана «Избранное» (по сохранённым авто).
const List<String> _kFavoritesHints = [
  'Поиск в избранном',
  'Марка или модель',
  'Golf 7',
  'BMW 320d',
  'Kia Sportage',
  'По городу: Beograd',
  'Škoda Octavia',
  'Mercedes C klasa',
];

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _repo = FavoritesRepository();
  final _auth = AuthRepository();

  late Future<List<FavoriteWithCarModel>> _future;

  // Локальный поиск по избранному + язык (общая шапка).
  String _query = '';
  String _lang = 'sr';

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
        showAppSnack(context, 'Не удалось обновить избранное');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return Scaffold(
        appBar: AppBar(leading: const PillBackButton(), title: const Text('Избранное')),
        body: const Center(child: Text('Войдите, чтобы видеть избранное')),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Общая шапка: логотип + поиск (по избранному) + язык.
            AppSearchHeader(
              query: _query,
              onSearchChanged: (v) => setState(() => _query = v),
              lang: _lang,
              onLangChanged: (v) => setState(() => _lang = v),
              hints: _kFavoritesHints,
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
                    return Center(child: Text('${snapshot.error}'));
                  }
                  final all = snapshot.data ?? [];
                  final items = _filter(all);
                  if (items.isEmpty) {
                    // Разные тексты: совсем пусто vs ничего не нашлось по поиску.
                    final empty = all.isEmpty
                        ? 'В избранном пока пусто'
                        : 'Ничего не найдено';
                    return RefreshIndicator(
                      onRefresh: () async => _reload(),
                      child: ListView(
                        children: [
                          const SizedBox(height: 120),
                          Center(child: Text(empty)),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) => _FavCard(
                        fav: items[i],
                        onRemove: () => _remove(items[i].carId),
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

// Карточка избранного
class _FavCard extends StatelessWidget {
  const _FavCard({required this.fav, required this.onRemove});
  final FavoriteWithCarModel fav;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    // Цена по назначению
    final price = fav.isForRent && fav.rentPriceDaily != null
        ? '${fav.rentPriceDaily!.toStringAsFixed(0)} ${fav.currency.value}/сутки'
        : fav.salePrice != null
            ? '${fav.salePrice!.toStringAsFixed(0)} ${fav.currency.value}'
            : '—';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        onTap: () => context.push('/car/${fav.carId}'),
        leading: fav.carPhoto != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  fav.carPhoto!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.directions_car, size: 40),
                ),
              )
            : const CircleAvatar(child: Icon(Icons.directions_car)),
        title: Text('${fav.brand} ${fav.model}'
            '${fav.year != null ? ', ${fav.year}' : ''}'),
        subtitle: Text('${fav.city} · $price'),
        trailing: IconButton(
          icon: const Icon(Icons.favorite, color: Color(0xFFE01E23)),
          onPressed: onRemove,
        ),
      ),
    );
  }
}
