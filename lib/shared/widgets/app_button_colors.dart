// ============================================================
// AUTO.RS — Роли цветов кнопок (единый источник).
// Зелёный — главное действие (Позвонить, Опубликовать…);
// синий — связь/второстепенное (Написать, Войти…);
// красный — сброс/деструктив; тёмный — нейтральные плашки (Filteri, назад).
// Иконка на цветных/тёмных кнопках — белая; на тёмной — золотой акцент.
// ============================================================

import 'package:flutter/material.dart';

/// Роль кнопки определяет её цвет. Не хардкодим оттенки в экранах —
/// используем этот enum, чтобы палитра менялась в одном месте.
enum PillVariant {
  dark,   // нейтральная тёмная плашка (Filteri в шапке, старый вид)
  green,  // главное/подтверждающее действие
  blue,   // связь / второстепенное
  red,    // сброс / деструктив
}

class AppButtonColors {
  AppButtonColors._();

  // Зелёный «Позвонить»/главное действие.
  static const Color green = Color(0xFF22C063);
  // Синий «Написать»/связь.
  static const Color blue = Color(0xFF1E9AF0);
  // Бренд-красный (сброс, акценты).
  static const Color red = Color(0xFFE01E23);
  // Тёмный фон нейтральных плашек.
  static const Color dark = Color(0xFF2B2B2E);
  // Золотой акцент иконки на тёмной плашке.
  static const Color gold = Color(0xFFE8A73C);

  /// Основной цвет заливки по роли.
  static Color fill(PillVariant v) => switch (v) {
        PillVariant.dark => dark,
        PillVariant.green => green,
        PillVariant.blue => blue,
        PillVariant.red => red,
      };
}
