import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../datasources/iva_datasource.dart';

/// Estado del módulo IVA
class IvaState {
  final List<IvaInvoice> invoices;
  final BimonthlySettlement? currentSettlement;
  final List<SettlementRecord> settlements;
  final List<BimonthlySummaryView> summaries;
  final IvaConfig? config;
  final String selectedPeriod;
  final String? selectedType; // null = todos, 'COMPRA', 'VENTA'
  final bool isLoading;
  final String? error;

  IvaState({
    this.invoices = const [],
    this.currentSettlement,
    this.settlements = const [],
    this.summaries = const [],
    this.config,
    this.selectedPeriod = '',
    this.selectedType,
    this.isLoading = false,
    this.error,
  });

  /// IVA ventas del periodo seleccionado
  double get totalIvaVentas => invoices
      .where((i) => i.invoiceType == 'VENTA')
      .fold(0.0, (sum, i) => sum + i.ivaAmount);

  /// IVA compras del periodo seleccionado
  double get totalIvaCompras => invoices
      .where((i) => i.invoiceType == 'COMPRA')
      .fold(0.0, (sum, i) => sum + i.ivaAmount);

  /// Base ventas del periodo
  double get totalBaseVentas => invoices
      .where((i) => i.invoiceType == 'VENTA')
      .fold(0.0, (sum, i) => sum + i.baseAmount);

  /// Base compras del periodo
  double get totalBaseCompras => invoices
      .where((i) => i.invoiceType == 'COMPRA')
      .fold(0.0, (sum, i) => sum + i.baseAmount);

  /// Facturas filtradas
  List<IvaInvoice> get filteredInvoices {
    if (selectedType == null) return invoices;
    return invoices.where((i) => i.invoiceType == selectedType).toList();
  }

  IvaState copyWith({
    List<IvaInvoice>? invoices,
    BimonthlySettlement? currentSettlement,
    List<SettlementRecord>? settlements,
    List<BimonthlySummaryView>? summaries,
    IvaConfig? config,
    String? selectedPeriod,
    String? selectedType,
    bool? isLoading,
    String? error,
    bool clearType = false,
    bool clearSettlement = false,
  }) {
    return IvaState(
      invoices: invoices ?? this.invoices,
      currentSettlement: clearSettlement
          ? null
          : (currentSettlement ?? this.currentSettlement),
      settlements: settlements ?? this.settlements,
      summaries: summaries ?? this.summaries,
      config: config ?? this.config,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      selectedType: clearType ? null : (selectedType ?? this.selectedType),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Provider principal del módulo IVA
class IvaNotifier extends Notifier<IvaState> {
  @override
  IvaState build() => IvaState();

  /// Cargar todo al iniciar
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Periodo actual
      final currentPeriod = getBimonthlyPeriod(DateTime.now());
      final period = state.selectedPeriod.isEmpty
          ? currentPeriod
          : state.selectedPeriod;

      // Cargar en paralelo
      final results = await Future.wait([
        IvaDataSource.getInvoices(period: period),
        IvaDataSource.getConfig(DateTime.now().year),
        IvaDataSource.getBimonthlySummaries(),
        IvaDataSource.getSettlements(),
      ]);

      state = state.copyWith(
        invoices: results[0] as List<IvaInvoice>,
        config: results[1] as IvaConfig?,
        summaries: results[2] as List<BimonthlySummaryView>,
        settlements: results[3] as List<SettlementRecord>,
        selectedPeriod: period,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Cambiar periodo seleccionado
  Future<void> changePeriod(String period) async {
    state = state.copyWith(
      selectedPeriod: period,
      isLoading: true,
      error: null,
    );
    try {
      final invoices = await IvaDataSource.getInvoices(period: period);
      state = state.copyWith(invoices: invoices, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Filtrar por tipo
  void filterByType(String? type) {
    if (type == null) {
      state = state.copyWith(clearType: true);
    } else {
      state = state.copyWith(selectedType: type);
    }
  }

  /// Crear factura IVA
  Future<bool> createInvoice(IvaInvoice invoice) async {
    try {
      await IvaDataSource.createInvoice(invoice);
      await _reloadInvoices();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Actualizar factura IVA
  Future<bool> updateInvoice(IvaInvoice invoice) async {
    try {
      await IvaDataSource.updateInvoice(invoice);
      await _reloadInvoices();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Eliminar factura IVA
  Future<bool> deleteInvoice(String id) async {
    try {
      await IvaDataSource.deleteInvoice(id);
      await _reloadInvoices();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Liquidar bimestre
  Future<BimonthlySettlement?> liquidarBimestre(String period) async {
    try {
      final settlement = await IvaDataSource.liquidarBimestre(period);
      // Recargar liquidaciones
      final settlements = await IvaDataSource.getSettlements();
      state = state.copyWith(
        currentSettlement: settlement,
        settlements: settlements,
      );
      return settlement;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Marcar como declarado
  Future<void> markAsSettled(String period) async {
    try {
      await IvaDataSource.markAsSettled(period);
      final settlements = await IvaDataSource.getSettlements();
      state = state.copyWith(settlements: settlements);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Guardar configuración
  Future<bool> saveConfig(IvaConfig config) async {
    try {
      final saved = await IvaDataSource.saveConfig(config);
      state = state.copyWith(config: saved);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Recargar facturas del periodo actual
  Future<void> _reloadInvoices() async {
    try {
      final period = state.selectedPeriod.isEmpty
          ? getBimonthlyPeriod(DateTime.now())
          : state.selectedPeriod;
      final invoices = await IvaDataSource.getInvoices(period: period);
      final summaries = await IvaDataSource.getBimonthlySummaries();
      state = state.copyWith(invoices: invoices, summaries: summaries);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

/// Provider global
final ivaProvider = NotifierProvider<IvaNotifier, IvaState>(() {
  return IvaNotifier();
});
