// ============================================================
// AUTO.RS — Кнопка «Назад» в фирменном стиле: чёрный круг + белая стрелка.
// Используется как leading во всех AppBar приложения (единый вид).
//
// Если экран открыт стеком навигации (есть куда возвращаться) — по тапу
// делает pop. Иначе (корневой экран) кнопка не показывается.
// ============================================================

import 'package:flutter/material.dart';

import '../../core/theme/app_brand.dart';

class PillBackButton extends StatelessWidget {
  const PillBackButton({super.key, this.onPressed});

  // Необязательный обработчик. По умолчанию — Navigator.maybePop.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // На корневых экранах (вкладки нижнего меню) возвращаться некуда —
    // кнопку не показываем, чтобы AppBar не завёл лишний leading.
    if (onPressed == null && !Navigator.canPop(context)) {
      return const SizedBox.shrink();
    }
    return Center(
      child: Material(
        color: AppBrandColors.dark,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed ?? () => Navigator.maybePop(context),
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
