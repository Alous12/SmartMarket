import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartmarket/features/store_navigation/domain/entities/store_model.dart';
import 'package:smartmarket/features/store_navigation/presentation/widgets/next_stop_sheet.dart';

void main() {
  Future<void> pump(WidgetTester tester, {int index = 0}) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: NextStopSheet(
            stops: const [
              StoreProduct(id: 'F1', name: 'Fideos', category: 'Despensa'),
              StoreProduct(id: 'A1', name: 'Azúcar'),
            ],
            index: index,
            collected: 0,
            nameOf: (product) => product.name,
            onSkip: () {},
            onCollected: () {},
            onRestart: () {},
          ),
        ),
      ),
    ),
  );

  testWidgets('se pliega para dejar ver el mapa y conserva los botones', (
    tester,
  ) async {
    await pump(tester);
    final open = tester.getSize(find.byType(NextStopSheet)).height;
    expect(find.text('Siguiente parada · 1 de 2'), findsOneWidget);
    expect(find.text('Fideos'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Plegar la parada'));
    await tester.pump();

    final folded = tester.getSize(find.byType(NextStopSheet)).height;
    expect(folded, lessThan(open - 40));
    expect(find.text('Fideos · 1 de 2'), findsOneWidget);
    expect(find.text('Ya lo tengo'), findsOneWidget);
    expect(find.text('Saltar'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Mostrar la parada'));
    await tester.pump();
    expect(tester.getSize(find.byType(NextStopSheet)).height, open);
  });

  testWidgets('al terminar ofrece repetir la ruta', (tester) async {
    await pump(tester, index: 2);
    expect(find.text('Ruta completada'), findsOneWidget);
    expect(find.text('Repetir ruta'), findsOneWidget);
  });
}
