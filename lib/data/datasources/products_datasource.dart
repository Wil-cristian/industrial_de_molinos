import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/product.dart';
import 'supabase_datasource.dart';

class ProductsDataSource {
  static const String _table = 'products';
  static const String _categoriesTable = 'categories';

  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Obtener todos los productos
  static Future<List<Product>> getAll({bool activeOnly = true}) async {
    var query = _client.from(_table).select();
    
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    
    final response = await query.order('name');
    return response.map<Product>((json) => _fromJson(json)).toList();
  }

  /// Obtener producto por ID
  static Future<Product?> getById(String id) async {
    try {
      final response = await _client.from(_table).select().eq('id', id).single();
      return _fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Buscar productos
  static Future<List<Product>> search(String query) async {
    final response = await _client
        .from(_table)
        .select()
        .or('name.ilike.%$query%,code.ilike.%$query%,description.ilike.%$query%')
        .order('name');
    return response.map<Product>((json) => _fromJson(json)).toList();
  }

  /// Crear producto
  static Future<Product> create(Product product) async {
    final data = _toJson(product);
    data.remove('id');
    data.remove('created_at');
    data.remove('updated_at');
    
    final response = await _client.from(_table).insert(data).select().single();
    return _fromJson(response);
  }

  /// Actualizar producto
  static Future<Product> update(Product product) async {
    final data = _toJson(product);
    data.remove('id');
    data.remove('created_at');
    data.remove('updated_at');
    
    final response = await _client
        .from(_table)
        .update(data)
        .eq('id', product.id)
        .select()
        .single();
    return _fromJson(response);
  }

  /// Eliminar producto (hard delete - elimina completamente)
  static Future<void> delete(String id) async {
    // Primero eliminar componentes relacionados (si es receta)
    await _client.from('product_components').delete().eq('product_id', id);
    // Luego eliminar el producto
    await _client.from(_table).delete().eq('id', id);
  }

  /// Desactivar producto (soft delete - solo marca como inactivo)
  static Future<void> deactivate(String id) async {
    await _client.from(_table).update({'is_active': false}).eq('id', id);
  }

  /// Productos con stock bajo
  static Future<List<Product>> getLowStock() async {
    final response = await _client
        .from('v_low_stock_products')
        .select();
    return response.map<Product>((json) => _fromJson(json)).toList();
  }

  /// Actualizar stock
  static Future<void> updateStock(String id, double newStock) async {
    await _client.from(_table).update({'stock': newStock}).eq('id', id);
  }

  /// Registrar movimiento de stock
  static Future<void> registerStockMovement({
    required String productId,
    required String type, // 'incoming', 'outgoing', 'adjustment'
    required double quantity,
    String? reason,
    String? reference,
  }) async {
    // Obtener stock actual
    final product = await getById(productId);
    if (product == null) throw Exception('Producto no encontrado');
    
    final previousStock = product.stock;
    double newStock;
    
    if (type == 'incoming') {
      newStock = previousStock + quantity;
    } else if (type == 'outgoing') {
      newStock = previousStock - quantity;
      if (newStock < 0) throw Exception('Stock insuficiente');
    } else {
      newStock = quantity; // adjustment = set direct value
    }
    
    // Registrar movimiento
    await _client.from('stock_movements').insert({
      'product_id': productId,
      'type': type,
      'quantity': quantity,
      'previous_stock': previousStock,
      'new_stock': newStock,
      'reason': reason,
      'reference': reference,
    });
    
    // Actualizar stock del producto
    await updateStock(productId, newStock);
  }

  /// Descontar stock para una factura
  static Future<void> deductStockForInvoice(String invoiceId) async {
    try {
      await _client.rpc('deduct_stock_for_invoice', params: {'p_invoice_id': invoiceId});
    } catch (e) {
      print('❌ Error al descontar stock: $e');
      rethrow;
    }
  }

  /// Obtener movimientos de stock de un producto
  static Future<List<Map<String, dynamic>>> getStockMovements(String productId) async {
    final response = await _client
        .from('stock_movements')
        .select()
        .eq('product_id', productId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Obtener todas las categorías
  static Future<List<Category>> getCategories() async {
    final response = await _client.from(_categoriesTable).select().order('name');
    return response.map<Category>((json) => Category(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      parentId: json['parent_id'],
      createdAt: DateTime.parse(json['created_at']),
    )).toList();
  }

  // Helpers de conversión
  static Product _fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      categoryId: json['category_id'],
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      costPrice: (json['cost_price'] ?? 0).toDouble(),
      stock: (json['stock'] ?? 0).toDouble(),
      minStock: (json['min_stock'] ?? 0).toDouble(),
      unit: json['unit'] ?? 'UND',
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      isRecipe: json['is_recipe'] ?? false,
      recipeDescription: json['recipe_description'],
      totalWeight: (json['total_weight'] ?? 0).toDouble(),
      totalCost: (json['total_cost'] ?? 0).toDouble(),
    );
  }

  static Map<String, dynamic> _toJson(Product product) {
    return {
      'id': product.id,
      'code': product.code,
      'name': product.name,
      'description': product.description,
      'category_id': product.categoryId,
      'unit_price': product.unitPrice,
      'cost_price': product.costPrice,
      'stock': product.stock,
      'min_stock': product.minStock,
      'unit': product.unit,
      'is_active': product.isActive,
      'created_at': product.createdAt.toIso8601String(),
      'updated_at': product.updatedAt.toIso8601String(),
      'is_recipe': product.isRecipe,
      'recipe_description': product.recipeDescription,
      'total_weight': product.totalWeight,
      'total_cost': product.totalCost,
    };
  }
}
