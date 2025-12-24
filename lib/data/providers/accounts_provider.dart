import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/cash_movement.dart';
import '../datasources/accounts_datasource.dart';

/// Estado para Caja Diaria
class DailyCashState {
  final List<Account> accounts;
  final List<CashMovement> movements;
  final DateTime selectedDate;
  final String? selectedAccountId;
  final bool isLoading;
  final String? error;

  DailyCashState({
    this.accounts = const [],
    this.movements = const [],
    DateTime? selectedDate,
    this.selectedAccountId,
    this.isLoading = false,
    this.error,
  }) : selectedDate = selectedDate ?? DateTime.now();

  DailyCashState copyWith({
    List<Account>? accounts,
    List<CashMovement>? movements,
    DateTime? selectedDate,
    String? selectedAccountId,
    bool? isLoading,
    String? error,
  }) {
    return DailyCashState(
      accounts: accounts ?? this.accounts,
      movements: movements ?? this.movements,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  // Getters calculados
  
  /// Balance total de todas las cuentas
  double get totalBalance => accounts.fold(0.0, (sum, a) => sum + a.balance);
  
  /// Movimientos filtrados por cuenta seleccionada
  List<CashMovement> get filteredMovements {
    if (selectedAccountId == null) return movements;
    return movements.where((m) => 
      m.accountId == selectedAccountId || 
      m.toAccountId == selectedAccountId
    ).toList();
  }
  
  /// Total de ingresos del día (excluyendo traslados)
  double get dayIncome => movements
      .where((m) => m.type == MovementType.income)
      .fold(0.0, (sum, m) => sum + m.amount);
  
  /// Total de gastos del día (excluyendo traslados)
  double get dayExpense => movements
      .where((m) => m.type == MovementType.expense)
      .fold(0.0, (sum, m) => sum + m.amount);
  
  /// Saldo neto del día
  double get dayNet => dayIncome - dayExpense;
  
  /// Cantidad de movimientos
  int get movementCount => movements.length;
  
  /// Ingresos del día por cuenta
  Map<String, double> get incomeByAccount {
    final result = <String, double>{};
    for (final account in accounts) {
      result[account.id] = movements
          .where((m) => m.accountId == account.id && m.type == MovementType.income)
          .fold(0.0, (sum, m) => sum + m.amount);
    }
    return result;
  }
  
  /// Gastos del día por cuenta
  Map<String, double> get expenseByAccount {
    final result = <String, double>{};
    for (final account in accounts) {
      result[account.id] = movements
          .where((m) => m.accountId == account.id && m.type == MovementType.expense)
          .fold(0.0, (sum, m) => sum + m.amount);
    }
    return result;
  }
  
  /// Obtener cuenta por ID
  Account? getAccountById(String id) {
    try {
      return accounts.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Cuentas predeterminadas (para mostrar si no hay conexión)
  static List<Account> get defaultAccounts => [
    Account(
      id: 'default-caja',
      name: 'Caja',
      type: AccountType.cash,
      balance: 0,
      color: '#4CAF50',
    ),
    Account(
      id: 'default-daniela',
      name: 'Cuenta Daniela',
      type: AccountType.bank,
      bankName: 'Banco',
      balance: 0,
      color: '#2196F3',
    ),
    Account(
      id: 'default-industrial',
      name: 'Cuenta Industrial de Molinos',
      type: AccountType.bank,
      bankName: 'Banco',
      balance: 0,
      color: '#9C27B0',
    ),
  ];
}

/// Notifier para gestionar Caja Diaria
class DailyCashNotifier extends Notifier<DailyCashState> {
  @override
  DailyCashState build() {
    // Iniciar con cuentas por defecto para mostrar algo de inmediato
    return DailyCashState(accounts: DailyCashState.defaultAccounts);
  }

  /// Cargar datos iniciales
  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Inicializar cuentas predeterminadas si es necesario
      await AccountsDataSource.initializeDefaultAccounts();
      
      final results = await Future.wait([
        AccountsDataSource.getAllAccounts(),
        AccountsDataSource.getMovementsByDate(state.selectedDate),
      ]);
      
      final loadedAccounts = results[0] as List<Account>;
      print('📦 Cuentas cargadas: ${loadedAccounts.length}');
      for (final acc in loadedAccounts) {
        print('   - ${acc.name} (ID: ${acc.id})');
      }
      
      state = state.copyWith(
        accounts: loadedAccounts.isNotEmpty ? loadedAccounts : DailyCashState.defaultAccounts,
        movements: results[1] as List<CashMovement>,
        isLoading: false,
      );
    } catch (e) {
      print('❌ Error cargando cuentas: $e');
      // Si hay error, mantener las cuentas por defecto
      state = state.copyWith(
        isLoading: false, 
        error: e.toString(),
        accounts: DailyCashState.defaultAccounts,
      );
    }
  }

  /// Cambiar fecha seleccionada
  Future<void> selectDate(DateTime date) async {
    state = state.copyWith(selectedDate: date, isLoading: true);
    try {
      final movements = await AccountsDataSource.getMovementsByDate(date);
      state = state.copyWith(movements: movements, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Filtrar por cuenta
  void selectAccount(String? accountId) {
    state = state.copyWith(selectedAccountId: accountId);
  }

  /// Agregar ingreso
  Future<bool> addIncome({
    required String accountId,
    required double amount,
    required String description,
    required MovementCategory category,
    String? personName,
    String? reference,
  }) async {
    try {
      print('💰 Registrando ingreso: $amount en cuenta $accountId');
      final movement = CashMovement(
        id: '',
        accountId: accountId,
        type: MovementType.income,
        category: category,
        amount: amount,
        description: description,
        personName: personName,
        reference: reference,
        date: state.selectedDate,
      );
      
      await AccountsDataSource.createMovementWithBalanceUpdate(movement);
      print('✅ Ingreso registrado correctamente');
      await load(); // Recargar todo
      return true;
    } catch (e) {
      print('❌ Error al registrar ingreso: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Agregar gasto
  Future<bool> addExpense({
    required String accountId,
    required double amount,
    required String description,
    required MovementCategory category,
    String? personName,
    String? reference,
  }) async {
    try {
      print('📤 Registrando gasto: cuenta=$accountId, monto=$amount, desc=$description');
      final movement = CashMovement(
        id: '',
        accountId: accountId,
        type: MovementType.expense,
        category: category,
        amount: amount,
        description: description,
        personName: personName,
        reference: reference,
        date: state.selectedDate,
      );
      
      await AccountsDataSource.createMovementWithBalanceUpdate(movement);
      print('✅ Gasto registrado exitosamente');
      await load(); // Recargar todo
      return true;
    } catch (e) {
      print('❌ Error al registrar gasto: $e');
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Crear traslado entre cuentas
  Future<bool> transfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    required String description,
    String? reference,
  }) async {
    try {
      await AccountsDataSource.createTransfer(
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amount: amount,
        description: description,
        date: state.selectedDate,
        reference: reference,
      );
      await load(); // Recargar todo
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Eliminar movimiento
  Future<bool> deleteMovement(String movementId) async {
    try {
      await AccountsDataSource.deleteMovement(movementId);
      await load(); // Recargar todo
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Actualizar cuenta
  Future<bool> updateAccount(Account account) async {
    try {
      await AccountsDataSource.updateAccount(account);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Actualizar balance manual (corrección)
  Future<bool> adjustBalance(String accountId, double newBalance) async {
    try {
      await AccountsDataSource.updateAccountBalance(accountId, newBalance);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

/// Provider para Caja Diaria
final dailyCashProvider = NotifierProvider<DailyCashNotifier, DailyCashState>(() {
  return DailyCashNotifier();
});

/// Provider para obtener movimientos de un rango de fechas (para reportes)
final movementsByDateRangeProvider = FutureProvider.family<List<CashMovement>, ({DateTime start, DateTime end})>(
  (ref, dates) async {
    return AccountsDataSource.getMovementsByDateRange(dates.start, dates.end);
  },
);

/// Provider para obtener el balance total
final totalBalanceProvider = FutureProvider<double>((ref) async {
  return AccountsDataSource.getTotalBalance();
});
