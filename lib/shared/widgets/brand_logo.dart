// ============================================================
// RS AUTO — Логотип. ЕДИНСТВЕННОЕ место сборки знака в приложении.
// ============================================================
// Зеркало components/ui/Logo.tsx сайта: пока векторного логотипа у
// проекта нет, знак собирается ТЕКСТОМ — название бренда brand.primary
// полужирным. Раньше в шапке стоял Image.asset('logo.png') высотой 60,
// из-за чего шапка приложения не совпадала с сайтом ни по высоте, ни по
// виду знака.
//
// КАК ПОДКЛЮЧИТЬ НАСТОЯЩИЙ ЛОГОТИП, когда дизайнер отдаст файл:
//   1. положить его в assets/images/logo.svg;
//   2. в этом виджете заменить Text на SvgPicture/Image;
//   3. больше НИЧЕГО не трогать — шапка получит знак сама.
//
// Вариант mark — квадратный знак «RS» для тесных мест, как на сайте.
// ============================================================

import 'package:flutter/material.dart';

import '../../core/theme/app_brand.dart';

enum BrandLogoVariant {
  /// Название целиком — шапка.
  full,

  /// Квадратный знак «RS» — тесные места.
  mark,
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.variant = BrandLogoVariant.full,
    this.inverted = false,
  });

  final BrandLogoVariant variant;

  /// Знак на тёмном фоне: брендовый синий там читается плохо.
  final bool inverted;

  /// Название площадки. Совпадает с brand.name сайта.
  static const String name = 'RS Auto';

  @override
  Widget build(BuildContext context) {
    if (variant == BrandLogoVariant.mark) {
      return Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppBrandColors.primary,
          borderRadius: AppBrandRadius.controlAll,
        ),
        child: Text(
          'RS',
          style: AppBrandText.caption.copyWith(
            color: Colors.white,
            fontWeight: AppBrandFont.bold,
          ),
        ),
      );
    }

    return Text(
      name,
      maxLines: 1,
      // 14px = text-sm сайта на мобильном. Ступень h4 (18) делала знак
      // заметно крупнее сайтового и перетягивала внимание с CTA.
      style: AppBrandText.caption.copyWith(
        color: inverted ? Colors.white : AppBrandColors.primary,
        fontWeight: AppBrandFont.bold,
      ),
    );
  }
}
