import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/supplier.dart';
import 'supabase_datasource.dart';

class SuppliersDataSource {
  static const String _table = 'proveedores';

  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Obtener todos los proveedores
  static Future<List<Supplier>> getAll({bool activeOnly = true}) async {
    var query = _client.from(_table).select();
    
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    
    final response = await query.order('name');
    return response.map<Supplier>((json) => Supplier.fromJson(json)).toList();
  }

  /// Obtener proveedor por ID
  static Future<Supplier?> getById(String id) async {
    try {
      final response = await _client.from(_table).select().eq('id', id).single();
      return Supplier.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Buscar proveedores por nombre o documento
  static Future<List<Supplier>> search(String query) async {
    final response = await _client
        .from(_table)
        .select()
        .or('name.ilike.%$query%,document_number.ilike.%$query%,trade_name.ilike.%$query%')
        .order('name');
    return response.map<Supplier>((json) => Supplier.fromJson(json)).toList();
  }

  /// Crear proveedor
  static Future<Supplier> create(Supplier supplier) async {
    final data = supplier.toJson();
    data.remove('id');
    data.remove('created_at');
    data.remove('updated_at');
    
    final response = await _client.from(_table).insert(data).select().single();
    return Supplier.fromJson(response);
  }

  /// Crear proveedor rápido (solo nombre y documento)
  static Future<Supplier> createQuick({
    required String name,
    String documentType = 'RUC',
    String documentNumber = '',
    SupplierType type = SupplierType.business,
  }) async {
    final data = {
      'name': name,
      'document_type': documentType,
      'document_number': documentNumber,
      'type': type.name,
      'is_active': true,
    };
    
    final response = await _client.from(_table).insert(data).select().single();
    return Supplier.fromJson(response);
  }

  /// Actualizar proveedor
  static Future<Supplier> update(Supplier supplier) async {
    final data = supplier.toJson();
    data.remove('id');
    data.remove('created_at');
    data['updated_at'] = DateTime.now().toIso8601String();
    
    final response = await _client
        .from(_table)
        .update(data)
        .eq('id', supplier.id)
        .select()
        .single();
    return Supplier.fromJson(response);
  }

  /// Eliminar (desactivar) proveedor
  static Future<void> delete(String id) async {
    await _client.from(_table).update({'is_active': false}).eq('id', id);
  }

  /// Actualizar deuda del proveedor
  static Future<void> updateDebt(String supplierId, double amount) async {
    // amount positivo = aumenta deuda (compramos), negativo = disminuye (pagamos)
    final current = await getById(supplierId);
    if (current != null) {
      final newDebt = current.currentDebt + amount;
      await _client
          .from(_table)
          .update({'current_debt': newDebt})
          .eq('id', supplierId);
    }
  }
}
