// ============================================================
// AUTO.RS — Общая шапка с поиском: логотип + «умная» строка поиска +
// (опционально) слот справа + переключатель языка. Одна высота у логотипа
// и кнопок (49), всё отцентровано.
//
// Используется в Каталоге (со слотом «Фильтры»), Избранном и Сообщениях
// (без фильтров — там поиск фильтрует список локально).
// ============================================================

import 'package:flutter/material.dart';

import 'smart_search_bar.dart';

// Бренд-красный (буква R в тумблере языка).
const Color _kRed = Color(0xFFE01E23);

class AppSearchHeader extends StatelessWidget {
  const AppSearchHeader({
    super.key,
    required this.query,
    required this.onSearchChanged,
    required this.lang,
    required this.onLangChanged,
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

  /// Текущий язык ('sr' | 'ru') и его переключение.
  final String lang;
  final ValueChanged<String> onLangChanged;

  /// Необязательный виджет между поиском и языком (например, «Фильтры»).
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
          const SizedBox(width: 10),
          LangToggle(value: lang, onChanged: onLangChanged),
        ],
      ),
    );
  }
}

// Кнопка-тумблер языка: показывает текущий (RS/RU), по тапу переключает.
// Первая буква R — бренд-красная, вторая (S/U) — белая, фон тёмный.
class LangToggle extends StatelessWidget {
  const LangToggle({super.key, required this.value, required this.onChanged});
  final String value; // 'sr' | 'ru'
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(16));
    final isSr = value == 'sr';
    final second = isSr ? 'S' : 'U'; // RS — сербский, RU — русский
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF2B2B2E),
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onChanged(isSr ? 'ru' : 'sr'),
            child: SizedBox(
              width: 52,
              height: 49,
              child: Center(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    children: [
                      const TextSpan(text: 'R', style: TextStyle(color: _kRed)),
                      TextSpan(
                        text: second,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
