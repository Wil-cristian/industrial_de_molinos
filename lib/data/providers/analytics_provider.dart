import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../datasources/analytics_datasource.dart';
import '../../domain/entities/analytics.dart';

// ============================================================
// ESTADO DE ANALYTICS
// ============================================================

class AnalyticsState {
  final List<CustomerMetrics> customerMetrics;
  final List<TopSellingProduct> topProducts;
  final List<ProfitLossMonthly> profitLoss;
  final List<AccountReceivableAging> accountsReceivable;
  final Map<String, double> agingSummary;
  final List<DSOMonthly> dsoTrend;
  final CollectionKPIs? collectionKPIs;
  final List<ProductABC> productABC;
  final bool isLoading;
  final String? error;

  AnalyticsState({
    this.customerMetrics = const [],
    this.topProducts = const [],
    this.profitLoss = const [],
    this.accountsReceivable = const [],
    this.agingSummary = const {},
    this.dsoTrend = const [],
    this.collectionKPIs,
    this.productABC = const [],
    this.isLoading = false,
    this.error,
  });

  AnalyticsState copyWith({
    List<CustomerMetrics>? customerMetrics,
    List<TopSellingProduct>? topProducts,
    List<ProfitLossMonthly>? profitLoss,
    List<AccountReceivableAging>? accountsReceivable,
    Map<String, double>? agingSummary,
    List<DSOMonthly>? dsoTrend,
    CollectionKPIs? collectionKPIs,
    List<ProductABC>? productABC,
    bool? isLoading,
    String? error,
  }) {
    return AnalyticsState(
      customerMetrics: customerMetrics ?? this.customerMetrics,
      topProducts: topProducts ?? this.topProducts,
      profitLoss: profitLoss ?? this.profitLoss,
      accountsReceivable: accountsReceivable ?? this.accountsReceivable,
      agingSummary: agingSummary ?? this.agingSummary,
      dsoTrend: dsoTrend ?? this.dsoTrend,
      collectionKPIs: collectionKPIs ?? this.collectionKPIs,
      productABC: productABC ?? this.productABC,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  // Helpers
  double get totalReceivables =>
      agingSummary.values.fold(0, (sum, val) => sum + val);

  double get overdueReceivables => (agingSummary['1-30 days'] ?? 0) +
      (agingSummary['31-60 days'] ?? 0) +
      (agingSummary['61-90 days'] ?? 0) +
      (agingSummary['over 90 days'] ?? 0);
}

// ============================================================
// NOTIFIER DE ANALYTICS
// ============================================================

class AnalyticsNotifier extends Notifier<AnalyticsState> {
  @override
  AnalyticsState build() {
    return AnalyticsState();
  }

  /// Cargar todos los datos de analytics
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final results = await Future.wait([
        AnalyticsDataSource.getAllCustomerMetrics(),
        AnalyticsDataSource.getTopSellingProducts(limit: 20),
        AnalyticsDataSource.getProfitLoss(limit: 12),
        AnalyticsDataSource.getAccountsReceivable(),
        AnalyticsDataSource.getAgingSummary(),
        AnalyticsDataSource.getDSOTrend(months: 12),
        AnalyticsDataSource.getCollectionKPIs(),
        AnalyticsDataSource.getProductABCAnalysis(),
      ]);

      state = state.copyWith(
        customerMetrics: results[0] as List<CustomerMetrics>,
        topProducts: results[1] as List<TopSellingProduct>,
        profitLoss: results[2] as List<ProfitLossMonthly>,
        accountsReceivable: results[3] as List<AccountReceivableAging>,
        agingSummary: results[4] as Map<String, double>,
        dsoTrend: results[5] as List<DSOMonthly>,
        collectionKPIs: results[6] as CollectionKPIs,
        productABC: results[7] as List<ProductABC>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error cargando analytics: $e',
      );
    }
  }

