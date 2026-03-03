import 'package:flutter_test/flutter_test.dart';
import 'package:molinos_app/domain/entities/invoice.dart';

void main() {
  group('Invoice', () {
    late Invoice sampleInvoice;

    setUp(() {
      sampleInvoice = Invoice(
        id: 'inv-001',
        type: InvoiceType.invoice,
        series: 'F001',
        number: '00000001',
        customerId: 'cust-001',
        customerName: 'Aceros del Sur',
        customerDocument: '20123456789',
        issueDate: DateTime(2025, 1, 15),
        dueDate: DateTime(2025, 2, 15),
        subtotal: 1000.0,
        taxAmount: 180.0,
        discount: 0,
        total: 1180.0,
        paidAmount: 500.0,
        status: InvoiceStatus.partial,
        paymentMethod: PaymentMethod.transfer,
        notes: 'Primera nota',
        items: [],
        createdAt: DateTime(2025, 1, 15),
        updatedAt: DateTime(2025, 1, 15),
      );
    });

    test('fullNumber concatena series y number', () {
      expect(sampleInvoice.fullNumber, 'F001-00000001');
    });

    test('pendingAmount calcula total - paidAmount', () {
      expect(sampleInvoice.pendingAmount, 680.0);
    });

    test('pendingAmount es 0 cuando está pagada', () {
      final paid = sampleInvoice.copyWith(
        paidAmount: 1180.0,
        status: InvoiceStatus.paid,
      );
      expect(paid.pendingAmount, 0.0);
    });

    test('isOverdue es true cuando dueDate pasó y no está pagada', () {
      final overdue = sampleInvoice.copyWith(
        dueDate: DateTime(2020, 1, 1),
        status: InvoiceStatus.issued,
      );
      expect(overdue.isOverdue, true);
    });

    test('isOverdue es false cuando dueDate está en el futuro', () {
      final notOverdue = sampleInvoice.copyWith(
        dueDate: DateTime(2099, 12, 31),
      );
      expect(notOverdue.isOverdue, false);
    });

    test('isOverdue es false cuando status es paid', () {
      final paid = sampleInvoice.copyWith(
        dueDate: DateTime(2020, 1, 1),
        status: InvoiceStatus.paid,
      );
      expect(paid.isOverdue, false);
    });

    test('isOverdue es false cuando status es cancelled', () {
      final cancelled = sampleInvoice.copyWith(
        dueDate: DateTime(2020, 1, 1),
        status: InvoiceStatus.cancelled,
      );
      expect(cancelled.isOverdue, false);
    });

    test('isPaid es true solo con status paid', () {
      expect(sampleInvoice.isPaid, false);
      final paid = sampleInvoice.copyWith(status: InvoiceStatus.paid);
      expect(paid.isPaid, true);
    });

    test('copyWith preserva valores originales', () {
      final copy = sampleInvoice.copyWith(notes: 'Nota nueva');
      expect(copy.notes, 'Nota nueva');
      expect(copy.id, 'inv-001');
      expect(copy.total, 1180.0);
      expect(copy.customerName, 'Aceros del Sur');
    });

    test('copyWith permite cambiar cualquier campo', () {
      final copy = sampleInvoice.copyWith(
        id: 'inv-new',
        total: 2000.0,
        status: InvoiceStatus.paid,
        paidAmount: 2000.0,
      );
      expect(copy.id, 'inv-new');
      expect(copy.total, 2000.0);
      expect(copy.status, InvoiceStatus.paid);
      expect(copy.paidAmount, 2000.0);
    });

    group('fromJson / toJson', () {
      test('roundtrip serialization mantiene datos', () {
        final json = sampleInvoice.toJson();
        final restored = Invoice.fromJson(json);

        expect(restored.id, sampleInvoice.id);
        expect(restored.type, sampleInvoice.type);
        expect(restored.series, sampleInvoice.series);
        expect(restored.number, sampleInvoice.number);
        expect(restored.customerName, sampleInvoice.customerName);
        expect(restored.subtotal, sampleInvoice.subtotal);
        expect(restored.total, sampleInvoice.total);
        expect(restored.status, sampleInvoice.status);
      });

      test('fromJson con valores nulos usa defaults', () {
        final json = <String, dynamic>{
          'id': 'x',
          'issue_date': '2025-01-01',
          'created_at': '2025-01-01T00:00:00.000',
          'updated_at': '2025-01-01T00:00:00.000',
        };
        final inv = Invoice.fromJson(json);
        expect(inv.series, '');
        expect(inv.number, '');
        expect(inv.customerName, '');
        expect(inv.subtotal, 0);
        expect(inv.total, 0);
        expect(inv.paidAmount, 0);
        expect(inv.status, InvoiceStatus.draft);
        expect(inv.type, InvoiceType.invoice);
      });

      test('fromJson parsea status correctamente', () {
        expect(
          Invoice.fromJson({
            'id': '1',
            'issue_date': '2025-01-01',
            'status': 'paid',
            'created_at': '2025-01-01T00:00:00.000',
            'updated_at': '2025-01-01T00:00:00.000',
          }).status,
          InvoiceStatus.paid,
        );
        expect(
          Invoice.fromJson({
            'id': '1',
            'issue_date': '2025-01-01',
            'status': 'overdue',
            'created_at': '2025-01-01T00:00:00.000',
            'updated_at': '2025-01-01T00:00:00.000',
          }).status,
          InvoiceStatus.overdue,
        );
      });

      test('fromJson parsea invoice type correctamente', () {
        expect(
          Invoice.fromJson({
            'id': '1',
            'issue_date': '2025-01-01',
            'type': 'credit_note',
            'created_at': '2025-01-01T00:00:00.000',
            'updated_at': '2025-01-01T00:00:00.000',
          }).type,
          InvoiceType.creditNote,
        );
      });

      test('toJson usa snake_case para claves', () {
        final json = sampleInvoice.toJson();
        expect(json.containsKey('customer_id'), true);
        expect(json.containsKey('customer_name'), true);
        expect(json.containsKey('issue_date'), true);
        expect(json.containsKey('due_date'), true);
        expect(json.containsKey('tax_amount'), true);
        expect(json.containsKey('paid_amount'), true);
        expect(json.containsKey('payment_method'), true);
      });

      test('toJson formatea fechas como ISO date (sin hora)', () {
        final json = sampleInvoice.toJson();
        expect(json['issue_date'], '2025-01-15');
        expect(json['due_date'], '2025-02-15');
      });
    });
  });

  group('InvoiceItem', () {
    test('fromJson parsea correctamente', () {
      final item = InvoiceItem.fromJson({
        'id': 'item-001',
        'invoice_id': 'inv-001',
        'product_name': 'Molino Industrial',
        'product_code': 'MOL-001',
        'quantity': 2,
        'unit_price': 500.0,
        'subtotal': 1000.0,
        'total': 1000.0,
      });

      expect(item.id, 'item-001');
      expect(item.productName, 'Molino Industrial');
      expect(item.quantity, 2.0);
      expect(item.unitPrice, 500.0);
      expect(item.total, 1000.0);
    });

    test('fromJson con valores nulos usa defaults', () {
      final item = InvoiceItem.fromJson({
        'id': 'x',
        'invoice_id': 'y',
        'product_name': 'Test',
        'quantity': 1,
        'unit_price': 100,
        'subtotal': 100,
        'total': 100,
      });
      expect(item.unit, 'UND');
      expect(item.discount, 0);
      expect(item.taxRate, 0);
      expect(item.taxAmount, 0);
    });

    test('toJson roundtrip', () {
      final item = InvoiceItem(
        id: 'item-001',
        invoiceId: 'inv-001',
        productName: 'Pieza A',
        quantity: 3,
        unitPrice: 100.0,
        subtotal: 300.0,
        total: 354.0,
        taxRate: 18.0,
        taxAmount: 54.0,
      );
      final json = item.toJson();
      final restored = InvoiceItem.fromJson(json);
      expect(restored.id, item.id);
      expect(restored.productName, item.productName);
      expect(restored.quantity, item.quantity);
      expect(restored.total, item.total);
    });
  });
}
