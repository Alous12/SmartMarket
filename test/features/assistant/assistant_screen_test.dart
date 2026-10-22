import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartmarket/core/theme/app_theme.dart';
import 'package:smartmarket/features/assistant/presentation/screens/assistant_screen.dart';

Future<void> _pumpAssistant(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light, home: const AssistantScreen()),
  );
}

void main() {
  testWidgets('CC1: muestra un campo de texto para introducir una solicitud', (
    tester,
  ) async {
    await _pumpAssistant(tester);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Escribe un plato o un producto…'), findsOneWidget);
  });

  testWidgets('CC2: el campo permite al usuario ingresar texto', (
    tester,
  ) async {
    await _pumpAssistant(tester);
    await tester.enterText(
      find.byType(TextField),
      'Quiero preparar lasaña para 4 personas',
    );
    await tester.pump();
    expect(
      find.text('Quiero preparar lasaña para 4 personas'),
      findsOneWidget,
    );
  });

  testWidgets('CC3: el campo está disponible antes de enviar una solicitud', (
    tester,
  ) async {
    await _pumpAssistant(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled ?? true, isTrue);
    expect(field.readOnly, isFalse);
    expect(field.controller!.text, isEmpty);
  });
}