  /// Cargar solo métricas de clientes
  Future<void> loadCustomerMetrics() async {
    state = state.copyWith(isLoading: true);
    try {
      final metrics = await AnalyticsDataSource.getAllCustomerMetrics();
      state = state.copyWith(customerMetrics: metrics, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Cargar productos top
  Future<void> loadTopProducts({int limit = 20}) async {
    state = state.copyWith(isLoading: true);
    try {
      final products =
          await AnalyticsDataSource.getTopSellingProducts(limit: limit);
      state = state.copyWith(topProducts: products, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Cargar P&L
  Future<void> loadProfitLoss({int? year}) async {
    state = state.copyWith(isLoading: true);
    try {
      final pl = await AnalyticsDataSource.getProfitLoss(year: year);
      state = state.copyWith(profitLoss: pl, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Cargar cuentas por cobrar
  Future<void> loadAccountsReceivable() async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await Future.wait([
        AnalyticsDataSource.getAccountsReceivable(),
        AnalyticsDataSource.getAgingSummary(),
      ]);
      state = state.copyWith(
        accountsReceivable: results[0] as List<AccountReceivableAging>,
        agingSummary: results[1] as Map<String, double>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// ============================================================
// ESTADO DE HISTORIAL DE CLIENTE
// ============================================================

class CustomerHistoryState {
  final String? customerId;
  final CustomerMetrics? metrics;
  final CustomerCLV? clv;
  final List<CustomerPurchaseHistory> purchaseHistory;
  final List<CustomerProductAnalysis> productAnalysis;
  final bool isLoading;
  final String? error;

  CustomerHistoryState({
    this.customerId,
    this.metrics,
    this.clv,
    this.purchaseHistory = const [],
    this.productAnalysis = const [],
    this.isLoading = false,
    this.error,
  });

  CustomerHistoryState copyWith({
    String? customerId,
    CustomerMetrics? metrics,
    CustomerCLV? clv,
    List<CustomerPurchaseHistory>? purchaseHistory,
    List<CustomerProductAnalysis>? productAnalysis,
    bool? isLoading,
    String? error,
  }) {
    return CustomerHistoryState(
      customerId: customerId ?? this.customerId,
      metrics: metrics ?? this.metrics,
      clv: clv ?? this.clv,
      purchaseHistory: purchaseHistory ?? this.purchaseHistory,
      productAnalysis: productAnalysis ?? this.productAnalysis,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  // Agrupar compras por factura
  Map<String, List<CustomerPurchaseHistory>> get purchasesByInvoice {
    final Map<String, List<CustomerPurchaseHistory>> grouped = {};
    for (var item in purchaseHistory) {
      if (item.invoiceId != null) {
        grouped.putIfAbsent(item.invoiceId!, () => []).add(item);
      }
    }
    return grouped;
  }

  // Productos únicos comprados
  List<String> get uniqueProducts {
    return productAnalysis.map((p) => p.productName ?? '').toSet().toList();
  }
}

// ============================================================
// NOTIFIER DE HISTORIAL DE CLIENTE
// ============================================================

class CustomerHistoryNotifier extends Notifier<CustomerHistoryState> {
  @override
  CustomerHistoryState build() {
    return CustomerHistoryState();
  }

  /// Cargar historial completo de un cliente
  Future<void> loadCustomerHistory(String customerId) async {
    state = CustomerHistoryState(customerId: customerId, isLoading: true);

    try {
      final results = await Future.wait([
        AnalyticsDataSource.getCustomerMetrics(customerId),
        AnalyticsDataSource.calculateCustomerCLV(customerId),
        AnalyticsDataSource.getCustomerPurchaseHistory(customerId),
        AnalyticsDataSource.getCustomerProductAnalysis(customerId),
      ]);

      state = state.copyWith(
        metrics: results[0] as CustomerMetrics?,
        clv: results[1] as CustomerCLV?,
        purchaseHistory: results[2] as List<CustomerPurchaseHistory>,
        productAnalysis: results[3] as List<CustomerProductAnalysis>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error cargando historial: $e',
      );
    }
  }

  /// Limpiar estado
  void clear() {
    state = CustomerHistoryState();
  }
}

// ============================================================
// ESTADO DE CONSUMO DE MATERIALES
// ============================================================

class MaterialConsumptionState {
  final List<MaterialConsumption> consumption;
  final bool isLoading;
  final String? error;

  MaterialConsumptionState({
    this.consumption = const [],
    this.isLoading = false,
    this.error,
  });

  MaterialConsumptionState copyWith({
    List<MaterialConsumption>? consumption,
    bool? isLoading,
    String? error,
  }) {
    return MaterialConsumptionState(
      consumption: consumption ?? this.consumption,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  // Agrupar por mes
  Map<String, List<MaterialConsumption>> get byMonth {
    final Map<String, List<MaterialConsumption>> grouped = {};
    for (var item in consumption) {
      final key =
          '${item.month.year}-${item.month.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }

  // Top materiales consumidos
  List<MaterialConsumption> get topConsumed {
    final byMaterial = <String, double>{};
    for (var item in consumption) {
      byMaterial[item.materialId] =
          (byMaterial[item.materialId] ?? 0) + item.consumed;
    }
    final sorted = byMaterial.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .take(10)
        .map((e) => consumption.firstWhere((c) => c.materialId == e.key))
        .toList();
  }
}

// ============================================================
// NOTIFIER DE CONSUMO DE MATERIALES
// ============================================================

class MaterialConsumptionNotifier extends Notifier<MaterialConsumptionState> {
  @override
  MaterialConsumptionState build() {
    return MaterialConsumptionState();
  }

  /// Cargar consumo de materiales
  Future<void> loadConsumption({DateTime? fromMonth, int limit = 100}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final data = await AnalyticsDataSource.getMaterialConsumption(
        fromMonth: fromMonth,
        limit: limit,
      );
      state = state.copyWith(consumption: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Cargar consumo de un material específico
  Future<void> loadMaterialConsumption(String materialId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final data =
          await AnalyticsDataSource.getMaterialConsumptionById(materialId);
      state = state.copyWith(consumption: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// ============================================================
// PROVIDERS
// ============================================================

/// Provider principal de analytics
final analyticsProvider =
    NotifierProvider<AnalyticsNotifier, AnalyticsState>(AnalyticsNotifier.new);

/// Provider de historial de cliente
final customerHistoryProvider =
    NotifierProvider<CustomerHistoryNotifier, CustomerHistoryState>(
        CustomerHistoryNotifier.new);

/// Provider de consumo de materiales
final materialConsumptionProvider =
    NotifierProvider<MaterialConsumptionNotifier, MaterialConsumptionState>(
        MaterialConsumptionNotifier.new);

// ============================================================
// PROVIDERS AUXILIARES (para consultas específicas)
// ============================================================

/// Provider para obtener CLV de un cliente específico
final customerCLVProvider =
    FutureProvider.family<CustomerCLV?, String>((ref, customerId) async {
  return await AnalyticsDataSource.calculateCustomerCLV(customerId);
});

/// Provider para obtener productos relacionados
final relatedProductsProvider = FutureProvider.family<List<RelatedProduct>,
    String>((ref, productCode) async {
  return await AnalyticsDataSource.getRelatedProducts(productCode);
});

/// Provider para dashboard summary
final dashboardSummaryProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  return await AnalyticsDataSource.getDashboardSummary();
});

/// Provider para top clientes
final topCustomersProvider =
    FutureProvider.family<List<CustomerMetrics>, int>((ref, limit) async {
  return await AnalyticsDataSource.getTopCustomers(limit: limit);
});
