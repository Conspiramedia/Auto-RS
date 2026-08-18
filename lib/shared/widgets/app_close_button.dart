// ============================================================
// AUTO.RS — Кнопка закрытия («крестик»). Зеркало components/ui/
// CloseButton.tsx сайта: те же размеры, цвета и два варианта подложки.
// ============================================================
// Ставится в шапку каждой шторки и модалки, где человек может передумать,
// и поверх галереи объявления. До этого крестик был написан заново в
// шторке меню (neutral40, размер 22), а в остальных листах его не было
// вовсе — закрыть их можно было только свайпом, о котором пользователь
// должен догадаться.
//
// ВАРИАНТЫ (по подложке, на которой лежит крестик):
//   plain   — на белом фоне листа: фильтры, выбор значения, языковой
//             лист, лист уведомлений;
//   overlay — поверх фотографии: галерея объявления. Тёмный знак на
//             белом круге — единственный вариант, читаемый и на светлом
//             небе, и на чёрном кузове.
//
// Область нажатия — 40×40, как у PillBackButton: тот же минимум, при
// котором в кнопку попадают пальцем.
// ============================================================

import 'package:flutter/material.dart';

import '../../core/theme/app_brand.dart';

enum AppCloseButtonVariant { plain, overlay }

class AppCloseButton extends StatelessWidget {
  const AppCloseButton({
    super.key,
    this.onPressed,
    required this.tooltip,
    this.variant = AppCloseButtonVariant.plain,
  });

  /// По умолчанию — Navigator.maybePop: закрыть текущий слой.
  final VoidCallback? onPressed;

  /// Подпись для средств доступности. Обязательна и всегда из словаря:
  /// у кнопки нет текста, и без неё TalkBack читает её как «кнопка».
  final String tooltip;

  final AppCloseButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final isOverlay = variant == AppCloseButtonVariant.overlay;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          // На белом листе подложки нет: крестик — это знак, а не плашка.
          color: isOverlay ? Colors.white : Colors.transparent,
          shape: isOverlay
              ? const CircleBorder()
              : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppBrandRadius.control),
                ),
          clipBehavior: Clip.antiAlias,
          // Тень отделяет круг от фотографии: без неё на светлом кадре
          // белая подложка сливается с небом.
          elevation: 0,
          child: Ink(
            decoration: isOverlay
                ? const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: AppBrandElevation.modal,
                  )
                : null,
            child: InkWell(
              onTap: onPressed ?? () => Navigator.maybePop(context),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.close,
                  size: 20,
                  color: isOverlay
                      ? AppBrandColors.neutral100
                      : AppBrandColors.neutral60,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
