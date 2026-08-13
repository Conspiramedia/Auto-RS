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

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _repo = FavoritesRepository();
  final _auth = AuthRepository();

  late Future<List<FavoriteWithCarModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchMyFavorites();
  }

  void _reload() => setState(() => _future = _repo.fetchMyFavorites());

  // Убрать из избранного (toggle вернёт false)
  Future<void> _remove(String carId) async {
    try {
      await _repo.toggle(carId);
      _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось обновить избранное')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Избранное')),
        body: const Center(child: Text('Войдите, чтобы видеть избранное')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Избранное')),
      body: FutureBuilder<List<FavoriteWithCarModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('В избранном пока пусто')),
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
