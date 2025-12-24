import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_datasource.dart';
import '../../domain/entities/analytics.dart';

/// DataSource para consultas analíticas usando las vistas SQL
class AnalyticsDataSource {
  static SupabaseClient get _client => SupabaseDataSource.client;

  // ============================================================
  // HISTORIAL DE COMPRAS POR CLIENTE
  // ============================================================

  /// Obtener historial de compras de un cliente específico
  static Future<List<CustomerPurchaseHistory>> getCustomerPurchaseHistory(
      String customerId) async {
    try {
      final response = await _client
          .from('v_customer_purchase_history')
          .select()
          .eq('customer_id', customerId)
          .order('issue_date', ascending: false);

      return (response as List)
          .map((json) => CustomerPurchaseHistory.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo historial de compras: $e');
      return [];
    }
  }

  /// Obtener historial de compras de todos los clientes
  static Future<List<CustomerPurchaseHistory>> getAllPurchaseHistory({
    int limit = 100,
  }) async {
    try {
      final response = await _client
          .from('v_customer_purchase_history')
          .select()
          .order('issue_date', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => CustomerPurchaseHistory.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo historial general: $e');
      return [];
    }
  }

  // ============================================================
  // MÉTRICAS DE CLIENTES
  // ============================================================

  /// Obtener métricas de todos los clientes
  static Future<List<CustomerMetrics>> getAllCustomerMetrics() async {
    try {
      final response = await _client
          .from('v_customer_metrics')
          .select()
          .order('total_spent', ascending: false);

      return (response as List)
          .map((json) => CustomerMetrics.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo métricas de clientes: $e');
      return [];
    }
  }

  /// Obtener métricas de un cliente específico
  static Future<CustomerMetrics?> getCustomerMetrics(String customerId) async {
    try {
      final response = await _client
          .from('v_customer_metrics')
          .select()
          .eq('id', customerId)
          .maybeSingle();

      if (response != null) {
        return CustomerMetrics.fromJson(response);
      }
      return null;
    } catch (e) {
      print('❌ Error obteniendo métricas del cliente: $e');
      return null;
    }
  }

  /// Obtener clientes top por gasto total
  static Future<List<CustomerMetrics>> getTopCustomers({int limit = 10}) async {
    try {
      final response = await _client
          .from('v_customer_metrics')
          .select()
          .gt('total_spent', 0)
          .order('total_spent', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => CustomerMetrics.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo top clientes: $e');
      return [];
    }
  }

  // ============================================================
  // PRODUCTOS MÁS VENDIDOS
  // ============================================================

  /// Obtener productos más vendidos
  static Future<List<TopSellingProduct>> getTopSellingProducts({
    int limit = 20,
  }) async {
    try {
      final response = await _client
          .from('v_top_selling_products')
          .select()
          .order('total_revenue', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => TopSellingProduct.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo productos top: $e');
      return [];
    }
  }

  // ============================================================
  // CONSUMO DE MATERIALES
  // ============================================================

  /// Obtener consumo de materiales por mes
  static Future<List<MaterialConsumption>> getMaterialConsumption({
    DateTime? fromMonth,
    int limit = 100,
  }) async {
    try {
      var query = _client.from('v_material_consumption_monthly').select();

      if (fromMonth != null) {
        query = query.gte('month', fromMonth.toIso8601String());
      }

      final response =
          await query.order('month', ascending: false).limit(limit);

      return (response as List)
          .map((json) => MaterialConsumption.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo consumo de materiales: $e');
      return [];
    }
  }

  /// Obtener consumo de un material específico
  static Future<List<MaterialConsumption>> getMaterialConsumptionById(
      String materialId) async {
    try {
      final response = await _client
          .from('v_material_consumption_monthly')
          .select()
          .eq('material_id', materialId)
          .order('month', ascending: false);

      return (response as List)
          .map((json) => MaterialConsumption.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo consumo del material: $e');
      return [];
    }
  }

  // ============================================================
  // VENTAS POR PERÍODO
  // ============================================================

  /// Obtener ventas por período
  static Future<List<SalesByPeriod>> getSalesByPeriod({
    DateTime? fromDate,
    int limit = 365,
  }) async {
    try {
      var query = _client.from('v_sales_by_period').select();

      if (fromDate != null) {
        query = query.gte('day', fromDate.toIso8601String());
      }

      final response = await query.order('day', ascending: false).limit(limit);

      return (response as List)
          .map((json) => SalesByPeriod.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo ventas por período: $e');
      return [];
    }
  }

  /// Obtener ventas agrupadas por mes
  static Future<Map<String, double>> getMonthlySales({int year = 0}) async {
    try {
      final targetYear = year == 0 ? DateTime.now().year : year;
      final startDate = DateTime(targetYear, 1, 1);
      final endDate = DateTime(targetYear, 12, 31);

      final response = await _client
          .from('v_sales_by_period')
          .select('month, total')
          .gte('day', startDate.toIso8601String())
          .lte('day', endDate.toIso8601String());

      Map<String, double> monthlySales = {};
      for (var row in response) {
        final monthKey = row['month'].toString().substring(0, 7);
        monthlySales[monthKey] =
            (monthlySales[monthKey] ?? 0) + (row['total'] as num).toDouble();
      }

      return monthlySales;
    } catch (e) {
      print('❌ Error obteniendo ventas mensuales: $e');
      return {};
    }
  }

  // ============================================================
  // GANANCIA/PÉRDIDA MENSUAL
  // ============================================================

  /// Obtener ganancias/pérdidas mensuales
  static Future<List<ProfitLossMonthly>> getProfitLoss({
    int? year,
    int limit = 12,
  }) async {
    try {
      var query = _client.from('v_profit_loss_monthly').select();

      if (year != null) {
        query = query.eq('year', year);
      }

      final response =
          await query.order('year', ascending: false).order('month', ascending: false).limit(limit);

      return (response as List)
          .map((json) => ProfitLossMonthly.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo P&L: $e');
      return [];
    }
  }

  // ============================================================
  // ANÁLISIS DE PRODUCTOS POR CLIENTE
  // ============================================================

  /// Obtener análisis de productos por cliente
  static Future<List<CustomerProductAnalysis>> getCustomerProductAnalysis(
      String customerId) async {
    try {
      final response = await _client
          .from('v_customer_product_analysis')
          .select()
          .eq('customer_id', customerId)
          .order('purchase_count', ascending: false);

      return (response as List)
          .map((json) => CustomerProductAnalysis.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo análisis de productos: $e');
      return [];
    }
  }

  // ============================================================
  // CUENTAS POR COBRAR
  // ============================================================

  /// Obtener cuentas por cobrar con antigüedad
  static Future<List<AccountReceivableAging>> getAccountsReceivable() async {
    try {
      final response = await _client
          .from('v_accounts_receivable_aging')
          .select()
          .order('days_overdue', ascending: false);

      return (response as List)
          .map((json) => AccountReceivableAging.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo cuentas por cobrar: $e');
      return [];
    }
  }

  /// Obtener resumen de antigüedad de cuentas por cobrar
  static Future<Map<String, double>> getAgingSummary() async {
    try {
      final accounts = await getAccountsReceivable();

      Map<String, double> summary = {
        'current': 0,
        '1-30 days': 0,
        '31-60 days': 0,
        '61-90 days': 0,
        'over 90 days': 0,
      };

      for (var account in accounts) {
        summary[account.agingBucket] =
            (summary[account.agingBucket] ?? 0) + account.pendingAmount;
      }

      return summary;
    } catch (e) {
      print('❌ Error obteniendo resumen de antigüedad: $e');
      return {};
    }
  }

  // ============================================================
  // FUNCIONES RPC (usan las funciones SQL)
  // ============================================================

  /// Calcular CLV de un cliente
  static Future<CustomerCLV?> calculateCustomerCLV(String customerId) async {
    try {
      final response = await _client
          .rpc('calculate_customer_clv', params: {'p_customer_id': customerId});

      if (response != null && (response as List).isNotEmpty) {
        return CustomerCLV.fromJson(response.first);
      }
      return null;
    } catch (e) {
      print('❌ Error calculando CLV: $e');
      return null;
    }
  }

  /// Obtener productos relacionados
  static Future<List<RelatedProduct>> getRelatedProducts(
    String productCode, {
    int limit = 5,
  }) async {
    try {
      final response = await _client.rpc('get_related_products', params: {
        'p_product_code': productCode,
        'p_limit': limit,
      });

      return (response as List)
          .map((json) => RelatedProduct.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo productos relacionados: $e');
      return [];
    }
  }

  // ============================================================
  // DASHBOARD SUMMARY
  // ============================================================

  /// Obtener resumen para dashboard
  static Future<Map<String, dynamic>> getDashboardSummary() async {
    try {
      // Ventas del mes actual
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      // Ejecutar consultas en paralelo
      final invoicesMonth = await _client
          .from('invoices')
          .select('total')
          .gte('issue_date', startOfMonth.toIso8601String())
          .neq('status', 'cancelled');
      
      final invoicesPending = await _client
          .from('invoices')
          .select('total, paid_amount')
          .neq('status', 'paid')
          .neq('status', 'cancelled');
      
      final topCustomers = await getTopCustomers(limit: 5);
      final topProducts = await getTopSellingProducts(limit: 5);

      // Procesar ventas del mes
      double monthlySales = 0;
      for (var inv in invoicesMonth) {
        monthlySales += (inv['total'] as num).toDouble();
      }

      // Procesar cuentas por cobrar
      double totalReceivables = 0;
      for (var inv in invoicesPending) {
        totalReceivables += (inv['total'] as num).toDouble() -
            (inv['paid_amount'] as num).toDouble();
      }

      return {
        'monthly_sales': monthlySales,
        'total_receivables': totalReceivables,
        'top_customers': topCustomers,
        'top_products': topProducts,
      };
    } catch (e) {
      print('❌ Error obteniendo dashboard summary: $e');
      return {};
    }
  }
}
