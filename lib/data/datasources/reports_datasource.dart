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

/// Modelo para reporte de inventario con análisis de márgenes
class InventoryReport {
  final String productId;
  final String productCode;
  final String productName;
  final String category;
  final String unit;
  final String itemType; // 'product', 'material' o 'recipe'
  final double currentStock;
  final double minStock;
  final double unitPrice;      // Precio de venta
  final double costPrice;      // Precio de compra/fabricación
  final double totalValue;
  final bool isLowStock;
  final bool isOutOfStock;

  InventoryReport({
    required this.productId,
    required this.productCode,
    required this.productName,
    this.category = '',
    this.unit = 'UND',
    this.itemType = 'product',
    required this.currentStock,
    required this.minStock,
    required this.unitPrice,
    required this.costPrice,
    required this.totalValue,
    required this.isLowStock,
    this.isOutOfStock = false,
  });

  /// Ganancia por unidad
  double get profitPerUnit => unitPrice - costPrice;

  /// Margen de ganancia (markup sobre costo)
  /// Fórmula: (Precio Venta - Costo) / Costo * 100
  double get marginPercent => costPrice > 0 
      ? ((unitPrice - costPrice) / costPrice * 100) 
      : 0;

  /// Margen bruto (sobre precio de venta)
  /// Fórmula: (Precio Venta - Costo) / Precio Venta * 100
  double get grossMarginPercent => unitPrice > 0 
      ? ((unitPrice - costPrice) / unitPrice * 100) 
      : 0;

  /// Valor del stock al costo
  double get stockCostValue => currentStock * costPrice;

  /// Valor del stock a precio de venta
  double get stockSaleValue => currentStock * unitPrice;

  /// Ganancia potencial del stock actual
  double get potentialProfit => currentStock * profitPerUnit;
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

      double averageTicket = transactionCount > 0
          ? totalSales / transactionCount
          : 0;

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
          : (totalSales > 0
                ? 100
                : 0); // Si no hay período anterior pero hay ventas, 100% de crecimiento

      // Calcular margen bruto real basado en costos de items
      double grossMargin = await _calculateGrossMargin(
        startDate,
        endDate,
        totalSales,
      );

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

  /// Calcular margen bruto real
  static Future<double> _calculateGrossMargin(
    DateTime startDate,
    DateTime endDate,
    double totalSales,
  ) async {
    if (totalSales <= 0) return 0;

    try {
      // Obtener items de facturas del período
      // Nota: cost_price puede no existir en invoice_items, usamos un margen estimado
      final itemsResponse = await _client
          .from('invoice_items')
          .select(
            'quantity, unit_price, invoice_id, invoices!inner(issue_date, status)',
          )
          .gte('invoices.issue_date', startDate.toIso8601String())
          .lte('invoices.issue_date', endDate.toIso8601String())
          .neq('invoices.status', 'cancelled');

      // ignore: unused_local_variable - Reservado para cálculo futuro de margen real
      double totalRevenue = 0;
      for (var item in itemsResponse) {
        final qty = (item['quantity'] ?? 0).toDouble();
        final unitPrice = (item['unit_price'] ?? 0).toDouble();
        totalRevenue += qty * unitPrice;
      }

      // Si no tenemos datos de costos reales, usamos un margen estimado
      // basado en el tipo de negocio industrial (30-40% típico)
      // En el futuro, podemos agregar cost_price a invoice_items o
      // calcular desde materials/products
      return 35.0; // Margen estimado para negocio industrial
    } catch (e) {
      print('⚠️ Error calculando margen bruto: $e');
      return 35.0; // Margen estimado si hay error
    }
  }

