import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/audit_log.dart';

class AuditLogDatasource {
  static final _client = Supabase.instance.client;

  /// Registrar un movimiento en el log de auditoría
  static Future<void> log({
    required String action,
    required String module,
    String? recordId,
    required String description,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _client.rpc(
        'log_audit',
        params: {
          'p_action': action,
          'p_module': module,
          'p_record_id': recordId,
          'p_description': description,
          'p_details': details != null ? jsonEncode(details) : null,
        },
      );
    } catch (e) {
      // No lanzar excepción — el audit log no debe interrumpir la operación principal
      AppLogger.warning('No se pudo registrar audit log: $e');
    }
  }

  /// Obtener logs con filtros opcionales
  static Future<List<AuditLog>> getLogs({
    String? module,
    String? action,
    String? userId,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final response = await _client.rpc(
        'get_audit_logs',
        params: {
          'p_module': module,
          'p_action': action,
          'p_user_id': userId,
          'p_from_date': fromDate?.toIso8601String(),
          'p_to_date': toDate?.toIso8601String(),
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      return (response as List)
          .map((json) => AuditLog.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('Error cargando audit logs: $e');
      return [];
    }
  }

  /// Obtener logs recientes (últimos N)
  static Future<List<AuditLog>> getRecentLogs({int limit = 50}) async {
    return getLogs(limit: limit);
  }

  /// Obtener logs de un usuario específico
  static Future<List<AuditLog>> getLogsByUser(
    String userId, {
    int limit = 50,
  }) async {
    return getLogs(userId: userId, limit: limit);
  }

  /// Obtener logs de un módulo específico
  static Future<List<AuditLog>> getLogsByModule(
    String module, {
    int limit = 50,
  }) async {
    return getLogs(module: module, limit: limit);
  }

  /// Obtener lista de usuarios únicos que tienen logs
  static Future<List<Map<String, String>>> getActiveUsers() async {
    try {
      final response = await _client
          .from('audit_logs')
          .select('user_id, user_email, user_display_name, user_role')
          .order('created_at', ascending: false);

      // Deduplicar por user_id
      final seen = <String>{};
      final users = <Map<String, String>>[];
      for (final row in (response as List)) {
        final uid = row['user_id'] as String? ?? '';
        if (uid.isNotEmpty && seen.add(uid)) {
          users.add({
            'user_id': uid,
            'user_email': row['user_email'] as String? ?? '',
            'user_display_name': row['user_display_name'] as String? ?? '',
            'user_role': row['user_role'] as String? ?? '',
          });
        }
      }
      return users;
    } catch (e) {
      AppLogger.error('Error obteniendo usuarios activos: $e');
      return [];
    }
  }
}
