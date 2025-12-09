import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/quotation.dart';
import 'supabase_datasource.dart';

class QuotationsDataSource {
  static const String _table = 'quotations';
  static const String _itemsTable = 'quotation_items';

  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Obtener todas las cotizaciones
  static Future<List<Quotation>> getAll() async {
    final response = await _client
        .from(_table)
        .select()
        .order('date', ascending: false);
    
    List<Quotation> quotations = [];
    for (var json in response) {
      final items = await getItems(json['id']);
      quotations.add(_fromJson(json, items));
    }
    return quotations;
  }

  /// Obtener cotizaciones por estado
  static Future<List<Quotation>> getByStatus(String status) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('status', status)
        .order('date', ascending: false);
    
    List<Quotation> quotations = [];
    for (var json in response) {
      final items = await getItems(json['id']);
      quotations.add(_fromJson(json, items));
    }
    return quotations;
  }

  /// Obtener cotización por ID con items
  static Future<Quotation?> getById(String id) async {
    try {
      final response = await _client.from(_table).select().eq('id', id).single();
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
    // Generar número automático
    final number = await generateNumber();
    
    final data = _toJson(quotation);
    data['number'] = number;
    data.remove('id');
    data.remove('items');
    data.remove('created_at');
    data.remove('updated_at');
    data.remove('synced');
    
    final response = await _client.from(_table).insert(data).select().single();
    final newId = response['id'];
    
    // Insertar items
    for (var i = 0; i < quotation.items.length; i++) {
      await createItem(newId, quotation.items[i], i);
    }
    
    // Retornar cotización con items
    return (await getById(newId))!;
  }

  /// Crear item de cotización
  static Future<QuotationItem> createItem(String quotationId, QuotationItem item, int order) async {
    final data = _itemToJson(item);
    data['quotation_id'] = quotationId;
    data['sort_order'] = order;
    data.remove('id');
    data.remove('created_at');
    
    final response = await _client.from(_itemsTable).insert(data).select().single();
    return _itemFromJson(response);
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

  /// Eliminar cotización
  static Future<void> delete(String id) async {
    // Items se eliminan por CASCADE
    await _client.from(_table).delete().eq('id', id);
  }

  /// Buscar cotizaciones
  static Future<List<Quotation>> search(String query) async {
    final response = await _client
        .from(_table)
        .select()
        .or('number.ilike.%$query%,customer_name.ilike.%$query%')
        .order('date', ascending: false);
    
    List<Quotation> quotations = [];
    for (var json in response) {
      final items = await getItems(json['id']);
      quotations.add(_fromJson(json, items));
    }
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
  static Quotation _fromJson(Map<String, dynamic> json, List<QuotationItem> items) {
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
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      synced: true,
    );
  }

  static Map<String, dynamic> _toJson(Quotation quotation) {
    return {
      'id': quotation.id,
      'number': quotation.number,
      'date': quotation.date.toIso8601String().split('T')[0],
      'valid_until': quotation.validUntil.toIso8601String().split('T')[0],
      'customer_id': quotation.customerId.isNotEmpty ? quotation.customerId : null,
      'customer_name': quotation.customerName,
      'status': quotation.status,
      'materials_cost': quotation.materialsCost,
      'labor_cost': quotation.laborCost,
      'labor_hours': quotation.laborCost / 25, // Asumiendo tarifa por hora
      'labor_rate': 25.00,
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
      quantity: json['quantity'] ?? 1,
      unitWeight: (json['unit_weight'] ?? 0).toDouble(),
      pricePerKg: (json['price_per_kg'] ?? 0).toDouble(),
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
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
      'material_name': item.materialType,
      'material_type': item.materialType,
      'dimensions': item.dimensions,
      'dimensions_text': _formatDimensions(item),
      'quantity': item.quantity,
      'unit_weight': item.unitWeight,
      'total_weight': item.totalWeight,
      'price_per_kg': item.pricePerKg,
      'unit_price': item.unitPrice,
      'total_price': item.totalPrice,
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
