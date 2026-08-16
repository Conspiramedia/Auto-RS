// ============================================================
// AUTO.RS — Кабинет продавца: мои объявления со статистикой.
//
// Данные берём из RPC get_my_listings_stats (Пакет B + D): объявление,
// метрики (просмотры/избранное/контакты) и статус продвижения приходят
// ОДНИМ запросом — без доборов по каждой карточке.
//
// Действия: редактировать, дублировать, «Продано» (с подтверждением),
// «Продвинуть» (activate_promotion, режим «подарок» — денег не списывает).
//
// Просмотры считаются с дедупликацией (1 раз в сутки на пользователя), и
// собственные заходы владельца в них не попадают — цифра отражает реальный
// интерес, а не обновления экрана.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../data/models/car_model.dart';
import '../../../data/models/listing_stats_model.dart';
import '../../../data/repositories/cars_repository.dart';
import '../../../data/repositories/listing_stats_repository.dart';
import '../../../shared/utils/app_snack.dart';
import '../../../shared/widgets/app_button_colors.dart';
import '../../../shared/widgets/dark_pill_button.dart';
import '../../../shared/widgets/pill_back_button.dart';

class MyCarsScreen extends StatefulWidget {
  const MyCarsScreen({super.key});

  @override
  State<MyCarsScreen> createState() => _MyCarsScreenState();
}

class _MyCarsScreenState extends State<MyCarsScreen> {
  final _repo = CarsRepository();
  final _stats = ListingStatsRepository();

  late Future<_CabinetData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  // Список и итоги грузим параллельно: два независимых запроса, ждать их
  // последовательно незачем.
  Future<_CabinetData> _load() async {
    final results = await Future.wait([
      _stats.fetchMyListingsStats(),
      _stats.fetchTotals(),
    ]);
    return _CabinetData(
      listings: results[0] as List<ListingStatsModel>,
      totals: results[1] as ListingStatsTotals,
    );
  }

  void _reload() {
    setState(() => _future = _load());
  }

  // ----------------------------------------------------------
  // Действия по объявлению
  // ----------------------------------------------------------

  // Редактирование и дублирование работают с CarModel, а список отдаёт
  // ListingStatsModel (это разные контракты: у статистики нет фото, телефона
  // и описания). Поэтому перед переходом дочитываем полное объявление.
  Future<CarModel?> _fetchFullCar(String carId) async {
    try {
      return await _repo.fetchById(carId);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
      return null;
    }
  }

  Future<void> _edit(ListingStatsModel item) async {
    final car = await _fetchFullCar(item.carId);
    if (car == null || !mounted) return;

    final res = await context.push<String>('/edit-car', extra: car);
    if (res != null) _reload();
  }

  Future<void> _duplicate(ListingStatsModel item) async {
    final car = await _fetchFullCar(item.carId);
    if (car == null || !mounted) return;

    final res = await context.push<String>('/duplicate-car', extra: car);
    if (!mounted) return;
    if (res != null) {
      showAppSnack(context, context.t.duplicateSuccess, success: true);
      _reload();
    }
  }

  // «Продано»: объявление уходит из каталога, но остаётся доступным по
  // прямой ссылке с плашкой «Продано» (см. get_car_details).
  Future<void> _markSold(ListingStatsModel item) async {
    final t = context.t;

    final confirmed = await _confirm(
      title: t.markSoldTitle,
      body: t.markSoldBody,
      okLabel: t.actionMarkSold,
    );
    if (confirmed != true) return;

    try {
      await _repo.setCarStatus(item.carId, 'sold');
      if (!mounted) return;
      showAppSnack(context, t.markSoldSuccess, success: true);
      _reload();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  // «Продвинуть»: activate_promotion. На Этапе 0 это подарок — с баланса
  // ничего не списывается, поэтому в подтверждении так и написано.
  Future<void> _promote(ListingStatsModel item) async {
    final t = context.t;

    final confirmed = await _confirm(
      title: t.promoteTitle,
      body: t.promoteBody,
      okLabel: t.promoteConfirm,
    );
    if (confirmed != true) return;

    try {
      await _repo.activatePromotion(item.carId);
      if (!mounted) return;
      showAppSnack(context, t.promoteSuccess, success: true);
      _reload();
    } catch (e) {
      // Сервер сам проверяет владельца и статус — сюда попадут его
      // человекочитаемые сообщения («Продвигать можно только активное…»).
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String okLabel,
  }) {
    final t = context.t;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(okLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Scaffold(
      appBar: AppBar(
        leading: const PillBackButton(),
        title: Text(t.myCarsTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _AddButton(
              onTap: () async {
                final created = await context.push<String>('/create-car');
                if (created != null) _reload();
              },
            ),
          ),
        ],
      ),
      body: FutureBuilder<_CabinetData>(
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
          if (data.listings.isEmpty) {
            return _EmptyCabinet(
              onCreate: () async {
                final created = await context.push<String>('/create-car');
                if (created != null) _reload();
              },
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              // +1 — плашка итогов первой строкой.
              itemCount: data.listings.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return _TotalsCard(totals: data.totals);
                final item = data.listings[i - 1];
                return _ListingCard(
                  item: item,
                  onOpen: () => context.push('/car/${item.carId}'),
                  onEdit: () => _edit(item),
                  onDuplicate: () => _duplicate(item),
                  onSold: () => _markSold(item),
                  onPromote: () => _promote(item),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// Данные кабинета: список объявлений и суммарные метрики.
class _CabinetData {
  const _CabinetData({required this.listings, required this.totals});
  final List<ListingStatsModel> listings;
  final ListingStatsTotals totals;
}

// ============================================================
// Плашка итогов по всем объявлениям
// ============================================================
class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totals});
  final ListingStatsTotals totals;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _TotalItem(
            icon: Icons.visibility_outlined,
            value: totals.views,
            label: t.statsViews,
          ),
          _TotalItem(
            icon: Icons.favorite_border,
            value: totals.favorites,
            label: t.statsFavorites,
          ),
          _TotalItem(
            icon: Icons.phone_outlined,
            value: totals.contacts,
            label: t.statsContacts,
          ),
        ],
      ),
    );
  }
}

class _TotalItem extends StatelessWidget {
  const _TotalItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Карточка объявления со статистикой и действиями
// ============================================================
class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.item,
    required this.onOpen,
    required this.onEdit,
    required this.onDuplicate,
    required this.onSold,
    required this.onPromote,
  });

