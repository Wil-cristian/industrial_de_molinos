// Test básico para verificar que la app se inicia correctamente

import 'package:flutter_test/flutter_test.dart';
import 'package:molinos_app/main.dart';

void main() {
  testWidgets('App se inicia correctamente', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MolinosApp());

    // Verificar que el título de la app está presente
    expect(find.text('¡Bienvenido!'), findsOneWidget);
  });
}
