import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/material.dart';
import 'supabase_datasource.dart';

/// DataSource para la tabla 'materials' (inventario de materia prima)
class InventoryDataSource {
  static const String _table = 'materials';
  static const String _componentsTable = 'product_components';

  static SupabaseClient get _client => SupabaseDataSource.client;

  // ==================== MATERIALS ====================

  /// Obtener todos los materiales
  static Future<List<Material>> getAllMaterials({bool activeOnly = true}) async {
    var query = _client.from(_table).select();
    
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    
    final response = await query.order('category').order('name');
    return response.map<Material>((json) => Material.fromJson(json)).toList();
  }

  /// Obtener materiales por categoría
  static Future<List<Material>> getMaterialsByCategory(String category) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('category', category)
        .eq('is_active', true)
        .order('name');
    return response.map<Material>((json) => Material.fromJson(json)).toList();
  }

  /// Obtener material por ID
  static Future<Material?> getMaterialById(String id) async {
    try {
      final response = await _client.from(_table).select().eq('id', id).single();
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

  /// Crear material
  static Future<Material> createMaterial(Material material) async {
    final data = material.toJson();
    final response = await _client.from(_table).insert(data).select().single();
    return Material.fromJson(response);
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
    return Material.fromJson(response);
  }

  /// Eliminar material (soft delete)
  static Future<void> deleteMaterial(String id) async {
    await _client.from(_table).update({'is_active': false}).eq('id', id);
  }

  /// Actualizar stock de material
  static Future<void> updateStock(String id, double newStock) async {
    await _client.from(_table).update({
      'stock': newStock,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Ajustar stock (incrementar/decrementar)
  static Future<void> adjustStock(String id, double adjustment) async {
    final material = await getMaterialById(id);
    if (material != null) {
      await updateStock(id, material.stock + adjustment);
    }
  }

  // ==================== PRODUCT COMPONENTS ====================

  /// Obtener componentes de un producto/receta
  static Future<List<ProductComponent>> getProductComponents(String productId) async {
    final response = await _client
        .from(_componentsTable)
        .select()
        .eq('product_id', productId)
        .order('sort_order');
    return response.map<ProductComponent>((json) => ProductComponent.fromJson(json)).toList();
  }

  /// Crear componente
  static Future<ProductComponent> createComponent(ProductComponent component) async {
    final data = component.toJson();
    final response = await _client.from(_componentsTable).insert(data).select().single();
    return ProductComponent.fromJson(response);
  }

  /// Actualizar componente
  static Future<ProductComponent> updateComponent(ProductComponent component) async {
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
    await _client.rpc('update_product_totals', params: {'p_product_id': productId});
  }

  // ==================== FUNCIONES RPC ====================

  /// Verificar stock para una receta
  static Future<List<Map<String, dynamic>>> checkRecipeStock(String productId, {int quantity = 1}) async {
    final response = await _client.rpc('check_recipe_stock', params: {
      'p_product_id': productId,
      'p_quantity': quantity,
    });
    return List<Map<String, dynamic>>.from(response);
  }

  /// Agregar receta a cotización
  static Future<void> addRecipeToQuotation(String quotationId, String productId, {int quantity = 1}) async {
    await _client.rpc('add_recipe_to_quotation', params: {
      'p_quotation_id': quotationId,
      'p_product_id': productId,
      'p_quantity': quantity,
    });
  }
}
