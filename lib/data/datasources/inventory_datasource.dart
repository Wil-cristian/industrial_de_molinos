import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/material.dart';
import 'audit_log_datasource.dart';
import 'supabase_datasource.dart';

/// DataSource para la tabla 'materials' (inventario de materia prima)
class InventoryDataSource {
  static const String _table = 'materials';
  static const String _componentsTable = 'product_components';

  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Exposed client for direct queries in dialogs
  static SupabaseClient get client => SupabaseDataSource.client;

  // ==================== MATERIALS ====================

  /// Obtener todos los materiales
  static Future<List<Material>> getAllMaterials({
    bool activeOnly = true,
  }) async {
    var query = _client.from(_table).select();

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    final response = await query
        .order('category', ascending: false)
        .order('name', ascending: false);
    return response.map<Material>((json) => Material.fromJson(json)).toList();
  }

  /// Obtener materiales por categoría
  static Future<List<Material>> getMaterialsByCategory(String category) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('category', category)
        .eq('is_active', true)
        .order('name', ascending: false);
    return response.map<Material>((json) => Material.fromJson(json)).toList();
  }

  /// Obtener material por ID
  static Future<Material?> getMaterialById(String id) async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('id', id)
          .single();
      return Material.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Obtener categorías disponibles
  static Future<List<String>> getCategories() async {
    final response = await _client
        .from(_table)
        .select('category')
        .eq('is_active', true);

    final categories = <String>{};
    for (var item in response) {
      if (item['category'] != null) {
        categories.add(item['category'] as String);
      }
    }
    return categories.toList()..sort();
  }

  /// Obtener el siguiente número secuencial para un prefijo de código.
  /// Busca materiales cuyo código empiece con [prefix] y retorna max+1.
  static Future<int> getNextSequential(String prefix) async {
    final response = await _client
        .from(_table)
        .select('code')
        .ilike('code', '$prefix-%');

    int maxSeq = 0;
    for (final row in response) {
      final code = row['code'] as String? ?? '';
      // El secuencial es la última parte después del último guión
      final lastDash = code.lastIndexOf('-');
      if (lastDash >= 0 && lastDash < code.length - 1) {
        final seqStr = code.substring(lastDash + 1);
        final seq = int.tryParse(seqStr) ?? 0;
        if (seq > maxSeq) maxSeq = seq;
      }
    }
    return maxSeq + 1;
  }

  /// Crear material
  static Future<Material> createMaterial(Material material) async {
    final data = material.toJson();
    final response = await _client.from(_table).insert(data).select().single();
    final created = Material.fromJson(response);
    AuditLogDatasource.log(
      action: 'create',
      module: 'inventory',
      recordId: created.id,
      description: 'Material creado: ${created.name}',
    );
    return created;
  }

  /// Actualizar material
  static Future<Material> updateMaterial(Material material) async {
    final data = material.toJson();
    final response = await _client
        .from(_table)
        .update(data)
        .eq('id', material.id)
        .select()
        .single();
    AuditLogDatasource.log(
      action: 'update',
      module: 'inventory',
      recordId: material.id,
      description: 'Material actualizado: ${material.name}',
    );
    return Material.fromJson(response);
  }

  /// Eliminar material (soft delete)
  static Future<void> deleteMaterial(String id) async {
    await _client.from(_table).update({'is_active': false}).eq('id', id);
    AuditLogDatasource.log(
      action: 'delete',
      module: 'inventory',
      recordId: id,
      description: 'Material desactivado',
    );
  }

  /// Actualizar stock de material
  static Future<void> updateStock(String id, double newStock) async {
    try {
      await _client
          .from(_table)
          .update({
            'stock': newStock,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);
    } catch (e) {
      if (e.toString().contains('Stock insuficiente') ||
          e.toString().contains('chk_materials_stock_non_negative')) {
        throw Exception(
          'Stock insuficiente: no se puede establecer un stock negativo',
        );
      }
      rethrow;
    }
  }

  /// Ajustar stock (incrementar/decrementar)
  static Future<void> adjustStock(String id, double adjustment) async {
    final material = await getMaterialById(id);
    if (material != null) {
      final newStock = material.stock + adjustment;
      if (newStock < 0) {
        throw Exception(
          'Stock insuficiente para "${material.name}": disponible ${material.stock}, solicitado ${adjustment.abs()}',
        );
      }
      await updateStock(id, newStock);
      AuditLogDatasource.log(
        action: 'update',
        module: 'inventory',
        recordId: id,
        description:
            'Stock ajustado: ${material.name} ${adjustment >= 0 ? "+" : ""}${adjustment.toStringAsFixed(2)} → ${newStock.toStringAsFixed(2)}',
      );
    }
  }

  // ==================== PRODUCT COMPONENTS ====================

  /// Obtener componentes de un producto/receta
  static Future<List<ProductComponent>> getProductComponents(
    String productId,
  ) async {
    final response = await _client
        .from(_componentsTable)
        .select()
        .eq('product_id', productId)
        .order('sort_order');
    return response
        .map<ProductComponent>((json) => ProductComponent.fromJson(json))
        .toList();
  }

  /// Crear componente
  static Future<ProductComponent> createComponent(
    ProductComponent component,
  ) async {
    final data = component.toJson();
    final response = await _client
        .from(_componentsTable)
        .insert(data)
        .select()
        .single();
    return ProductComponent.fromJson(response);
  }

  /// Actualizar componente
  static Future<ProductComponent> updateComponent(
    ProductComponent component,
  ) async {
    final data = component.toJson();
    final response = await _client
        .from(_componentsTable)
        .update(data)
        .eq('id', component.id)
        .select()
        .single();
    return ProductComponent.fromJson(response);
  }

  /// Eliminar componente
  static Future<void> deleteComponent(String id) async {
    await _client.from(_componentsTable).delete().eq('id', id);
  }

  /// Eliminar todos los componentes de un producto
  static Future<void> deleteAllComponents(String productId) async {
    await _client.from(_componentsTable).delete().eq('product_id', productId);
  }

  /// Actualizar totales del producto (llamar después de modificar componentes)
  static Future<void> updateProductTotals(String productId) async {
    await _client.rpc(
      'update_product_totals',
      params: {'p_product_id': productId},
    );
  }

  // ==================== FUNCIONES RPC ====================

  /// Verificar stock para una receta
  static Future<List<Map<String, dynamic>>> checkRecipeStock(
    String productId, {
    int quantity = 1,
  }) async {
    final response = await _client.rpc(
      'check_recipe_stock',
      params: {'p_product_id': productId, 'p_quantity': quantity},
    );
    return List<Map<String, dynamic>>.from(response);
  }

  /// Verificar stock consolidado de TODA la cotización
  /// Agrega todos los materiales de todas las recetas y materiales directos
  static Future<List<Map<String, dynamic>>> checkQuotationStock(
    String quotationId,
  ) async {
    final response = await _client.rpc(
      'check_quotation_stock',
      params: {'p_quotation_id': quotationId},
    );
    return List<Map<String, dynamic>>.from(response);
  }

  /// Agregar receta a cotización
  static Future<void> addRecipeToQuotation(
    String quotationId,
    String productId, {
    int quantity = 1,
  }) async {
    await _client.rpc(
      'add_recipe_to_quotation',
      params: {
        'p_quotation_id': quotationId,
        'p_product_id': productId,
        'p_quantity': quantity,
      },
    );
  }

  /// Obtener precios EN VIVO de una receta desde el inventario de materiales
  /// Recalcula costos y precios de venta usando los precios ACTUALES de cada material
  static Future<Map<String, dynamic>?> getRecipeLivePricing(
    String productId,
  ) async {
    try {
      final response = await _client.rpc(
        'get_recipe_live_pricing',
        params: {'p_product_id': productId},
      );
      if (response is Map<String, dynamic>) {
        return response;
      }
      // Some Supabase versions return a list with single element
      if (response is List && response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first);
      }
      return null;
    } catch (e) {
      // If the RPC doesn't exist yet, return null gracefully
      debugPrint('getRecipeLivePricing error: $e');
      return null;
    }
  }
}
