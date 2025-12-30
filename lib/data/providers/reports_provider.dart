import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../datasources/reports_datasource.dart';

/// Estado para reportes de ventas
class SalesReportState {
  final SalesStats? stats;
  final List<SalesChartData> chartData;
  final List<TopProduct> topProducts;
  final List<CustomerSales> salesByCustomer;
  final bool isLoading;
  final String? error;
  final String selectedPeriod;
  final DateTime startDate;
  final DateTime endDate;

  SalesReportState({
    this.stats,
    this.chartData = const [],
    this.topProducts = const [],
    this.salesByCustomer = const [],
    this.isLoading = false,
    this.error,
    this.selectedPeriod = 'Este Mes',
    DateTime? startDate,
    DateTime? endDate,
  }) : startDate = startDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1),
       endDate = endDate ?? DateTime.now();

  SalesReportState copyWith({
    SalesStats? stats,
    List<SalesChartData>? chartData,
    List<TopProduct>? topProducts,
    List<CustomerSales>? salesByCustomer,
    bool? isLoading,
    String? error,
    String? selectedPeriod,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return SalesReportState(
      stats: stats ?? this.stats,
      chartData: chartData ?? this.chartData,
      topProducts: topProducts ?? this.topProducts,
      salesByCustomer: salesByCustomer ?? this.salesByCustomer,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}

/// Notifier para reportes de ventas
class SalesReportNotifier extends Notifier<SalesReportState> {
  @override
  SalesReportState build() {
    return SalesReportState();
  }

  /// Cambiar período
  void setPeriod(String period) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;

    switch (period) {
      case 'Hoy':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'Esta Semana':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        break;
      case 'Este Mes':
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'Este Trimestre':
        final quarter = ((now.month - 1) ~/ 3) * 3 + 1;
        startDate = DateTime(now.year, quarter, 1);
        break;
      case 'Este Año':
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month, 1);
    }

    state = state.copyWith(
      selectedPeriod: period,
      startDate: startDate,
      endDate: endDate,
    );

    loadSalesReport();
  }

  /// Cargar reporte de ventas completo
  Future<void> loadSalesReport() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      print('🔄 Cargando reporte de ventas...');
      
      final results = await Future.wait([
        ReportsDataSource.getSalesStats(
          startDate: state.startDate,
          endDate: state.endDate,
        ),
        ReportsDataSource.getMonthlySalesChart(year: DateTime.now().year),
        ReportsDataSource.getTopProducts(
          startDate: state.startDate,
          endDate: state.endDate,
        ),
        ReportsDataSource.getSalesByCustomer(
          startDate: state.startDate,
          endDate: state.endDate,
        ),
      ]);

      state = state.copyWith(
        stats: results[0] as SalesStats,
        chartData: results[1] as List<SalesChartData>,
        topProducts: results[2] as List<TopProduct>,
        salesByCustomer: results[3] as List<CustomerSales>,
        isLoading: false,
      );

      print('✅ Reporte de ventas cargado');
    } catch (e) {
      print('❌ Error cargando reporte: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

/// Estado para reporte de inventario
class InventoryReportState {
  final List<InventoryReport> products;
  final Map<String, dynamic> summary;
  final bool isLoading;
  final String? error;
  final bool showLowStockOnly;

  InventoryReportState({
    this.products = const [],
    this.summary = const {},
    this.isLoading = false,
    this.error,
    this.showLowStockOnly = true, // Por defecto solo muestra críticos en Analytics
  });

  InventoryReportState copyWith({
    List<InventoryReport>? products,
    Map<String, dynamic>? summary,
    bool? isLoading,
    String? error,
    bool? showLowStockOnly,
  }) {
    return InventoryReportState(
      products: products ?? this.products,
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      showLowStockOnly: showLowStockOnly ?? this.showLowStockOnly,
    );
  }
}

/// Notifier para reporte de inventario
class InventoryReportNotifier extends Notifier<InventoryReportState> {
  @override
  InventoryReportState build() {
    return InventoryReportState();
  }

  Future<void> loadInventoryReport() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      print('🔄 Cargando reporte de inventario...');
      
      final results = await Future.wait([
        ReportsDataSource.getInventoryReport(lowStockOnly: state.showLowStockOnly),
        ReportsDataSource.getInventorySummary(),
      ]);

      state = state.copyWith(
        products: results[0] as List<InventoryReport>,
        summary: results[1] as Map<String, dynamic>,
        isLoading: false,
      );

      print('✅ Reporte de inventario cargado: ${state.products.length} productos');
    } catch (e) {
      print('❌ Error cargando inventario: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void toggleLowStockFilter() {
    state = state.copyWith(showLowStockOnly: !state.showLowStockOnly);
    loadInventoryReport();
  }
}

/// Estado para cuentas por cobrar
class ReceivablesReportState {
  final List<ReceivableReport> receivables;
  final Map<String, dynamic> summary;
  final bool isLoading;
  final String? error;

  ReceivablesReportState({
    this.receivables = const [],
    this.summary = const {},
    this.isLoading = false,
    this.error,
  });

  ReceivablesReportState copyWith({
    List<ReceivableReport>? receivables,
    Map<String, dynamic>? summary,
    bool? isLoading,
    String? error,
  }) {
    return ReceivablesReportState(
      receivables: receivables ?? this.receivables,
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier para cuentas por cobrar
class ReceivablesReportNotifier extends Notifier<ReceivablesReportState> {
  @override
  ReceivablesReportState build() {
    return ReceivablesReportState();
  }

  Future<void> loadReceivablesReport() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      print('🔄 Cargando cuentas por cobrar...');
      
      final results = await Future.wait([
        ReportsDataSource.getReceivablesReport(),
        ReportsDataSource.getReceivablesSummary(),
      ]);

      state = state.copyWith(
        receivables: results[0] as List<ReceivableReport>,
        summary: results[1] as Map<String, dynamic>,
        isLoading: false,
      );

      print('✅ Cuentas por cobrar cargadas: ${state.receivables.length} clientes');
    } catch (e) {
      print('❌ Error cargando cuentas por cobrar: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// ============ PROVIDERS ============

/// Provider de reportes de ventas
final salesReportProvider = NotifierProvider<SalesReportNotifier, SalesReportState>(() {
  return SalesReportNotifier();
});

/// Provider de reporte de inventario
final inventoryReportProvider = NotifierProvider<InventoryReportNotifier, InventoryReportState>(() {
  return InventoryReportNotifier();
});

/// Provider de cuentas por cobrar
final receivablesReportProvider = NotifierProvider<ReceivablesReportNotifier, ReceivablesReportState>(() {
  return ReceivablesReportNotifier();
});
