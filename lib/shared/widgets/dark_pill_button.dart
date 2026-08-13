// ============================================================
// AUTO.RS — DarkPillButton: плашка-пилюля бренда.
// variant задаёт роль/цвет: dark (нейтральная, по умолчанию), green
// (главное действие), blue (связь), red (сброс). Тёмный вариант — с
// градиентом и золотой иконкой; цветные — сплошная заливка, белая иконка.
// По умолчанию ширина ПО КОНТЕНТУ; expand:true — на всю ширину родителя.
// ============================================================

import 'package:flutter/material.dart';

import 'app_button_colors.dart';

class DarkPillButton extends StatelessWidget {
  const DarkPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.expand = false,
    this.variant = PillVariant.dark,
  });

  final String label;
  final VoidCallback? onTap; // null — кнопка неактивна
  final IconData? icon;      // null — только текст, по центру
  final bool expand;         // true — растянуть на всю ширину
  final PillVariant variant; // роль/цвет кнопки

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(16));
    final isDark = variant == PillVariant.dark;
    // Иконка: золотая на тёмной плашке, белая на цветных.
    final iconColor = isDark ? AppButtonColors.gold : Colors.white;
    final fill = AppButtonColors.fill(variant);

    // Тёмный вариант — фирменный градиент; цветные — сплошная заливка.
    final decoration = BoxDecoration(
      borderRadius: radius,
      color: isDark ? null : fill,
      gradient: isDark
          ? const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3A3A3E), Color(0xFF242427)],
            )
          : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );

    final button = DecoratedBox(
      decoration: decoration,
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
                      Icon(icon, color: iconColor, size: 22),
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

    // По контенту — оборачиваем в Align, чтобы не растягивалась на всю ширину.
    return expand ? button : Align(alignment: Alignment.center, child: button);
  }
}
