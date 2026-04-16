import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/messenger_fund.dart';
import '../datasources/messenger_funds_datasource.dart';

class MessengerFundReport {
  final String employeeName;
  final int totalFunds;
  final int openFunds;
  final double totalGiven;
  final double totalSpent;
  final double totalReturned;
  final double totalPending;

  MessengerFundReport({
    required this.employeeName,
    required this.totalFunds,
    required this.openFunds,
    required this.totalGiven,
    required this.totalSpent,
    required this.totalReturned,
    required this.totalPending,
  });
}

/// Estado para fondos de mensajería
class MessengerFundsState {
  final List<MessengerFund> funds;
  final bool isLoading;
  final String? error;

  MessengerFundsState({
    this.funds = const [],
    this.isLoading = false,
    this.error,
  });

  MessengerFundsState copyWith({
    List<MessengerFund>? funds,
    bool? isLoading,
    String? error,
  }) {
    return MessengerFundsState(
      funds: funds ?? this.funds,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Fondos abiertos (abierto + parcial)
  List<MessengerFund> get openFunds =>
      funds.where((f) => f.isOpen).toList();

  /// Fondos cerrados (legalizado + cancelado)
  List<MessengerFund> get closedFunds =>
      funds.where((f) => !f.isOpen).toList();

  /// Total entregado en fondos abiertos
  double get totalActiveGiven =>
      openFunds.fold(0.0, (sum, f) => sum + f.amountGiven);

  /// Total gastado en fondos abiertos
  double get totalActiveSpent =>
      openFunds.fold(0.0, (sum, f) => sum + f.amountSpent);

  /// Total pendiente por legalizar
  double get totalActivePending =>
      openFunds.fold(0.0, (sum, f) => sum + f.remainingBalance);

  /// Reporte agrupado por mensajero
  List<MessengerFundReport> get messengerReports {
    final grouped = <String, List<MessengerFund>>{};
    for (final fund in funds) {
      grouped.putIfAbsent(fund.employeeName, () => []).add(fund);
    }

    final reports = grouped.entries.map((entry) {
      final items = entry.value;
      return MessengerFundReport(
        employeeName: entry.key,
        totalFunds: items.length,
        openFunds: items.where((f) => f.isOpen).length,
        totalGiven: items.fold(0.0, (sum, f) => sum + f.amountGiven),
        totalSpent: items.fold(0.0, (sum, f) => sum + f.amountSpent),
        totalReturned: items.fold(0.0, (sum, f) => sum + f.amountReturned),
        totalPending: items.fold(0.0, (sum, f) => sum + f.remainingBalance),
      );
    }).toList();

    reports.sort((a, b) => b.totalPending.compareTo(a.totalPending));
    return reports;
  }
}

/// Notifier para fondos de mensajería
class MessengerFundsNotifier extends Notifier<MessengerFundsState> {
  @override
  MessengerFundsState build() => MessengerFundsState();

  /// Cargar todos los fondos
  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final funds = await MessengerFundsDataSource.getAll();
      state = state.copyWith(funds: funds, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error cargando fondos: $e',
      );
    }
  }

  /// Crear nuevo fondo de mensajería
  Future<String?> createFund({
    required String employeeId,
    required String employeeName,
    required double amount,
    required String accountId,
    String? notes,
  }) async {
    try {
      final fundId = await MessengerFundsDataSource.createFund(
        employeeId: employeeId,
        employeeName: employeeName,
        amount: amount,
        accountId: accountId,
        notes: notes,
      );
      await load(); // Recargar
      return fundId;
    } catch (e) {
      state = state.copyWith(error: 'Error creando fondo: $e');
      return null;
    }
  }

  /// Legalizar un item del fondo
  Future<String?> legalizeItem({
    required String fundId,
    required FundItemType itemType,
    required double amount,
    required String description,
    String? reference,
    String? category,
    String? purchaseOrderId,
    String? invoiceId,
    String? attachmentUrl,
    String? attachmentName,
  }) async {
    try {
      final itemId = await MessengerFundsDataSource.legalizeItem(
        fundId: fundId,
        itemType: itemType,
        amount: amount,
        description: description,
        reference: reference,
        category: category,
        purchaseOrderId: purchaseOrderId,
        invoiceId: invoiceId,
        attachmentUrl: attachmentUrl,
        attachmentName: attachmentName,
      );
      await load(); // Recargar
      return itemId;
    } catch (e) {
      state = state.copyWith(error: 'Error legalizando item: $e');
      return null;
    }
  }

  /// Cancelar un fondo abierto
  Future<bool> cancelFund(String fundId) async {
    try {
      await MessengerFundsDataSource.cancelFund(fundId);
      await load(); // Recargar
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Error cancelando fondo: $e');
      return false;
    }
  }
}

/// Provider para fondos de mensajería
final messengerFundsProvider =
    NotifierProvider<MessengerFundsNotifier, MessengerFundsState>(
  () => MessengerFundsNotifier(),
);
