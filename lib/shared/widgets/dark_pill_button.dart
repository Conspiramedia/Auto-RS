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
    // Радиус — control (12), как rounded-control у кнопки сайта.
    // Раньше здесь стоял pillAll (999): плашка выходила капсулой, тогда
    // как на сайте у неё скруглённые углы. Расхождение было видно на
    // любом экране, где кнопки лежат рядом с полями того же радиуса.
    const radius = AppBrandRadius.controlAll;
    final isDark = variant == PillVariant.dark;
    // Цвет текста и иконки берём из роли: на сплошных плашках он белый,
    // на контурной («Назад» в подаче) — основной, иначе белым по белому.
    final contentColor = AppButtonColors.content(variant);
    // Иконка: золотая на тёмной плашке, цвет содержимого — на остальных.
    final iconColor = isDark ? AppButtonColors.gold : contentColor;
    final borderColor = AppButtonColors.border(variant);

    // Неактивная кнопка (onTap == null) гасится прозрачностью, как
    // disabled:opacity-40 на сайте. Без этого «Далее» на первом шаге
    // подачи выглядела обычной зелёной кнопкой, которая молча не
    // нажимается, — человек решал, что приложение сломалось.
    final enabled = onTap != null;

    final decoration = BoxDecoration(
      borderRadius: radius,
      color: AppButtonColors.fill(variant),
      border: borderColor == null ? null : Border.all(color: borderColor),
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
                // 48 = py-3 (12+12) + интерлиньяж 24 у текста 16px.
                // Ровно высота кнопки сайта; прежние 52 не совпадали
                // ни с ней, ни с высотой полей формы.
                height: 48,
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
                        // body (16), как у кнопки сайта: там размер
                        // не задан классом и наследуется от базового
                        // 16px. Стоявший здесь small (12) делал подпись
                        // заметно мельче эталона.
                        style: AppBrandText.body.copyWith(
                          color: contentColor,
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

    // 0.4 — то же значение, что у disabled:opacity-40 сайта.
    final opaque = enabled ? button : Opacity(opacity: 0.4, child: button);

    // По контенту — оборачиваем в Align, чтобы не растягивалась на всю ширину.
    return expand ? opaque : Align(alignment: Alignment.center, child: opaque);
  }
}
