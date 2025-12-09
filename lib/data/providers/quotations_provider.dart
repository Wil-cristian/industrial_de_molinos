import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      filtered = filtered.where((q) =>
        q.number.toLowerCase().contains(query) ||
        q.customerName.toLowerCase().contains(query)
      ).toList();
    }
    
    return filtered;
  }

  // Estadísticas
  int get totalQuotations => quotations.length;
  int get draftCount => quotations.where((q) => q.status == 'Borrador').length;
  int get sentCount => quotations.where((q) => q.status == 'Enviada').length;
  int get approvedCount => quotations.where((q) => q.status == 'Aprobada').length;
  int get rejectedCount => quotations.where((q) => q.status == 'Rechazada').length;
  
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
      state = state.copyWith(
        quotations: [created, ...state.quotations],
      );
      return created;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> updateQuotation(Quotation quotation) async {
    try {
      final updated = await QuotationsDataSource.update(quotation);
      final quotations = state.quotations.map((q) =>
        q.id == quotation.id ? updated : q
      ).toList();
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
      final quotations = state.quotations.map((q) =>
        q.id == id ? q.copyWith(status: status) : q
      ).toList();
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

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider principal de cotizaciones
final quotationsProvider = NotifierProvider<QuotationsNotifier, QuotationsState>(() {
  return QuotationsNotifier();
});

/// Provider para cotización individual
final quotationByIdProvider = FutureProvider.family<Quotation?, String>((ref, id) async {
  return await QuotationsDataSource.getById(id);
});

/// Provider para cotizaciones pendientes
final pendingQuotationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await QuotationsDataSource.getPending();
});

/// Estado para la cotización en edición
class QuotationEditorState {
  final Quotation? quotation;
  final List<QuotationItem> items;
  final String customerName;
  final String customerId;
  final double laborCost;
  final double energyCost;
  final double gasCost;
  final double suppliesCost;
  final double otherCosts;
  final double profitMargin;
  final String notes;
  final int currentStep;

  QuotationEditorState({
    this.quotation,
    this.items = const [],
    this.customerName = '',
    this.customerId = '',
    this.laborCost = 0,
    this.energyCost = 0,
    this.gasCost = 0,
    this.suppliesCost = 0,
    this.otherCosts = 0,
    this.profitMargin = 20,
    this.notes = '',
    this.currentStep = 0,
  });

  double get materialsCost => items.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get indirectCosts => energyCost + gasCost + suppliesCost + otherCosts;
  double get subtotal => materialsCost + laborCost + indirectCosts;
  double get profitAmount => subtotal * (profitMargin / 100);
  double get total => subtotal + profitAmount;
  double get totalWeight => items.fold(0.0, (sum, item) => sum + item.totalWeight);

  QuotationEditorState copyWith({
    Quotation? quotation,
    List<QuotationItem>? items,
    String? customerName,
    String? customerId,
    double? laborCost,
    double? energyCost,
    double? gasCost,
    double? suppliesCost,
    double? otherCosts,
    double? profitMargin,
    String? notes,
    int? currentStep,
  }) {
    return QuotationEditorState(
      quotation: quotation ?? this.quotation,
      items: items ?? this.items,
      customerName: customerName ?? this.customerName,
      customerId: customerId ?? this.customerId,
      laborCost: laborCost ?? this.laborCost,
      energyCost: energyCost ?? this.energyCost,
      gasCost: gasCost ?? this.gasCost,
      suppliesCost: suppliesCost ?? this.suppliesCost,
      otherCosts: otherCosts ?? this.otherCosts,
      profitMargin: profitMargin ?? this.profitMargin,
      notes: notes ?? this.notes,
      currentStep: currentStep ?? this.currentStep,
    );
  }
}

/// Notifier para el editor de cotizaciones
class QuotationEditorNotifier extends Notifier<QuotationEditorState> {
  @override
  QuotationEditorState build() {
    return QuotationEditorState();
  }

  void reset() {
    state = QuotationEditorState();
  }

  void loadQuotation(Quotation quotation) {
    state = QuotationEditorState(
      quotation: quotation,
      items: quotation.items,
      customerName: quotation.customerName,
      customerId: quotation.customerId,
      laborCost: quotation.laborCost,
      energyCost: quotation.energyCost,
      gasCost: quotation.gasCost,
      suppliesCost: quotation.suppliesCost,
      otherCosts: quotation.otherCosts,
      profitMargin: quotation.profitMargin,
      notes: quotation.notes,
    );
  }

  void setCustomer(String id, String name) {
    state = state.copyWith(customerId: id, customerName: name);
  }

  void setStep(int step) {
    state = state.copyWith(currentStep: step);
  }

  void addItem(QuotationItem item) {
    state = state.copyWith(items: [...state.items, item]);
  }

  void updateItem(int index, QuotationItem item) {
    final items = [...state.items];
    items[index] = item;
    state = state.copyWith(items: items);
  }

  void removeItem(int index) {
    final items = [...state.items];
    items.removeAt(index);
    state = state.copyWith(items: items);
  }

  void setCosts({
    double? laborCost,
    double? energyCost,
    double? gasCost,
    double? suppliesCost,
    double? otherCosts,
    double? profitMargin,
  }) {
    state = state.copyWith(
      laborCost: laborCost,
      energyCost: energyCost,
      gasCost: gasCost,
      suppliesCost: suppliesCost,
      otherCosts: otherCosts,
      profitMargin: profitMargin,
    );
  }

  void setNotes(String notes) {
    state = state.copyWith(notes: notes);
  }

  Quotation buildQuotation() {
    final now = DateTime.now();
    return Quotation(
      id: state.quotation?.id ?? '',
      number: state.quotation?.number ?? '',
      date: now,
      validUntil: now.add(const Duration(days: 30)),
      customerId: state.customerId,
      customerName: state.customerName,
      status: 'Borrador',
      items: state.items,
      laborCost: state.laborCost,
      energyCost: state.energyCost,
      gasCost: state.gasCost,
      suppliesCost: state.suppliesCost,
      otherCosts: state.otherCosts,
      profitMargin: state.profitMargin,
      notes: state.notes,
      createdAt: state.quotation?.createdAt ?? now,
    );
  }
}

/// Provider para el editor de cotización
final quotationEditorProvider = NotifierProvider<QuotationEditorNotifier, QuotationEditorState>(() {
  return QuotationEditorNotifier();
});
