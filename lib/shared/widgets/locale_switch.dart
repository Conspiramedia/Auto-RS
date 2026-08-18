// ============================================================
// RS AUTO — Переключатель языка в шапке: чипсы SR / RU.
// ============================================================
// Зеркало components/LocaleSwitch.tsx сайта: активный язык — тёмная
// плашка бренда с белым текстом, неактивный — приглушённый тёмный без
// заливки. Так выбор виден сразу, без открытия списка.
//
// В приложении язык до этого выбирался ТОЛЬКО через лист в профиле
// («Язык / Jezik»). Лист остаётся — он даёт вариант «Как в телефоне»,
// которого на сайте нет; чипсы же переключают язык в один тап прямо
// в шапке, как на сайте.
//
// Логика хранения не меняется: пишем в тот же AppLanguageService, что и
// лист профиля, поэтому выбор и здесь, и там один и тот же.
// ============================================================

import 'package:flutter/material.dart';

import '../../core/i18n/app_language.dart';
import '../../core/theme/app_brand.dart';

class LocaleSwitch extends StatelessWidget {
  const LocaleSwitch({super.key});

  // Порядок как на сайте: сербский первым — основной язык рынка.
  static const List<(AppLanguage, String)> _options = [
    (AppLanguage.sr, 'SR'),
    (AppLanguage.ru, 'RU'),
  ];

  @override
  Widget build(BuildContext context) {
    final service = AppLanguageService.instance;

    // AnimatedBuilder: сам сервис — ChangeNotifier, и без подписки чипсы
    // остались бы с прежней подсветкой до следующей перестройки экрана.
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) => _row(context, service),
    );
  }

  Widget _row(BuildContext context, AppLanguageService service) {
    // Подсвечиваем ИТОГОВЫЙ язык интерфейса, а не сохранённый выбор:
    // при значении «Как в телефоне» выбор пуст, но интерфейс всё равно
    // на каком-то языке, и чипс обязан это показывать.
    final active = _activeLanguage(context, service);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (language, label) in _options)
          Padding(
            padding: const EdgeInsets.only(left: AppBrandSpacing.xs),
            child: _Chip(
              label: label,
              selected: language == active,
              onTap: () => service.setSelection(language),
            ),
          ),
      ],
    );
  }

  // Какой язык показан прямо сейчас.
  AppLanguage _activeLanguage(
    BuildContext context,
    AppLanguageService service,
  ) {
    if (service.selection != AppLanguage.system) return service.selection;
    // «Как в телефоне» — смотрим на локаль, которую выбрал Flutter.
    return Localizations.localeOf(context).languageCode == 'ru'
        ? AppLanguage.ru
        : AppLanguage.sr;
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppBrandColors.dark : Colors.transparent,
      borderRadius: AppBrandRadius.controlAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppBrandRadius.controlAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppBrandSpacing.sm,
            vertical: AppBrandSpacing.xs,
          ),
          child: Text(
            label,
            style: AppBrandText.small.copyWith(
              // Неактивный — тот же тёмный, но приглушённый: на сайте
              // это text-brand-dark/60.
              color: selected ? Colors.white : AppBrandColors.neutral60,
              fontWeight: AppBrandFont.semibold,
            ),
          ),
        ),
      ),
    );
  }
}
