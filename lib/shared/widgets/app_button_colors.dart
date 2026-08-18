// ============================================================
// RS AUTO — Роли цветов кнопок.
// Источник значений — core/theme/app_brand.dart (зеркало brand.ts).
// Зелёный — главное действие (Позвонить, Опубликовать…);
// синий — связь/второстепенное (Написать, Войти…);
// красный — сброс/деструктив; тёмный — нейтральные плашки (Filteri, назад).
// Иконка на цветных/тёмных кнопках — белая; на тёмной — золотой акцент.
// ============================================================

import 'package:flutter/material.dart';

import '../../core/theme/app_brand.dart';

/// Роль кнопки определяет её цвет. Не хардкодим оттенки в экранах —
/// используем этот enum, чтобы палитра менялась в одном месте.
enum PillVariant {
  dark,   // нейтральная тёмная плашка (Filteri в шапке, старый вид)
  green,  // главное/подтверждающее действие
  blue,   // связь / второстепенное
  red,    // сброс / деструктив
  /// Контурная: равнозначное действие рядом с главным — «Назад» в
  /// пошаговой подаче. Зеркало variant="secondary" кнопки сайта.
  /// Заливки нет: второй сплошной плашки рядом с зелёным CTA быть
  /// не должно, иначе на экране два одинаково громких действия.
  outline,
}

/// Тонкий слой ролей поверх палитры бренда. Собственных значений здесь
/// НЕТ — только алиасы на AppBrandColors: цвет, продублированный в двух
/// файлах, рано или поздно разъезжается. Класс сохранён, потому что на
/// него ссылаются экраны, и потому что «зелёный = главное действие» —
/// это роль, а не оттенок.
class AppButtonColors {
  AppButtonColors._();

  // Зелёный «Позвонить»/главное действие.
  static const Color green = AppBrandColors.green;
  // Синий «Написать»/связь.
  static const Color blue = AppBrandColors.blue;
  // Бренд-красный (сброс, акценты).
  static const Color red = AppBrandColors.red;
  // Тёмный фон нейтральных плашек.
  static const Color dark = AppBrandColors.dark;
  // Золотой акцент иконки на тёмной плашке.
  static const Color gold = AppBrandColors.gold;

  /// Основной цвет заливки по роли.
  static Color fill(PillVariant v) => switch (v) {
        PillVariant.dark => dark,
        PillVariant.green => green,
        PillVariant.blue => blue,
        PillVariant.red => red,
        // Прозрачная заливка: вид кнопке задают рамка и цвет текста.
        PillVariant.outline => Colors.transparent,
      };

  /// Цвет РАМКИ по роли. Рамка есть только у контурного варианта —
  /// у остальных её роль выполняет сплошная заливка.
  static Color? border(PillVariant v) =>
      v == PillVariant.outline ? AppBrandColors.neutral15 : null;

  /// Цвет ТЕКСТА и иконки по роли. На сплошных плашках он белый,
  /// на контурной — основной текст: белым по белому не читается.
  static Color content(PillVariant v) =>
      v == PillVariant.outline ? AppBrandColors.neutral100 : Colors.white;
}
