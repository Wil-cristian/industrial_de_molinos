import '../../core/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/quotation.dart';
import 'supabase_datasource.dart';

class QuotationsDataSource {
  static const String _table = 'quotations';
  static const String _itemsTable = 'quotation_items';

  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Obtener todas las cotizaciones (con items en batch para evitar N+1)
  static Future<List<Quotation>> getAll() async {
    final response = await _client
        .from(_table)
        .select()
        .order('date', ascending: false);

    if (response.isEmpty) return [];

    // Cargar TODOS los items en una sola consulta
    final allIds = response.map<String>((q) => q['id'] as String).toList();
    final allItemsResponse = await _client
        .from(_itemsTable)
        .select()
        .inFilter('quotation_id', allIds)
        .order('sort_order');

    // Agrupar items por quotation_id
    final itemsByQuotation = <String, List<QuotationItem>>{};
    for (var itemJson in allItemsResponse) {
      final qId = itemJson['quotation_id'] as String;
      itemsByQuotation.putIfAbsent(qId, () => []);
      itemsByQuotation[qId]!.add(_itemFromJson(itemJson));
    }

    return response.map((json) {
      final items = itemsByQuotation[json['id']] ?? [];
      return _fromJson(json, items);
    }).toList();
  }

  /// Obtener cotizaciones por estado
  static Future<List<Quotation>> getByStatus(String status) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('status', status)
        .order('date', ascending: false);

    if (response.isEmpty) return [];

    // Batch load items
    final allIds = response.map<String>((q) => q['id'] as String).toList();
    final allItemsResponse = await _client
        .from(_itemsTable)
        .select()
        .inFilter('quotation_id', allIds)
        .order('sort_order');

    final itemsByQuotation = <String, List<QuotationItem>>{};
    for (var itemJson in allItemsResponse) {
      final qId = itemJson['quotation_id'] as String;
      itemsByQuotation.putIfAbsent(qId, () => []);
      itemsByQuotation[qId]!.add(_itemFromJson(itemJson));
    }

