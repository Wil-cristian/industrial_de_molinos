import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../datasources/commissions_datasource.dart';
import '../../domain/entities/sales_commission.dart';

/// Estado del sistema de comisiones
class CommissionsState {
  final List<SalesCommission> commissions;
  final List<Map<String, dynamic>> summaryByEmployee;
  final bool isLoading;
  final String? error;

  CommissionsState({
    this.commissions = const [],
    this.summaryByEmployee = const [],
    this.isLoading = false,
    this.error,
  });

  CommissionsState copyWith({
    List<SalesCommission>? commissions,
    List<Map<String, dynamic>>? summaryByEmployee,
    bool? isLoading,
    String? error,
  }) {
    return CommissionsState(
      commissions: commissions ?? this.commissions,
      summaryByEmployee: summaryByEmployee ?? this.summaryByEmployee,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Total de comisiones pendientes
  double get totalPending => commissions
      .where((c) => c.isPending)
      .fold(0.0, (sum, c) => sum + c.commissionAmount);

  /// Comisiones pendientes
  List<SalesCommission> get pendingCommissions =>
      commissions.where((c) => c.isPending).toList();

  /// Comisiones pagadas
  List<SalesCommission> get paidCommissions =>
      commissions.where((c) => c.isPaid).toList();
}

/// Notifier para comisiones
class CommissionsNotifier extends Notifier<CommissionsState> {
  @override
  CommissionsState build() {
    return CommissionsState();
  }

  /// Cargar todas las comisiones
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final commissions = await CommissionsDatasource.getAll();
      final summary =
          await CommissionsDatasource.getCommissionSummaryByEmployee();
      state = state.copyWith(
        commissions: commissions,
        summaryByEmployee: summary,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Cargar comisiones de un empleado
  Future<void> loadByEmployee(String employeeId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final commissions = await CommissionsDatasource.getByEmployee(employeeId);
      state = state.copyWith(commissions: commissions, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Crear comisión al hacer una venta
  Future<SalesCommission?> createCommission({
    required String invoiceId,
    required String employeeId,
    required String invoiceNumber,
    required String customerName,
    required double invoiceTotal,
    required double commissionPercentage,
  }) async {
    try {
      final commission = await CommissionsDatasource.createCommission(
        invoiceId: invoiceId,
        employeeId: employeeId,
        invoiceNumber: invoiceNumber,
        customerName: customerName,
        invoiceTotal: invoiceTotal,
        commissionPercentage: commissionPercentage,
      );
      if (commission != null) {
        state = state.copyWith(commissions: [commission, ...state.commissions]);
      }
      return commission;
    } catch (e) {
      print('❌ Error creando comisión: $e');
      return null;
    }
  }

  /// Pagar comisiones pendientes de un empleado (al procesar nómina)
  Future<bool> payCommissions({
    required String employeeId,
    required String payrollId,
  }) async {
    try {
      final pending = await CommissionsDatasource.getPendingByEmployee(
        employeeId,
      );
      if (pending.isEmpty) return true;

      final ids = pending.map((c) => c.id).toList();
      await CommissionsDatasource.markAsPaid(
        commissionIds: ids,
        payrollId: payrollId,
      );

      // Actualizar estado local
      final updatedCommissions = state.commissions.map((c) {
        if (ids.contains(c.id)) {
          return c.copyWith(status: 'pagada', payrollId: payrollId);
        }
        return c;
      }).toList();

      state = state.copyWith(commissions: updatedCommissions);
      return true;
    } catch (e) {
      print('❌ Error pagando comisiones: $e');
      return false;
    }
  }

  /// Cancelar comisiones de una factura
  Future<void> cancelByInvoice(String invoiceId) async {
    try {
      await CommissionsDatasource.cancelByInvoice(invoiceId);
      final updated = state.commissions.map((c) {
        if (c.invoiceId == invoiceId && c.isPending) {
          return c.copyWith(status: 'anulada');
        }
        return c;
      }).toList();
      state = state.copyWith(commissions: updated);
    } catch (e) {
      print('❌ Error anulando comisiones: $e');
    }
  }
}

/// Provider de comisiones
final commissionsProvider =
    NotifierProvider<CommissionsNotifier, CommissionsState>(
      CommissionsNotifier.new,
    );
