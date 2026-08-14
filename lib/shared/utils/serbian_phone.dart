// ============================================================
// AUTO.RS — Работа с сербскими номерами телефона.
//
// SerbianPhoneFormatter — маска ввода «+381 6X XXX XXX(X)» (та же, что
// в форме объявления). serbianPhoneToE164 — приведение к формату E.164
// «+3816XXXXXXXX» для Supabase Auth (вход по SMS) и хранения контакта.
//
// Хранится только национальная часть без кода страны и ведущего 0:
// «6XXXXXXXX». Мобильный номер начинается с 6; допускаем 8–9 цифр
// национальной части (сербский мобильный 6X + 6–7 цифр).
// ============================================================

import 'package:flutter/services.dart';

// Национальная часть сербского номера из произвольного ввода:
// отбрасываем код страны (+381 / 00381 / 381) и ведущий 0, оставляем
// максимум 9 цифр. Возвращает только цифры «6XXXXXXXX» (может быть пустой).
String serbianNationalDigits(String raw) {
  var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('00381')) {
    digits = digits.substring(5);
  } else if (digits.startsWith('381')) {
    digits = digits.substring(3);
  } else if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.length > 9) digits = digits.substring(0, 9);
  return digits;
}

// Приведение к E.164 «+3816XXXXXXXX» для Supabase Auth.
// Возвращает null, если номер не похож на сербский мобильный
// (нужно 8–9 цифр национальной части, начинается с 6).
String? serbianPhoneToE164(String raw) {
  final d = serbianNationalDigits(raw);
  if (d.length < 8 || d.length > 9) return null;
  if (!d.startsWith('6')) return null; // мобильный
  return '+381$d';
}

// Форматтер поля ввода: по мере набора приводит к «+381 6X XXX XXX(X)».
// Группы: 2-3-3(+1). Курсор всегда в конце — вставка/удаление в середине
// не ломают маску.
class SerbianPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = serbianNationalDigits(newValue.text);

    // Национальной части ещё нет. Если пользователь уже начал (в поле был
    // префикс «381») — оставляем «+381 » как подсказку; иначе поле пустое.
    if (digits.isEmpty) {
      final hadPrefix =
          newValue.text.replaceAll(RegExp(r'[^0-9]'), '') == '381';
      return hadPrefix
          ? const TextEditingValue(
              text: '+381 ',
              selection: TextSelection.collapsed(offset: 5),
            )
          : const TextEditingValue(text: '');
    }

    // Собираем «+381 6X XXX XXX(X)»: пробелы после 2-й и 5-й цифр.
    final buf = StringBuffer('+381 ');
    for (int i = 0; i < digits.length; i++) {
      if (i == 2 || i == 5) buf.write(' ');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
