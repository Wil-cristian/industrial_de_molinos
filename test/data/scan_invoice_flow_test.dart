import 'package:flutter_test/flutter_test.dart';
import 'package:molinos_app/core/utils/scan_helpers.dart';
import 'package:molinos_app/data/datasources/invoice_scanner_service.dart';
import 'package:molinos_app/domain/entities/material.dart' as mat;

void main() {
  // ═══════════════════════════════════════════════════════════════════
  // 1. Normalización de unidades
  // ═══════════════════════════════════════════════════════════════════
  group('normalizeScannedUnit', () {
    test('normaliza kilogramos en todas sus variantes', () {
      for (final variant in [
        'KG',
        'kg',
        'Kgs',
        'KILO',
        'kilos',
        'KILOGRAMO',
        'kilogramos',
      ]) {
        expect(normalizeScannedUnit(variant), 'KG', reason: '$variant → KG');
      }
    });

    test('normaliza unidades/piezas', () {
      for (final variant in [
        'UND',
        'UN',
        'unidad',
        'UNIDADES',
        'PZA',
        'pieza',
        'PIEZAS',
        'PZ',
      ]) {
        expect(normalizeScannedUnit(variant), 'UND', reason: '$variant → UND');
      }
    });

    test('normaliza metros', () {
      for (final variant in [
        'M',
        'MT',
        'MTS',
        'metro',
        'METROS',
        'ML',
        'METRO LINEAL',
      ]) {
        expect(normalizeScannedUnit(variant), 'M', reason: '$variant → M');
      }
    });

    test('normaliza litros', () {
      for (final variant in ['L', 'LT', 'LTS', 'litro', 'LITROS']) {
        expect(normalizeScannedUnit(variant), 'L', reason: '$variant → L');
      }
    });

    test('normaliza galones', () {
      for (final variant in ['GAL', 'galon', 'GALONES']) {
        expect(normalizeScannedUnit(variant), 'GAL', reason: '$variant → GAL');
      }
    });

    test('normaliza metros cuadrados', () {
      for (final variant in ['M2', 'MT2', 'METRO CUADRADO']) {
        expect(normalizeScannedUnit(variant), 'M2', reason: '$variant → M2');
      }
    });

    test('normaliza global/servicio', () {
      for (final variant in ['GLB', 'GLOBAL', 'servicio', 'SV']) {
        expect(normalizeScannedUnit(variant), 'GLB', reason: '$variant → GLB');
      }
    });

    test('normaliza contenedores a UND', () {
      for (final variant in ['ROLLO', 'BOLSA', 'CAJA', 'PAQUETE']) {
        expect(normalizeScannedUnit(variant), 'UND', reason: '$variant → UND');
      }
    });

    test('unidad desconocida → UND por defecto', () {
      expect(normalizeScannedUnit('XYZ'), 'UND');
      expect(normalizeScannedUnit(''), 'UND');
      expect(normalizeScannedUnit('BARRIL'), 'UND');
    });

    test('ignora espacios al inicio y final', () {
      expect(normalizeScannedUnit('  KG  '), 'KG');
      expect(normalizeScannedUnit(' metros '), 'M');
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 2. Inferencia de categoría
  // ═══════════════════════════════════════════════════════════════════
  group('inferCategoryFromDescription', () {
    test('detecta bolas/esferas', () {
      expect(inferCategoryFromDescription('Bola de acero 4"'), 'Bolas');
      expect(inferCategoryFromDescription('Esfera fundida'), 'Bolas');
    });

    test('detecta tubería', () {
      expect(inferCategoryFromDescription('Tubo SCH 40 2"'), 'Tubería');
      expect(inferCategoryFromDescription('Tubería galvanizada'), 'Tubería');
      expect(inferCategoryFromDescription('Caño negro 3/4"'), 'Tubería');
    });

    test('detecta láminas', () {
      expect(inferCategoryFromDescription('Lámina HR 1/4"'), 'Láminas');
      expect(inferCategoryFromDescription('Lamina acero 3mm'), 'Láminas');
      expect(inferCategoryFromDescription('Chapa naval'), 'Láminas');
      expect(inferCategoryFromDescription('Placa de acero'), 'Láminas');
    });

    test('detecta ejes y barras', () {
      expect(inferCategoryFromDescription('Eje 1045 Ø2"'), 'Ejes y Barras');
      expect(inferCategoryFromDescription('Barra redonda'), 'Ejes y Barras');
      expect(
        inferCategoryFromDescription('Varilla corrugada'),
        'Ejes y Barras',
      );
    });

    test('detecta tornillería', () {
      expect(inferCategoryFromDescription('Tornillo hex 1/2x2'), 'Tornillería');
      expect(inferCategoryFromDescription('Perno grado 8'), 'Tornillería');
      expect(
        inferCategoryFromDescription('Tuerca autofrenante'),
        'Tornillería',
      );
      expect(inferCategoryFromDescription('Arandela plana'), 'Tornillería');
    });

    test('detecta soldadura', () {
      expect(inferCategoryFromDescription('Soldadura 7018'), 'Soldadura');
      expect(inferCategoryFromDescription('Electrodo 6013'), 'Soldadura');
    });

    test('detecta pintura', () {
      expect(inferCategoryFromDescription('Pintura epóxica roja'), 'Pintura');
      expect(inferCategoryFromDescription('Anticorrosivo gris'), 'Pintura');
      expect(inferCategoryFromDescription('Esmalte industrial'), 'Pintura');
    });

    test('detecta rodamientos', () {
      expect(inferCategoryFromDescription('Rodamiento 6205'), 'Rodamientos');
      expect(inferCategoryFromDescription('Balero SKF'), 'Rodamientos');
      expect(inferCategoryFromDescription('Chumacera UCP 205'), 'Rodamientos');
    });

    test('detecta consumibles', () {
      expect(inferCategoryFromDescription('Disco de corte 7"'), 'Consumibles');
      expect(inferCategoryFromDescription('Lija #80'), 'Consumibles');
      expect(inferCategoryFromDescription('Grasa multiuso'), 'Consumibles');
      expect(inferCategoryFromDescription('Aceite hidráulico'), 'Consumibles');
      expect(inferCategoryFromDescription('Filtro de aire'), 'Consumibles');
    });

    test('retorna General para descripciones no reconocidas', () {
      expect(inferCategoryFromDescription('Algo desconocido'), 'General');
      expect(inferCategoryFromDescription('Servicio técnico'), 'General');
    });

    test('es case-insensitive', () {
      expect(inferCategoryFromDescription('TUBO SCH 40'), 'Tubería');
      expect(inferCategoryFromDescription('Tubo sch 40'), 'Tubería');
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 3. Generación de filas para invoice_items
  // ═══════════════════════════════════════════════════════════════════
  group('buildInvoiceItemRow', () {
    test('genera mapa con todas las columnas requeridas', () {
      final row = buildInvoiceItemRow(
        invoiceId: 'inv-123',
        sortOrder: 0,
        description: 'Tubo SCH 40 2"',
        referenceCode: 'REF-001',
        materialId: 'mat-456',
        quantity: 5,
        unit: 'M',
        unitPrice: 25000,
        subtotal: 125000,
        total: 125000,
      );

      expect(row['invoice_id'], 'inv-123');
      expect(row['product_id'], isNull);
      expect(row['material_id'], 'mat-456');
      expect(row['product_code'], 'REF-001');
      expect(row['product_name'], 'Tubo SCH 40 2"');
      expect(row['description'], 'Tubo SCH 40 2"');
      expect(row['quantity'], 5);
      expect(row['unit'], 'M');
      expect(row['unit_price'], 25000);
      expect(row['discount'], 0);
      expect(row['tax_rate'], 0);
      expect(row['subtotal'], 125000);
      expect(row['tax_amount'], 0);
      expect(row['total'], 125000);
      expect(row['sort_order'], 0);
    });

    test('normaliza unidad vacía a UND', () {
      final row = buildInvoiceItemRow(
        invoiceId: 'inv-1',
        sortOrder: 0,
        description: 'Item',
        quantity: 1,
        unit: '',
        unitPrice: 100,
        subtotal: 100,
        total: 100,
      );
      expect(row['unit'], 'UND');
    });

    test('convierte unidad a mayúsculas', () {
      final row = buildInvoiceItemRow(
        invoiceId: 'inv-1',
        sortOrder: 0,
        description: 'Item',
        quantity: 1,
        unit: 'kg',
        unitPrice: 100,
        subtotal: 100,
        total: 100,
      );
      expect(row['unit'], 'KG');
    });

    test('material_id es null cuando no se pasa', () {
      final row = buildInvoiceItemRow(
        invoiceId: 'inv-1',
        sortOrder: 0,
        description: 'Item sin material',
        quantity: 1,
        unit: 'UND',
        unitPrice: 100,
        subtotal: 100,
        total: 100,
      );
      expect(row['material_id'], isNull);
    });

    test('incluye IVA cuando se especifica', () {
      final row = buildInvoiceItemRow(
        invoiceId: 'inv-1',
        sortOrder: 0,
        description: 'Item con IVA',
        quantity: 2,
        unit: 'UND',
        unitPrice: 1000,
        taxRate: 19,
        taxAmount: 380,
        subtotal: 2000,
        total: 2380,
      );
      expect(row['tax_rate'], 19);
      expect(row['tax_amount'], 380);
      expect(row['subtotal'], 2000);
      expect(row['total'], 2380);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 4. Cálculo de stock
  // ═══════════════════════════════════════════════════════════════════
  group('computeNewStock', () {
    test('suma correctamente stock existente + recibido', () {
      expect(computeNewStock(100, 25), 125);
    });

    test('funciona con decimales', () {
      expect(computeNewStock(10.5, 3.25), closeTo(13.75, 0.001));
    });

    test('funciona con stock inicial 0', () {
      expect(computeNewStock(0, 50), 50);
    });

    test('funciona con cantidad recibida 0', () {
      expect(computeNewStock(100, 0), 100);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 5. ScannedInvoiceItem fromJson → toJson roundtrip
  // ═══════════════════════════════════════════════════════════════════
  group('ScannedInvoiceItem', () {
    test('fromJson parsea todos los campos', () {
      final json = {
        'reference_code': 'REF-001',
        'description': 'Tubo SCH 40 2"',
        'quantity': 5.0,
        'unit': 'M',
        'unit_price': 25000.0,
        'discount': 0,
        'tax_rate': 19.0,
        'tax_amount': 23750.0,
        'subtotal': 125000.0,
        'total': 148750.0,
      };

      final item = ScannedInvoiceItem.fromJson(json);

      expect(item.referenceCode, 'REF-001');
      expect(item.description, 'Tubo SCH 40 2"');
      expect(item.quantity, 5.0);
      expect(item.unit, 'M');
      expect(item.unitPrice, 25000.0);
      expect(item.discount, 0);
      expect(item.taxRate, 19.0);
      expect(item.taxAmount, 23750.0);
      expect(item.subtotal, 125000.0);
      expect(item.total, 148750.0);
    });

    test('fromJson maneja valores null con defaults', () {
      final item = ScannedInvoiceItem.fromJson({});

      expect(item.referenceCode, isNull);
      expect(item.description, '');
      expect(item.quantity, 1);
      expect(item.unit, 'UND');
      expect(item.unitPrice, 0);
    });

    test('toJson → fromJson roundtrip conserva datos', () {
      final original = ScannedInvoiceItem(
        referenceCode: 'X-100',
        description: 'Lámina HR 3/16"',
        quantity: 2,
        unit: 'UND',
        unitPrice: 450000,
        subtotal: 900000,
        total: 900000,
      );

      final json = original.toJson();
      final restored = ScannedInvoiceItem.fromJson(json);

      expect(restored.referenceCode, original.referenceCode);
      expect(restored.description, original.description);
      expect(restored.quantity, original.quantity);
      expect(restored.unit, original.unit);
      expect(restored.unitPrice, original.unitPrice);
      expect(restored.subtotal, original.subtotal);
      expect(restored.total, original.total);
    });

    test('fromJson castea int a double correctamente', () {
      final item = ScannedInvoiceItem.fromJson({
        'description': 'Test',
        'quantity': 3, // int, no double
        'unit_price': 1000, // int
        'subtotal': 3000, // int
        'total': 3000, // int
      });

      expect(item.quantity, 3.0);
      expect(item.unitPrice, 1000.0);
      expect(item.subtotal, 3000.0);
      expect(item.total, 3000.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 6. InvoiceScanResult fromJson — parsing de respuesta OCR
  // ═══════════════════════════════════════════════════════════════════
  group('InvoiceScanResult.fromJson', () {
    test('parsea respuesta completa del edge function', () {
      final json = {
        'data': {
          'confidence': 0.92,
          'supplier': {
            'name': 'Aceros del Sur S.A.S',
            'document_type': 'NIT',
            'document_number': '900123456-7',
            'address': 'Cra 10 #20-30',
            'phone': '3001234567',
          },
          'invoice': {
            'number': 'FE-12345',
            'date': '2026-03-20',
            'due_date': '2026-04-19',
            'credit_days': 30,
            'cufe': 'abc123cufe',
          },
          'items': [
            {
              'reference_code': 'TUB-001',
              'description': 'Tubo SCH 40 2"',
              'quantity': 5,
              'unit': 'M',
              'unit_price': 25000,
              'tax_rate': 19,
              'tax_amount': 23750,
              'subtotal': 125000,
              'total': 148750,
            },
            {
              'description': 'Soldadura 7018 3/32',
              'quantity': 10,
              'unit': 'KG',
              'unit_price': 15000,
              'tax_rate': 19,
              'tax_amount': 28500,
              'subtotal': 150000,
              'total': 178500,
            },
          ],
          'totals': {
            'subtotal': 275000,
            'tax_rate': 19,
            'tax_amount': 52250,
            'total': 327250,
          },
        },
        'usage': {'total_tokens': 2500, 'estimated_cost_usd': '0.025'},
      };

      final result = InvoiceScanResult.fromJson(json);

      expect(result.confidence, 0.92);
      expect(result.supplier.name, 'Aceros del Sur S.A.S');
      expect(result.supplier.documentNumber, '900123456-7');
      expect(result.invoiceNumber, 'FE-12345');
      expect(result.creditDays, 30);
      expect(result.items.length, 2);
      expect(result.items[0].description, 'Tubo SCH 40 2"');
      expect(result.items[1].description, 'Soldadura 7018 3/32');
      expect(result.subtotal, 275000);
      expect(result.taxRate, 19);
      expect(result.taxAmount, 52250);
      expect(result.total, 327250);
      expect(result.totalTokens, 2500);
    });

    test('anti-IVA inventado: limpia IVA cuando total ≈ subtotal', () {
      final json = {
        'data': {
          'confidence': 0.85,
          'supplier': {'name': 'Proveedor Informal'},
          'items': [
            {
              'description': 'Servicio de transporte',
              'quantity': 1,
              'unit_price': 500000,
              'tax_rate': 19,
              'tax_amount': 95000,
              'subtotal': 500000,
              'total': 595000,
            },
          ],
          'totals': {
            'subtotal': 500000,
            'tax_rate': 19,
            'tax_amount': 95000,
            'total': 500000, // ← total = subtotal → IA inventó el IVA
          },
        },
      };

      final result = InvoiceScanResult.fromJson(json);

      // IVA debe ser limpiado porque total ≈ subtotal
      expect(result.taxRate, 0);
      expect(result.taxAmount, 0);
      expect(result.total, 500000);
      // Items también deben ser limpiados
      expect(result.items[0].taxRate, 0);
      expect(result.items[0].taxAmount, 0);
    });

    test('maneja respuesta vacía sin crashear', () {
      final result = InvoiceScanResult.fromJson({});

      expect(result.confidence, 0);
      expect(result.items, isEmpty);
      expect(result.subtotal, 0);
      expect(result.total, 0);
      expect(result.supplier.name, isNull);
    });

    test('parsea factura sin IVA correctamente', () {
      final json = {
        'data': {
          'confidence': 0.9,
          'supplier': {'name': 'Ferretería Local'},
          'items': [
            {
              'description': 'Disco de corte 7"',
              'quantity': 20,
              'unit': 'UND',
              'unit_price': 5000,
              'subtotal': 100000,
              'total': 100000,
            },
          ],
          'totals': {
            'subtotal': 100000,
            'tax_rate': 0,
            'tax_amount': 0,
            'total': 100000,
          },
        },
      };

      final result = InvoiceScanResult.fromJson(json);
      expect(result.taxRate, 0);
      expect(result.taxAmount, 0);
      expect(result.total, 100000);
    });

    test('parsea retenciones (reteFte, reteIca, reteIva)', () {
      final json = {
        'data': {
          'confidence': 0.9,
          'supplier': {'name': 'Aceros'},
          'items': [],
          'totals': {
            'subtotal': 1000000,
            'tax_rate': 19,
            'tax_amount': 190000,
            'retention_rte_fte': 25000,
            'retention_ica': 10000,
            'retention_iva': 28500,
            'total': 1190000,
          },
        },
      };

      final result = InvoiceScanResult.fromJson(json);
      expect(result.retentionRteFte, 25000);
      expect(result.retentionIca, 10000);
      expect(result.retentionIva, 28500);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 7. Material entity — fromJson/toJson y cálculos de stock
  // ═══════════════════════════════════════════════════════════════════
  group('Material entity integración con inventario', () {
    final now = DateTime.now();

    mat.Material _makeMaterial({
      String id = 'mat-1',
      String code = 'TUB-001',
      String name = 'Tubo SCH 40 2"',
      double stock = 100,
      double costPrice = 25000,
      String unit = 'M',
      String category = 'Tubería',
    }) {
      return mat.Material(
        id: id,
        code: code,
        name: name,
        stock: stock,
        costPrice: costPrice,
        unit: unit,
        category: category,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('toJson genera campos correctos para insert a Supabase', () {
      final material = _makeMaterial();
      final json = material.toJson();

      expect(json['code'], 'TUB-001');
      expect(json['name'], 'Tubo SCH 40 2"');
      expect(json['stock'], 100.0);
      expect(json['cost_price'], 25000.0);
      expect(json['unit'], 'M');
      expect(json['category'], 'Tubería');
      expect(json['is_active'], true);
      // toJson no incluye id (Supabase lo genera)
      expect(json.containsKey('id'), false);
    });

    test('fromJson → toJson roundtrip conserva datos clave', () {
      final json = {
        'id': 'uuid-123',
        'code': 'LAM-005',
        'name': 'Lámina HR 1/4"',
        'category': 'Láminas',
        'stock': 50.0,
        'cost_price': 350000.0,
        'unit': 'UND',
        'is_active': true,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final material = mat.Material.fromJson(json);
      expect(material.id, 'uuid-123');
      expect(material.code, 'LAM-005');
      expect(material.name, 'Lámina HR 1/4"');
      expect(material.stock, 50.0);
      expect(material.costPrice, 350000.0);
      expect(material.unit, 'UND');

      final back = material.toJson();
      expect(back['code'], json['code']);
      expect(back['stock'], json['stock']);
      expect(back['cost_price'], json['cost_price']);
    });

    test('isLowStock detecta stock bajo correctamente', () {
      final low = _makeMaterial(stock: 5).copyWith(minStock: 10);
      final ok = _makeMaterial(stock: 20).copyWith(minStock: 10);

      expect(low.isLowStock, true);
      expect(ok.isLowStock, false);
    });

    test('simulación: actualizar stock tras recibir factura', () {
      final material = _makeMaterial(stock: 100);
      final receivedQty = 25.0;
      final newStock = computeNewStock(material.stock, receivedQty);

      expect(newStock, 125.0);

      // Simular el updated material
      final updated = material.copyWith(
        stock: newStock,
        costPrice: 28000, // nuevo precio de compra
      );
      expect(updated.stock, 125.0);
      expect(updated.costPrice, 28000);
      expect(updated.name, material.name); // no cambia
    });

    test('simulación: crear material nuevo desde factura escaneada', () {
      final scannedItem = ScannedInvoiceItem(
        referenceCode: 'ROD-6205',
        description: 'Rodamiento 6205 2RS',
        quantity: 10,
        unit: 'UND',
        unitPrice: 18500,
        subtotal: 185000,
        total: 185000,
      );

      final normalizedUnit = normalizeScannedUnit(scannedItem.unit);
      final category = inferCategoryFromDescription(scannedItem.description);

      final newMaterial = mat.Material(
        id: '',
        code: 'FAC-${now.millisecondsSinceEpoch % 1000000}',
        name: scannedItem.description,
        description: 'Creado automáticamente desde factura FE-12345',
        category: category.toLowerCase(),
        costPrice: scannedItem.unitPrice,
        unitPrice: scannedItem.unitPrice,
        stock: scannedItem.quantity,
        unit: normalizedUnit,
        createdAt: now,
        updatedAt: now,
      );

      expect(newMaterial.name, 'Rodamiento 6205 2RS');
      expect(newMaterial.stock, 10);
      expect(newMaterial.costPrice, 18500);
      expect(newMaterial.unit, 'UND');
      expect(category, 'Rodamientos');

      // Verificar que toJson está listo para Supabase
      final json = newMaterial.toJson();
      expect(json['stock'], 10);
      expect(json['cost_price'], 18500);
      expect(json['unit'], 'UND');
    });

    test('simulación: movement audit trail para material existente', () {
      final material = _makeMaterial(stock: 50, unit: 'KG');
      final receivedQty = 15.0;
      final newStock = computeNewStock(material.stock, receivedQty);

      // Simular el insert a material_movements
      final movementData = {
        'material_id': material.id,
        'type': 'entrada',
        'quantity': receivedQty,
        'previous_stock': material.stock,
        'new_stock': newStock,
        'reason': 'Ingreso por factura FE-12345',
        'reference': 'FAC-FE-12345',
      };

      expect(movementData['material_id'], 'mat-1');
      expect(movementData['type'], 'entrada');
      expect(movementData['quantity'], 15.0);
      expect(movementData['previous_stock'], 50.0);
      expect(movementData['new_stock'], 65.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 8. Flujo completo: OCR → items → inventario (sin DB)
  // ═══════════════════════════════════════════════════════════════════
  group('Flujo completo escaneo → inventario', () {
    test(
      'parsea factura OCR, normaliza unidades, mapea items y calcula stock',
      () {
        // Simular respuesta del edge function scan-invoice
        final ocrResponse = {
          'data': {
            'confidence': 0.95,
            'supplier': {
              'name': 'Hierros Colombia S.A.',
              'document_number': '800123456-1',
            },
            'invoice': {
              'number': 'FE-99001',
              'date': '2026-03-25',
              'credit_days': 30,
            },
            'items': [
              {
                'reference_code': 'TB-40-2',
                'description': 'Tubo SCH 40 Ø2" x 6m',
                'quantity': 10,
                'unit': 'MTS',
                'unit_price': 32000,
                'subtotal': 320000,
                'total': 320000,
              },
              {
                'description': 'Soldadura 7018 3/32" x 5kg',
                'quantity': 5,
                'unit': 'KILOS',
                'unit_price': 18000,
                'subtotal': 90000,
                'total': 90000,
              },
              {
                'description': 'Disco de corte 7" x 1/8"',
                'quantity': 50,
                'unit': 'PIEZAS',
                'unit_price': 4500,
                'subtotal': 225000,
                'total': 225000,
              },
            ],
            'totals': {
              'subtotal': 635000,
              'tax_rate': 0,
              'tax_amount': 0,
              'total': 635000,
            },
          },
        };

        // PASO 1: Parsear resultado OCR
        final scanResult = InvoiceScanResult.fromJson(ocrResponse);
        expect(scanResult.items.length, 3);
        expect(scanResult.total, 635000);

        // PASO 2: Normalizar unidades de cada item
        final normalizedUnits = scanResult.items
            .map((item) => normalizeScannedUnit(item.unit))
            .toList();
        expect(normalizedUnits, ['M', 'KG', 'UND']);

        // PASO 3: Inferir categorías
        final categories = scanResult.items
            .map((item) => inferCategoryFromDescription(item.description))
            .toList();
        expect(categories, ['Tubería', 'Soldadura', 'Consumibles']);

        // PASO 4: Construir filas para insert en invoice_items
        final rows = scanResult.items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return buildInvoiceItemRow(
            invoiceId: 'test-invoice-id',
            sortOrder: idx,
            description: item.description,
            referenceCode: item.referenceCode,
            quantity: item.quantity,
            unit: item.unit.isEmpty ? 'UND' : item.unit.toUpperCase(),
            unitPrice: item.unitPrice,
            subtotal: item.subtotal,
            total: item.total,
          );
        }).toList();

        expect(rows.length, 3);
        expect(rows[0]['invoice_id'], 'test-invoice-id');
        expect(rows[0]['quantity'], 10);
        expect(rows[1]['unit'], 'KILOS');
        expect(rows[2]['sort_order'], 2);

        // PASO 5: Simular actualización de stock para materiales existentes
        final existingMaterials = {
          'Tubo SCH 40': mat.Material(
            id: 'mat-tub',
            code: 'TUB-40-2',
            name: 'Tubo SCH 40 2"',
            stock: 50,
            unit: 'M',
            category: 'tubería',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          'Soldadura 7018': mat.Material(
            id: 'mat-sol',
            code: 'SOL-7018',
            name: 'Soldadura 7018',
            stock: 20,
            unit: 'KG',
            category: 'soldadura',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        };

        // Item 0: Tubo → existente → stock 50 + 10 = 60
        final tubeStock = computeNewStock(
          existingMaterials['Tubo SCH 40']!.stock,
          scanResult.items[0].quantity,
        );
        expect(tubeStock, 60);

        // Item 1: Soldadura → existente → stock 20 + 5 = 25
        final soldStock = computeNewStock(
          existingMaterials['Soldadura 7018']!.stock,
          scanResult.items[1].quantity,
        );
        expect(soldStock, 25);

        // Item 2: Disco → nuevo material → stock = quantity = 50
        final discoStock = computeNewStock(0, scanResult.items[2].quantity);
        expect(discoStock, 50);
      },
    );

    test('factura con múltiples ítems del mismo material acumula stock', () {
      // Dos líneas del mismo material en una factura
      final items = [
        ScannedInvoiceItem(
          description: 'Tubo SCH 40 2" x 6m',
          quantity: 10,
          unit: 'M',
          unitPrice: 32000,
          subtotal: 320000,
          total: 320000,
        ),
        ScannedInvoiceItem(
          description: 'Tubo SCH 40 2" x 3m',
          quantity: 5,
          unit: 'M',
          unitPrice: 32000,
          subtotal: 160000,
          total: 160000,
        ),
      ];

      final currentStock = 50.0;
      var newStock = currentStock;
      for (final item in items) {
        newStock = computeNewStock(newStock, item.quantity);
      }
      expect(newStock, 65); // 50 + 10 + 5
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 9. Validaciones del flujo de guardado
  // ═══════════════════════════════════════════════════════════════════
  group('Validaciones de guardado', () {
    test('detecta factura duplicada por normalización de número', () {
      // Simula _normalizeInvoiceNumber
      String normalize(String value) {
        return value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      }

      expect(normalize('FE 22613'), normalize('FE22613'));
      expect(normalize('FE-226.13'), normalize('FE22613'));
      expect(normalize('fe 22613'), normalize('FE22613'));
    });

    test('genera notas de factura con CUFE y observaciones', () {
      final scannedNumber = 'FE-12345';
      final cufe = 'abcdef1234567890';
      final userNotes = 'Entrega parcial';

      final invoiceNotes = [
        'Factura compra escaneada: $scannedNumber',
        if (cufe.isNotEmpty) 'CUFE: $cufe',
        if (userNotes.isNotEmpty) userNotes,
      ].join('\n');

      expect(invoiceNotes, contains('Factura compra escaneada: FE-12345'));
      expect(invoiceNotes, contains('CUFE: abcdef1234567890'));
      expect(invoiceNotes, contains('Entrega parcial'));
    });

    test('calcula fecha de vencimiento a partir de días de crédito', () {
      final invoiceDate = DateTime(2026, 3, 25);
      final creditDays = 30;
      final dueDate = invoiceDate.add(Duration(days: creditDays));

      expect(dueDate, DateTime(2026, 4, 24));
    });
  });
}
