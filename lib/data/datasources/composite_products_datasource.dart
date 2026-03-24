import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/composite_product.dart';
import 'supabase_datasource.dart';

/// DataSource unificado para productos compuestos
/// Lee/escribe en: products (is_recipe=true) + product_components
class CompositeProductsDataSource {
  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Obtener todos los productos compuestos con sus componentes
  static Future<List<CompositeProduct>> getAll() async {
    try {
      // 1. Obtener TODOS los productos activos (compuestos y simples)
      final productsResponse = await _client
          .from('products')
          .select()
          .eq('is_active', true)
          .order('name');

      if (productsResponse.isEmpty) return [];

      // 2. Obtener IDs de productos que son recetas (para cargar componentes)
      final recipeIds = productsResponse
          .where((p) => p['is_recipe'] == true)
          .map<String>((p) => p['id'] as String)
          .toList();

      // 3. Obtener componentes solo para productos receta (con precios EN VIVO)
      final Map<String, List<Map<String, dynamic>>> componentsByProduct = {};
      if (recipeIds.isNotEmpty) {
        final componentsResponse = await _client
            .from('product_components')
            .select(
              '*, materials:material_id(price_per_kg, unit_price, cost_price, name, code)',
            )
            .inFilter('product_id', recipeIds)
            .order('sort_order');

        // 4. Agrupar componentes por product_id, inyectando precios VIVO del material
        for (final comp in componentsResponse) {
          final pid = comp['product_id'] as String;

          final materialData = comp['materials'] as Map<String, dynamic>?;
          if (materialData != null) {
            final liveSalePerKg =
                (materialData['price_per_kg'] as num?)?.toDouble() ?? 0;
            final liveUnitPrice =
                (materialData['unit_price'] as num?)?.toDouble() ?? 0;
            final liveCostPerKg =
                (materialData['cost_price'] as num?)?.toDouble() ?? 0;
            final weightPerUnit =
                (comp['calculated_weight'] as num?)?.toDouble() ?? 0;

            // Precio VENTA: usar price_per_kg × peso, o unit_price si no hay precio por kg
            comp['unit_cost'] = liveSalePerKg > 0
                ? weightPerUnit * liveSalePerKg
                : liveUnitPrice;
            comp['live_cost'] = weightPerUnit * liveCostPerKg;
            comp['material_name'] ??= materialData['name'];
            comp['material_code'] ??= materialData['code'];
          }
          comp.remove('materials');

          componentsByProduct.putIfAbsent(pid, () => []);
          componentsByProduct[pid]!.add(comp);
        }
      }

      // 5. Construir la lista de CompositeProduct
      return productsResponse.map<CompositeProduct>((json) {
        final pid = json['id'] as String;
        return CompositeProduct.fromSupabase(
          json,
          componentsByProduct[pid] ?? [],
        );
      }).toList();
    } catch (e) {
      AppLogger.error('❌ Error cargando productos compuestos: $e');
      rethrow;
    }
  }

  /// Obtener un producto compuesto por ID (con precios EN VIVO de materiales)
  static Future<CompositeProduct> getById(String id) async {
    final productResponse = await _client
        .from('products')
        .select()
        .eq('id', id)
        .single();

    final componentsResponse = await _client
        .from('product_components')
        .select(
          '*, materials:material_id(price_per_kg, unit_price, cost_price, name, code)',
        )
        .eq('product_id', id)
        .order('sort_order');

    // SIEMPRE inyectar precios EN VIVO del material (COMPRA y VENTA)
    for (final comp in componentsResponse) {
      final materialData = comp['materials'] as Map<String, dynamic>?;
      if (materialData != null) {
        final liveSalePerKg =
            (materialData['price_per_kg'] as num?)?.toDouble() ?? 0;
        final liveUnitPrice =
            (materialData['unit_price'] as num?)?.toDouble() ?? 0;
        final liveCostPerKg =
            (materialData['cost_price'] as num?)?.toDouble() ?? 0;
        final weightPerUnit =
            (comp['calculated_weight'] as num?)?.toDouble() ?? 0;

        // Precio VENTA: usar price_per_kg × peso, o unit_price si no hay precio por kg
        comp['unit_cost'] = liveSalePerKg > 0
            ? weightPerUnit * liveSalePerKg
            : liveUnitPrice;

        // Precio COMPRA por pieza = peso × precio_compra_por_kg del material
        comp['live_cost'] = weightPerUnit * liveCostPerKg;

        comp['material_name'] ??= materialData['name'];
        comp['material_code'] ??= materialData['code'];
      }
      comp.remove('materials');
    }

    return CompositeProduct.fromSupabase(productResponse, componentsResponse);
  }

  /// Crear un nuevo producto compuesto
  static Future<CompositeProduct> create(CompositeProduct product) async {
    try {
      // 1. Insertar el producto
      final productData = product.toSupabase();

      final response = await _client
          .from('products')
          .insert(productData)
          .select()
          .single();

      final productId = response['id'] as String;

      // 2. Insertar componentes
      if (product.components.isNotEmpty) {
        final componentRows = <Map<String, dynamic>>[];
        for (int i = 0; i < product.components.length; i++) {
          componentRows.add(product.components[i].toSupabase(productId, i));
        }
        await _client.from('product_components').insert(componentRows);
      }

      AppLogger.info('✅ Producto compuesto creado: ${product.name}');
      return await getById(productId);
    } catch (e) {
      AppLogger.error('❌ Error creando producto compuesto: $e');
      rethrow;
    }
  }

  /// Actualizar un producto compuesto existente
  static Future<CompositeProduct> update(CompositeProduct product) async {
    try {
      // 1. Actualizar datos del producto
      final productData = product.toSupabase();
      await _client.from('products').update(productData).eq('id', product.id);

      // 2. Eliminar componentes existentes y re-insertar
      await _client
          .from('product_components')
          .delete()
          .eq('product_id', product.id);

      if (product.components.isNotEmpty) {
        final componentRows = <Map<String, dynamic>>[];
        for (int i = 0; i < product.components.length; i++) {
          componentRows.add(product.components[i].toSupabase(product.id, i));
        }
        await _client.from('product_components').insert(componentRows);
      }

      AppLogger.info('✅ Producto compuesto actualizado: ${product.name}');
      return await getById(product.id);
    } catch (e) {
      AppLogger.error('❌ Error actualizando producto compuesto: $e');
      rethrow;
    }
  }

  /// Eliminar un producto compuesto
  static Future<void> delete(String id) async {
    try {
      // Los componentes se eliminan por CASCADE
      await _client.from('products').delete().eq('id', id);
      AppLogger.info('✅ Producto compuesto eliminado');
    } catch (e) {
      AppLogger.error('❌ Error eliminando producto compuesto: $e');
      rethrow;
    }
  }

  /// Duplicar un producto compuesto
  static Future<CompositeProduct> duplicate(String id) async {
    try {
      final original = await getById(id);
      final duplicated = original.copyWith(
        id: '', // Nuevo ID será generado
        code: '${original.code}-COPIA',
        name: '${original.name} (Copia)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      return await create(duplicated);
    } catch (e) {
      AppLogger.error('❌ Error duplicando producto compuesto: $e');
      rethrow;
    }
  }
}
