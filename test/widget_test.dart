// Test básico para verificar que la app se inicia correctamente

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:molinos_app/main.dart';

void main() {
  testWidgets('App se inicia correctamente', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MolinosApp()));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsAtLeastNWidgets(1));
  });
}
