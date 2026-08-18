// ============================================================
// AUTO.RS — Виджет-тесты кнопки закрытия (AppCloseButton).
// ============================================================
// Метод А1: виджет поднимается в изоляции, без Supabase и роутера —
// проверяем только его собственный контракт.
//
// Что именно проверяется:
//   1. подпись доступности реально доходит до дерева (без неё TalkBack
//      читает кнопку как «кнопка» — ради этого виджет и появился);
//   2. нажатие вызывает переданный обработчик;
//   3. без обработчика кнопка закрывает текущий маршрут (maybePop) —
//      это поведение по умолчанию во всех шторках;
//   4. вариант overlay рисует белый круг с тенью: именно он лежит
//      поверх фотографии и обязан на ней читаться.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_rs/core/theme/app_brand.dart';
import 'package:auto_rs/shared/widgets/app_close_button.dart';

void main() {
  testWidgets('Подпись доступности берётся из параметра', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppCloseButton(tooltip: 'Закрыть'),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Закрыть'),
      findsWidgets,
      reason: 'Без метки кнопка озвучивается как безымянная',
    );
  });

  testWidgets('Нажатие вызывает переданный обработчик', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppCloseButton(
            tooltip: 'Закрыть',
            onPressed: () => taps++,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AppCloseButton));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('Без обработчика закрывает текущий маршрут', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Center(
                      child: AppCloseButton(tooltip: 'Закрыть'),
                    ),
                  ),
                ),
              ),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    expect(find.byType(AppCloseButton), findsOneWidget);

    // Крестик на втором экране обязан вернуть на первый.
    await tester.tap(find.byType(AppCloseButton));
    await tester.pumpAndSettle();

    expect(find.text('Открыть'), findsOneWidget);
    expect(find.byType(AppCloseButton), findsNothing);
  });

  testWidgets('Вариант overlay — белый круг с тенью', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppCloseButton(
            tooltip: 'Назад',
            variant: AppCloseButtonVariant.overlay,
          ),
        ),
      ),
    );

    // Ink рисует подложку кнопки: у overlay это белый круг с тенью,
    // единственный вариант, читаемый и на светлом, и на тёмном кадре.
    final decoration = tester
        .widgetList<Ink>(find.byType(Ink))
        .map((ink) => ink.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.shape == BoxShape.circle);

    expect(decoration.color, Colors.white);
    expect(decoration.boxShadow, AppBrandElevation.modal);
  });
}
