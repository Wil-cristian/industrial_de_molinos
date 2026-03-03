import 'package:flutter_test/flutter_test.dart';
import 'package:molinos_app/domain/entities/account.dart';

void main() {
  group('Account', () {
    test('constructor con defaults', () {
      final account = Account(
        id: 'acc-001',
        name: 'Caja Principal',
        type: AccountType.cash,
      );
      expect(account.balance, 0);
      expect(account.isActive, true);
      expect(account.bankName, isNull);
      expect(account.accountNumber, isNull);
      expect(account.createdAt, isNotNull);
      expect(account.updatedAt, isNotNull);
    });

    test('typeLabel retorna etiqueta correcta', () {
      final cash = Account(id: '1', name: 'Caja', type: AccountType.cash);
      expect(cash.typeLabel, 'Efectivo');

      final bank = Account(id: '2', name: 'BCP', type: AccountType.bank);
      expect(bank.typeLabel, 'Cuenta Bancaria');
    });

    test('displayName para cuenta bancaria incluye banco', () {
      final bank = Account(
        id: '1',
        name: 'Cuenta Corriente',
        type: AccountType.bank,
        bankName: 'BCP',
      );
      expect(bank.displayName, 'Cuenta Corriente (BCP)');
    });

    test('displayName para efectivo solo muestra nombre', () {
      final cash = Account(id: '1', name: 'Caja Chica', type: AccountType.cash);
      expect(cash.displayName, 'Caja Chica');
    });

    test('displayName para banco sin bankName solo muestra nombre', () {
      final bank = Account(id: '1', name: 'Banco', type: AccountType.bank);
      expect(bank.displayName, 'Banco');
    });

    test('copyWith preserva valores y actualiza updatedAt', () {
      final original = Account(
        id: 'acc-001',
        name: 'Original',
        type: AccountType.cash,
        balance: 1000.0,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      final copy = original.copyWith(balance: 2000.0);
      expect(copy.balance, 2000.0);
      expect(copy.name, 'Original');
      expect(copy.createdAt, DateTime(2025, 1, 1));
      // updatedAt se actualiza en copyWith
      expect(copy.updatedAt.isAfter(DateTime(2025, 1, 1)), true);
    });

    group('fromJson / toJson', () {
      test('roundtrip serialization', () {
        final original = Account(
          id: 'acc-test',
          name: 'BCP Corriente',
          type: AccountType.bank,
          balance: 15000.50,
          bankName: 'BCP',
          accountNumber: '123-456-789',
          color: '#2196F3',
          isActive: true,
          createdAt: DateTime(2025, 1, 15, 10, 30),
          updatedAt: DateTime(2025, 1, 15, 10, 30),
        );
        final json = original.toJson();
        final restored = Account.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.type, AccountType.bank);
        expect(restored.balance, 15000.50);
        expect(restored.bankName, 'BCP');
        expect(restored.accountNumber, '123-456-789');
        expect(restored.isActive, true);
      });

      test('fromJson con valores mínimos', () {
        final account = Account.fromJson({
          'id': 'x',
          'name': 'Test',
        });
        expect(account.type, AccountType.cash);
        expect(account.balance, 0);
        expect(account.isActive, true);
      });

      test('fromJson parsea AccountType correctamente', () {
        final cash = Account.fromJson({
          'id': '1',
          'name': 'Caja',
          'type': 'cash',
        });
        expect(cash.type, AccountType.cash);

        final bank = Account.fromJson({
          'id': '2',
          'name': 'BCP',
          'type': 'bank',
        });
        expect(bank.type, AccountType.bank);
      });

      test('fromJson con type desconocido usa cash por default', () {
        final account = Account.fromJson({
          'id': '1',
          'name': 'Test',
          'type': 'crypto',
        });
        expect(account.type, AccountType.cash);
      });
    });
  });
}
