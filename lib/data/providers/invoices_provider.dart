import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../datasources/invoices_datasource.dart';
import '../../domain/entities/invoice.dart';

// Estado de los recibos de caja menor
class InvoicesState {
  final List<Invoice> invoices;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? monthlyStats;

  const InvoicesState({
    this.invoices = const [],
    this.isLoading = false,
    this.error,
    this.monthlyStats,
  });

  InvoicesState copyWith({
    List<Invoice>? invoices,
    bool? isLoading,
    String? error,
    Map<String, dynamic>? monthlyStats,
  }) {
    return InvoicesState(
      invoices: invoices ?? this.invoices,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      monthlyStats: monthlyStats ?? this.monthlyStats,
    );
  }

  // Getters útiles
  double get totalVentas => invoices
      .where((i) => i.status != InvoiceStatus.cancelled)
      .fold(0, (sum, i) => sum + i.total);

  double get totalPendiente => invoices
      .where((i) => i.status == InvoiceStatus.issued || i.status == InvoiceStatus.partial)
      .fold(0, (sum, i) => sum + (i.total - i.paidAmount));

  double get totalPagado => invoices
      .where((i) => i.status == InvoiceStatus.paid)
      .fold(0, (sum, i) => sum + i.total);

  int get countPendientes => invoices
      .where((i) => i.status == InvoiceStatus.issued || i.status == InvoiceStatus.partial)
      .length;

  int get countVencidas => invoices
      .where((i) => i.status == InvoiceStatus.overdue)
      .length;

  List<Invoice> get recentInvoices => invoices.take(10).toList();
}

// Notifier para manejar los recibos
class InvoicesNotifier extends Notifier<InvoicesState> {

  @override
  InvoicesState build() {
    // Cargar recibos al iniciar
    _loadInvoices();
    return const InvoicesState(isLoading: true);
  }

  Future<void> _loadInvoices() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      print('🔄 Cargando recibos desde Supabase...');
      final invoices = await InvoicesDataSource.getAll();
      print('✅ Recibos cargados: ${invoices.length}');
      final stats = await InvoicesDataSource.getMonthlyStats();
      print('✅ Stats: $stats');
      state = state.copyWith(
        invoices: invoices,
        monthlyStats: stats,
        isLoading: false,
      );
    } catch (e) {
      print('❌ Error cargando recibos: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar recibos: $e',
      );
    }
  }

  Future<void> refresh() async {
    await _loadInvoices();
  }

  Future<void> loadByStatus(InvoiceStatus status) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final statusStr = status.name;
      final invoices = await InvoicesDataSource.getByStatus(statusStr);
      state = state.copyWith(invoices: invoices, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al filtrar recibos: $e',
      );
    }
  }

  Future<bool> registerPayment(
    String invoiceId,
    double amount,
    PaymentMethod method, {
    String paymentType = 'complete',
    int? installmentNumber,
    int? totalInstallments,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await InvoicesDataSource.registerPayment(
        invoiceId: invoiceId,
        amount: amount,
        method: method.name,
        paymentType: paymentType,
        installmentNumber: installmentNumber,
        totalInstallments: totalInstallments,
      );
      await _loadInvoices(); // Recargar lista
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al registrar pago: $e',
      );
      return false;
    }
  }

  Future<bool> cancelInvoice(String invoiceId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await InvoicesDataSource.cancel(invoiceId);
      await _loadInvoices();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cancelar recibo: $e',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider principal de recibos
final invoicesProvider = NotifierProvider<InvoicesNotifier, InvoicesState>(() {
  return InvoicesNotifier();
});

// Provider para recibos recientes (dashboard)
final recentInvoicesProvider = Provider<List<Invoice>>((ref) {
  final state = ref.watch(invoicesProvider);
  return state.recentInvoices;
});

// Provider para estadísticas del dashboard
final invoiceStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final state = ref.watch(invoicesProvider);
  return {
    'totalVentas': state.totalVentas,
    'totalPendiente': state.totalPendiente,
    'totalPagado': state.totalPagado,
    'countPendientes': state.countPendientes,
    'countVencidas': state.countVencidas,
    'monthlyStats': state.monthlyStats,
  };
});

// Provider para recibos filtrados por estado
final filteredInvoicesProvider = Provider.family<List<Invoice>, InvoiceStatus?>((ref, status) {
  final state = ref.watch(invoicesProvider);
  if (status == null) return state.invoices;
  return state.invoices.where((i) => i.status == status).toList();
});
