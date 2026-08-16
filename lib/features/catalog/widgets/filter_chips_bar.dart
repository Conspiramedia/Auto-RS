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

import '../../../core/config/reference_data.dart';
import '../../../core/i18n/app_strings.dart';
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
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(t.catalogFiltersReset),
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
        ReferenceData.bodyTypes[filters.bodyType] ?? filters.bodyType!,
      ));
    }
    if (filters.transmission != null) {
      items.add(_ChipItem(
        CarFilterKind.transmission,
        ReferenceData.transmissions[filters.transmission] ??
            filters.transmission!,
      ));
    }
    if (filters.fuel != null) {
      items.add(_ChipItem(
        CarFilterKind.fuel,
        ReferenceData.fuels[filters.fuel] ?? filters.fuel!,
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

// Один чипс: подпись + «×». Компактный, чтобы в строку помещалось
// несколько штук без прокрутки в типичном случае (2–3 фильтра).
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onRemove,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.close,
                size: 15,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
