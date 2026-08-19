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

    // ПЕРЕНОС СТРОК, а не горизонтальная прокрутка: на сайте это
    // flex flex-wrap (FilterChips.tsx), и при пяти-шести условиях видно
    // сразу все. Прежний горизонтальный ListView прятал хвост списка за
    // краем экрана — вместе с кнопкой сброса, стоящей последней.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppBrandSpacing.md),
      // SizedBox во всю ширину: Column каталога центрирует детей, и Wrap,
      // сжатый по содержимому, вставал серединой экрана. Растянутый на
      // всю строку, он прижимает чипсы к левому краю — как flex-контейнер
      // сайта, занимающий ширину родителя.
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          // ВЫКЛЮЧКА ВЛЕВО. Родительский Column каталога не задаёт
          // crossAxisAlignment, поэтому по умолчанию центрирует детей, и
          // ряд чипсов вставал серединой экрана вместо левого края.
          // Соседние блоки (заголовок, «Найдено») спасал Align; здесь ту
          // же роль играют растянутый SizedBox и явное выравнивание.
          alignment: WrapAlignment.start,
          // gap-2 сайта = 8px по обеим осям.
          spacing: AppBrandSpacing.sm,
          runSpacing: AppBrandSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final item in items)
              _FilterChip(
                label: item.label,
                onRemove: () => onRemove(item.kind),
              ),
            // Сброс — в хвосте ряда, при ЛЮБОМ числе фильтров, как ссылка
            // сброса на сайте.
            TextButton(
              onPressed: onClearAll,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppBrandSpacing.sm),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                // Сброс — деструктивное действие, красный из бренда.
                foregroundColor: AppBrandColors.red,
              ),
              child: Text(
                t.catalogFiltersReset,
                style: AppBrandText.caption
                    .copyWith(fontWeight: AppBrandFont.semibold),
              ),
            ),
          ],
        ),
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

// Один чипс применённого фильтра: подпись + «×». СВЕТЛАЯ плашка
// surfaceActive со скруглением control — один в один с сайтом
// (FilterChips.tsx: bg-surface-active, rounded-control, text-sm).
// Раньше здесь стояла тёмная капсула с белым текстом: комментарий
// утверждал, что так выглядит чипс на сайте, но на сайте он светлый,
// а тёмная заливка на выдаче спорила с кнопкой «Фильтры».
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppBrandColors.surfaceActive,
      borderRadius: AppBrandRadius.controlAll,
      child: InkWell(
        onTap: onRemove,
        borderRadius: AppBrandRadius.controlAll,
        // px-3 py-1.5 сайта: 12 по горизонтали, 6 по вертикали.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                // Обычное начертание и основной цвет текста: на сайте у
                // чипса нет ни medium, ни белого — это не «включённая»
                // плашка, а снимаемое условие отбора.
                style: AppBrandText.caption
                    .copyWith(color: AppBrandColors.neutral100),
              ),
              // gap-1.5 сайта = 6px.
              const SizedBox(width: 6),
              // Крестик — ТЕКСТОВЫЙ символ «×» (U+00D7) тем же кеглем,
              // что подпись, а не Icons.close: материальная иконка рисует
              // более толстые штрихи и на пиксель выше, из-за чего чипс
              // получался крупнее эталонного. На сайте это <span>×</span>
              // внутри той же строки (FilterChips.tsx).
              Text(
                '×',
                style: AppBrandText.caption
                    .copyWith(color: AppBrandColors.neutral40),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
