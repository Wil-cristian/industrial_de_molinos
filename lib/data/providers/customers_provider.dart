import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/customer.dart';
import '../datasources/customers_datasource.dart';

/// Estado para la lista de clientes
class CustomersState {
  final List<Customer> customers;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  CustomersState({
    this.customers = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
  });

  CustomersState copyWith({
    List<Customer>? customers,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) {
    return CustomersState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<Customer> get filteredCustomers {
    if (searchQuery.isEmpty) return customers;
    final query = searchQuery.toLowerCase();
    return customers
        .where(
          (c) =>
              c.name.toLowerCase().contains(query) ||
              c.documentNumber.toLowerCase().contains(query) ||
              (c.tradeName?.toLowerCase().contains(query) ?? false),
        )
        .toList();
  }
}

/// Notifier para gestionar clientes (Riverpod 3.0)
class CustomersNotifier extends Notifier<CustomersState> {
  @override
  CustomersState build() {
    return CustomersState();
  }

  Future<void> loadCustomers({bool activeOnly = true}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      print('🔄 Cargando clientes desde Supabase...');
      final customers = await CustomersDataSource.getAll(
        activeOnly: activeOnly,
      );
      print('✅ Clientes cargados: ${customers.length}');

      // Calcular deuda real desde facturas en batch (una sola consulta)
      final debtMap = await CustomersDataSource.getCalculatedDebtBatch(
        customers.map((c) => c.id).toList(),
      );

      final customersWithRealDebt = <Customer>[];
      final updateFutures = <Future>[];

      for (final customer in customers) {
        final realDebt = debtMap[customer.id] ?? 0.0;
        customersWithRealDebt.add(customer.copyWith(currentBalance: realDebt));

        // Si la deuda en BD es diferente, actualizar (en paralelo)
        if ((customer.currentBalance - realDebt).abs() > 0.01) {
          print(
            '📊 Cliente ${customer.name}: Deuda BD=${customer.currentBalance}, Real=$realDebt',
          );
          updateFutures.add(
            CustomersDataSource.updateBalance(customer.id, realDebt),
          );
        }
      }

      // Ejecutar updates en paralelo
      if (updateFutures.isNotEmpty) {
        await Future.wait(updateFutures);
      }

      state = state.copyWith(
        customers: customersWithRealDebt,
        isLoading: false,
      );
    } catch (e) {
      print('❌ Error cargando clientes: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void search(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<Customer?> createCustomer(Customer customer) async {
    try {
      print('🔄 Provider: Creando cliente ${customer.name}...');
      final created = await CustomersDataSource.create(customer);
      print('✅ Provider: Cliente creado con ID: ${created.id}');
      state = state.copyWith(customers: [...state.customers, created]);
      return created;
    } catch (e, stackTrace) {
      print('❌ Provider: Error creando cliente: $e');
      print('📋 Stack trace: $stackTrace');
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> updateCustomer(Customer customer) async {
    try {
      final updated = await CustomersDataSource.update(customer);
      final customers = state.customers
          .map((c) => c.id == customer.id ? updated : c)
          .toList();
      state = state.copyWith(customers: customers);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteCustomer(String id) async {
    try {
      await CustomersDataSource.delete(id);
      final customers = state.customers.where((c) => c.id != id).toList();
      state = state.copyWith(customers: customers);
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

/// Provider principal de clientes
final customersProvider = NotifierProvider<CustomersNotifier, CustomersState>(
  () {
    return CustomersNotifier();
  },
);

/// Provider para cliente individual
final customerByIdProvider = FutureProvider.family<Customer?, String>((
  ref,
  id,
) async {
  return await CustomersDataSource.getById(id);
});

/// Provider para clientes con deuda
final customersWithDebtProvider = FutureProvider<List<Customer>>((ref) async {
  return await CustomersDataSource.getWithDebt();
});
