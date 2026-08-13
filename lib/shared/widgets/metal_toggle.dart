// ============================================================
// AUTO.RS — MetalToggle: брашированный металлик-переключатель.
// Активная половина тёмная (с золотой галочкой), неактивная — светлый металл.
// Используется в каталоге (Prodaja/Najam) и форме подачи (Продажа/Аренда).
// ============================================================

import 'package:flutter/material.dart';

// Золотой акцент бренда (галочка активного сегмента).
const Color _kGold = Color(0xFFE8A73C);

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
    const radius = BorderRadius.all(Radius.circular(16));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              for (final seg in segments)
                Expanded(
                  child: _half(
                    label: seg.$2,
                    selected: value == seg.$1,
                    onTap: () => onChanged(seg.$1),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Одна половина переключателя.
  Widget _half({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final gradient = selected
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4A4A4E), Color(0xFF2A2A2D)],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFCFCFCF), Color(0xFF9C9C9C)],
          );
    final textColor = selected ? Colors.white : const Color(0xFF2B2B2E);

    return InkWell(
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(gradient: gradient),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check_circle_outline, color: _kGold, size: 22),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
