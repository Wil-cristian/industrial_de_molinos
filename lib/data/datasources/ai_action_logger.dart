import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_datasource.dart';

/// Logger de acciones del usuario para aprendizaje de IA.
/// Registra cada acción significativa que el usuario realiza
/// para que la IA pueda aprender patrones de uso.
class AiActionLogger {
  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Registra una acción del usuario
  static Future<void> log({
    required String actionType,
    required String module,
    String? entityId,
    String? entityName,
    Map<String, dynamic> parameters = const {},
    Map<String, dynamic> context = const {},
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client.from('ai_action_log').insert({
        'user_id': userId,
        'action_type': actionType,
        'module': module,
        'entity_id': entityId,
        'entity_name': entityName,
        'parameters': parameters,
        'context': context,
      });
    } catch (e) {
      // No interrumpir el flujo del usuario si falla el logging
      print('AiActionLogger error: $e');
    }
  }

  /// Obtiene las ultimas N acciones del usuario para contexto de IA
  static Future<List<Map<String, dynamic>>> getRecentActions({
    int limit = 50,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final data = await _client
          .from('ai_action_log')
          .select('action_type, module, entity_name, parameters, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  /// Obtiene acciones frecuentes del usuario (para sugerir)
  static Future<List<Map<String, dynamic>>> getFrequentActions({
    int limit = 10,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final data = await _client.rpc(
        'get_frequent_actions',
        params: {'p_user_id': userId, 'p_limit': limit},
      );

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      // Si la RPC no existe, usar fallback con query simple
      return _getFrequentActionsFallback(limit);
    }
  }

  static Future<List<Map<String, dynamic>>> _getFrequentActionsFallback(
    int limit,
  ) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final data = await _client
          .from('ai_action_log')
          .select('action_type, module')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(200);

      // Contar frecuencias localmente
      final freq = <String, int>{};
      for (final row in data) {
        final key = '${row['module']}:${row['action_type']}';
        freq[key] = (freq[key] ?? 0) + 1;
      }

      final sorted = freq.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sorted.take(limit).map((e) {
        final parts = e.key.split(':');
        return {'module': parts[0], 'action_type': parts[1], 'count': e.value};
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ═══════ Helpers de logging por modulo ═══════

  static Future<void> logInvoice(
    String action, {
    String? invoiceId,
    String? invoiceName,
    Map<String, dynamic> params = const {},
  }) => log(
    actionType: action,
    module: 'facturas',
    entityId: invoiceId,
    entityName: invoiceName,
    parameters: params,
  );

  static Future<void> logQuotation(
    String action, {
    String? quotationId,
    String? quotationName,
    Map<String, dynamic> params = const {},
  }) => log(
    actionType: action,
    module: 'cotizaciones',
    entityId: quotationId,
    entityName: quotationName,
    parameters: params,
  );

  static Future<void> logProduction(
    String action, {
    String? orderId,
    String? orderName,
    Map<String, dynamic> params = const {},
  }) => log(
    actionType: action,
    module: 'produccion',
    entityId: orderId,
    entityName: orderName,
    parameters: params,
  );

  static Future<void> logPurchase(
    String action, {
    String? orderId,
    String? orderName,
    Map<String, dynamic> params = const {},
  }) => log(
    actionType: action,
    module: 'compras',
    entityId: orderId,
    entityName: orderName,
    parameters: params,
  );

  static Future<void> logShipment(
    String action, {
    String? shipmentId,
    String? shipmentName,
    Map<String, dynamic> params = const {},
  }) => log(
    actionType: action,
    module: 'envios',
    entityId: shipmentId,
    entityName: shipmentName,
    parameters: params,
  );

  static Future<void> logEmployee(
    String action, {
    String? employeeId,
    String? employeeName,
    Map<String, dynamic> params = const {},
  }) => log(
    actionType: action,
    module: 'empleados',
    entityId: employeeId,
    entityName: employeeName,
    parameters: params,
  );

  static Future<void> logInventory(
    String action, {
    String? itemId,
    String? itemName,
    Map<String, dynamic> params = const {},
  }) => log(
    actionType: action,
    module: 'inventario',
    entityId: itemId,
    entityName: itemName,
    parameters: params,
  );

  static Future<void> logActivity(
    String action, {
    String? activityId,
    String? activityName,
    Map<String, dynamic> params = const {},
  }) => log(
    actionType: action,
    module: 'calendario',
    entityId: activityId,
    entityName: activityName,
    parameters: params,
  );

  static Future<void> logNavigation(String pageName) =>
      log(actionType: 'navegar', module: 'navegacion', entityName: pageName);
}