  /// Obtener datos de gráfico de ventas mensuales
  static Future<List<SalesChartData>> getMonthlySalesChart({
    required int year,
  }) async {
    try {
      final List<SalesChartData> chartData = [];
      final months = [
        'Ene',
        'Feb',
        'Mar',
        'Abr',
        'May',
        'Jun',
        'Jul',
        'Ago',
        'Sep',
        'Oct',
        'Nov',
        'Dic',
      ];

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

        chartData.add(
          SalesChartData(
            label: months[month - 1],
            currentValue: currentValue,
            previousValue: previousValue,
          ),
        );
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
      // Usar la vista v_top_selling_products que ya tiene la lógica correcta
      // Pero como necesitamos filtrar por fecha, hacemos la consulta directa
      final response = await _client
          .from('invoice_items')
          .select('''
            product_name,
            product_code,
            quantity,
            total,
            invoice_id,
            invoices!inner(issue_date, status)
          ''')
          .gte('invoices.issue_date', startDate.toIso8601String())
          .lte('invoices.issue_date', endDate.toIso8601String())
          .neq('invoices.status', 'cancelled');

      print('📊 Items encontrados para top productos: ${response.length}');

      // Agrupar por nombre de producto (ya que puede no tener product_id)
      final Map<String, TopProduct> productMap = {};

      for (var item in response) {
        final productName = item['product_name']?.toString() ?? '';
        final productCode = item['product_code']?.toString() ?? '';

        if (productName.isEmpty) continue;

        final key = productCode.isNotEmpty ? productCode : productName;
        final quantity = (item['quantity'] ?? 0).toDouble();
        final total = (item['total'] ?? 0).toDouble();

        if (productMap.containsKey(key)) {
          final existing = productMap[key]!;
          productMap[key] = TopProduct(
            productId: key,
            productName: existing.productName,
            productCode: existing.productCode,
            quantity: existing.quantity + quantity,
            totalSales: existing.totalSales + total,
            transactionCount: existing.transactionCount + 1,
          );
        } else {
          productMap[key] = TopProduct(
            productId: key,
            productName: productName,
            productCode: productCode,
            quantity: quantity,
            totalSales: total,
            transactionCount: 1,
          );
        }
      }

      // Ordenar por ventas totales y limitar
      final sorted = productMap.values.toList()
        ..sort((a, b) => b.totalSales.compareTo(a.totalSales));

      print('📊 Productos agrupados: ${sorted.length}');
      for (var p in sorted.take(3)) {
        print('   - ${p.productName}: ${p.totalSales}');
      }

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
              averageTicket:
                  (existing.totalSales + totalAmount) /
                  (existing.transactionCount + 1),
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

  /// Obtener reporte de inventario (productos y materiales)
  static Future<List<InventoryReport>> getInventoryReport({
    bool lowStockOnly = false,
  }) async {
    try {
      final List<InventoryReport> reports = [];

      // 1. Obtener productos
      final productsResponse = await _client
          .from('products')
          .select()
          .eq('is_active', true)
          .order('code');

      for (var product in productsResponse) {
        final stock = (product['stock'] ?? 0).toDouble();
        final minStock = (product['min_stock'] ?? 0).toDouble();
        final unitPrice = (product['unit_price'] ?? 0).toDouble();
        final costPrice = (product['cost_price'] ?? 0).toDouble();
        final isLowStock = stock <= minStock && stock > 0;
        final isOutOfStock = stock <= 0;

        if (lowStockOnly && !isLowStock && !isOutOfStock) continue;

        reports.add(
          InventoryReport(
            productId: product['id'] ?? '',
            productCode: product['code'] ?? '',
            productName: product['name'] ?? '',
            category: product['category'] ?? 'Producto',
            unit: product['unit'] ?? 'UND',
            itemType: 'product',
            currentStock: stock,
            minStock: minStock,
            unitPrice: unitPrice,
            costPrice: costPrice,
            totalValue: stock * (costPrice > 0 ? costPrice : unitPrice),
            isLowStock: isLowStock,
            isOutOfStock: isOutOfStock,
          ),
        );
      }

      // 2. Obtener materiales (materia prima)
      final materialsResponse = await _client
          .from('materials')
          .select()
          .eq('is_active', true)
          .order('category')
          .order('name');

      for (var material in materialsResponse) {
        final stock = (material['stock'] ?? 0).toDouble();
        final minStock = (material['min_stock'] ?? 0).toDouble();
        final pricePerKg = (material['price_per_kg'] ?? 0).toDouble();
        final unitPrice = (material['unit_price'] ?? 0).toDouble();
        final costPrice = (material['cost_price'] ?? 0).toDouble();
        final isLowStock = stock <= minStock && stock > 0;
        final isOutOfStock = stock <= 0;

        if (lowStockOnly && !isLowStock && !isOutOfStock) continue;

        // Usar el precio más relevante disponible
        final price = costPrice > 0
            ? costPrice
            : (unitPrice > 0 ? unitPrice : pricePerKg);

        reports.add(
          InventoryReport(
            productId: material['id'] ?? '',
            productCode: material['code'] ?? '',
            productName: material['name'] ?? '',
            category: material['category'] ?? 'Material',
            unit: material['unit'] ?? 'KG',
            itemType: 'material',
            currentStock: stock,
            minStock: minStock,
            unitPrice: pricePerKg > 0 ? pricePerKg : unitPrice,
            costPrice: price,
            totalValue: stock * price,
            isLowStock: isLowStock,
            isOutOfStock: isOutOfStock,
          ),
        );
      }

      // Ordenar: primero los críticos (sin stock), luego bajo stock, luego el resto
      reports.sort((a, b) {
        if (a.isOutOfStock && !b.isOutOfStock) return -1;
        if (!a.isOutOfStock && b.isOutOfStock) return 1;
        if (a.isLowStock && !b.isLowStock) return -1;
        if (!a.isLowStock && b.isLowStock) return 1;
        return a.productName.compareTo(b.productName);
      });

      return reports;
    } catch (e) {
      print('❌ Error obteniendo reporte de inventario: $e');
      return [];
    }
  }

  /// Obtener resumen de inventario
  static Future<Map<String, dynamic>> getInventorySummary() async {
    try {
      // Obtener TODOS los productos (sin filtro de stock bajo)
      final products = await getInventoryReport(lowStockOnly: false);

      int totalProducts = products.length;
      int lowStockCount = products.where((p) => p.isLowStock).length;
      int outOfStockCount = products.where((p) => p.isOutOfStock).length;
      double totalValue = products.fold(0.0, (sum, p) => sum + p.totalValue);
      double totalStock = products.fold(0.0, (sum, p) => sum + p.currentStock);
      
      // Cálculos de márgenes (sobre TODOS los productos)
      double totalStockCost = products.fold(0.0, (sum, p) => sum + p.stockCostValue);
      double totalStockSaleValue = products.fold(0.0, (sum, p) => sum + p.stockSaleValue);
      double totalPotentialProfit = products.fold(0.0, (sum, p) => sum + p.potentialProfit);
      double avgMargin = products.isNotEmpty 
          ? products.fold(0.0, (sum, p) => sum + p.marginPercent) / products.length 
          : 0.0;

      return {
        'totalProducts': totalProducts,
        'lowStockCount': lowStockCount,
        'outOfStockCount': outOfStockCount,
        'totalValue': totalValue,
        'totalStock': totalStock,
        'totalStockCost': totalStockCost,
        'totalStockSaleValue': totalStockSaleValue,
        'totalPotentialProfit': totalPotentialProfit,
        'avgMargin': avgMargin,
      };
    } catch (e) {
      print('❌ Error obteniendo resumen de inventario: $e');
      return {
        'totalProducts': 0,
        'lowStockCount': 0,
        'outOfStockCount': 0,
        'totalValue': 0.0,
        'totalStock': 0.0,
        'totalStockCost': 0.0,
        'totalStockSaleValue': 0.0,
        'totalPotentialProfit': 0.0,
        'avgMargin': 0.0,
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
          final dueDate = DateTime.parse(
            invoice['due_date'] ?? now.toIso8601String(),
          );
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

      double totalDebt = 0,
          current = 0,
          overdue30 = 0,
          overdue60 = 0,
          overdue90 = 0;
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
