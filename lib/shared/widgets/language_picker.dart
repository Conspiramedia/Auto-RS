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
import '../../core/i18n/app_strings.dart';
import '../../core/theme/app_brand.dart';
import 'app_close_button.dart';

// Кнопка-глобус для AppBar. Цвет по умолчанию — тёмная плашка бренда,
// но оставлен параметром: на тёмных шапках понадобится светлый.
class LangButton extends StatelessWidget {
  const LangButton({
    super.key,
    this.size = 26,
    this.color = AppBrandColors.dark,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Язык / Jezik',
                      style: AppBrandText.h4
                          .copyWith(color: AppBrandColors.neutral100),
                    ),
                  ),
                  // Подпись берётся из СЛОВАРЯ, а не из заголовка на двух
                  // языках: она озвучивается TalkBack и должна быть на
                  // языке текущего интерфейса.
                  AppCloseButton(
                    tooltip: ctx.t.commonClose,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            for (final option in AppLanguage.values)
              _LanguageRow(
                option: option,
                selected: option == current,
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

// Строка выбора языка. Активный вариант — тёмная плашка бренда с белым
// текстом, как чип текущего языка в шапке сайта: выбор читается сразу,
// без поиска галочки в хвосте строки. Неактивные — нейтральные.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = selected ? Colors.white : AppBrandColors.neutral100;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppBrandSpacing.md,
        vertical: AppBrandSpacing.xs,
      ),
      child: Material(
        color: selected ? AppBrandColors.dark : Colors.transparent,
        borderRadius: AppBrandRadius.controlAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppBrandRadius.controlAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppBrandSpacing.md,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(
                  option == AppLanguage.system
                      ? Icons.smartphone
                      : Icons.translate,
                  size: 22,
                  color: selected ? Colors.white : AppBrandColors.neutral60,
                ),
                const SizedBox(width: AppBrandSpacing.md),
                Expanded(
                  child: Text(
                    option.label,
                    style: AppBrandText.body.copyWith(
                      color: content,
                      fontWeight: selected
                          ? AppBrandFont.semibold
                          : AppBrandFont.regular,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(Icons.check, size: 20, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
