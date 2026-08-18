// ============================================================
// RS AUTO — Поле локального поиска по уже загруженному списку.
// ============================================================
// Используется в «Избранном» и «Сообщениях»: там поиск не ходит на
// сервер, а фильтрует список, который уже на экране.
//
// Почему отдельно от шапки: в каталоге свободный поиск переехал в форму
// фильтров (как на сайте), и общая шапка стала чистым фирменным рядом.
// Но у избранного и чатов экрана фильтров нет вовсе, а искать по своим
// закладкам и диалогам нужно — этим экранам поле остаётся, только уже
// в теле экрана, а не в шапке.
//
// Оформление — из темы (пакет А1): рамка neutral15, фокус primary 2px,
// радиус control. Никаких собственных цветов.
// ============================================================

import 'package:flutter/material.dart';

import '../../core/theme/app_brand.dart';

class LocalSearchField extends StatelessWidget {
  const LocalSearchField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.hint,
  });

  /// Текущий текст запроса.
  final String value;

  final ValueChanged<String> onChanged;

  /// Подсказка внутри поля («Поиск по избранному», «Поиск по диалогам»).
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppBrandSpacing.md,
        AppBrandSpacing.md,
        AppBrandSpacing.md,
        0,
      ),
      child: TextFormField(
        // initialValue вместо контроллера: значение приходит снаружи и
        // меняется только этим же полем — состояние держать негде.
        initialValue: value,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: AppBrandText.body.copyWith(color: AppBrandColors.neutral100),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: AppBrandColors.neutral60,
          ),
        ),
      ),
    );
  }
}
