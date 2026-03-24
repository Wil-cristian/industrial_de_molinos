import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/material_subcategory.dart';
import 'supabase_datasource.dart';

/// DataSource para la tabla 'material_subcategories'
class MaterialSubcategoryDatasource {
  static const String _table = 'material_subcategories';

  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Obtener todas las subcategorías activas
  static Future<List<MaterialSubcategory>> getAll({
    bool activeOnly = true,
  }) async {
    var query = _client.from(_table).select();
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    final response = await query.order('sort_order').order('name');
    return response
        .map<MaterialSubcategory>((json) => MaterialSubcategory.fromJson(json))
        .toList();
  }

  /// Obtener subcategorías de una categoría específica
  static Future<List<MaterialSubcategory>> getByCategory(
    String categoryId, {
    bool activeOnly = true,
  }) async {
    var query = _client.from(_table).select().eq('category_id', categoryId);
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    final response = await query.order('sort_order').order('name');
    return response
        .map<MaterialSubcategory>((json) => MaterialSubcategory.fromJson(json))
        .toList();
  }

  /// Obtener subcategoría por ID
  static Future<MaterialSubcategory?> getById(String id) async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('id', id)
          .single();
      return MaterialSubcategory.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Crear nueva subcategoría
  static Future<MaterialSubcategory> create(
    MaterialSubcategory subcategory,
  ) async {
    final data = subcategory.toJson();
    final response = await _client.from(_table).insert(data).select().single();
    return MaterialSubcategory.fromJson(response);
  }

  /// Actualizar subcategoría
  static Future<MaterialSubcategory> update(
    MaterialSubcategory subcategory,
  ) async {
    final data = subcategory.toJson();
    final response = await _client
        .from(_table)
        .update(data)
        .eq('id', subcategory.id)
        .select()
        .single();
    return MaterialSubcategory.fromJson(response);
  }

  /// Eliminar subcategoría
  static Future<bool> delete(String id) async {
    // Verificar que no tenga materiales asignados
    final materialsCount = await _client
        .from('materials')
        .select('id')
        .eq('subcategory_id', id)
        .eq('is_active', true);

    if ((materialsCount as List).isNotEmpty) {
      throw Exception(
        'No se puede eliminar la subcategoría porque tiene '
        '${materialsCount.length} material(es) asignado(s).',
      );
    }

    await _client.from(_table).delete().eq('id', id);
    return true;
  }

  /// Verificar si un slug ya existe dentro de la misma categoría
  static Future<bool> slugExists(
    String categoryId,
    String slug, {
    String? excludeId,
  }) async {
    var query = _client
        .from(_table)
        .select('id')
        .eq('category_id', categoryId)
        .eq('slug', slug);
    if (excludeId != null) {
      query = query.neq('id', excludeId);
    }
    final result = await query;
    return (result as List).isNotEmpty;
  }
}
