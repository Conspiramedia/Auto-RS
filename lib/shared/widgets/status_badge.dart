// ============================================================
// RS AUTO — Бейдж статуса/метки.
// ============================================================
// Одна плашка на весь апп: бейджи поверх фотографии в карточке каталога
// (промо, аренда, продано), статус объявления в «Моих объявлениях»,
// пометка дилера в витрине. Раньше каждый экран рисовал свою: радиусы
// расходились (6 / 8 / 10), шрифт был то 10, то 11.
//
// Радиус sm, а не control: плашка высотой ~22px со ступенью control
// превращается в капсулу, а нужен прямоугольник со скруглением.
// ============================================================

import 'package:flutter/material.dart';

import '../../core/theme/app_brand.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.background,
    this.foreground = Colors.white,
    this.icon,
  });

  final String label;
  final Color background;

  /// Цвет текста и иконки. По умолчанию белый — плашки заливаются
  /// насыщенными брендовыми цветами.
  final Color foreground;

  /// Необязательная иконка слева от подписи (например, ракета у промо).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppBrandSpacing.sm,
        vertical: AppBrandSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppBrandRadius.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: AppBrandSpacing.xs),
          ],
          Text(
            label,
            style: AppBrandText.small.copyWith(
              color: foreground,
              fontWeight: AppBrandFont.semibold,
            ),
          ),
        ],
      ),
    );
  }
}
