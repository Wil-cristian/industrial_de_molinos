import 'package:flutter_test/flutter_test.dart';
import 'package:molinos_app/domain/entities/cash_movement.dart';

void main() {
  group('CashMovement', () {
    late CashMovement sampleIncome;
    late CashMovement sampleExpense;
    late CashMovement sampleTransfer;

    setUp(() {
      sampleIncome = CashMovement(
        id: 'mov-001',
        accountId: 'acc-001',
        type: MovementType.income,
        category: MovementCategory.sale,
        amount: 1500.0,
        description: 'Venta de piezas',
        personName: 'Carlos',
        date: DateTime(2025, 3, 15),
      );

      sampleExpense = CashMovement(
        id: 'mov-002',
        accountId: 'acc-001',
        type: MovementType.expense,
        category: MovementCategory.purchase,
        amount: 800.0,
        description: 'Compra de material',
        date: DateTime(2025, 3, 15),
      );

      sampleTransfer = CashMovement(
        id: 'mov-003',
        accountId: 'acc-001',
        toAccountId: 'acc-002',
        type: MovementType.transfer,
        category: MovementCategory.transferOut,
        amount: 5000.0,
        description: 'Traslado a banco',
        date: DateTime(2025, 3, 15),
        linkedTransferId: 'link-001',
      );
    });

    test('typeLabel muestra etiqueta correcta', () {
      expect(sampleIncome.typeLabel, 'Ingreso');
      expect(sampleExpense.typeLabel, 'Gasto');
      expect(sampleTransfer.typeLabel, 'Traslado');
    });

    test('categoryLabel mapea todas las categorías', () {
      expect(
        CashMovement(
          id: '1', accountId: 'a', type: MovementType.income,
          category: MovementCategory.sale, amount: 1, description: '', date: DateTime.now(),
        ).categoryLabel,
        'Venta',
      );
      expect(
        CashMovement(
          id: '1', accountId: 'a', type: MovementType.income,
          category: MovementCategory.collection, amount: 1, description: '', date: DateTime.now(),
        ).categoryLabel,
        'Cobranza',
      );
      expect(
        CashMovement(
          id: '1', accountId: 'a', type: MovementType.expense,
          category: MovementCategory.salary, amount: 1, description: '', date: DateTime.now(),
        ).categoryLabel,
        'Salario',
      );
      expect(
        CashMovement(
          id: '1', accountId: 'a', type: MovementType.expense,
          category: MovementCategory.services, amount: 1, description: '', date: DateTime.now(),
        ).categoryLabel,
        'Servicios',
      );
      expect(
        CashMovement(
          id: '1', accountId: 'a', type: MovementType.expense,
          category: MovementCategory.transport, amount: 1, description: '', date: DateTime.now(),
        ).categoryLabel,
        'Transporte',
      );
      expect(
        CashMovement(
          id: '1', accountId: 'a', type: MovementType.expense,
          category: MovementCategory.maintenance, amount: 1, description: '', date: DateTime.now(),
        ).categoryLabel,
        'Mantenimiento',
      );
    });

    test('isIncome identifica ingresos y transferencias de entrada', () {
      expect(sampleIncome.isIncome, true);
      expect(sampleExpense.isIncome, false);

      final transferIn = sampleTransfer.copyWith(
        category: MovementCategory.transferIn,
      );
      expect(transferIn.isIncome, true);
    });

    test('isExpense identifica gastos y transferencias de salida', () {
      expect(sampleExpense.isExpense, true);
      expect(sampleIncome.isExpense, false);
      expect(sampleTransfer.isExpense, true); // transferOut
    });

    test('copyWith preserva valores', () {
      final copy = sampleIncome.copyWith(amount: 2000.0);
      expect(copy.amount, 2000.0);
      expect(copy.id, 'mov-001');
      expect(copy.description, 'Venta de piezas');
      expect(copy.personName, 'Carlos');
    });

    test('createdAt se asigna automáticamente', () {
      final movement = CashMovement(
        id: '1',
        accountId: 'a',
        type: MovementType.income,
        category: MovementCategory.sale,
        amount: 100,
        description: 'Test',
        date: DateTime.now(),
      );
      expect(movement.createdAt, isNotNull);
    });

    group('fromJson / toJson', () {
      test('roundtrip serialization', () {
        final json = sampleIncome.toJson();
        final restored = CashMovement.fromJson(json);

        expect(restored.id, sampleIncome.id);
        expect(restored.accountId, sampleIncome.accountId);
        expect(restored.type, MovementType.income);
        expect(restored.category, MovementCategory.sale);
        expect(restored.amount, 1500.0);
        expect(restored.description, 'Venta de piezas');
      });

      test('fromJson con valores mínimos', () {
        final m = CashMovement.fromJson({
          'id': 'x',
          'accountId': 'a',
          'type': 'income',
          'category': 'sale',
          'amount': 100,
          'description': 'Test',
        });
        expect(m.amount, 100.0);
        expect(m.type, MovementType.income);
      });

      test('fromJson con categoría desconocida usa otherIncome', () {
        final m = CashMovement.fromJson({
          'id': 'x',
          'accountId': 'a',
          'type': 'income',
          'category': 'unknown_category',
          'amount': 50,
          'description': '',
        });
        expect(m.category, MovementCategory.otherIncome);
      });
    });
  });

  group('DailyCashReport', () {
    test('netChange = totalIncome - totalExpense', () {
      final report = DailyCashReport(
        date: DateTime(2025, 3, 15),
        openingBalances: {'acc-1': 1000.0, 'acc-2': 5000.0},
        closingBalances: {'acc-1': 1500.0, 'acc-2': 4500.0},
        movements: [],
        totalIncome: 2000.0,
        totalExpense: 1000.0,
      );
      expect(report.netChange, 1000.0);
    });

    test('totalOpeningBalance suma todos los saldos', () {
      final report = DailyCashReport(
        date: DateTime(2025, 3, 15),
        openingBalances: {'a': 1000.0, 'b': 2000.0, 'c': 3000.0},
        closingBalances: {},
        movements: [],
        totalIncome: 0,
        totalExpense: 0,
      );
      expect(report.totalOpeningBalance, 6000.0);
    });

    test('totalClosingBalance suma saldos de cierre', () {
      final report = DailyCashReport(
        date: DateTime(2025, 3, 15),
        openingBalances: {},
        closingBalances: {'a': 1500.0, 'b': 2500.0},
        movements: [],
        totalIncome: 0,
        totalExpense: 0,
      );
      expect(report.totalClosingBalance, 4000.0);
    });

    test('movementCount, incomeCount, expenseCount', () {
      final movements = [
        CashMovement(id: '1', accountId: 'a', type: MovementType.income, category: MovementCategory.sale, amount: 100, description: '', date: DateTime.now()),
        CashMovement(id: '2', accountId: 'a', type: MovementType.income, category: MovementCategory.collection, amount: 200, description: '', date: DateTime.now()),
        CashMovement(id: '3', accountId: 'a', type: MovementType.expense, category: MovementCategory.purchase, amount: 50, description: '', date: DateTime.now()),
      ];
      final report = DailyCashReport(
        date: DateTime.now(),
        openingBalances: {},
        closingBalances: {},
        movements: movements,
        totalIncome: 300,
        totalExpense: 50,
      );
      expect(report.movementCount, 3);
      expect(report.incomeCount, 2);
      expect(report.expenseCount, 1);
    });

    test('fromJson / toJson roundtrip', () {
      final original = DailyCashReport(
        date: DateTime(2025, 3, 15),
        openingBalances: {'acc-1': 1000.0},
        closingBalances: {'acc-1': 1200.0},
        movements: [
          CashMovement(
            id: 'mov-1',
            accountId: 'acc-1',
            type: MovementType.income,
            category: MovementCategory.sale,
            amount: 200.0,
            description: 'Venta',
            date: DateTime(2025, 3, 15),
          ),
        ],
        totalIncome: 200.0,
        totalExpense: 0,
        isClosed: true,
        notes: 'Cierre diario',
      );
      final json = original.toJson();
      final restored = DailyCashReport.fromJson(json);

      expect(restored.date.day, 15);
      expect(restored.totalIncome, 200.0);
      expect(restored.isClosed, true);
      expect(restored.notes, 'Cierre diario');
      expect(restored.movements.length, 1);
      expect(restored.openingBalances['acc-1'], 1000.0);
    });
  });
}
