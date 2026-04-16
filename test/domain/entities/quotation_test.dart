import 'package:flutter_test/flutter_test.dart';
import 'package:molinos_app/domain/entities/quotation.dart';

void main() {
  group('Quotation', () {
    late Quotation sampleQuotation;
    late List<QuotationItem> sampleItems;

    setUp(() {
      sampleItems = [
        QuotationItem(
          id: 'qi-001',
          name: 'Eje de acero',
          type: 'cylinder',
          quantity: 2,
          unitWeight: 5.0,
          pricePerKg: 10.0,
          costPerKg: 6.5,
        ),
        QuotationItem(
          id: 'qi-002',
          name: 'Tapa circular',
          type: 'circular_plate',
          quantity: 4,
          unitWeight: 2.5,
          pricePerKg: 12.0,
          costPerKg: 8.0,
          unitPrice: 50.0,
          unitCost: 30.0,
        ),
      ];

      sampleQuotation = Quotation(
        id: 'q-001',
        number: 'COT-2025-0001',
        date: DateTime(2025, 3, 1),
        validUntil: DateTime(2025, 4, 1),
        customerId: 'cust-001',
        customerName: 'Metalmecánica SAC',
        status: 'Borrador',
        items: sampleItems,
        laborCost: 100.0,
        energyCost: 50.0,
        gasCost: 30.0,
        suppliesCost: 20.0,
        otherCosts: 10.0,
        profitMargin: 25.0,
        createdAt: DateTime(2025, 3, 1),
      );
    });

    test('materialsCost suma totalPrice de todos los items', () {
      // Item 1: totalWeight=10, pricePerKg=10 → totalPrice=100
      // Item 2: unitPrice=50, qty=4 → totalPrice=200
      expect(sampleQuotation.materialsCost, 300.0);
    });

    test('indirectCosts suma energía+gas+suministros+otros', () {
      expect(sampleQuotation.indirectCosts, 110.0); // 50+30+20+10
    });

    test('subtotal = materialsCost + laborCost + indirectCosts', () {
      // 300 + 100 + 110 = 510
      expect(sampleQuotation.subtotal, 510.0);
    });

    test('profitAmount aplica margen al subtotal', () {
      // 510 * 25% = 127.5
      expect(sampleQuotation.profitAmount, 127.5);
    });

    test('total = subtotal + profitAmount', () {
      // 510 + 127.5 = 637.5
      expect(sampleQuotation.total, 637.5);
    });

    test('totalWeight suma peso de todos los items', () {
      // Item 1: 5*2=10, Item 2: 2.5*4=10 → total=20
      expect(sampleQuotation.totalWeight, 20.0);
    });

    test('copyWith preserva valores originales', () {
      final copy = sampleQuotation.copyWith(status: 'Aprobada');
      expect(copy.status, 'Aprobada');
      expect(copy.customerName, 'Metalmecánica SAC');
      expect(copy.items.length, 2);
    });

    group('fromJson / toJson', () {
      test('roundtrip serialization', () {
        final json = sampleQuotation.toJson();
        final restored = Quotation.fromJson(json);

        expect(restored.id, sampleQuotation.id);
        expect(restored.number, sampleQuotation.number);
        expect(restored.customerName, sampleQuotation.customerName);
        expect(restored.status, sampleQuotation.status);
        expect(restored.laborCost, sampleQuotation.laborCost);
        expect(restored.profitMargin, sampleQuotation.profitMargin);
        expect(restored.items.length, sampleQuotation.items.length);
      });

      test('fromJson con valores nulos usa defaults', () {
        final q = Quotation.fromJson({
          'id': 'q-x',
          'number': 'COT-2025-0099',
          'date': '2025-01-01',
          'valid_until': '2025-02-01',
          'customer_id': 'c-x',
          'customer_name': 'Test',
          'created_at': '2025-01-01T00:00:00.000',
        });
        expect(q.status, 'Borrador');
        expect(q.laborCost, 0);
        expect(q.profitMargin, 20);
        expect(q.items, isEmpty);
        expect(q.synced, false);
      });

      test('toJson usa snake_case', () {
        final json = sampleQuotation.toJson();
        expect(json.containsKey('customer_id'), true);
        expect(json.containsKey('customer_name'), true);
        expect(json.containsKey('valid_until'), true);
        expect(json.containsKey('labor_cost'), true);
        expect(json.containsKey('profit_margin'), true);
        expect(json.containsKey('created_at'), true);
      });
    });
  });

  group('QuotationItem', () {
    test('totalWeight = unitWeight * quantity', () {
      final item = QuotationItem(
        id: '1',
        name: 'Eje',
        type: 'cylinder',
        quantity: 3,
        unitWeight: 4.5,
      );
      expect(item.totalWeight, 13.5);
    });

    test('totalPrice usa unitPrice si está definido', () {
      final item = QuotationItem(
        id: '1',
        name: 'Pieza',
        type: 'custom',
        quantity: 2,
        unitPrice: 100.0,
        unitWeight: 5.0,
        pricePerKg: 10.0,
      );
      // unitPrice > 0, entonces usa unitPrice * quantity
      expect(item.totalPrice, 200.0);
    });

    test('totalPrice cae a totalWeight * pricePerKg si unitPrice es 0', () {
      final item = QuotationItem(
        id: '1',
        name: 'Barra',
        type: 'cylinder',
        quantity: 2,
        unitWeight: 5.0,
        pricePerKg: 10.0,
        unitPrice: 0,
      );
      // totalWeight=10, pricePerKg=10 → 100
      expect(item.totalPrice, 100.0);
    });

    test('totalCost usa unitCost si está definido', () {
      final item = QuotationItem(
        id: '1',
        name: 'Pieza',
        type: 'custom',
        quantity: 3,
        unitCost: 50.0,
      );
      expect(item.totalCost, 150.0);
    });

    test('totalCost cae a totalWeight * costPerKg si unitCost es 0', () {
      final item = QuotationItem(
        id: '1',
        name: 'Barra',
        type: 'cylinder',
        quantity: 2,
        unitWeight: 4.0,
        costPerKg: 6.0,
      );
      // totalWeight=8, costPerKg=6 → 48
      expect(item.totalCost, 48.0);
    });

    test('totalProfit = totalPrice - totalCost', () {
      final item = QuotationItem(
        id: '1',
        name: 'Test',
        type: 'custom',
        quantity: 1,
        unitPrice: 100.0,
        unitCost: 65.0,
      );
      expect(item.totalProfit, 35.0);
    });

    test('profitMargin calcula porcentaje sobre costo', () {
      final item = QuotationItem(
        id: '1',
        name: 'Test',
        type: 'custom',
        quantity: 1,
        unitPrice: 130.0,
        unitCost: 100.0,
      );
      // profit=30, margin=(30/100)*100=30%
      expect(item.profitMargin, 30.0);
    });

    test('profitMargin devuelve 0 si totalCost es 0', () {
      final item = QuotationItem(
        id: '1',
        name: 'Test',
        type: 'custom',
        quantity: 1,
        unitPrice: 100.0,
        unitCost: 0,
      );
      expect(item.profitMargin, 0);
    });

    test('fromJson / toJson roundtrip', () {
      final item = QuotationItem(
        id: 'qi-test',
        name: 'Eje Cromado',
        type: 'shaft',
        materialId: 'mat-001',
        quantity: 2,
        unitWeight: 3.5,
        pricePerKg: 15.0,
        costPerKg: 10.0,
        dimensions: {'outer_diameter': 50, 'length': 200},
      );
      final json = item.toJson();
      final restored = QuotationItem.fromJson(json);

      expect(restored.id, item.id);
      expect(restored.name, item.name);
      expect(restored.materialId, item.materialId);
      expect(restored.quantity, item.quantity);
      expect(restored.unitWeight, item.unitWeight);
      expect(restored.pricePerKg, item.pricePerKg);
      expect(restored.dimensions['outer_diameter'], 50);
    });

    test('copyWith funciona correctamente', () {
      final item = QuotationItem(id: '1', name: 'Original', type: 'custom');
      final copy = item.copyWith(name: 'Modificado', quantity: 5);
      expect(copy.name, 'Modificado');
      expect(copy.quantity, 5);
      expect(copy.id, '1');
    });
  });
}
