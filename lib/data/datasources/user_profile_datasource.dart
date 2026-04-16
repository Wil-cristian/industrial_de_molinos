import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/user_profile.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/logger.dart';
import 'supabase_datasource.dart';
import 'audit_log_datasource.dart';

class UserProfileDatasource {
  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Obtener perfil del usuario actual via RPC
  static Future<UserProfile?> getMyProfile() async {
    try {
      final result = await _client.rpc('get_my_profile');
      if (result == null) return null;
      final data = Map<String, dynamic>.from(result as Map);
      return UserProfile.fromJson(data);
    } catch (e) {
      AppLogger.error('Error obteniendo perfil', e);
      return null;
    }
  }

  /// Crear cuenta de empleado auto-generada (solo admin)
  /// Retorna {success, email, password, employee_name} o {success, error, message}
  static Future<Map<String, dynamic>> createEmployeeAccount({
    required String employeeId,
    String role = 'employee',
  }) async {
    try {
      final result = await _client.rpc(
        'create_employee_account',
        params: {'p_employee_id': employeeId, 'p_role': role},
      );
      final data = Map<String, dynamic>.from(result as Map);
      if (data['success'] == true) {
        AuditLogDatasource.log(
          action: 'create',
          module: 'users',
          description:
              'Creó cuenta para ${data['employee_name'] ?? 'empleado'} con rol $role',
        );
      }
      return data;
    } catch (e) {
      AppLogger.error('Error creando cuenta de empleado', e);
      return {
        'success': false,
        'error': 'RPC_ERROR',
        'message': 'Error al crear cuenta: $e',
      };
    }
  }

  /// Ver credenciales de un empleado (admin desencripta del servidor)
  static Future<Map<String, dynamic>> getEmployeeCredential(
    String profileId,
  ) async {
    try {
      final result = await _client.rpc(
        'get_employee_credential',
        params: {'p_profile_id': profileId},
      );
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      AppLogger.error('Error obteniendo credenciales', e);
      return {'success': false, 'error': 'RPC_ERROR', 'message': '$e'};
    }
  }

  /// Resetear contraseña de un empleado (admin genera nueva)
  static Future<Map<String, dynamic>> resetEmployeePassword(
    String profileId,
  ) async {
    try {
      final result = await _client.rpc(
        'reset_employee_password',
        params: {'p_profile_id': profileId},
      );
      final data = Map<String, dynamic>.from(result as Map);
      if (data['success'] == true) {
        AuditLogDatasource.log(
          action: 'update',
          module: 'users',
          recordId: profileId,
          description:
              'Resetó contraseña de ${data['display_name'] ?? 'usuario'}',
        );
      }
      return data;
    } catch (e) {
      AppLogger.error('Error reseteando contraseña', e);
      return {'success': false, 'error': 'RPC_ERROR', 'message': '$e'};
    }
  }

  /// Listar todas las cuentas de usuario (solo admin)
  static Future<List<UserProfile>> listUserAccounts() async {
    try {
      final result = await _client.rpc('list_user_accounts');
      if (result == null) return [];
      final list = List<Map<String, dynamic>>.from(
        (result as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
      return list.map((e) => UserProfile.fromJson(e)).toList();
    } catch (e) {
      AppLogger.error('Error listando cuentas', e);
      return [];
    }
  }

  /// Cambiar rol de un usuario (solo admin)
  static Future<Map<String, dynamic>> updateUserRole(
    String profileId,
    String newRole,
  ) async {
    try {
      final result = await _client.rpc(
        'update_user_role',
        params: {'p_profile_id': profileId, 'p_new_role': newRole},
      );
      final data = Map<String, dynamic>.from(result as Map);
      if (data['success'] == true) {
        AuditLogDatasource.log(
          action: 'update',
          module: 'users',
          recordId: profileId,
          description:
              'Cambió rol de ${data['display_name'] ?? 'usuario'} a $newRole',
        );
      }
      return data;
    } catch (e) {
      AppLogger.error('Error actualizando rol', e);
      return {'success': false, 'error': 'RPC_ERROR', 'message': '$e'};
    }
  }

  /// Activar/desactivar cuenta
  static Future<bool> toggleUserAccount(String profileId, bool active) async {
    try {
      final result = await _client.rpc(
        'toggle_user_account',
        params: {'p_profile_id': profileId, 'p_active': active},
      );
      final data = Map<String, dynamic>.from(result as Map);
      if (data['success'] == true) {
        AuditLogDatasource.log(
          action: 'update',
          module: 'users',
          recordId: profileId,
          description: active
              ? 'Activó cuenta de usuario'
              : 'Desactivó cuenta de usuario',
        );
      }
      return data['success'] == true;
    } catch (e) {
      AppLogger.error('Error toggling cuenta', e);
      return false;
    }
  }

  // ─── Session / Device Tracking ────────────────────────────

  static String get _currentPlatform {
    if (kIsWeb) return 'web';
    if (Platform.isWindows) return 'windows';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  static String get _deviceName {
    if (kIsWeb) return 'Navegador Web';
    if (Platform.isWindows) return 'Windows Desktop';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iPhone / iPad';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Dispositivo desconocido';
  }

  /// ID de sesión local (se guarda mientras la app esté abierta)
  static String? _currentSessionId;

  /// Registrar sesión activa o actualizar heartbeat
  static Future<String?> registerSession() async {
    try {
      final result = await _client.rpc(
        'register_session',
        params: {
          'p_platform': _currentPlatform,
          'p_device_name': _deviceName,
          'p_app_version': AppConstants.appFullVersion,
        },
      );
      if (result != null) {
        _currentSessionId = result as String;
        AppLogger.debug('Sesión registrada: $_currentSessionId');
      }
      return _currentSessionId;
    } catch (e) {
      AppLogger.error('Error registrando sesión', e);
      return null;
    }
  }

  /// Enviar heartbeat (llamar periódicamente)
  static Future<void> heartbeat() async {
    try {
      await _client.rpc(
        'register_session',
        params: {
          'p_platform': _currentPlatform,
          'p_device_name': _deviceName,
          'p_app_version': AppConstants.appFullVersion,
        },
      );
    } catch (e) {
      // Silencioso — no interrumpir el flujo
    }
  }

  /// Cerrar sesión del dispositivo actual
  static Future<void> closeSession() async {
    if (_currentSessionId == null) return;
    try {
      await _client.rpc(
        'close_session',
        params: {'p_session_id': _currentSessionId},
      );
      _currentSessionId = null;
    } catch (e) {
      AppLogger.error('Error cerrando sesión de dispositivo', e);
    }
  }

  /// Listar sesiones activas (admin ve todas)
  static Future<List<Map<String, dynamic>>> listActiveSessions() async {
    try {
      final result = await _client.rpc('list_active_sessions');
      if (result == null) return [];
      return List<Map<String, dynamic>>.from(
        (result as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } catch (e) {
      AppLogger.error('Error listando sesiones activas', e);
      return [];
    }
  }
}
