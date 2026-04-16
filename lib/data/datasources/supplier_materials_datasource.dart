import '../../core/utils/colombia_time.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/supplier_material.dart';
import 'audit_log_datasource.dart';
import 'supabase_datasource.dart';

class SupplierMaterialsDataSource {
  static const String _table = 'supplier_materials';

  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Obtener materiales de un proveedor con datos de join
  static Future<List<SupplierMaterial>> getBySupplier(String supplierId) async {
    final response = await _client
        .from(_table)
        .select('*, materials(name, unit, code)')
        .eq('supplier_id', supplierId)
        .order('created_at');
    return response
        .map<SupplierMaterial>((json) => SupplierMaterial.fromJson(json))
        .toList();
  }

  /// Obtener proveedores de un material
  static Future<List<SupplierMaterial>> getByMaterial(String materialId) async {
    final response = await _client
        .from(_table)
        .select('*, proveedores(name)')
        .eq('material_id', materialId)
        .order('is_preferred', ascending: false);
    return response
        .map<SupplierMaterial>((json) => SupplierMaterial.fromJson(json))
        .toList();
  }

  /// Obtener precio de un material con un proveedor específico
  static Future<SupplierMaterial?> getPrice(
    String supplierId,
    String materialId,
  ) async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('supplier_id', supplierId)
          .eq('material_id', materialId)
          .single();
      return SupplierMaterial.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Crear o actualizar relación proveedor-material (upsert)
  static Future<SupplierMaterial> upsert({
    required String supplierId,
    required String materialId,
    required double unitPrice,
    double? minOrderQuantity,
    int? leadTimeDays,
    String? notes,
    bool? isPreferred,
  }) async {
    final data = {
      'supplier_id': supplierId,
      'material_id': materialId,
      'unit_price': unitPrice,
      'last_purchase_price': unitPrice,
      'last_purchase_date': ColombiaTime.nowIso8601(),
      if (minOrderQuantity != null) 'min_order_quantity': minOrderQuantity,
      if (leadTimeDays != null) 'lead_time_days': leadTimeDays,
      if (notes != null) 'notes': notes,
      if (isPreferred != null) 'is_preferred': isPreferred,
    };

    final response = await _client
        .from(_table)
        .upsert(data, onConflict: 'supplier_id,material_id')
        .select()
        .single();
    final result = SupplierMaterial.fromJson(response);
    AuditLogDatasource.log(
      action: 'update',
      module: 'supplier_materials',
      recordId: result.id,
      description:
          'Precio proveedor-material actualizado: \$${unitPrice.toStringAsFixed(2)}',
    );
    return result;
  }

  /// Eliminar relación
  static Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
    AuditLogDatasource.log(
      action: 'delete',
      module: 'supplier_materials',
      recordId: id,
      description: 'Relación proveedor-material eliminada',
    );
  }

  /// Obtener todos los precios (para cálculo de órdenes)
  static Future<List<SupplierMaterial>> getAll() async {
    final response = await _client
        .from(_table)
        .select('*, proveedores(name), materials(name, unit, code)')
        .order('created_at');
    return response
        .map<SupplierMaterial>((json) => SupplierMaterial.fromJson(json))
        .toList();
  }
}
