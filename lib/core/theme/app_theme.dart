// ============================================================
// AUTO.RS — Тема приложения (Material 3).
// Единый источник цветов/типографики. Шрифт Inter (кириллица+латиница).
// ============================================================

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Основной цвет бренда
  static const Color _seed = Color(0xFF1565C0);

  // Фон приложения под цвет фона логотипа (чтобы логотип не выделялся)
  static const Color _bg = Color(0xFFFEFEFE);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        scaffoldBackgroundColor: _bg,
        // Основной шрифт Montserrat (кириллица+латиница) из assets/fonts.
        fontFamily: 'Montserrat',
        appBarTheme: const AppBarTheme(centerTitle: true, backgroundColor: _bg),
      );
}
