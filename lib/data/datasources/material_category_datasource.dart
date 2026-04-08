import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/material_category.dart';
import 'audit_log_datasource.dart';
import 'supabase_datasource.dart';

/// DataSource para la tabla 'material_categories'
class MaterialCategoryDatasource {
  static const String _table = 'material_categories';

  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Obtener todas las categorías activas
  static Future<List<MaterialCategory>> getAll({bool activeOnly = true}) async {
    var query = _client.from(_table).select();

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    final response = await query
        .order('sort_order')
        .order('name', ascending: false);
    return response
        .map<MaterialCategory>((json) => MaterialCategory.fromJson(json))
        .toList();
  }

  /// Obtener categoría por slug
  static Future<MaterialCategory?> getBySlug(String slug) async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('slug', slug)
          .single();
      return MaterialCategory.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Obtener categoría por ID
  static Future<MaterialCategory?> getById(String id) async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('id', id)
          .single();
      return MaterialCategory.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Crear nueva categoría
  static Future<MaterialCategory> create(MaterialCategory category) async {
    final data = category.toJson();
    final response = await _client.from(_table).insert(data).select().single();
    final created = MaterialCategory.fromJson(response);
    AuditLogDatasource.log(
      action: 'create',
      module: 'material_categories',
      recordId: created.id,
      description: 'Categoría material creada: ${created.name}',
    );
    return created;
  }

  /// Actualizar categoría
  static Future<MaterialCategory> update(MaterialCategory category) async {
    final data = category.toJson();
    final response = await _client
        .from(_table)
        .update(data)
        .eq('id', category.id)
        .select()
        .single();
    AuditLogDatasource.log(
      action: 'update',
      module: 'material_categories',
      recordId: category.id,
      description: 'Categoría material actualizada: ${category.name}',
    );
    return MaterialCategory.fromJson(response);
  }

  /// Eliminar categoría (solo si no es del sistema)
  /// Devuelve true si se eliminó, false si es del sistema
  static Future<bool> delete(String id) async {
    // Verificar que no sea del sistema
    final cat = await getById(id);
    if (cat == null || cat.isSystem) return false;

    // Verificar que no tenga materiales asignados
    final materialsCount = await _client
        .from('materials')
        .select('id')
        .eq('category', cat.slug)
        .eq('is_active', true);

    if ((materialsCount as List).isNotEmpty) {
      throw Exception(
        'No se puede eliminar la categoría "${cat.name}" porque tiene '
        '${materialsCount.length} material(es) asignado(s). '
        'Reasigna los materiales primero.',
      );
    }

    await _client.from(_table).delete().eq('id', id);
    AuditLogDatasource.log(
      action: 'delete',
      module: 'material_categories',
      recordId: id,
      description: 'Categoría material eliminada',
    );
    return true;
  }

  /// Verificar si un slug ya existe
  static Future<bool> slugExists(String slug, {String? excludeId}) async {
    var query = _client.from(_table).select('id').eq('slug', slug);
    if (excludeId != null) {
      query = query.neq('id', excludeId);
    }
    final result = await query;
    return (result as List).isNotEmpty;
  }

  /// Obtener el siguiente sort_order disponible
  static Future<int> getNextSortOrder() async {
    final response = await _client
        .from(_table)
        .select('sort_order')
        .order('sort_order', ascending: false)
        .limit(1);
    if ((response as List).isEmpty) return 0;
    return (response[0]['sort_order'] as int) + 1;
  }
}
