import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_datasource.dart';

/// Modelo para estadísticas de ventas
class SalesStats {
  final double totalSales;
  final int transactionCount;
  final double averageTicket;
  final double grossMargin;
  final double previousPeriodSales;
  final double growthPercentage;

  SalesStats({
    required this.totalSales,
    required this.transactionCount,
    required this.averageTicket,
    required this.grossMargin,
    required this.previousPeriodSales,
    required this.growthPercentage,
  });
}

/// Modelo para datos de gráficos de ventas
class SalesChartData {
  final String label;
  final double currentValue;
  final double previousValue;

  SalesChartData({
    required this.label,
    required this.currentValue,
    required this.previousValue,
  });
}

/// Modelo para productos más vendidos
class TopProduct {
  final String productId;
  final String productName;
  final String productCode;
  final double quantity;
  final double totalSales;
  final int transactionCount;

  TopProduct({
    required this.productId,
    required this.productName,
    required this.productCode,
    required this.quantity,
    required this.totalSales,
    required this.transactionCount,
  });
}

/// Modelo para ventas por cliente
class CustomerSales {
  final String customerId;
  final String customerName;
  final double totalSales;
  final int transactionCount;
  final double averageTicket;
  final double pendingBalance;

  CustomerSales({
    required this.customerId,
    required this.customerName,
    required this.totalSales,
    required this.transactionCount,
    required this.averageTicket,
    required this.pendingBalance,
  });
}

/// Modelo para reporte de inventario
class InventoryReport {
  final String productId;
  final String productCode;
  final String productName;
  final double currentStock;
  final double minStock;
  final double unitPrice;
  final double costPrice;
  final double totalValue;
  final bool isLowStock;

  InventoryReport({
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.currentStock,
    required this.minStock,
    required this.unitPrice,
    required this.costPrice,
    required this.totalValue,
    required this.isLowStock,
  });
}

/// Modelo para cuentas por cobrar
class ReceivableReport {
  final String customerId;
  final String customerName;
  final double totalDebt;
  final double current; // 0-30 días
  final double overdue30; // 31-60 días
  final double overdue60; // 61-90 días
  final double overdue90; // +90 días
  final int overdueInvoices;

  ReceivableReport({
    required this.customerId,
    required this.customerName,
    required this.totalDebt,
    required this.current,
    required this.overdue30,
    required this.overdue60,
    required this.overdue90,
    required this.overdueInvoices,
  });
}

class ReportsDataSource {
  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Obtener estadísticas de ventas del período
  static Future<SalesStats> getSalesStats({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Ventas del período actual
      final currentResponse = await _client
          .from('invoices')
          .select('total, paid_amount, status')
          .gte('issue_date', startDate.toIso8601String())
          .lte('issue_date', endDate.toIso8601String())
          .neq('status', 'cancelled');

      double totalSales = 0;
      int transactionCount = currentResponse.length;
      
      for (var invoice in currentResponse) {
        totalSales += (invoice['total'] ?? 0).toDouble();
      }

      double averageTicket = transactionCount > 0 ? totalSales / transactionCount : 0;

      // Período anterior (misma duración)
      final duration = endDate.difference(startDate);
      final prevEndDate = startDate.subtract(const Duration(days: 1));
      final prevStartDate = prevEndDate.subtract(duration);

      final prevResponse = await _client
          .from('invoices')
          .select('total')
          .gte('issue_date', prevStartDate.toIso8601String())
          .lte('issue_date', prevEndDate.toIso8601String())
          .neq('status', 'cancelled');

      double previousPeriodSales = 0;
      for (var invoice in prevResponse) {
        previousPeriodSales += (invoice['total'] ?? 0).toDouble();
      }

      double growthPercentage = previousPeriodSales > 0
          ? ((totalSales - previousPeriodSales) / previousPeriodSales) * 100
          : 0;

      // Margen bruto (estimado 32.5% por defecto)
      double grossMargin = 32.5;

      return SalesStats(
        totalSales: totalSales,
        transactionCount: transactionCount,
        averageTicket: averageTicket,
        grossMargin: grossMargin,
        previousPeriodSales: previousPeriodSales,
        growthPercentage: growthPercentage,
      );
    } catch (e) {
      print('❌ Error obteniendo stats de ventas: $e');
      return SalesStats(
        totalSales: 0,
        transactionCount: 0,
        averageTicket: 0,
        grossMargin: 0,
        previousPeriodSales: 0,
        growthPercentage: 0,
      );
    }
  }

