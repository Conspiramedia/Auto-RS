// ============================================================
// RS AUTO — Форматтеры числового ввода.
// ============================================================
// Разделитель разрядов в полях цены, пробега и года. Жил приватным
// классом внутри формы подачи, из-за чего экран фильтров вводил те же
// суммы без форматирования: «10000» в одном месте и «10 000» в другом.
// Вынесен в общий утиль, чтобы правило форматирования было одно.
// ============================================================

import 'package:flutter/services.dart';

/// Разделяет вводимое число на группы по три разряда пробелом:
/// «10000» → «10 000». Нецифровые символы отбрасываются, поэтому поле
/// остаётся числовым при любом способе ввода (вставка, автозамена).
class ThousandsFormatter extends TextInputFormatter {
  const ThousandsFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    // Группы по 3 справа налево.
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
      buf.write(digits[i]);
    }

    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      // Курсор в конец: форматтер меняет длину строки, и сохранять
      // исходную позицию бессмысленно — она уже относится к другому тексту.
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Убирает разделители разрядов перед разбором числа: «10 000» → 10000.
/// Парная функция к [ThousandsFormatter] — там, где отформатированное
/// поле нужно превратить в число для запроса.
int? parseFormattedInt(String? text) {
  if (text == null) return null;
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}

/// То же для дробных значений цены.
double? parseFormattedDouble(String? text) {
  final value = parseFormattedInt(text);
  return value?.toDouble();
}
