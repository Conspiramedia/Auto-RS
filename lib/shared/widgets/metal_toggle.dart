// ============================================================
// RS AUTO — MetalToggle: две кнопки-сегмента с зазором 5px.
// Активный сегмент — зелёный с галочкой, неактивный — нейтральная плашка
// neutral15 с тёмным текстом. Раньше неактивный был синим: два ярких
// сегмента спорили между собой и было неясно, какой из них выбран.
// Используется в каталоге (Prodaja/Najam) и форме подачи (Продажа/Аренда).
// ============================================================

import 'package:flutter/material.dart';

import '../../core/theme/app_brand.dart';
import 'app_button_colors.dart';

class MetalToggle extends StatelessWidget {
  const MetalToggle({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  final String value;
  // Сегменты: (значение, подпись). Обычно 2 штуки.
  final List<(String, String)> segments;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Высота как у кнопок «Фильтры» и языка в шапке.
      height: 49,
      child: Row(
        children: [
          for (int i = 0; i < segments.length; i++) ...[
            if (i > 0) const SizedBox(width: 5), // зазор между кнопками 5px
            Expanded(
              child: _segment(
                label: segments[i].$2,
                selected: value == segments[i].$1,
                onTap: () => onChanged(segments[i].$1),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Одна кнопка-сегмент: активная — зелёная, неактивная — синяя.
  Widget _segment({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    const radius = AppBrandRadius.controlAll;
    // Активный — зелёный главного действия с белым текстом; неактивный —
    // нейтральная плашка с тёмным текстом. Контраст ролей, а не двух
    // ярких цветов: выбранный сегмент виден сразу.
    final fill =
        selected ? AppButtonColors.green : AppBrandColors.neutral15;
    final content =
        selected ? Colors.white : AppBrandColors.neutral100;

    return DecoratedBox(
      decoration: BoxDecoration(color: fill, borderRadius: radius),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    Icon(Icons.check_circle_outline, color: content, size: 22),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppBrandText.body.copyWith(
                        color: content,
                        fontWeight: AppBrandFont.semibold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