  /// Obtener datos de gráfico de ventas mensuales
  static Future<List<SalesChartData>> getMonthlySalesChart({
    required int year,
  }) async {
    try {
      final List<SalesChartData> chartData = [];
      final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

      for (int month = 1; month <= 12; month++) {
        final startDate = DateTime(year, month, 1);
        final endDate = DateTime(year, month + 1, 0);
        
        final prevStartDate = DateTime(year - 1, month, 1);
        final prevEndDate = DateTime(year - 1, month + 1, 0);

        // Ventas mes actual
        final currentResponse = await _client
            .from('invoices')
            .select('total')
            .gte('issue_date', startDate.toIso8601String())
            .lte('issue_date', endDate.toIso8601String())
            .neq('status', 'cancelled');

        double currentValue = 0;
        for (var invoice in currentResponse) {
          currentValue += (invoice['total'] ?? 0).toDouble();
        }

        // Ventas mes anterior
        final prevResponse = await _client
            .from('invoices')
            .select('total')
            .gte('issue_date', prevStartDate.toIso8601String())
            .lte('issue_date', prevEndDate.toIso8601String())
            .neq('status', 'cancelled');

        double previousValue = 0;
        for (var invoice in prevResponse) {
          previousValue += (invoice['total'] ?? 0).toDouble();
        }

        chartData.add(SalesChartData(
          label: months[month - 1],
          currentValue: currentValue,
          previousValue: previousValue,
        ));
      }

      return chartData;
    } catch (e) {
      print('❌ Error obteniendo gráfico de ventas: $e');
      return [];
    }
  }

