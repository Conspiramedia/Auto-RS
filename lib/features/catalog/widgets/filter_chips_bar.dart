// ============================================================
// AUTO.RS — Строка применённых фильтров над выдачей каталога.
//
// Зачем: с закрытым экраном фильтров пользователь не видит, ПОЧЕМУ в
// каталоге мало объявлений. Бейджа с числом на кнопке «Фильтры» мало —
// он говорит «их три», но не какие именно. Чипсы показывают состав и
// позволяют снять лишнее одним тапом, не открывая экран фильтров.
//
// Год и цена — одним чипсом-диапазоном: «2015–2020», «до 10000 EUR».
// Снимать половину диапазона по тапу на × пользователь не ожидает.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/i18n/app_strings.dart';
import '../../../core/theme/app_brand.dart';
import '../models/car_filters.dart';

class FilterChipsBar extends StatelessWidget {
  const FilterChipsBar({
    super.key,
    required this.filters,
    required this.onRemove,
    required this.onClearAll,
  });

  final CarFilters filters;
  final ValueChanged<CarFilterKind> onRemove;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final items = _buildItems(context);

    // Фильтров нет — строка не занимает место.
    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        // +1 — кнопка «Сбросить» в хвосте, когда фильтров больше одного:
        // снимать их по одному дольше, чем сбросить все разом.
        itemCount: items.length + (items.length > 1 ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          if (i == items.length) {
            return Center(
              child: TextButton(
                onPressed: onClearAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppBrandSpacing.sm),
                  // Сброс — деструктивное действие, красный из бренда.
                  foregroundColor: AppBrandColors.red,
                ),
                child: Text(
                  t.catalogFiltersReset,
                  style: AppBrandText.caption
                      .copyWith(fontWeight: AppBrandFont.medium),
                ),
              ),
            );
          }

          final item = items[i];
          return Center(
            child: _FilterChip(
              label: item.label,
              onRemove: () => onRemove(item.kind),
            ),
          );
        },
      ),
    );
  }

  // Собираем подписи применённых фильтров. Порядок фиксирован и совпадает
  // с порядком полей на экране фильтров — так чипсы не «прыгают» между
  // перерисовками и их легче соотнести с формой.
  List<_ChipItem> _buildItems(BuildContext context) {
    final t = context.t;
    final items = <_ChipItem>[];

    if (filters.listingType != null) {
      items.add(_ChipItem(
        CarFilterKind.listingType,
        filters.listingType == 'rent' ? t.filterRent : t.filterSale,
      ));
    }
    if (filters.brand != null) {
      items.add(_ChipItem(CarFilterKind.brand, filters.brand!));
    }
    if (filters.model != null) {
      items.add(_ChipItem(CarFilterKind.model, filters.model!));
    }
    if (filters.city != null) {
      items.add(_ChipItem(CarFilterKind.city, filters.city!));
    }

    // Год: «2015–2020», «от 2015», «до 2020».
    final yearLabel = _range(
      context,
      from: filters.yearFrom?.toString(),
      to: filters.yearTo?.toString(),
    );
    if (yearLabel != null) {
      items.add(_ChipItem(CarFilterKind.year, yearLabel));
    }

    if (filters.mileageMax != null) {
      items.add(_ChipItem(
        CarFilterKind.mileage,
        '${t.commonUpTo} ${filters.mileageMax} km',
      ));
    }

    // Цена: суммы округляем до целых — копейки в чипсе только мешают.
    final priceLabel = _range(
      context,
      from: filters.priceFrom?.toStringAsFixed(0),
      to: filters.priceTo?.toStringAsFixed(0),
      suffix: 'EUR',
    );
    if (priceLabel != null) {
      items.add(_ChipItem(CarFilterKind.price, priceLabel));
    }

    // Характеристики: показываем человекочитаемую подпись из справочника,
    // а не код enum ('sedan' → «Седан»).
    if (filters.bodyType != null) {
      items.add(_ChipItem(
        CarFilterKind.bodyType,
        t.bodyTypeLabel(filters.bodyType!),
      ));
    }
    if (filters.transmission != null) {
      items.add(_ChipItem(
        CarFilterKind.transmission,
        t.transmissionLabel(filters.transmission!),
      ));
    }
    if (filters.fuel != null) {
      items.add(_ChipItem(
        CarFilterKind.fuel,
        t.fuelLabel(filters.fuel!),
      ));
    }

    return items;
  }

  // Подпись диапазона: обе границы, только нижняя или только верхняя.
  String? _range(
    BuildContext context, {
    String? from,
    String? to,
    String? suffix,
  }) {
    final t = context.t;
    final tail = suffix != null ? ' $suffix' : '';

    if (from != null && to != null) return '$from–$to$tail';
    if (from != null) return '${t.commonFrom} $from$tail';
    if (to != null) return '${t.commonUpTo} $to$tail';
    return null;
  }
}

class _ChipItem {
  const _ChipItem(this.kind, this.label);
  final CarFilterKind kind;
  final String label;
}

// Один чипс применённого фильтра: подпись + «×». Тёмная плашка бренда,
// капсула — так же выглядит применённый фильтр на сайте: он «включён»,
// в отличие от неактивных элементов управления.
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppBrandColors.dark,
      borderRadius: AppBrandRadius.pillAll,
      child: InkWell(
        onTap: onRemove,
        borderRadius: AppBrandRadius.pillAll,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppBrandText.caption.copyWith(
                  color: Colors.white,
                  fontWeight: AppBrandFont.medium,
                ),
              ),
              const SizedBox(width: AppBrandSpacing.xs),
              const Icon(Icons.close, size: 15, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
