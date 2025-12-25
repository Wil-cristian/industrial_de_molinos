import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/product.dart';

/// Datasource para operaciones de recetas en Supabase
class RecipeDataSource {
  static final _supabase = Supabase.instance.client;

  /// Guardar una nueva receta
  static Future<Product> saveRecipe({
    required String title,
    required String description,
    required List<RecipeComponentData> components,
    required double totalWeight,
    required double totalCost,
    required double unitPrice,
  }) async {
    try {
      // Generar código único
      final code = 'REC-${DateTime.now().millisecondsSinceEpoch}';

      // Insertar el producto como receta
      final response = await _supabase
          .from('products')
          .insert({
            'code': code,
            'name': title,
            'description': description,
            'is_recipe': true,
            'recipe_description': description,
            'unit_price': unitPrice,
            'cost_price': totalCost,
            'total_weight': totalWeight,
            'total_cost': totalCost,
            'unit': 'UND',
            'is_active': true,
          })
          .select()
          .single();

      final productId = response['id'];

      // Insertar componentes de la receta
      for (int i = 0; i < components.length; i++) {
        final comp = components[i];
        await _supabase.from('product_components').insert({
          'product_id': productId,
          'material_id': comp.materialId,
          'name': comp.name,
          'description': comp.description,
          'quantity': comp.quantity,
          'unit': comp.unit,
          'outer_diameter': comp.outerDiameter,
          'thickness': comp.thickness,
          'length': comp.length,
          'calculated_weight': comp.calculatedWeight,
          'unit_cost': comp.unitCost,
          'total_cost': comp.totalCost,
          'sort_order': i + 1,
        });
      }

      return Product(
        id: productId,
        code: code,
        name: title,
        description: description,
        unitPrice: unitPrice,
        costPrice: totalCost,
        unit: 'UND',
        isRecipe: true,
        recipeDescription: description,
        totalWeight: totalWeight,
        totalCost: totalCost,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Error al guardar receta: $e');
    }
  }

  /// Obtener todas las recetas
  static Future<List<Product>> getRecipes() async {
    try {
      final response = await _supabase
          .from('products')
          .select()
          .eq('is_recipe', true);

      return (response as List)
          .map((e) => Product(
                id: e['id'],
                code: e['code'],
                name: e['name'],
                description: e['description'],
                unitPrice: (e['unit_price'] ?? 0).toDouble(),
                costPrice: (e['cost_price'] ?? 0).toDouble(),
                unit: e['unit'] ?? 'UND',
                isRecipe: true,
                recipeDescription: e['recipe_description'],
                totalWeight: (e['total_weight'] ?? 0).toDouble(),
                totalCost: (e['total_cost'] ?? 0).toDouble(),
                createdAt: DateTime.parse(e['created_at']),
                updatedAt: DateTime.parse(e['updated_at']),
              ))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener recetas: $e');
    }
  }

  /// Obtener componentes de una receta
  static Future<List<RecipeComponentData>> getRecipeComponents(String productId) async {
    try {
      final response = await _supabase
          .from('product_components')
          .select()
          .eq('product_id', productId)
          .order('sort_order', ascending: true);

      return (response as List)
          .map((e) => RecipeComponentData(
                id: e['id'],
                productId: e['product_id'],
                materialId: e['material_id'],
                name: e['name'],
                description: e['description'],
                quantity: (e['quantity'] ?? 0).toDouble(),
                unit: e['unit'] ?? 'KG',
                outerDiameter: e['outer_diameter']?.toDouble(),
                thickness: e['thickness']?.toDouble(),
                length: e['length']?.toDouble(),
                calculatedWeight: (e['calculated_weight'] ?? 0).toDouble(),
                unitCost: (e['unit_cost'] ?? 0).toDouble(),
                totalCost: (e['total_cost'] ?? 0).toDouble(),
              ))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener componentes: $e');
    }
  }

  /// Actualizar una receta
  static Future<void> updateRecipe({
    required String productId,
    required String title,
    required String description,
    required List<RecipeComponentData> components,
    required double totalWeight,
    required double totalCost,
    required double unitPrice,
  }) async {
    try {
      // Actualizar producto
      await _supabase.from('products').update({
        'name': title,
        'description': description,
        'recipe_description': description,
        'unit_price': unitPrice,
        'cost_price': totalCost,
        'total_weight': totalWeight,
        'total_cost': totalCost,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', productId);

      // Eliminar componentes anteriores
      await _supabase.from('product_components').delete().eq('product_id', productId);

      // Insertar nuevos componentes
      for (int i = 0; i < components.length; i++) {
        final comp = components[i];
        await _supabase.from('product_components').insert({
          'product_id': productId,
          'material_id': comp.materialId,
          'name': comp.name,
          'description': comp.description,
          'quantity': comp.quantity,
          'unit': comp.unit,
          'outer_diameter': comp.outerDiameter,
          'thickness': comp.thickness,
          'length': comp.length,
          'calculated_weight': comp.calculatedWeight,
          'unit_cost': comp.unitCost,
          'total_cost': comp.totalCost,
          'sort_order': i + 1,
        });
      }
    } catch (e) {
      throw Exception('Error al actualizar receta: $e');
    }
  }

  /// Eliminar una receta
  static Future<void> deleteRecipe(String productId) async {
    try {
      // Eliminar componentes primero
      await _supabase.from('product_components').delete().eq('product_id', productId);

      // Eliminar producto
      await _supabase.from('products').delete().eq('id', productId);
    } catch (e) {
      throw Exception('Error al eliminar receta: $e');
    }
  }
}

/// Modelo de datos para componentes de receta
class RecipeComponentData {
  final String? id;
  final String? productId;
  final String? materialId;
  final String name;
  final String? description;
  final double quantity;
  final String unit;
  final double? outerDiameter;
  final double? thickness;
  final double? length;
  final double calculatedWeight;
  final double unitCost;
  final double totalCost;

  RecipeComponentData({
    this.id,
    this.productId,
    this.materialId,
    required this.name,
    this.description,
    required this.quantity,
    required this.unit,
    this.outerDiameter,
    this.thickness,
    this.length,
    required this.calculatedWeight,
    required this.unitCost,
    required this.totalCost,
  });
}