  final ListingStatsModel item;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onSold;
  final VoidCallback onPromote;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);

    final price = item.rentPriceDaily != null
        ? '${item.rentPriceDaily!.toStringAsFixed(0)} ${item.currency}'
        : item.salePrice != null
            ? '${item.salePrice!.toStringAsFixed(0)} ${item.currency}'
            : '—';

    // Редактировать имеет смысл у рабочих объявлений; проданное и архивное
    // правкой не возвращают — для них есть дублирование.
    final canEdit = item.status == 'active' ||
        item.status == 'moderation' ||
        item.status == 'rejected';
    // Продвигать и отмечать проданным — только активные (это же проверяет
    // и сервер; здесь просто не показываем заведомо недоступные действия).
    final isActive = item.isActive;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Превью объявления. Проданное притеняем и накрываем
                  // плашкой — статус виден с одного взгляда на список.
                  _Thumb(url: item.photoUrl, sold: item.isSold),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.brand} ${item.model}, ${item.year}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.city} · $price',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _StatusChip(status: item.status),
                            if (item.isPromoted) ...[
                              const SizedBox(width: 6),
                              const _PromotedChip(),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Строка метрик объявления.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                _Metric(
                  icon: Icons.visibility_outlined,
                  value: item.views,
                  label: t.statsViews,
                ),
                _Metric(
                  icon: Icons.favorite_border,
                  value: item.favorites,
                  label: t.statsFavorites,
                ),
                _Metric(
                  icon: Icons.phone_outlined,
                  value: item.contacts,
                  label: t.statsContacts,
                ),
              ],
            ),
          ),

          // Срок действия продвижения — рядом с кнопкой, чтобы было понятно,
          // до какого числа объявление стоит в начале каталога.
          if (item.isPromoted && item.boostedUntil != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.rocket_launch,
                      size: 14, color: AppButtonColors.green),
                  const SizedBox(width: 6),
                  Text(
                    t.promotedUntil(_formatDate(item.boostedUntil!)),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: AppButtonColors.green),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Продвижение — главное платное (пока подарочное) действие,
                // поэтому первое и зелёное. Уже продвигаемое объявление
                // продлевать можно, но кнопку не навязываем.
                if (isActive && !item.isPromoted) ...[
                  DarkPillButton(
                    label: t.actionPromote,
                    variant: PillVariant.green,
                    expand: true,
                    onTap: onPromote,
                  ),
                  const SizedBox(height: 8),
                ],
                if (canEdit) ...[
                  DarkPillButton(
                    label: t.actionEdit,
                    variant: PillVariant.blue,
                    expand: true,
                    onTap: onEdit,
                  ),
                  const SizedBox(height: 8),
                ],
                DarkPillButton(
                  label: t.actionDuplicate,
                  variant: PillVariant.dark,
                  expand: true,
                  onTap: onDuplicate,
                ),
                if (isActive) ...[
                  const SizedBox(height: 8),
                  DarkPillButton(
                    label: t.actionMarkSold,
                    variant: PillVariant.red,
                    expand: true,
                    onTap: onSold,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Короткая дата «23.08» — год не нужен, продвижение живёт не больше 30 дней.
  // Формат собираем вручную: пакет intl не содержит русской локали, и
  // DateFormat с 'ru' падает в рантайме. [[intl-no-russian-locale]]
  static String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d.$m';
  }
}

// Превью с плашкой «Продано».
class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.sold});
  final String? url;
  final bool sold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 96,
        height: 72,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url != null)
              Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(theme),
              )
            else
              _placeholder(theme),
            if (sold)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                alignment: Alignment.center,
                child: Text(
                  context.t.carSold.toUpperCase(),
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

// Одна метрика в строке карточки.
class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

// Чип статуса объявления. Подписи — из словарей (carStatus по коду из БД).
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'moderation' => Colors.orange,
      'active' => Colors.green,
      'rejected' => Colors.red,
      'archived' => Colors.blueGrey,
      'sold' => Colors.teal,
      _ => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        context.t.carStatus(status),
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// Значок «Продвигается».
class _PromotedChip extends StatelessWidget {
  const _PromotedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppButtonColors.gold,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.rocket_launch, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            context.t.catalogPromoted,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Пустой кабинет: одно понятное действие вместо строки текста.
class _EmptyCabinet extends StatelessWidget {
  const _EmptyCabinet({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 100, 32, 32),
      children: [
        Icon(
          Icons.directions_car_outlined,
          size: 64,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 16),
        Text(
          t.myCarsEmpty,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: Text(
              t.myCarsCreate,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(t.commonRetry)),
          ],
        ),
      ),
    );
  }
}

// Кнопка «+» в шапке: чёрный круг с белым плюсом — зеркало PillBackButton.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  static const Color _kDark = Color(0xFF2B2B2E);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: _kDark,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.add, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
