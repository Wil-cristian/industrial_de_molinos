import '../../core/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/driver.dart';
import 'supabase_datasource.dart';

class DriversDataSource {
  static const String _table = 'drivers';

  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Obtener todos los conductores
  static Future<List<Driver>> getAll({bool activeOnly = true}) async {
    var query = _client.from(_table).select();
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    final response = await query.order('name', ascending: true);
    return (response as List).map((json) => Driver.fromJson(json)).toList();
  }

  /// Buscar conductores
  static Future<List<Driver>> search(String query) async {
    final response = await _client
        .from(_table)
        .select()
        .or('name.ilike.%$query%,document.ilike.%$query%,vehicle_plate.ilike.%$query%')
        .order('name', ascending: true);
    return (response as List).map((json) => Driver.fromJson(json)).toList();
  }

  /// Crear conductor
  static Future<Driver> create(Driver driver) async {
    try {
      final response = await _client
          .from(_table)
          .insert(driver.toJson())
          .select()
          .single();
      return Driver.fromJson(response);
    } catch (e) {
      AppLogger.error('Error creando conductor: $e');
      rethrow;
    }
  }

  /// Actualizar conductor
  static Future<Driver> update(Driver driver) async {
    try {
      final response = await _client
          .from(_table)
          .update(driver.toJson())
          .eq('id', driver.id)
          .select()
          .single();
      return Driver.fromJson(response);
    } catch (e) {
      AppLogger.error('Error actualizando conductor: $e');
      rethrow;
    }
  }

  /// Eliminar conductor (soft delete)
  static Future<void> delete(String id) async {
    await _client.from(_table).update({'is_active': false}).eq('id', id);
  }

  /// Eliminar permanente
  static Future<void> deletePermanent(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}
