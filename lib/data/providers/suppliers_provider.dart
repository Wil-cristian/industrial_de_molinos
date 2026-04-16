import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/supplier.dart';
import '../datasources/suppliers_datasource.dart';

/// Estado para la lista de proveedores
class SuppliersState {
  final List<Supplier> suppliers;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  SuppliersState({
    this.suppliers = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
  });

  SuppliersState copyWith({
    List<Supplier>? suppliers,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) {
    return SuppliersState(
      suppliers: suppliers ?? this.suppliers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<Supplier> get filteredSuppliers {
    if (searchQuery.isEmpty) return suppliers;
    final query = searchQuery.toLowerCase();
    return suppliers.where((s) =>
      s.name.toLowerCase().contains(query) ||
      s.documentNumber.toLowerCase().contains(query) ||
      (s.tradeName?.toLowerCase().contains(query) ?? false)
    ).toList();
  }
}

/// Notifier para gestionar proveedores (Riverpod 3.0)
class SuppliersNotifier extends Notifier<SuppliersState> {
  @override
  SuppliersState build() {
    return SuppliersState();
  }

  Future<void> loadSuppliers({bool activeOnly = true}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      print('🔄 Cargando proveedores desde Supabase...');
      final suppliers = await SuppliersDataSource.getAll(activeOnly: activeOnly);
      print('✅ Proveedores cargados: ${suppliers.length}');
      state = state.copyWith(suppliers: suppliers, isLoading: false);
    } catch (e) {
      print('❌ Error cargando proveedores: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<Supplier?> createSupplier(Supplier supplier) async {
    try {
      final created = await SuppliersDataSource.create(supplier);
      state = state.copyWith(suppliers: [...state.suppliers, created]);
      return created;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Crear proveedor rápido (solo nombre)
  Future<Supplier?> createQuickSupplier(String name) async {
    try {
      final created = await SuppliersDataSource.createQuick(name: name);
      state = state.copyWith(suppliers: [...state.suppliers, created]);
      return created;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> updateSupplier(Supplier supplier) async {
    try {
      final updated = await SuppliersDataSource.update(supplier);
      final suppliers = state.suppliers.map((s) =>
        s.id == supplier.id ? updated : s
      ).toList();
      state = state.copyWith(suppliers: suppliers);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteSupplier(String id) async {
    try {
      await SuppliersDataSource.delete(id);
      final suppliers = state.suppliers.where((s) => s.id != id).toList();
      state = state.copyWith(suppliers: suppliers);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Supplier? getById(String id) {
    try {
      return state.suppliers.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Provider global para proveedores
final suppliersProvider = NotifierProvider<SuppliersNotifier, SuppliersState>(
  SuppliersNotifier.new,
);