  /// Obtener productos más vendidos
  static Future<List<TopProduct>> getTopProducts({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 10,
  }) async {
    try {
      // Obtener items de facturas con productos
      final response = await _client
          .from('invoice_items')
          .select('''
            product_id,
            quantity,
            subtotal,
            products(id, code, name)
          ''')
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String());

      // Agrupar por producto
      final Map<String, TopProduct> productMap = {};
      
      for (var item in response) {
        final productId = item['product_id'] ?? '';
        final product = item['products'];
        
        if (product != null && productId.isNotEmpty) {
          final quantity = (item['quantity'] ?? 0).toDouble();
          final subtotal = (item['subtotal'] ?? 0).toDouble();
          
          if (productMap.containsKey(productId)) {
            final existing = productMap[productId]!;
            productMap[productId] = TopProduct(
              productId: productId,
              productName: existing.productName,
              productCode: existing.productCode,
              quantity: existing.quantity + quantity,
              totalSales: existing.totalSales + subtotal,
              transactionCount: existing.transactionCount + 1,
            );
          } else {
            productMap[productId] = TopProduct(
              productId: productId,
              productName: product['name'] ?? '',
              productCode: product['code'] ?? '',
              quantity: quantity,
              totalSales: subtotal,
              transactionCount: 1,
            );
          }
        }
      }

      // Ordenar por ventas totales y limitar
      final sorted = productMap.values.toList()
        ..sort((a, b) => b.totalSales.compareTo(a.totalSales));
      
      return sorted.take(limit).toList();
    } catch (e) {
      print('❌ Error obteniendo productos más vendidos: $e');
      return [];
    }
  }

  /// Obtener ventas por cliente
  static Future<List<CustomerSales>> getSalesByCustomer({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _client
          .from('invoices')
          .select('''
            customer_id,
            total,
            paid_amount,
            customers(id, name)
          ''')
          .gte('issue_date', startDate.toIso8601String())
          .lte('issue_date', endDate.toIso8601String())
          .neq('status', 'cancelled');

      // Agrupar por cliente
      final Map<String, CustomerSales> customerMap = {};
      
      for (var invoice in response) {
        final customerId = invoice['customer_id'] ?? '';
        final customer = invoice['customers'];
        
        if (customer != null && customerId.isNotEmpty) {
          final totalAmount = (invoice['total'] ?? 0).toDouble();
          final paidAmount = (invoice['paid_amount'] ?? 0).toDouble();
          final pending = totalAmount - paidAmount;
          
          if (customerMap.containsKey(customerId)) {
            final existing = customerMap[customerId]!;
            customerMap[customerId] = CustomerSales(
              customerId: customerId,
              customerName: existing.customerName,
              totalSales: existing.totalSales + totalAmount,
              transactionCount: existing.transactionCount + 1,
              averageTicket: (existing.totalSales + totalAmount) / (existing.transactionCount + 1),
              pendingBalance: existing.pendingBalance + pending,
            );
          } else {
            customerMap[customerId] = CustomerSales(
              customerId: customerId,
              customerName: customer['name'] ?? '',
              totalSales: totalAmount,
              transactionCount: 1,
              averageTicket: totalAmount,
              pendingBalance: pending,
            );
          }
        }
      }

      // Ordenar por ventas totales
      final sorted = customerMap.values.toList()
        ..sort((a, b) => b.totalSales.compareTo(a.totalSales));
      
      return sorted;
    } catch (e) {
      print('❌ Error obteniendo ventas por cliente: $e');
      return [];
    }
  }

  /// Obtener reporte de inventario
  static Future<List<InventoryReport>> getInventoryReport({bool lowStockOnly = false}) async {
    try {
      final response = await _client
          .from('products')
          .select()
          .eq('is_active', true)
          .order('code');

      final List<InventoryReport> reports = [];
      
      for (var product in response) {
        final stock = (product['stock'] ?? 0).toDouble();
        final minStock = (product['min_stock'] ?? 0).toDouble();
        final unitPrice = (product['unit_price'] ?? 0).toDouble();
        final costPrice = (product['cost_price'] ?? 0).toDouble();
        final isLowStock = stock <= minStock;

        if (lowStockOnly && !isLowStock) continue;

        reports.add(InventoryReport(
          productId: product['id'] ?? '',
          productCode: product['code'] ?? '',
          productName: product['name'] ?? '',
          currentStock: stock,
          minStock: minStock,
          unitPrice: unitPrice,
          costPrice: costPrice,
          totalValue: stock * costPrice,
          isLowStock: isLowStock,
        ));
      }

      return reports;
    } catch (e) {
      print('❌ Error obteniendo reporte de inventario: $e');
      return [];
    }
  }

  /// Obtener resumen de inventario
  static Future<Map<String, dynamic>> getInventorySummary() async {
    try {
      final products = await getInventoryReport();
      
      int totalProducts = products.length;
      int lowStockCount = products.where((p) => p.isLowStock).length;
      double totalValue = products.fold(0, (sum, p) => sum + p.totalValue);
      double totalStock = products.fold(0, (sum, p) => sum + p.currentStock);

      return {
        'totalProducts': totalProducts,
        'lowStockCount': lowStockCount,
        'totalValue': totalValue,
        'totalStock': totalStock,
      };
    } catch (e) {
      print('❌ Error obteniendo resumen de inventario: $e');
      return {
        'totalProducts': 0,
        'lowStockCount': 0,
        'totalValue': 0.0,
        'totalStock': 0.0,
      };
    }
  }

  /// Obtener cuentas por cobrar (antigüedad de saldos)
  static Future<List<ReceivableReport>> getReceivablesReport() async {
    try {
      final now = DateTime.now();
      
      final response = await _client
          .from('invoices')
          .select('''
            id,
            customer_id,
            total,
            paid_amount,
            due_date,
            customers(id, name)
          ''')
          .or('status.eq.issued,status.eq.partial')
          .order('due_date');

      // Agrupar por cliente
      final Map<String, ReceivableReport> customerMap = {};
      
      for (var invoice in response) {
        final customerId = invoice['customer_id'] ?? '';
        final customer = invoice['customers'];
        
        if (customer != null && customerId.isNotEmpty) {
          final total = (invoice['total'] ?? 0).toDouble();
          final paid = (invoice['paid_amount'] ?? 0).toDouble();
          final pending = total - paid;
          final dueDate = DateTime.parse(invoice['due_date'] ?? now.toIso8601String());
          final daysOverdue = now.difference(dueDate).inDays;

          double current = 0, overdue30 = 0, overdue60 = 0, overdue90 = 0;
          int overdueCount = 0;

          if (daysOverdue <= 0) {
            current = pending;
          } else if (daysOverdue <= 30) {
            overdue30 = pending;
            overdueCount = 1;
          } else if (daysOverdue <= 60) {
            overdue60 = pending;
            overdueCount = 1;
          } else {
            overdue90 = pending;
            overdueCount = 1;
          }

          if (customerMap.containsKey(customerId)) {
            final existing = customerMap[customerId]!;
            customerMap[customerId] = ReceivableReport(
              customerId: customerId,
              customerName: existing.customerName,
              totalDebt: existing.totalDebt + pending,
              current: existing.current + current,
              overdue30: existing.overdue30 + overdue30,
              overdue60: existing.overdue60 + overdue60,
              overdue90: existing.overdue90 + overdue90,
              overdueInvoices: existing.overdueInvoices + overdueCount,
            );
          } else {
            customerMap[customerId] = ReceivableReport(
              customerId: customerId,
              customerName: customer['name'] ?? '',
              totalDebt: pending,
              current: current,
              overdue30: overdue30,
              overdue60: overdue60,
              overdue90: overdue90,
              overdueInvoices: overdueCount,
            );
          }
        }
      }

      // Ordenar por deuda total
      final sorted = customerMap.values.toList()
        ..sort((a, b) => b.totalDebt.compareTo(a.totalDebt));
      
      return sorted;
    } catch (e) {
      print('❌ Error obteniendo cuentas por cobrar: $e');
      return [];
    }
  }

  /// Obtener resumen de cuentas por cobrar
  static Future<Map<String, dynamic>> getReceivablesSummary() async {
    try {
      final receivables = await getReceivablesReport();
      
      double totalDebt = 0, current = 0, overdue30 = 0, overdue60 = 0, overdue90 = 0;
      int totalCustomers = receivables.length;
      int overdueCustomers = 0;

      for (var r in receivables) {
        totalDebt += r.totalDebt;
        current += r.current;
        overdue30 += r.overdue30;
        overdue60 += r.overdue60;
        overdue90 += r.overdue90;
        if (r.overdueInvoices > 0) overdueCustomers++;
      }

      return {
        'totalDebt': totalDebt,
        'current': current,
        'overdue30': overdue30,
        'overdue60': overdue60,
        'overdue90': overdue90,
        'totalCustomers': totalCustomers,
        'overdueCustomers': overdueCustomers,
      };
    } catch (e) {
      print('❌ Error obteniendo resumen de cuentas por cobrar: $e');
      return {
        'totalDebt': 0.0,
        'current': 0.0,
        'overdue30': 0.0,
        'overdue60': 0.0,
        'overdue90': 0.0,
        'totalCustomers': 0,
        'overdueCustomers': 0,
      };
    }
  }
}
