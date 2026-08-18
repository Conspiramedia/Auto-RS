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
import '../../../core/theme/app_brand.dart';
import '../../../shared/widgets/status_badge.dart';
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
                  // Пустая витрина: иконка + причина по паттерну EmptyState.
                  // Действий не даём — это чужая витрина, сбрасывать
                  // пользователю тут нечего.
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppBrandSpacing.lg,
                      vertical: AppBrandSpacing.xl,
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.directions_car_outlined,
                          size: 48,
                          color: AppBrandColors.neutral30,
                        ),
                        const SizedBox(height: AppBrandSpacing.md),
                        Text(
                          t.dealerNoListings,
                          textAlign: TextAlign.center,
                          style: AppBrandText.body
                              .copyWith(color: AppBrandColors.neutral60),
                        ),
                      ],
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
    final image = profile.imageUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        children: [
          // Логотип салона (у частника — аватар). Квадрат со скруглением
          // для дилера читается как логотип, круг — как человек.
          ClipRRect(
            borderRadius:
                profile.isDealer ? AppBrandRadius.cardAll : AppBrandRadius.pillAll,
            child: SizedBox(
              width: 80,
              height: 80,
              child: image != null && image.isNotEmpty
                  ? Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.displayName,
            textAlign: TextAlign.center,
            style: AppBrandText.h3.copyWith(color: AppBrandColors.neutral100),
          ),
          if (profile.isDealer) ...[
            const SizedBox(height: 6),
            StatusBadge(
              label: t.carDealerBadge,
              background: AppBrandColors.gold,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            t.memberSince(_formatMonthYear(context, profile.memberSince)),
            style: AppBrandText.caption
                .copyWith(color: AppBrandColors.neutral60),
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

  Widget _placeholder() => Container(
        color: AppBrandColors.surfaceMuted,
        child: Icon(
          profile.isDealer ? Icons.storefront : Icons.person,
          size: 36,
          color: AppBrandColors.neutral40,
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
    return Column(
      children: [
        Text(
          '$value',
          style: AppBrandText.h2.copyWith(color: AppBrandColors.neutral100),
        ),
        Text(
          label,
          style: AppBrandText.caption
              .copyWith(color: AppBrandColors.neutral60),
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
        style: AppBrandText.h4.copyWith(color: AppBrandColors.neutral100),
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
    final price = item.price;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: AppBrandRadius.controlAll,
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
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    else
                      _placeholder(),
                    // Проданное притеняем — блок «недавно проданные» не
                    // должен выглядеть как актуальное предложение.
                    if (item.isSold)
                      Container(
                        color: AppBrandColors.surfaceOverlay,
                        alignment: Alignment.center,
                        child: Text(
                          t.carSold.toUpperCase(),
                          style: AppBrandText.small.copyWith(
                            color: Colors.white,
                            fontWeight: AppBrandFont.bold,
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
                          style: AppBrandText.body.copyWith(
                            color: AppBrandColors.neutral100,
                            fontWeight: AppBrandFont.semibold,
                          ),
                        ),
                      ),
                      if (item.isPromoted)
                        const Icon(Icons.rocket_launch,
                            size: 14, color: AppBrandColors.gold),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.mileage != null
                        ? '${item.city} · ${item.mileage} km'
                        : item.city,
                    style: AppBrandText.caption
                        .copyWith(color: AppBrandColors.neutral60),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price != null
                        ? '${price.toStringAsFixed(0)} ${item.currency}'
                        : t.commonNotSpecified,
                    style: AppBrandText.body.copyWith(
                      color: AppBrandColors.primary,
                      fontWeight: AppBrandFont.semibold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppBrandColors.surfaceMuted,
        child: const Icon(
          Icons.directions_car_outlined,
          color: AppBrandColors.neutral40,
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
