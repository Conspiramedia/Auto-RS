// ============================================================
// AUTO.RS — Виджет-тесты контурного варианта DarkPillButton.
// ============================================================
// Метод А1: виджет поднимается в изоляции, без Supabase и роутера.
//
// Контурный вариант появился ради кнопки «Назад» в пошаговой подаче:
// рядом с зелёным «Далее» второй сплошной плашки быть не должно, иначе
// на экране два одинаково громких действия. Проверяем именно то, что
// отличает его от остальных ролей.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_rs/core/theme/app_brand.dart';
import 'package:auto_rs/shared/widgets/app_button_colors.dart';
import 'package:auto_rs/shared/widgets/dark_pill_button.dart';

void main() {
  // Достаём оформление плашки: у кнопки это единственный DecoratedBox
  // с BoxDecoration, остальное — ClipRRect и Material.
  BoxDecoration decorationOf(WidgetTester tester) {
    return tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.borderRadius != null);
  }

  testWidgets('Контурная кнопка: без заливки, с рамкой', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DarkPillButton(
            label: 'Назад',
            variant: PillVariant.outline,
            onTap: () {},
          ),
        ),
      ),
    );

    final decoration = decorationOf(tester);

    expect(
      decoration.color,
      Colors.transparent,
      reason: 'Заливка сделала бы её вторым громким действием рядом с CTA',
    );
    expect(decoration.border, isNotNull);
  });

  testWidgets('Контурная кнопка: текст тёмный, а не белый', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DarkPillButton(
            label: 'Назад',
            variant: PillVariant.outline,
            onTap: () {},
          ),
        ),
      ),
    );

    // Белый текст на прозрачной заливке был бы невидим на белом фоне.
    final text = tester.widget<Text>(find.text('Назад'));
    expect(text.style?.color, AppBrandColors.neutral100);
  });

  testWidgets('Сплошные варианты сохранили белый текст и заливку',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DarkPillButton(
            label: 'Далее',
            variant: PillVariant.green,
            onTap: () {},
          ),
        ),
      ),
    );

    final decoration = decorationOf(tester);
    expect(decoration.color, AppBrandColors.green);
    expect(decoration.border, isNull);

    final text = tester.widget<Text>(find.text('Далее'));
    expect(text.style?.color, Colors.white);
  });

  testWidgets('Радиус кнопки — control (12), а не капсула', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DarkPillButton(
            label: 'Далее',
            variant: PillVariant.green,
            onTap: () {},
          ),
        ),
      ),
    );

    // Кнопка сайта — rounded-control (12px). Раньше здесь стоял
    // pillAll (999): плашка выходила капсулой и не совпадала с полями
    // формы, у которых тот же control-радиус.
    expect(decorationOf(tester).borderRadius, AppBrandRadius.controlAll);
  });

  testWidgets('Неактивная кнопка гасится прозрачностью', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DarkPillButton(
            label: 'Далее',
            variant: PillVariant.green,
            onTap: null, // шаг не заполнен — переход запрещён
          ),
        ),
      ),
    );

    // 0.4 — то же значение, что disabled:opacity-40 на сайте. Без него
    // заблокированная кнопка выглядела обычной и «молча не нажималась».
    final opacity = tester.widget<Opacity>(find.byType(Opacity));
    expect(opacity.opacity, 0.4);
  });

  testWidgets('Активная кнопка не гасится', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DarkPillButton(
            label: 'Далее',
            variant: PillVariant.green,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('Текст кнопки — 16px, как на сайте', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DarkPillButton(
            label: 'Далее',
            variant: PillVariant.green,
            onTap: () {},
          ),
        ),
      ),
    );

    // У кнопки сайта размер шрифта не задан классом и наследуется от
    // базового 16px. Раньше здесь стоял small (12) — подпись выходила
    // заметно мельче эталона.
    final text = tester.widget<Text>(find.text('Далее'));
    expect(text.style?.fontSize, AppBrandText.body.fontSize);
  });

  testWidgets('Высота кнопки — 48, как py-3 сайта', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DarkPillButton(
            label: 'Далее',
            variant: PillVariant.green,
            onTap: () {},
          ),
        ),
      ),
    );

    // 48 = вертикальные отступы 12+12 плюс интерлиньяж 24 у текста 16px.
    final box = tester.widgetList<SizedBox>(find.byType(SizedBox)).firstWhere(
          (b) => b.height != null,
        );
    expect(box.height, 48);
  });

  test('Роли цветов: рамка только у контурного варианта', () {
    for (final v in PillVariant.values) {
      if (v == PillVariant.outline) {
        expect(AppButtonColors.border(v), isNotNull);
        expect(AppButtonColors.content(v), AppBrandColors.neutral100);
      } else {
        expect(AppButtonColors.border(v), isNull);
        expect(AppButtonColors.content(v), Colors.white);
      }
    }
  });
}
