// ============================================================
// AUTO.RS — Тема приложения (Material 3).
// Единый источник цветов/типографики. Шрифт Inter (кириллица+латиница).
// ============================================================

import 'package:flutter/material.dart';

import '../../shared/widgets/app_button_colors.dart';

class AppTheme {
  AppTheme._();

  // Основной цвет бренда
  static const Color _seed = Color(0xFF1565C0);

  // Фон приложения под цвет фона логотипа (чтобы логотип не выделялся)
  static const Color _bg = Color(0xFFFFFFFF);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        scaffoldBackgroundColor: _bg,
        // Основной шрифт Montserrat (кириллица+латиница) из assets/fonts.
        fontFamily: 'Montserrat',
        appBarTheme: const AppBarTheme(centerTitle: true, backgroundColor: _bg),
        // Главное действие приложения — зелёная кнопка (единый стиль с
        // «Позвонить»/«Опубликовать»). Все FilledButton зелёные, белый текст.
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppButtonColors.green,
            foregroundColor: Colors.white,
          ),
        ),
      );
}
