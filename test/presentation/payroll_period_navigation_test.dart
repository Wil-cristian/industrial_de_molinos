import 'package:flutter_test/flutter_test.dart';
import 'package:molinos_app/presentation/pages/employees/employees_payroll_tab.dart';

void main() {
  group('payroll period navigation', () {
    test('advances from Mar Q2 2026 to Apr Q1 2026 when current period is allowed', () {
      final next = resolveAdjacentPayrollPeriod(
        currentYear: 2026,
        currentPeriodNumber: 6,
        moveForward: true,
        now: DateTime(2026, 4, 15),
      );

      expect(next, isNotNull);
      expect(next!['year'], 2026);
      expect(next['periodNumber'], 7);
      expect(next['isQ1'], true);
    });

    test('does not advance from Apr Q1 2026 to Apr Q2 2026 before day 16', () {
      final next = resolveAdjacentPayrollPeriod(
        currentYear: 2026,
        currentPeriodNumber: 7,
        moveForward: true,
        now: DateTime(2026, 4, 15),
      );

      expect(next, isNull);
    });

    test('goes back from Apr Q1 2026 to Mar Q2 2026', () {
      final previous = resolveAdjacentPayrollPeriod(
        currentYear: 2026,
        currentPeriodNumber: 7,
        moveForward: false,
        now: DateTime(2026, 4, 15),
      );

      expect(previous, isNotNull);
      expect(previous!['year'], 2026);
      expect(previous['periodNumber'], 6);
      expect(previous['isQ1'], false);
    });
  });
}
