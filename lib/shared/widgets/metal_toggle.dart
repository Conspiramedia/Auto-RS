// ============================================================
// AUTO.RS — MetalToggle: две кнопки-сегмента с зазором 5px.
// Активный сегмент — зелёный (с галочкой), неактивный — синий.
// По тапу цвета меняются местами. Используется в каталоге (Prodaja/Najam)
// и форме подачи (Продажа/Аренда).
// ============================================================

import 'package:flutter/material.dart';

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
    const radius = BorderRadius.all(Radius.circular(16));
    final color = selected ? AppButtonColors.green : AppButtonColors.blue;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                    const Icon(Icons.check_circle_outline,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
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
