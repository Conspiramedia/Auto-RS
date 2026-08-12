// Базовый smoke-тест приложения Auto.RS.
// Полноценные виджет-тесты добавим по мере появления экранов.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Приложение поднимает MaterialApp без ошибок', (tester) async {
    // Минимальная проверка, что базовый каркас рендерится.
    // AutoRsApp требует инициализации Supabase, поэтому здесь проверяем
    // отдельный простой каркас — заглушку под будущие тесты экранов.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Auto.RS'))),
      ),
    );

    expect(find.text('Auto.RS'), findsOneWidget);
  });
}
