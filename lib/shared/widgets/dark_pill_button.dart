// ============================================================
// AUTO.RS — DarkPillButton: тёмная «стеклянная» плашка с золотой иконкой.
// Используется для «Filteri» в шапке каталога и «Опубликовать» в форме.
// По умолчанию ширина ПО КОНТЕНТУ; expand:true — на всю ширину родителя.
// ============================================================

import 'package:flutter/material.dart';

// Золотой акцент бренда (иконка).
const Color _kGold = Color(0xFFE8A73C);

class DarkPillButton extends StatelessWidget {
  const DarkPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onTap; // null — кнопка неактивна
  final IconData? icon;      // null — только текст, по центру
  final bool expand;         // true — растянуть на всю ширину

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(16));
    // Градиент+тень на внешнем контейнере; обрезка отдельным ClipRRect;
    // InkWell (рябь) внутри клипа. Так на кромках нет артефактов.
    final button = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A3A3E), Color(0xFF242427)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: SizedBox(
                height: 52,
                child: Row(
                  mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: _kGold, size: 22),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // По контенту — оборачиваем в Row/mainAxisSize.min через Align,
    // чтобы кнопка не растягивалась на всю ширину родителя.
    return expand ? button : Align(alignment: Alignment.center, child: button);
  }
}
