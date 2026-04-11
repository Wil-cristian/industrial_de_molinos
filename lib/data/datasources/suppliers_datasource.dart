import '../../core/utils/colombia_time.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/supplier.dart';
import 'supabase_datasource.dart';
import 'audit_log_datasource.dart';

class SuppliersDataSource {
  static const String _table = 'proveedores';

  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Obtener todos los proveedores
  static Future<List<Supplier>> getAll({bool activeOnly = true}) async {
    var query = _client.from(_table).select();

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    final response = await query.order('name', ascending: true);
    return response.map<Supplier>((json) => Supplier.fromJson(json)).toList();
  }

  /// Obtener proveedor por ID
  static Future<Supplier?> getById(String id) async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('id', id)
          .single();
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
        .or(
          'name.ilike.%$query%,document_number.ilike.%$query%,trade_name.ilike.%$query%',
        )
        .order('name', ascending: false);
    return response.map<Supplier>((json) => Supplier.fromJson(json)).toList();
  }

  /// Crear proveedor
  static Future<Supplier> create(Supplier supplier) async {
    final data = supplier.toJson();
    data.remove('id');
    data.remove('created_at');
    data.remove('updated_at');

    final response = await _client.from(_table).insert(data).select().single();
    final created = Supplier.fromJson(response);
    AuditLogDatasource.log(
      action: 'create',
      module: 'suppliers',
      recordId: created.id,
      description: 'Creó proveedor: ${created.name}',
    );
    return created;
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
    final created = Supplier.fromJson(response);
    AuditLogDatasource.log(
      action: 'create',
      module: 'suppliers',
      recordId: created.id,
      description: 'Creó proveedor rápido: ${created.name}',
    );
    return created;
  }

  /// Actualizar proveedor
  static Future<Supplier> update(Supplier supplier) async {
    final data = supplier.toJson();
    data.remove('id');
    data.remove('created_at');
    data['updated_at'] = ColombiaTime.nowIso8601();

    final response = await _client
        .from(_table)
        .update(data)
        .eq('id', supplier.id)
        .select()
        .single();
    final updated = Supplier.fromJson(response);
    AuditLogDatasource.log(
      action: 'update',
      module: 'suppliers',
      recordId: updated.id,
      description: 'Actualizó proveedor: ${updated.name}',
    );
    return updated;
  }

  /// Eliminar (desactivar) proveedor
  static Future<void> delete(String id) async {
    await _client.from(_table).update({'is_active': false}).eq('id', id);
    AuditLogDatasource.log(
      action: 'delete',
      module: 'suppliers',
      recordId: id,
      description: 'Desactivó proveedor',
    );
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
