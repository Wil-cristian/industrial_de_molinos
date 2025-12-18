import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/cash_movement.dart';
import 'supabase_datasource.dart';

class AccountsDataSource {
  static const String _accountsTable = 'accounts';
  static const String _movementsTable = 'cash_movements';

  static SupabaseClient get _client => SupabaseDataSource.client;

  // ===================== CUENTAS =====================

  /// Obtener todas las cuentas
  static Future<List<Account>> getAllAccounts({bool activeOnly = true}) async {
    var query = _client.from(_accountsTable).select();
    
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    
    final response = await query.order('name');
    return response.map<Account>((json) => _accountFromJson(json)).toList();
  }

  /// Obtener cuenta por ID
  static Future<Account?> getAccountById(String id) async {
    try {
      final response = await _client
          .from(_accountsTable)
          .select()
          .eq('id', id)
          .single();
      return _accountFromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Crear cuenta
  static Future<Account> createAccount(Account account) async {
    final data = _accountToJson(account);
    data.remove('id');
    data.remove('updated_at');
    data.remove('created_at');
    
    final response = await _client
        .from(_accountsTable)
        .insert(data)
        .select()
        .single();
    return _accountFromJson(response);
  }

  /// Actualizar cuenta
  static Future<Account> updateAccount(Account account) async {
    final data = _accountToJson(account);
    data.remove('id');
    data.remove('created_at');
    data['updated_at'] = DateTime.now().toIso8601String();
    
    final response = await _client
        .from(_accountsTable)
        .update(data)
        .eq('id', account.id)
        .select()
        .single();
    return _accountFromJson(response);
  }

  /// Actualizar balance de cuenta
  static Future<void> updateAccountBalance(String accountId, double newBalance) async {
    await _client
        .from(_accountsTable)
        .update({
          'balance': newBalance,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', accountId);
  }

  /// Eliminar cuenta (soft delete)
  static Future<void> deleteAccount(String id) async {
    await _client
        .from(_accountsTable)
        .update({'is_active': false})
        .eq('id', id);
  }

  // ===================== MOVIMIENTOS =====================

  /// Obtener todos los movimientos
  static Future<List<CashMovement>> getAllMovements() async {
    final response = await _client
        .from(_movementsTable)
        .select()
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    return response.map<CashMovement>((json) => _movementFromJson(json)).toList();
  }

  /// Obtener movimientos por fecha
  static Future<List<CashMovement>> getMovementsByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final response = await _client
        .from(_movementsTable)
        .select()
        .gte('date', startOfDay.toIso8601String())
        .lt('date', endOfDay.toIso8601String())
        .order('created_at', ascending: false);
    return response.map<CashMovement>((json) => _movementFromJson(json)).toList();
  }

  /// Obtener movimientos por rango de fechas
  static Future<List<CashMovement>> getMovementsByDateRange(
    DateTime startDate, 
    DateTime endDate,
  ) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day)
        .add(const Duration(days: 1));
    
    final response = await _client
        .from(_movementsTable)
        .select()
        .gte('date', start.toIso8601String())
        .lt('date', end.toIso8601String())
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    return response.map<CashMovement>((json) => _movementFromJson(json)).toList();
  }

  /// Obtener movimientos por cuenta
  static Future<List<CashMovement>> getMovementsByAccount(String accountId) async {
    final response = await _client
        .from(_movementsTable)
        .select()
        .or('account_id.eq.$accountId,to_account_id.eq.$accountId')
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    return response.map<CashMovement>((json) => _movementFromJson(json)).toList();
  }

  /// Crear movimiento
  static Future<CashMovement> createMovement(CashMovement movement) async {
    final data = _movementToJson(movement);
    data.remove('id');
    data.remove('created_at');
    
    print('📤 Insertando movimiento: $data');
    
    final response = await _client
        .from(_movementsTable)
        .insert(data)
        .select()
        .single();
    print('✅ Movimiento insertado: $response');
    return _movementFromJson(response);
  }

  /// Crear traslado entre cuentas (crea dos movimientos: salida y entrada)
  static Future<List<CashMovement>> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    required String description,
    required DateTime date,
    String? reference,
  }) async {
    final transferId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Movimiento de salida (gasto en cuenta origen)
    final outMovement = CashMovement(
      id: '',
      accountId: fromAccountId,
      toAccountId: toAccountId,
      type: MovementType.transfer,
      category: MovementCategory.transferOut,
      amount: amount,
      description: 'Traslado: $description',
      reference: reference,
      date: date,
      linkedTransferId: transferId,
    );
    
    // Movimiento de entrada (ingreso en cuenta destino)
    final inMovement = CashMovement(
      id: '',
      accountId: toAccountId,
      toAccountId: fromAccountId,
      type: MovementType.transfer,
      category: MovementCategory.transferIn,
      amount: amount,
      description: 'Traslado: $description',
      reference: reference,
      date: date,
      linkedTransferId: transferId,
    );
    
    // Insertar ambos movimientos
    final outData = _movementToJson(outMovement);
    outData.remove('id');
    outData.remove('created_at');
    
    final inData = _movementToJson(inMovement);
    inData.remove('id');
    inData.remove('created_at');
    
    final responses = await Future.wait([
      _client.from(_movementsTable).insert(outData).select().single(),
      _client.from(_movementsTable).insert(inData).select().single(),
    ]);
    
    // Actualizar balances de las cuentas
    final fromAccount = await getAccountById(fromAccountId);
    final toAccount = await getAccountById(toAccountId);
    
    if (fromAccount != null) {
      await updateAccountBalance(fromAccountId, fromAccount.balance - amount);
    }
    if (toAccount != null) {
      await updateAccountBalance(toAccountId, toAccount.balance + amount);
    }
    
    return [
      _movementFromJson(responses[0]),
      _movementFromJson(responses[1]),
    ];
  }

  /// Crear movimiento y actualizar balance
  static Future<CashMovement> createMovementWithBalanceUpdate(
    CashMovement movement,
  ) async {
    // Crear el movimiento
    final created = await createMovement(movement);
    
    // Obtener cuenta actual
    final account = await getAccountById(movement.accountId);
    if (account != null) {
      double newBalance = account.balance;
      
      if (movement.type == MovementType.income) {
        newBalance += movement.amount;
      } else if (movement.type == MovementType.expense) {
        newBalance -= movement.amount;
      }
      
      await updateAccountBalance(movement.accountId, newBalance);
    }
    
    return created;
  }

  /// Actualizar movimiento
  static Future<CashMovement> updateMovement(CashMovement movement) async {
    final data = _movementToJson(movement);
    data.remove('id');
    data.remove('created_at');
    
    final response = await _client
        .from(_movementsTable)
        .update(data)
        .eq('id', movement.id)
        .select()
        .single();
    return _movementFromJson(response);
  }

  /// Eliminar movimiento
  static Future<void> deleteMovement(String id) async {
    // Primero obtener el movimiento para revertir el balance
    final response = await _client
        .from(_movementsTable)
        .select()
        .eq('id', id)
        .single();
    final movement = _movementFromJson(response);
    
    // Revertir el balance
    final account = await getAccountById(movement.accountId);
    if (account != null) {
      double newBalance = account.balance;
      
      if (movement.type == MovementType.income || 
          movement.category == MovementCategory.transferIn) {
        newBalance -= movement.amount; // Revertir ingreso
      } else if (movement.type == MovementType.expense || 
                 movement.category == MovementCategory.transferOut) {
        newBalance += movement.amount; // Revertir gasto
      }
      
      await updateAccountBalance(movement.accountId, newBalance);
    }
    
    // Eliminar el movimiento
    await _client.from(_movementsTable).delete().eq('id', id);
  }

  // ===================== REPORTES =====================

  /// Calcular totales del día
  static Future<Map<String, double>> getDayTotals(DateTime date) async {
    final movements = await getMovementsByDate(date);
    
    double totalIncome = 0;
    double totalExpense = 0;
    
    for (final m in movements) {
      if (m.type == MovementType.income) {
        totalIncome += m.amount;
      } else if (m.type == MovementType.expense) {
        totalExpense += m.amount;
      }
    }
    
    return {
      'income': totalIncome,
      'expense': totalExpense,
      'net': totalIncome - totalExpense,
    };
  }

  /// Obtener balance total de todas las cuentas activas
  static Future<double> getTotalBalance() async {
    final accounts = await getAllAccounts();
    return accounts.fold<double>(0.0, (sum, account) => sum + account.balance);
  }

  // ===================== CONVERSIÓN JSON =====================

  static Account _accountFromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: AccountType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AccountType.cash,
      ),
      balance: (json['balance'] ?? 0).toDouble(),
      bankName: json['bank_name'],
      accountNumber: json['account_number'],
      color: json['color'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }

  static Map<String, dynamic> _accountToJson(Account account) {
    return {
      'id': account.id,
      'name': account.name,
      'type': account.type.name,
      'balance': account.balance,
      'bank_name': account.bankName,
      'account_number': account.accountNumber,
      'color': account.color,
      'is_active': account.isActive,
      'created_at': account.createdAt.toIso8601String(),
      'updated_at': account.updatedAt.toIso8601String(),
    };
  }

  static CashMovement _movementFromJson(Map<String, dynamic> json) {
    return CashMovement(
      id: json['id'] ?? '',
      accountId: json['account_id'] ?? '',
      toAccountId: json['to_account_id'],
      type: MovementType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MovementType.income,
      ),
      category: MovementCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => MovementCategory.otherIncome,
      ),
      amount: (json['amount'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      reference: json['reference'],
      personName: json['person_name'],
      date: json['date'] != null 
          ? DateTime.parse(json['date']) 
          : DateTime.now(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      linkedTransferId: json['linked_transfer_id'],
    );
  }

  static Map<String, dynamic> _movementToJson(CashMovement movement) {
    return {
      'id': movement.id,
      'account_id': movement.accountId,
      'to_account_id': movement.toAccountId,
      'type': movement.type.name,
      'category': movement.category.name,
      'amount': movement.amount,
      'description': movement.description,
      'reference': movement.reference,
      'person_name': movement.personName,
      'date': movement.date.toIso8601String(),
      'created_at': movement.createdAt.toIso8601String(),
      'linked_transfer_id': movement.linkedTransferId,
    };
  }

  // ===================== INICIALIZACIÓN =====================

  /// Crear cuentas predeterminadas si no existen
  static Future<void> initializeDefaultAccounts() async {
    final accounts = await getAllAccounts(activeOnly: false);
    
    if (accounts.isEmpty) {
      // Crear las 3 cuentas predeterminadas
      final defaultAccounts = [
        Account(
          id: '',
          name: 'Caja',
          type: AccountType.cash,
          balance: 0,
          color: '#4CAF50', // Verde
          isActive: true,
        ),
        Account(
          id: '',
          name: 'Cuenta Daniela',
          type: AccountType.bank,
          bankName: 'Banco',
          balance: 0,
          color: '#2196F3', // Azul
          isActive: true,
        ),
        Account(
          id: '',
          name: 'Cuenta Industrial de Molinos',
          type: AccountType.bank,
          bankName: 'Banco',
          balance: 0,
          color: '#9C27B0', // Morado
          isActive: true,
        ),
      ];
      
      for (final account in defaultAccounts) {
        await createAccount(account);
      }
    }
  }
}
