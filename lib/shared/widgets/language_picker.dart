// ============================================================
// AUTO.RS — Выбор языка интерфейса: кнопка-глобус для AppBar и общий
// лист выбора.
//
// Кнопка ставится в actions рядом с колокольчиком (NotifBell) — те же
// габариты (иконка 26 + отступ 8) и круглый InkWell, чтобы значки стояли
// ровно в ряд. По тапу открывается showLanguagePicker.
//
// Лист выбора вынесен отдельной функцией: понадобится и на других экранах
// (или в строке настроек), чтобы все точки входа вели в один и тот же
// диалог. [[language-selection-in-profile]]
// ============================================================

import 'package:flutter/material.dart';

import '../../core/i18n/app_language.dart';
import 'app_button_colors.dart';

// Кнопка-глобус для AppBar. Цвет по умолчанию — чёрный (как просили),
// но оставлен параметром: на тёмных шапках понадобится светлый.
class LangButton extends StatelessWidget {
  const LangButton({
    super.key,
    this.size = 26,
    this.color = Colors.black,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showLanguagePicker(context),
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.language, size: size, color: color),
      ),
    );
  }
}

// Лист выбора языка снизу: «Как в телефоне» / «Српски» / «Русский».
// Сохраняет выбор в AppLanguageService — интерфейс перестраивается сразу.
Future<void> showLanguagePicker(BuildContext context) async {
  final current = AppLanguageService.instance.selection;

  final picked = await showModalBottomSheet<AppLanguage>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок на двух языках: настройку ищут и тогда, когда
            // интерфейс сейчас на непонятном языке.
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Язык / Jezik',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ),
            for (final option in AppLanguage.values)
              ListTile(
                leading: Icon(
                  option == AppLanguage.system
                      ? Icons.smartphone
                      : Icons.translate,
                ),
                title: Text(option.label),
                // Галочка у активного варианта — видно текущий выбор.
                trailing: option == current
                    ? const Icon(Icons.check, color: AppButtonColors.green)
                    : null,
                onTap: () => Navigator.pop(ctx, option),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );

  if (picked == null) return; // закрыли лист без выбора
  await AppLanguageService.instance.setSelection(picked);
}
