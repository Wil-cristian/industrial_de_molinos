import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/quotation.dart';
import '../datasources/quotations_datasource.dart';

/// Estado para la lista de cotizaciones
class QuotationsState {
  final List<Quotation> quotations;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final String? statusFilter;

  QuotationsState({
    this.quotations = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.statusFilter,
  });

  QuotationsState copyWith({
    List<Quotation>? quotations,
    bool? isLoading,
    String? error,
    String? searchQuery,
    String? statusFilter,
  }) {
    return QuotationsState(
      quotations: quotations ?? this.quotations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }

  List<Quotation> get filteredQuotations {
    var filtered = quotations;

    if (statusFilter != null) {
      filtered = filtered.where((q) => q.status == statusFilter).toList();
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (q) =>
                q.number.toLowerCase().contains(query) ||
                q.customerName.toLowerCase().contains(query),
          )
          .toList();
    }

    return filtered;
  }

  // Estadísticas
  int get totalQuotations => quotations.length;
  int get draftCount => quotations.where((q) => q.status == 'Borrador').length;
  int get sentCount => quotations.where((q) => q.status == 'Enviada').length;
  int get approvedCount =>
      quotations.where((q) => q.status == 'Aprobada').length;
  int get rejectedCount =>
      quotations.where((q) => q.status == 'Rechazada').length;

  double get totalApprovedAmount => quotations
      .where((q) => q.status == 'Aprobada')
      .fold(0.0, (sum, q) => sum + q.total);
}

/// Notifier para gestionar cotizaciones (Riverpod 3.0)
class QuotationsNotifier extends Notifier<QuotationsState> {
  @override
  QuotationsState build() {
    return QuotationsState();
  }

  Future<void> loadQuotations() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final quotations = await QuotationsDataSource.getAll();
      state = state.copyWith(quotations: quotations, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void search(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void filterByStatus(String? status) {
    state = state.copyWith(statusFilter: status);
  }

  Future<Quotation?> createQuotation(Quotation quotation) async {
    try {
      final created = await QuotationsDataSource.create(quotation);
      state = state.copyWith(quotations: [created, ...state.quotations]);
      return created;
    } catch (e) {
      AppLogger.error('❌ QuotationsProvider.createQuotation error: $e');
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> updateQuotation(Quotation quotation) async {
    try {
      final updated = await QuotationsDataSource.update(quotation);
      final quotations = state.quotations
          .map((q) => q.id == quotation.id ? updated : q)
          .toList();
      state = state.copyWith(quotations: quotations);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> updateStatus(String id, String status) async {
    try {
      await QuotationsDataSource.updateStatus(id, status);
      final quotations = state.quotations
          .map((q) => q.id == id ? q.copyWith(status: status) : q)
          .toList();
      state = state.copyWith(quotations: quotations);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteQuotation(String id) async {
    try {
      await QuotationsDataSource.delete(id);
      final quotations = state.quotations.where((q) => q.id != id).toList();
      state = state.copyWith(quotations: quotations);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Aprobar cotización y crear factura automáticamente
  Future<Map<String, dynamic>?> approveAndCreateInvoice(
    String quotationId,
    String series,
  ) async {
    try {
      AppLogger.debug(
        '🔄 Provider: Llamando a datasource para aprobar cotización...',
      );
      final result = await QuotationsDataSource.approveAndCreateInvoice(
        quotationId,
        series: series,
      );

      AppLogger.debug('📊 Provider: Resultado de aprobación: $result');

      // Actualizar estado local
      final quotations = state.quotations
          .map((q) => q.id == quotationId ? q.copyWith(status: 'Aprobada') : q)
          .toList();
      state = state.copyWith(quotations: quotations);

      // Retornar info de la factura creada
      return result;
    } catch (e) {
      AppLogger.error('❌ Provider: Error al aprobar: $e');
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Rechazar cotización con motivo opcional
  Future<bool> reject(String quotationId, String? reason) async {
    try {
      await QuotationsDataSource.reject(quotationId, reason: reason);

      // Actualizar estado local
      final quotations = state.quotations
          .map(
            (q) => q.id == quotationId
                ? q.copyWith(status: 'Rechazada', notes: reason ?? q.notes)
                : q,
          )
          .toList();
      state = state.copyWith(quotations: quotations);

      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Verificar disponibilidad de stock para una cotización
  Future<List<Map<String, dynamic>>> checkStockAvailability(
    String quotationId,
  ) async {
    try {
      return await QuotationsDataSource.checkStockAvailability(quotationId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Anular cotización atómicamente (incluye factura asociada y material_movements)
  Future<Map<String, dynamic>?> annulQuotation(
    String quotationId, {
    String reason = 'Anulada por el usuario',
  }) async {
    try {
      final result = await QuotationsDataSource.annulQuotation(
        quotationId,
        reason: reason,
      );

      // Actualizar estado local
      final quotations = state.quotations
          .map((q) => q.id == quotationId ? q.copyWith(status: 'Anulada') : q)
          .toList();
      state = state.copyWith(quotations: quotations);

      return result;
    } catch (e) {
      AppLogger.error('❌ Provider: Error al anular: $e');
      state = state.copyWith(error: e.toString());
      return null;
    }
  }
}

/// Provider principal de cotizaciones
final quotationsProvider =
    NotifierProvider<QuotationsNotifier, QuotationsState>(() {
      return QuotationsNotifier();
    });

/// Provider para cotización individual
final quotationByIdProvider = FutureProvider.family<Quotation?, String>((
  ref,
  id,
) async {
  return await QuotationsDataSource.getById(id);
});

/// Provider para cotizaciones pendientes
final pendingQuotationsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  return await QuotationsDataSource.getPending();
});
