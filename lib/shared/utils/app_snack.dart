// ============================================================
// AUTO.RS — Единый SnackBar приложения + очистка текста ошибок.
// Все подсказки: фирменный красный фон, белый текст, увеличенное время.
// humanizeError() убирает технический «мусор» (PostgrestException, коды,
// hint/details), оставляя человеку только суть.
// ============================================================

import 'package:flutter/material.dart';

import '../widgets/app_button_colors.dart';

/// Приводит любую ошибку к короткому понятному тексту без тех-деталей.
///
/// Supabase кидает PostgrestException/AuthException, чей toString() содержит
/// «message: …, code: …, details: …, hint: …». Пользователю нужен только
/// message. Обычный Exception отдаёт «Exception: текст» — префикс срезаем.
String humanizeError(Object? error) {
  final raw = error?.toString() ?? '';

  // 1) Supabase-исключения: вытаскиваем содержимое «message: …» до запятой,
  //    за которой идёт следующий технический ключ (code/details/hint/
  //    statusCode/…) или закрывающая скобка.
  final msgMatch =
      RegExp(r'message:\s*(.+?)(?:,\s*[a-zA-Z]+:|\))').firstMatch(raw);
  if (msgMatch != null) {
    final msg = msgMatch.group(1)?.trim();
    if (msg != null && msg.isNotEmpty) return msg;
  }

  // 2) Обычный Exception: «Exception: текст» → «текст».
  var s = raw.replaceFirst(RegExp(r'^\w*Exception:\s*'), '').trim();
  if (s.isEmpty) return 'Что-то пошло не так. Попробуйте ещё раз.';

  // 3) Явно технические строки (сеть) — приводим к дружелюбному виду.
  if (s.contains('Failed to fetch') ||
      s.contains('SocketException') ||
      s.contains('Connection') ||
      s.contains('timeout')) {
    return 'Нет связи с сервером. Проверьте интернет и попробуйте снова.';
  }
  return s;
}

/// Показать фирменную подсказку: синий фон, белый текст, дольше на экране.
void showAppSnack(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  // Не копим очередь одинаковых подсказок — показываем только последнюю.
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      backgroundColor: AppButtonColors.red,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5), // увеличено (было ~4с по умолчанию)
    ),
  );
}

/// Удобный вариант для показа ошибки: сразу очищает текст.
void showErrorSnack(BuildContext context, Object? error) =>
    showAppSnack(context, humanizeError(error));
