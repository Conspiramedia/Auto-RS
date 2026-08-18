// ============================================================
// RS AUTO — DarkPillButton: плашка-пилюля бренда.
// variant задаёт роль/цвет: dark (нейтральная, по умолчанию), green
// (главное действие), blue (связь), red (сброс). Заливка всегда сплошная,
// радиус — pill. Градиент и тень тёмного варианта были легаси: на сайте
// плашки плоские, и приложение приведено к этому.
// Иконка золотая на тёмной плашке, белая на цветных.
// По умолчанию ширина ПО КОНТЕНТУ; expand:true — на всю ширину родителя.
// ============================================================

import 'package:flutter/material.dart';

import '../../core/theme/app_brand.dart';
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
    const radius = AppBrandRadius.pillAll;
    final isDark = variant == PillVariant.dark;
    // Иконка: золотая на тёмной плашке, белая на цветных.
    final iconColor = isDark ? AppButtonColors.gold : Colors.white;

    final decoration = BoxDecoration(
      borderRadius: radius,
      color: AppButtonColors.fill(variant),
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
                        style: AppBrandText.small.copyWith(
                          color: Colors.white,
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
      ),
    );

    // По контенту — оборачиваем в Align, чтобы не растягивалась на всю ширину.
    return expand ? button : Align(alignment: Alignment.center, child: button);
  }
}
