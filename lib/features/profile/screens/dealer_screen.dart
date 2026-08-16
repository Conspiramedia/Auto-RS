// ============================================================
// AUTO.RS — Страница дилера (витрина продавца).
//
// Открывается тапом по продавцу в карточке объявления. Доступна ГОСТЮ:
// человек может прийти по прямой ссылке из поиска или мессенджера, и
// требовать вход, чтобы посмотреть витрину салона, бессмысленно.
//
// Два блока объявлений:
//   1) активные — собственно витрина;
//   2) «недавно проданные» — социальное доказательство: видно, что салон
//      действительно продаёт, а не держит объявления годами.
//
// Данные: get_dealer_profile (шапка) + get_seller_listings (оба списка).
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../data/models/dealer_profile_model.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../shared/utils/app_snack.dart';
import '../../../shared/widgets/app_button_colors.dart';
import '../../../shared/widgets/pill_back_button.dart';

class DealerScreen extends StatefulWidget {
  const DealerScreen({super.key, required this.sellerId});

  final String sellerId;

  @override
  State<DealerScreen> createState() => _DealerScreenState();
}

class _DealerScreenState extends State<DealerScreen> {
  final _repo = ProfileRepository();

  late Future<_DealerData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // Шапка и оба списка грузятся параллельно — они независимы, и ждать их
  // последовательно значило бы утроить время открытия экрана.
  Future<_DealerData> _load() async {
    final results = await Future.wait([
      _repo.fetchDealerProfile(widget.sellerId),
      _repo.fetchSellerListings(widget.sellerId, status: 'active'),
      // Проданных показываем немного: это доказательство, а не витрина.
      _repo.fetchSellerListings(widget.sellerId, status: 'sold', limit: 6),
    ]);

    return _DealerData(
      profile: results[0] as DealerProfileModel?,
      active: results[1] as List<SellerListingModel>,
      sold: results[2] as List<SellerListingModel>,
    );
  }

  void _reload() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Scaffold(
      appBar: AppBar(
        leading: const PillBackButton(),
        title: Text(t.carSeller),
      ),
      body: FutureBuilder<_DealerData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorBody(
              message: humanizeError(snapshot.error),
              onRetry: _reload,
            );
          }

          final data = snapshot.data!;
          final profile = data.profile;

          // Профиль не найден (удалён или неверный id) — не показываем
          // пустую страницу-призрак.
          if (profile == null) {
            return Center(child: Text(t.commonError));
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _DealerHeader(profile: profile),

                // Витрина: активные объявления.
                if (data.active.isNotEmpty) ...[
                  _SectionTitle(title: t.carAllListings),
                  for (final item in data.active)
                    _ListingTile(
                      item: item,
                      onTap: () => context.push('/car/${item.id}'),
                    ),
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    child: Text(
                      t.dealerNoListings,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),

                // Социальное доказательство: недавно проданное.
                if (data.sold.isNotEmpty) ...[
                  _SectionTitle(title: t.dealerRecentlySold),
                  for (final item in data.sold)
                    _ListingTile(
                      item: item,
                      onTap: () => context.push('/car/${item.id}'),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DealerData {
  const _DealerData({
    required this.profile,
    required this.active,
    required this.sold,
  });

  final DealerProfileModel? profile;
  final List<SellerListingModel> active;
  final List<SellerListingModel> sold;
}

// ============================================================
// Шапка: логотип, название, «на площадке с…», счётчики
// ============================================================
class _DealerHeader extends StatelessWidget {
  const _DealerHeader({required this.profile});

  final DealerProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final image = profile.imageUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        children: [
          // Логотип салона (у частника — аватар). Квадрат со скруглением
          // для дилера читается как логотип, круг — как человек.
          ClipRRect(
            borderRadius:
                BorderRadius.circular(profile.isDealer ? 16 : 40),
            child: SizedBox(
              width: 80,
              height: 80,
              child: image != null && image.isNotEmpty
                  ? Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(theme),
                    )
                  : _placeholder(theme),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.displayName,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (profile.isDealer) ...[
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppButtonColors.gold,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                t.carDealerBadge,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            t.memberSince(_formatMonthYear(context, profile.memberSince)),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Counter(value: profile.activeCars, label: t.dealerActiveCars),
              const SizedBox(width: 32),
              _Counter(value: profile.soldCars, label: t.dealerSoldCars),
            ],
          ),
          const Divider(height: 32),
        ],
      ),
    );
  }

  Widget _placeholder(ThemeData theme) => Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          profile.isDealer ? Icons.storefront : Icons.person,
          size: 36,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );

  // «август 2025». Названия месяцев берём из словаря: пакет intl не содержит
  // русской локали, DateFormat с 'ru' падает в рантайме.
  // [[intl-no-russian-locale]]
  static String _formatMonthYear(BuildContext context, DateTime date) {
    final months = context.t.monthNames;
    final name = months[(date.month - 1).clamp(0, 11)];
    return '$name ${date.year}';
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          '$value',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ============================================================
// Строка объявления в витрине
// ============================================================
class _ListingTile extends StatelessWidget {
  const _ListingTile({required this.item, required this.onTap});

  final SellerListingModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final price = item.price;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 96,
                height: 72,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.photoUrl != null)
                      Image.network(
                        item.photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(theme),
                      )
                    else
                      _placeholder(theme),
                    // Проданное притеняем — блок «недавно проданные» не
                    // должен выглядеть как актуальное предложение.
                    if (item.isSold)
                      Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        alignment: Alignment.center,
                        child: Text(
                          t.carSold.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.brand} ${item.model}, ${item.year}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (item.isPromoted)
                        const Icon(Icons.rocket_launch,
                            size: 14, color: AppButtonColors.gold),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.mileage != null
                        ? '${item.city} · ${item.mileage} km'
                        : item.city,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price != null
                        ? '${price.toStringAsFixed(0)} ${item.currency}'
                        : t.commonNotSpecified,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) => Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.directions_car_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(context.t.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
