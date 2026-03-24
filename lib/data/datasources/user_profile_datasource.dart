import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/user_profile.dart';
import '../../core/utils/logger.dart';
import 'supabase_datasource.dart';

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
      return Map<String, dynamic>.from(result as Map);
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
      return Map<String, dynamic>.from(result as Map);
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
      return Map<String, dynamic>.from(result as Map);
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
      return data['success'] == true;
    } catch (e) {
      AppLogger.error('Error toggling cuenta', e);
      return false;
    }
  }
}
