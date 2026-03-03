import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../datasources/accounting_datasource.dart';

/// Estado de contabilidad
class AccountingState {
  final List<JournalEntry> journalEntries;
  final List<BalanceItem> balanceGeneral;
  final List<ResultItem> estadoResultados;
  final List<TrialBalanceItem> balanceComprobacion;
  final List<LedgerItem> libroMayor;
  final List<ChartAccount> chartOfAccounts;
  final List<MonthlyPL> pylMensual;
  final int totalEntries;
  final bool isLoading;
  final String? error;
  final String? selectedAccountCode;
  final DateTime? startDate;
  final DateTime? endDate;

  AccountingState({
    this.journalEntries = const [],
    this.balanceGeneral = const [],
    this.estadoResultados = const [],
    this.balanceComprobacion = const [],
    this.libroMayor = const [],
    this.chartOfAccounts = const [],
    this.pylMensual = const [],
    this.totalEntries = 0,
    this.isLoading = false,
    this.error,
    this.selectedAccountCode,
    this.startDate,
    this.endDate,
  });

  AccountingState copyWith({
    List<JournalEntry>? journalEntries,
    List<BalanceItem>? balanceGeneral,
    List<ResultItem>? estadoResultados,
    List<TrialBalanceItem>? balanceComprobacion,
    List<LedgerItem>? libroMayor,
    List<ChartAccount>? chartOfAccounts,
    List<MonthlyPL>? pylMensual,
    int? totalEntries,
    bool? isLoading,
    String? error,
    String? selectedAccountCode,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return AccountingState(
      journalEntries: journalEntries ?? this.journalEntries,
      balanceGeneral: balanceGeneral ?? this.balanceGeneral,
      estadoResultados: estadoResultados ?? this.estadoResultados,
      balanceComprobacion: balanceComprobacion ?? this.balanceComprobacion,
      libroMayor: libroMayor ?? this.libroMayor,
      chartOfAccounts: chartOfAccounts ?? this.chartOfAccounts,
      pylMensual: pylMensual ?? this.pylMensual,
      totalEntries: totalEntries ?? this.totalEntries,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedAccountCode: selectedAccountCode ?? this.selectedAccountCode,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  // ── Getters calculados ──

  /// Total de activos
  double get totalActivos => balanceGeneral
      .where((b) => b.tipo == 'asset')
      .fold(0.0, (sum, b) => sum + b.saldo);

  /// Total de pasivos (en negativo, lo invertimos)
  double get totalPasivos => balanceGeneral
      .where((b) => b.tipo == 'liability')
      .fold(0.0, (sum, b) => sum + b.saldo.abs());

  /// Total de patrimonio
  double get totalPatrimonio => totalActivos - totalPasivos;

  /// Total de ingresos del período
  double get totalIngresos => estadoResultados
      .where((r) => r.tipo == 'income')
      .fold(0.0, (sum, r) => sum + r.monto);

  /// Total de gastos del período
  double get totalGastos => estadoResultados
      .where((r) => r.tipo == 'expense')
      .fold(0.0, (sum, r) => sum + r.monto);

  /// Utilidad neta
  double get utilidadNeta => totalIngresos - totalGastos;

  /// Margen de utilidad
  double get margenUtilidad =>
      totalIngresos > 0 ? (utilidadNeta / totalIngresos) * 100 : 0;
}

/// Notifier para contabilidad
class AccountingNotifier extends Notifier<AccountingState> {
  @override
  AccountingState build() => AccountingState();

  /// Cargar todo
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        AccountingDataSource.getJournalEntries(),
        AccountingDataSource.getBalanceGeneral(),
        AccountingDataSource.getEstadoResultados(),
        AccountingDataSource.getChartOfAccounts(),
        AccountingDataSource.getPyLMensual(),
        AccountingDataSource.countEntries(),
      ]);

      state = state.copyWith(
        journalEntries: results[0] as List<JournalEntry>,
        balanceGeneral: results[1] as List<BalanceItem>,
        estadoResultados: results[2] as List<ResultItem>,
        chartOfAccounts: results[3] as List<ChartAccount>,
        pylMensual: results[4] as List<MonthlyPL>,
        totalEntries: results[5] as int,
        isLoading: false,
      );
    } catch (e) {
      print('❌ Error cargando contabilidad: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Cargar libro diario con filtros
  Future<void> loadJournalEntries({
    DateTime? startDate,
    DateTime? endDate,
    String? accountCode,
    String? referenceType,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final entries = await AccountingDataSource.getJournalEntries(
        startDate: startDate,
        endDate: endDate,
        accountCode: accountCode,
        referenceType: referenceType,
      );
      state = state.copyWith(
        journalEntries: entries,
        isLoading: false,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Cargar balance general
  Future<void> loadBalanceGeneral({DateTime? hastaFecha}) async {
    state = state.copyWith(isLoading: true);
    try {
      final items = await AccountingDataSource.getBalanceGeneral(
        hastaFecha: hastaFecha,
      );
      state = state.copyWith(balanceGeneral: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Cargar estado de resultados
  Future<void> loadEstadoResultados({DateTime? desde, DateTime? hasta}) async {
    state = state.copyWith(isLoading: true);
    try {
      final items = await AccountingDataSource.getEstadoResultados(
        desde: desde,
        hasta: hasta,
      );
      state = state.copyWith(estadoResultados: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Cargar balance de comprobación
  Future<void> loadBalanceComprobacion() async {
    state = state.copyWith(isLoading: true);
    try {
      final items = await AccountingDataSource.getBalanceComprobacion();
      state = state.copyWith(balanceComprobacion: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Cargar libro mayor de una cuenta
  Future<void> loadLibroMayor(String? accountCode) async {
    state = state.copyWith(isLoading: true, selectedAccountCode: accountCode);
    try {
      final items = await AccountingDataSource.getLibroMayor(
        accountCode: accountCode,
      );
      state = state.copyWith(libroMayor: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Cargar P&L mensual
  Future<void> loadPyLMensual() async {
    try {
      final items = await AccountingDataSource.getPyLMensual();
      state = state.copyWith(pylMensual: items);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

/// Provider principal de contabilidad
final accountingProvider =
    NotifierProvider<AccountingNotifier, AccountingState>(() {
      return AccountingNotifier();
    });
