import 'package:flutter_test/flutter_test.dart';
import 'package:molinos_app/domain/entities/inventory_material.dart';

void main() {
  group('InchFractions', () {
    group('toMm', () {
      test('convierte fracciones comunes correctamente', () {
        // 1/2 pulgada = 12.7 mm
        expect(InchFractions.toMm('1/2'), closeTo(12.7, 0.01));
        // 1/4 pulgada = 6.35 mm
        expect(InchFractions.toMm('1/4'), closeTo(6.35, 0.01));
        // 3/8 pulgada = 9.525 mm
        expect(InchFractions.toMm('3/8'), closeTo(9.525, 0.01));
        // 1/16 pulgada = 1.5875 mm
        expect(InchFractions.toMm('1/16'), closeTo(1.5875, 0.01));
      });

      test('retorna 0 para formato inválido', () {
        expect(InchFractions.toMm('invalid'), 0);
        expect(InchFractions.toMm(''), 0);
      });
    });

    group('inchesToMm', () {
      test('convierte pulgadas enteras', () {
        expect(InchFractions.inchesToMm(1, null), closeTo(25.4, 0.01));
        expect(InchFractions.inchesToMm(2, null), closeTo(50.8, 0.01));
        expect(InchFractions.inchesToMm(0, null), 0);
      });

      test('convierte pulgadas con fracción', () {
        // 1 1/2" = 38.1 mm
        expect(InchFractions.inchesToMm(1, '1/2'), closeTo(38.1, 0.01));
        // 2 3/4" = 69.85 mm
        expect(InchFractions.inchesToMm(2, '3/4'), closeTo(69.85, 0.01));
      });

      test('convierte solo fracción (0 pulgadas)', () {
        expect(InchFractions.inchesToMm(0, '1/2'), closeTo(12.7, 0.01));
      });

      test('ignora fracción vacía', () {
        expect(InchFractions.inchesToMm(3, ''), closeTo(76.2, 0.01));
      });
    });

    group('mmToInches', () {
      test('convierte mm a pulgadas con formato correcto', () {
        final result = InchFractions.mmToInches(25.4);
        expect(result, contains('1'));
        expect(result, contains('"'));
      });

      test('retorna formato con fracción para valores fraccionarios', () {
        final result = InchFractions.mmToInches(12.7);
        // 12.7mm = 1/2"
        expect(result, contains('1/2'));
      });

      test('convierte pulgadas y fracción combinados', () {
        final result = InchFractions.mmToInches(38.1);
        // 38.1mm = 1 1/2"
        expect(result, contains('1'));
        expect(result, contains('1/2'));
      });
    });

    test('common tiene 15 fracciones', () {
      expect(InchFractions.common.length, 15);
    });

    test('common empieza en 1/16 y termina en 15/16', () {
      expect(InchFractions.common.first, '1/16');
      expect(InchFractions.common.last, '15/16');
    });

    test('roundtrip: inchesToMm -> mmToInches es consistente', () {
      // 2 1/4" → mm → back to string
      final mm = InchFractions.inchesToMm(2, '1/4');
      final back = InchFractions.mmToInches(mm);
      expect(back, contains('2'));
      expect(back, contains('1/4'));
    });
  });
}
