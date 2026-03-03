import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/logger.dart';
import '../datasources/invoices_datasource.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/customer.dart';

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
      .where(
        (i) =>
            i.status == InvoiceStatus.issued ||
            i.status == InvoiceStatus.partial,
      )
      .fold(0, (sum, i) => sum + (i.total - i.paidAmount));

  double get totalPagado => invoices
      .where((i) => i.status == InvoiceStatus.paid)
      .fold(0, (sum, i) => sum + i.total);

  int get countPendientes => invoices
      .where(
        (i) =>
            i.status == InvoiceStatus.issued ||
            i.status == InvoiceStatus.partial,
      )
      .length;

  int get countVencidas =>
      invoices.where((i) => i.status == InvoiceStatus.overdue).length;

  List<Invoice> get recentInvoices => invoices.take(10).toList();
}

// Notifier para manejar los recibos
class InvoicesNotifier extends Notifier<InvoicesState> {
  @override
  InvoicesState build() {
    // Cargar recibos al iniciar - usar Future.microtask para evitar
    // acceder al state antes de que build() retorne
    Future.microtask(() => _loadInvoices());
    return const InvoicesState(isLoading: true);
  }

  Future<void> _loadInvoices() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      AppLogger.debug('🔄 Cargando recibos desde Supabase...');
      final invoices = await InvoicesDataSource.getAll();
      AppLogger.success('✅ Recibos cargados: ${invoices.length}');
      final stats = await InvoicesDataSource.getMonthlyStats();
      AppLogger.success('✅ Stats: $stats');
      state = state.copyWith(
        invoices: invoices,
        monthlyStats: stats,
        isLoading: false,
      );
    } catch (e) {
      AppLogger.error('❌ Error cargando recibos: $e');
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
    String? accountId,
    String paymentType = 'complete',
    int? installmentNumber,
    int? totalInstallments,
  }) async {
    // Guardar estado previo para rollback
    final previousState = state;

    try {
      // Actualización optimista: actualizar invoice local inmediatamente
      final updatedInvoices = state.invoices.map((inv) {
        if (inv.id == invoiceId) {
          final newPaid = inv.paidAmount + amount;
          final newStatus = newPaid >= inv.total
              ? InvoiceStatus.paid
              : InvoiceStatus.partial;
          return inv.copyWith(paidAmount: newPaid, status: newStatus);
        }
        return inv;
      }).toList();

      state = state.copyWith(invoices: updatedInvoices, error: null);

      // Enviar al servidor
      await InvoicesDataSource.registerPayment(
        invoiceId: invoiceId,
        amount: amount,
        method: method.name,
        accountId: accountId,
        paymentType: paymentType,
        installmentNumber: installmentNumber,
        totalInstallments: totalInstallments,
      );

      // Refrescar stats en background (no bloquea UI)
      _refreshStatsInBackground();
      return true;
    } catch (e) {
      // Rollback al estado previo
      state = previousState.copyWith(error: 'Error al registrar pago: $e');
      return false;
    }
  }

  Future<bool> cancelInvoice(String invoiceId) async {
    final previousState = state;

    try {
      // Actualización optimista
      final updatedInvoices = state.invoices.map((inv) {
        if (inv.id == invoiceId) {
          return inv.copyWith(status: InvoiceStatus.cancelled);
        }
        return inv;
      }).toList();

      state = state.copyWith(invoices: updatedInvoices, error: null);

      // Enviar al servidor
      await InvoicesDataSource.cancel(invoiceId);

      _refreshStatsInBackground();
      return true;
    } catch (e) {
      // Rollback
      state = previousState.copyWith(error: 'Error al cancelar recibo: $e');
      return false;
    }
  }

  /// Refresca stats sin bloquear la UI
  void _refreshStatsInBackground() {
    Future.microtask(() async {
      try {
        final stats = await InvoicesDataSource.getMonthlyStats();
        state = state.copyWith(monthlyStats: stats);
      } catch (_) {}
    });
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Crear factura con items (pasa por el provider para actualizar estado local)
  Future<Invoice?> createInvoice({
    required String type,
    required String series,
    required Customer customer,
    required DateTime issueDate,
    DateTime? dueDate,
    required List<InvoiceItem> items,
    double taxRate = 0.0,
    double discount = 0.0,
    String? quotationId,
    String? notes,
  }) async {
    try {
      final invoice = await InvoicesDataSource.createWithItems(
        type: type,
        series: series,
        customer: customer,
        issueDate: issueDate,
        dueDate: dueDate,
        items: items,
        taxRate: taxRate,
        discount: discount,
        quotationId: quotationId,
        notes: notes,
      );

      // Agregar al estado local inmediatamente
      state = state.copyWith(invoices: [invoice, ...state.invoices]);

      return invoice;
    } catch (e) {
      AppLogger.error('❌ Error al crear factura: $e');
      state = state.copyWith(error: 'Error al crear factura: $e');
      return null;
    }
  }

  /// Emitir una factura (cambia estado a issued y descuenta inventario)
  Future<bool> emitInvoice(String invoiceId) async {
    final previousState = state;
    try {
      // Optimistic update
      final updatedInvoices = state.invoices.map((inv) {
        if (inv.id == invoiceId) {
          return inv.copyWith(status: InvoiceStatus.issued);
        }
        return inv;
      }).toList();
      state = state.copyWith(invoices: updatedInvoices, error: null);

      await InvoicesDataSource.updateStatus(invoiceId, 'issued');
      _refreshStatsInBackground();
      return true;
    } catch (e) {
      state = previousState.copyWith(error: 'Error al emitir factura: $e');
      return false;
    }
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
final filteredInvoicesProvider = Provider.family<List<Invoice>, InvoiceStatus?>(
  (ref, status) {
    final state = ref.watch(invoicesProvider);
    if (status == null) return state.invoices;
    return state.invoices.where((i) => i.status == status).toList();
  },
);
