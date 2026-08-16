// ============================================================
// AUTO.RS — Общая шапка с поиском: логотип + «умная» строка поиска +
// (опционально) слот справа. Одна высота у логотипа и кнопок (49),
// всё отцентровано.
//
// Используется в Каталоге (со слотом «Фильтры»), Избранном и Сообщениях
// (без фильтров — там поиск фильтрует список локально).
//
// Переключателя языка здесь больше нет: язык выбирается в профиле
// («Язык / Jezik»), по умолчанию берётся из языка телефона. [[language-plan]]
// ============================================================

import 'package:flutter/material.dart';

import 'smart_search_bar.dart';

class AppSearchHeader extends StatelessWidget {
  const AppSearchHeader({
    super.key,
    required this.query,
    required this.onSearchChanged,
    this.onSubmitted,
    this.trailing,
    this.hints = kDefaultCatalogHints,
  });

  /// Подсказки поиска под тему экрана (по умолчанию — каталог авто).
  final List<String> hints;

  /// Текущий текст поиска.
  final String query;

  /// Живой ввод поиска.
  final ValueChanged<String> onSearchChanged;

  /// Отправка запроса (Enter).
  final ValueChanged<String>? onSubmitted;

  /// Необязательный виджет справа от поиска (например, «Фильтры»).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset('assets/images/logo.png', height: 60),
          const SizedBox(width: 10),
          Expanded(
            child: SmartSearchBar(
              value: query,
              onChanged: onSearchChanged,
              onSubmitted: onSubmitted,
              hints: hints,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}
