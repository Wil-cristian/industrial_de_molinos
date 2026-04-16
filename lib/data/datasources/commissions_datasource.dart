import '../../core/utils/colombia_time.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/sales_commission.dart';
import 'supabase_datasource.dart';

/// DataSource para comisiones por ventas
class CommissionsDatasource {
  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Porcentaje de comisión por defecto: 1.6667% (100,000 / 6,000,000)
  static const double defaultCommissionPercentage = 1.6667;

  // ==================== READ ====================

  /// Obtiene todas las comisiones (con nombre de empleado)
  static Future<List<SalesCommission>> getAll() async {
    final response = await _client
        .from('sales_commissions')
        .select('*, employees(first_name, last_name)')
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => SalesCommission.fromJson(json))
        .toList();
  }

  /// Obtiene comisiones de un empleado
  static Future<List<SalesCommission>> getByEmployee(String employeeId) async {
    final response = await _client
        .from('sales_commissions')
        .select('*, employees(first_name, last_name)')
        .eq('employee_id', employeeId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => SalesCommission.fromJson(json))
        .toList();
  }

  /// Obtiene comisiones pendientes de un empleado
  static Future<List<SalesCommission>> getPendingByEmployee(
    String employeeId,
  ) async {
    final response = await _client
        .from('sales_commissions')
        .select('*, employees(first_name, last_name)')
        .eq('employee_id', employeeId)
        .eq('status', 'pendiente')
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => SalesCommission.fromJson(json))
        .toList();
  }

  /// Obtiene el total de comisiones pendientes de un empleado
  static Future<double> getPendingTotal(String employeeId) async {
    final response = await _client
        .from('sales_commissions')
        .select('commission_amount')
        .eq('employee_id', employeeId)
        .eq('status', 'pendiente');

    double total = 0;
    for (final row in (response as List)) {
      total += (row['commission_amount'] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  /// Obtiene resumen de comisiones por empleado (para lista general)
  static Future<List<Map<String, dynamic>>>
  getCommissionSummaryByEmployee() async {
    final response = await _client
        .from('sales_commissions')
        .select(
          'employee_id, status, commission_amount, employees(first_name, last_name)',
        )
        .eq('status', 'pendiente');

    // Agrupar por empleado
    final Map<String, Map<String, dynamic>> grouped = {};
    for (final row in (response as List)) {
      final empId = row['employee_id'] as String;
      if (!grouped.containsKey(empId)) {
        String empName = '';
        if (row['employees'] != null && row['employees'] is Map) {
          final emp = row['employees'] as Map<String, dynamic>;
          empName = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'
              .trim();
        }
        grouped[empId] = {
          'employee_id': empId,
          'employee_name': empName,
          'total_pending': 0.0,
          'count': 0,
        };
      }
      grouped[empId]!['total_pending'] =
          (grouped[empId]!['total_pending'] as double) +
          ((row['commission_amount'] as num?)?.toDouble() ?? 0);
      grouped[empId]!['count'] = (grouped[empId]!['count'] as int) + 1;
    }

    return grouped.values.toList();
  }

  // ==================== CREATE ====================

  /// Crea una comisión al registrar una venta
  static Future<SalesCommission?> createCommission({
    required String invoiceId,
    required String employeeId,
    required String invoiceNumber,
    required String customerName,
    required double invoiceTotal,
    required double commissionPercentage,
  }) async {
    final commissionAmount = invoiceTotal * (commissionPercentage / 100);

    final response = await _client
        .from('sales_commissions')
        .insert({
          'invoice_id': invoiceId,
          'employee_id': employeeId,
          'invoice_number': invoiceNumber,
          'customer_name': customerName,
          'invoice_total': invoiceTotal,
          'commission_percentage': commissionPercentage,
          'commission_amount': commissionAmount,
          'status': 'pendiente',
        })
        .select()
        .single();

    return SalesCommission.fromJson(response);
  }

  // ==================== UPDATE ====================

  /// Marca comisiones como pagadas (al cobrar en nómina)
  static Future<void> markAsPaid({
    required List<String> commissionIds,
    required String payrollId,
  }) async {
    final now = ColombiaTime.todayString();
    await _client
        .from('sales_commissions')
        .update({'status': 'pagada', 'payroll_id': payrollId, 'paid_date': now})
        .inFilter('id', commissionIds);
  }

  /// Anula una comisión (si se cancela la factura)
  static Future<void> cancelCommission(String commissionId) async {
    await _client
        .from('sales_commissions')
        .update({'status': 'anulada'})
        .eq('id', commissionId);
  }

  /// Anula comisiones de una factura (cuando se cancela la factura)
  static Future<void> cancelByInvoice(String invoiceId) async {
    await _client
        .from('sales_commissions')
        .update({'status': 'anulada'})
        .eq('invoice_id', invoiceId)
        .eq('status', 'pendiente');
  }

  // ==================== SETTINGS ====================

  /// Obtiene la configuración de comisión de un empleado
  static Future<double> getEmployeeCommissionRate(String employeeId) async {
    final response = await _client
        .from('commission_settings')
        .select('commission_percentage')
        .eq('employee_id', employeeId)
        .eq('is_active', true)
        .maybeSingle();

    if (response != null) {
      return (response['commission_percentage'] as num?)?.toDouble() ??
          defaultCommissionPercentage;
    }
    return defaultCommissionPercentage;
  }

  /// Configura la tasa de comisión de un empleado
  static Future<void> setEmployeeCommissionRate({
    required String employeeId,
    required double percentage,
  }) async {
    await _client.from('commission_settings').upsert({
      'employee_id': employeeId,
      'commission_percentage': percentage,
      'is_active': true,
    }, onConflict: 'employee_id');
  }

  /// Obtiene todas las configuraciones de comisión
  static Future<List<CommissionSetting>> getAllSettings() async {
    final response = await _client
        .from('commission_settings')
        .select()
        .eq('is_active', true);

    return (response as List)
        .map((json) => CommissionSetting.fromJson(json))
        .toList();
  }
}
