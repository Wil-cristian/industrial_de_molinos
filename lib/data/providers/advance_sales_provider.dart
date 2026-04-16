import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/logger.dart';
import '../datasources/advance_sales_datasource.dart';
import '../../domain/entities/advance_sale.dart';

class AdvanceSalesState {
  final List<AdvanceSale> sales;
  final bool isLoading;
  final String? error;

  const AdvanceSalesState({
    this.sales = const [],
    this.isLoading = false,
    this.error,
  });

  AdvanceSalesState copyWith({
    List<AdvanceSale>? sales,
    bool? isLoading,
    String? error,
  }) {
    return AdvanceSalesState(
      sales: sales ?? this.sales,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  List<AdvanceSale> get pending =>
      sales.where((s) => s.status == AdvanceSaleStatus.pending).toList();

  List<AdvanceSale> get confirmed =>
      sales.where((s) => s.status == AdvanceSaleStatus.confirmed).toList();

  List<AdvanceSale> get cancelled =>
      sales.where((s) => s.status == AdvanceSaleStatus.cancelled).toList();

  double get totalEstimado =>
      pending.fold(0, (sum, s) => sum + s.estimatedTotal);

  double get totalAbonado => pending.fold(0, (sum, s) => sum + s.paidAmount);

  int get countPending => pending.length;
}

class AdvanceSalesNotifier extends Notifier<AdvanceSalesState> {
  @override
  AdvanceSalesState build() {
    Future.microtask(() => _load());
    return const AdvanceSalesState(isLoading: true);
  }

  Future<void> _load() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final sales = await AdvanceSalesDataSource.getAll();
      state = state.copyWith(sales: sales, isLoading: false);
    } catch (e) {
      AppLogger.error('Error cargando ventas anticipadas', e);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => _load();

  Future<AdvanceSale?> create({
    required String customerName,
    String? customerId,
    required String description,
    required double estimatedTotal,
    String? notes,
  }) async {
    try {
      final sale = await AdvanceSalesDataSource.create(
        customerName: customerName,
        customerId: customerId,
        description: description,
        estimatedTotal: estimatedTotal,
        notes: notes,
      );
      state = state.copyWith(sales: [sale, ...state.sales]);
      return sale;
    } catch (e) {
      AppLogger.error('Error creando venta anticipada', e);
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> registerPayment({
    required String advanceSaleId,
    required double amount,
    required String method,
    required DateTime paymentDate,
    required String accountId,
    required String accountName,
    String? reference,
    String? notes,
  }) async {
    try {
      final updated = await AdvanceSalesDataSource.registerPayment(
        advanceSaleId: advanceSaleId,
        amount: amount,
        method: method,
        paymentDate: paymentDate,
        accountId: accountId,
        accountName: accountName,
        reference: reference,
        notes: notes,
      );
      state = state.copyWith(
        sales: state.sales
            .map((s) => s.id == updated.id ? updated : s)
            .toList(),
      );
      return true;
    } catch (e) {
      AppLogger.error('Error registrando abono', e);
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> updateEstimatedTotal(String id, double newTotal) async {
    try {
      final updated =
          await AdvanceSalesDataSource.updateEstimatedTotal(id, newTotal);
      state = state.copyWith(
        sales: state.sales
            .map((s) => s.id == updated.id ? updated : s)
            .toList(),
      );
      return true;
    } catch (e) {
      AppLogger.error('Error actualizando precio', e);
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> updateDetails(
    String id, {
    String? description,
    String? notes,
  }) async {
    try {
      final updated = await AdvanceSalesDataSource.updateDetails(
        id,
        description: description,
        notes: notes,
      );
      state = state.copyWith(
        sales: state.sales
            .map((s) => s.id == updated.id ? updated : s)
            .toList(),
      );
      return true;
    } catch (e) {
      AppLogger.error('Error actualizando detalles', e);
      return false;
    }
  }

  Future<bool> confirm({
    required String id,
    required double finalTotal,
  }) async {
    try {
      final updated = await AdvanceSalesDataSource.confirm(
        id: id,
        finalTotal: finalTotal,
      );
      state = state.copyWith(
        sales: state.sales
            .map((s) => s.id == updated.id ? updated : s)
            .toList(),
      );
      return true;
    } catch (e) {
      AppLogger.error('Error confirmando venta anticipada', e);
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> cancel(String id) async {
    try {
      final updated = await AdvanceSalesDataSource.cancel(id);
      state = state.copyWith(
        sales: state.sales
            .map((s) => s.id == updated.id ? updated : s)
            .toList(),
      );
      return true;
    } catch (e) {
      AppLogger.error('Error cancelando venta anticipada', e);
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final advanceSalesProvider =
    NotifierProvider<AdvanceSalesNotifier, AdvanceSalesState>(
  AdvanceSalesNotifier.new,
);