    return response.map((json) {
      final items = itemsByQuotation[json['id']] ?? [];
      return _fromJson(json, items);
    }).toList();
  }

  /// Obtener cotización por ID con items
  static Future<Quotation?> getById(String id) async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('id', id)
          .single();
      final items = await getItems(id);
      return _fromJson(response, items);
    } catch (e) {
      return null;
    }
  }

  /// Obtener items de una cotización
  static Future<List<QuotationItem>> getItems(String quotationId) async {
    final response = await _client
        .from(_itemsTable)
        .select()
        .eq('quotation_id', quotationId)
        .order('sort_order');
    return response.map<QuotationItem>((json) => _itemFromJson(json)).toList();
  }

  /// Generar nuevo número de cotización
  static Future<String> generateNumber() async {
    final response = await _client.rpc('generate_quotation_number');
    return response as String;
  }

  /// Crear cotización
  static Future<Quotation> create(Quotation quotation) async {
    try {
      // Generar número automático
      AppLogger.debug('📝 Generando número de cotización...');
      final number = await generateNumber();
      AppLogger.success('✅ Número generado: $number');

      final data = _toJson(quotation);
      data['number'] = number;
      data.remove('id');
      data.remove('items');
      data.remove('created_at');
      data.remove('updated_at');
      data.remove('synced');

      AppLogger.debug('📤 Insertando cotización: $data');
      final response = await _client
          .from(_table)
          .insert(data)
          .select()
          .single();
      final newId = response['id'];
      AppLogger.success('✅ Cotización creada con ID: $newId');

      // Insertar items
      AppLogger.debug('📝 Insertando ${quotation.items.length} items...');
      for (var i = 0; i < quotation.items.length; i++) {
        AppLogger.debug('Item $i: ${quotation.items[i].name}');
        await createItem(newId, quotation.items[i], i);
      }
      AppLogger.success('✅ Items insertados');

      // Retornar cotización con items
      return (await getById(newId))!;
    } catch (e, stack) {
      AppLogger.error('❌ Error al crear cotización: $e');
      AppLogger.error('Stack: $stack');
      rethrow;
    }
  }

  /// Crear item de cotización
  static Future<QuotationItem> createItem(
    String quotationId,
    QuotationItem item,
    int order,
  ) async {
    try {
      final data = _itemToJson(item);
      data['quotation_id'] = quotationId;
      data['sort_order'] = order;
      data.remove('id');
      data.remove('created_at');

      AppLogger.debug('📤 Insertando item: $data');
      final response = await _client
          .from(_itemsTable)
          .insert(data)
          .select()
          .single();
      AppLogger.success('✅ Item insertado');
      return _itemFromJson(response);
    } catch (e) {
      AppLogger.error('❌ Error insertando item: $e');
      rethrow;
    }
  }

  /// Actualizar cotización
  static Future<Quotation> update(Quotation quotation) async {
    final data = _toJson(quotation);
    data.remove('id');
    data.remove('items');
    data.remove('number');
    data.remove('created_at');
    data.remove('updated_at');
    data.remove('synced');

    await _client.from(_table).update(data).eq('id', quotation.id);

    // Eliminar items existentes y recrear
    await _client.from(_itemsTable).delete().eq('quotation_id', quotation.id);

    for (var i = 0; i < quotation.items.length; i++) {
      await createItem(quotation.id, quotation.items[i], i);
    }

    return (await getById(quotation.id))!;
  }

  /// Actualizar estado
  static Future<void> updateStatus(String id, String status) async {
    await _client.from(_table).update({'status': status}).eq('id', id);
  }

  /// Aprobar cotización y crear factura automáticamente (con descuento de materiales)
  static Future<Map<String, dynamic>?> approveAndCreateInvoice(
    String quotationId, {
    String series = 'F001',
    bool deductMaterials = true,
  }) async {
    try {
      AppLogger.debug('📋 Aprobando cotización: $quotationId');
      final response = await _client.rpc(
        'approve_quotation_with_materials',
        params: {
          'p_quotation_id': quotationId,
          'p_series': series,
          'p_deduct_materials': deductMaterials,
        },
      );

      AppLogger.success('✅ Respuesta de aprobación:');
      AppLogger.debug(' Response: $response');
      if (response is Map<String, dynamic>) {
        AppLogger.debug(' Invoice: ${response['invoice_number']}');
        AppLogger.debug(' Items procesados: ${response['items_processed']}');
        AppLogger.debug(' Descuentos: ${response['deductions']}');
      }

      return response as Map<String, dynamic>?;
    } catch (e) {
      // NO usar fallback silencioso — la función con descuento de materiales es obligatoria
      AppLogger.error(
        '❌ Error al aprobar cotización con descuento de inventario: $e',
      );

      // Si el error es que la función no existe, dar instrucciones claras
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('function') &&
          (errorMsg.contains('not exist') ||
              errorMsg.contains('does not exist') ||
              errorMsg.contains('could not find'))) {
        throw Exception(
          'La función approve_quotation_with_materials no existe en Supabase. '
          'Ejecute la migración 036_bulk_inventory_operations.sql en el SQL Editor de Supabase.',
        );
      }
      rethrow;
    }
  }

  /// Rechazar cotización
  static Future<void> reject(String quotationId, {String? reason}) async {
    try {
      await _client.rpc(
        'reject_quotation',
        params: {'p_quotation_id': quotationId, 'p_reason': reason},
      );
    } catch (e) {
      AppLogger.error('❌ Error al rechazar cotización: $e');
      rethrow;
    }
  }

  /// Verificar disponibilidad de stock para cotización
  static Future<List<Map<String, dynamic>>> checkStockAvailability(
    String quotationId,
  ) async {
    try {
      final response = await _client.rpc(
        'check_stock_availability',
        params: {'p_quotation_id': quotationId},
      );
      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      AppLogger.error('❌ Error al verificar stock: $e');
      return [];
    }
  }

  /// Eliminar cotización (solo borradores, usa RPC segura)
  static Future<void> delete(String id) async {
    try {
      await _client.rpc(
        'safe_delete_quotation',
        params: {'p_quotation_id': id},
      );
    } catch (e) {
      // Fallback directo si la RPC no existe aún
      if (e.toString().contains('could not find')) {
        await _client.from(_table).delete().eq('id', id);
      } else {
        rethrow;
      }
    }
  }

  /// Anular cotización atómicamente con blindaje anti-fraude
  /// Si la factura asociada tiene pagos, la anulación será BLOQUEADA
  static Future<Map<String, dynamic>> annulQuotation(
    String quotationId, {
    String reason = 'Anulada por el usuario',
  }) async {
    try {
      AppLogger.debug('🔒 Anulación segura de cotización: $quotationId');
      final response = await _client.rpc(
        'secure_annul_quotation',
        params: {'p_quotation_id': quotationId, 'p_reason': reason},
      );
      final result = Map<String, dynamic>.from(response ?? {});

      if (result['success'] == true) {
        AppLogger.success('✅ Cotización anulada: $result');
      } else if (result['blocked'] == true) {
        AppLogger.warning('🚫 Anulación bloqueada: ${result['reason']}');
      }

      return result;
    } catch (e) {
      AppLogger.error('❌ Error al anular cotización: $e');
      rethrow;
    }
  }

  /// Buscar cotizaciones
  static Future<List<Quotation>> search(String query) async {
    final response = await _client
        .from(_table)
        .select()
        .or('number.ilike.%$query%,customer_name.ilike.%$query%')
        .order('date', ascending: false);

    if (response.isEmpty) return [];

    // Batch load items
    final allIds = response.map<String>((q) => q['id'] as String).toList();
    final allItemsResponse = await _client
        .from(_itemsTable)
        .select()
        .inFilter('quotation_id', allIds)
        .order('sort_order');

    final itemsByQuotation = <String, List<QuotationItem>>{};
    for (var itemJson in allItemsResponse) {
      final qId = itemJson['quotation_id'] as String;
      itemsByQuotation.putIfAbsent(qId, () => []);
      itemsByQuotation[qId]!.add(_itemFromJson(itemJson));
    }

    List<Quotation> quotations = response.map((json) {
      final items = itemsByQuotation[json['id']] ?? [];
      return _fromJson(json, items);
    }).toList();
    return quotations;
  }

  /// Cotizaciones pendientes (vista)
  static Future<List<Map<String, dynamic>>> getPending() async {
    final response = await _client
        .from('v_pending_quotations')
        .select()
        .order('valid_until');
    return List<Map<String, dynamic>>.from(response);
  }

  // Helpers de conversión
  static Quotation _fromJson(
    Map<String, dynamic> json,
    List<QuotationItem> items,
  ) {
    return Quotation(
      id: json['id'],
      number: json['number'],
      date: DateTime.parse(json['date']),
      validUntil: DateTime.parse(json['valid_until']),
      customerId: json['customer_id'] ?? '',
      customerName: json['customer_name'] ?? '',
      status: json['status'] ?? 'Borrador',
      items: items,
      laborCost: (json['labor_cost'] ?? 0).toDouble(),
      energyCost: (json['energy_cost'] ?? 0).toDouble(),
      gasCost: (json['gas_cost'] ?? 0).toDouble(),
      suppliesCost: (json['supplies_cost'] ?? 0).toDouble(),
      otherCosts: (json['other_costs'] ?? 0).toDouble(),
      profitMargin: (json['profit_margin'] ?? 20).toDouble(),
      notes: json['notes'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      synced: true,
    );
  }

  static Map<String, dynamic> _toJson(Quotation quotation) {
    return {
      'id': quotation.id,
      'number': quotation.number,
      'date': quotation.date.toIso8601String().split('T')[0],
      'valid_until': quotation.validUntil.toIso8601String().split('T')[0],
      'customer_id': quotation.customerId.isNotEmpty
          ? quotation.customerId
          : null,
      'customer_name': quotation.customerName,
      'status': quotation.status,
      'materials_cost': quotation.materialsCost,
      'labor_cost': quotation.laborCost,
      'energy_cost': quotation.energyCost,
      'gas_cost': quotation.gasCost,
      'supplies_cost': quotation.suppliesCost,
      'other_costs': quotation.otherCosts,
      'subtotal': quotation.subtotal,
      'profit_margin': quotation.profitMargin,
      'profit_amount': quotation.profitAmount,
      'total': quotation.total,
      'total_weight': quotation.totalWeight,
      'notes': quotation.notes,
      'created_at': quotation.createdAt.toIso8601String(),
      'updated_at': quotation.updatedAt?.toIso8601String(),
    };
  }

  static QuotationItem _itemFromJson(Map<String, dynamic> json) {
    return QuotationItem(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      type: json['type'] ?? 'custom',
      productId: json['product_id'],
      materialId:
          json['material_id'], // Columna correcta (inv_material_id fue eliminada en migración 028)
      quantity: json['quantity'] ?? 1,
      unitWeight: (json['unit_weight'] ?? 0).toDouble(),
      pricePerKg: (json['price_per_kg'] ?? 0).toDouble(),
      costPerKg: (json['cost_per_kg'] ?? 0).toDouble(),
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      unitCost: (json['unit_cost'] ?? 0).toDouble(),
      dimensions: json['dimensions'] ?? {},
      materialType: json['material_type'] ?? json['material_name'] ?? '',
    );
  }

  static Map<String, dynamic> _itemToJson(QuotationItem item) {
    return {
      'id': item.id,
      'name': item.name,
      'description': item.description,
      'type': item.type,
      'product_id': item.productId,
      'material_id': item.materialId, // FK a materials(id)
      'material_name': item.materialType,
      'material_type': item.materialType,
      'dimensions': item.dimensions,
      'dimensions_text': _formatDimensions(item),
      'quantity': item.quantity,
      'unit_weight': item.unitWeight,
      'total_weight': item.totalWeight,
      'price_per_kg': item.pricePerKg,
      'cost_per_kg': item.costPerKg,
      'unit_price': item.unitPrice,
      'unit_cost': item.unitCost,
      'total_price': item.totalPrice,
      'total_cost': item.totalCost,
    };
  }

  static String _formatDimensions(QuotationItem item) {
    final dims = item.dimensions;
    switch (item.type) {
      case 'cylinder':
        return 'Ø${dims['diameter']}mm × ${dims['thickness']}mm × ${dims['length']}mm';
      case 'circular_plate':
        return 'Ø${dims['diameter']}mm × ${dims['thickness']}mm';
      case 'rectangular_plate':
        return '${dims['width']}mm × ${dims['length']}mm × ${dims['thickness']}mm';
      case 'shaft':
        return 'Ø${dims['diameter']}mm × ${dims['length']}mm';
      case 'ring':
        return 'Øext ${dims['outerDiameter']}mm × Øint ${dims['innerDiameter']}mm × ${dims['thickness']}mm';
      default:
        return '';
    }
  }
}
