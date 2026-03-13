import '../../core/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/cash_movement.dart';
import 'storage_datasource.dart';
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
  static Future<void> updateAccountBalance(
    String accountId,
    double newBalance,
  ) async {
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

  /// Obtener el siguiente número de referencia consecutivo
  static Future<int> getNextReferenceNumber() async {
    try {
      final response = await _client
          .from(_movementsTable)
          .select('reference')
          .not('reference', 'is', null)
          .order('created_at', ascending: false)
          .limit(50);

      int maxNum = 0;
      for (final row in response) {
        final ref = row['reference'] as String?;
        if (ref != null) {
          final num = int.tryParse(ref.replaceAll(RegExp(r'[^0-9]'), ''));
          if (num != null && num > maxNum) maxNum = num;
        }
      }
      return maxNum + 1;
    } catch (e) {
      return 1;
    }
  }

  /// Obtener todos los movimientos
  static Future<List<CashMovement>> getAllMovements() async {
    final response = await _client
        .from(_movementsTable)
        .select()
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    return response
        .map<CashMovement>((json) => _movementFromJson(json))
        .toList();
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
    return response
        .map<CashMovement>((json) => _movementFromJson(json))
        .toList();
  }

  /// Obtener movimientos por rango de fechas
  static Future<List<CashMovement>> getMovementsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    ).add(const Duration(days: 1));

    final response = await _client
        .from(_movementsTable)
        .select()
        .gte('date', start.toIso8601String())
        .lt('date', end.toIso8601String())
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    return response
        .map<CashMovement>((json) => _movementFromJson(json))
        .toList();
  }

  /// Obtener movimientos por cuenta
  static Future<List<CashMovement>> getMovementsByAccount(
    String accountId,
  ) async {
    final response = await _client
        .from(_movementsTable)
        .select()
        .or('account_id.eq.$accountId,to_account_id.eq.$accountId')
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    return response
        .map<CashMovement>((json) => _movementFromJson(json))
        .toList();
  }

  /// Crear movimiento
  static Future<CashMovement> createMovement(CashMovement movement) async {
    final data = _movementToJson(movement);
    data.remove('id');
    data.remove('created_at');

    AppLogger.debug('?? Insertando movimiento: $data');

    final response = await _client
        .from(_movementsTable)
        .insert(data)
        .select()
        .single();
    AppLogger.success('? Movimiento insertado: $response');
    return _movementFromJson(response);
  }

  /// Crear traslado entre cuentas (usa RPC atómica para evitar race conditions)
  static Future<List<CashMovement>> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    required String description,
    required DateTime date,
    String? reference,
  }) async {
    // Validaciones
    if (amount <= 0) {
      throw Exception('El monto de la transferencia debe ser mayor a 0');
    }
    if (fromAccountId == toAccountId) {
      throw Exception('No se puede transferir a la misma cuenta');
    }

    try {
      // Usar RPC atómica (SELECT FOR UPDATE + insert + balance update en una transacción)
      final result = await _client.rpc(
        'atomic_transfer',
        params: {
          'p_from_account_id': fromAccountId,
          'p_to_account_id': toAccountId,
          'p_amount': amount,
          'p_description': description,
          'p_date': date.toIso8601String().split('T')[0],
          'p_reference': reference,
        },
      );

      // Recuperar los movimientos creados para devolver al caller
      final outId = result['out_movement_id'] as String;
      final inId = result['in_movement_id'] as String;

      final responses = await Future.wait([
        _client.from(_movementsTable).select().eq('id', outId).single(),
        _client.from(_movementsTable).select().eq('id', inId).single(),
      ]);

      return [_movementFromJson(responses[0]), _movementFromJson(responses[1])];
    } catch (e) {
      // Fallback: si la RPC no existe aún, usar el método clásico
      if (e.toString().contains('function') &&
          e.toString().contains('not exist')) {
        return _createTransferLegacy(
          fromAccountId: fromAccountId,
          toAccountId: toAccountId,
          amount: amount,
          description: description,
          date: date,
          reference: reference,
        );
      }
      rethrow;
    }
  }

  /// Fallback legacy para transferencias (read-then-write)
  static Future<List<CashMovement>> _createTransferLegacy({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    required String description,
    required DateTime date,
    String? reference,
  }) async {
    // Verificar saldo suficiente
    final sourceAccount = await getAccountById(fromAccountId);
    if (sourceAccount == null) throw Exception('Cuenta origen no encontrada');
    if (sourceAccount.balance < amount) {
      throw Exception(
        'Saldo insuficiente: disponible \$${sourceAccount.balance.toStringAsFixed(2)}, requerido \$${amount.toStringAsFixed(2)}',
      );
    }

    final transferId = DateTime.now().millisecondsSinceEpoch.toString();

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

    final outData = _movementToJson(outMovement)
      ..remove('id')
      ..remove('created_at');
    final inData = _movementToJson(inMovement)
      ..remove('id')
      ..remove('created_at');

    final responses = await Future.wait([
      _client.from(_movementsTable).insert(outData).select().single(),
      _client.from(_movementsTable).insert(inData).select().single(),
    ]);

    final fromAccount = await getAccountById(fromAccountId);
    final toAccount = await getAccountById(toAccountId);
    if (fromAccount != null) {
      await updateAccountBalance(fromAccountId, fromAccount.balance - amount);
    }
    if (toAccount != null) {
      await updateAccountBalance(toAccountId, toAccount.balance + amount);
    }

    return [_movementFromJson(responses[0]), _movementFromJson(responses[1])];
  }

  /// Crear movimiento y actualizar balance (usa RPC atómica)
  static Future<CashMovement> createMovementWithBalanceUpdate(
    CashMovement movement,
  ) async {
    // Validaciones
    if (movement.amount <= 0) {
      throw Exception('El monto del movimiento debe ser mayor a 0');
    }

    try {
      final result = await _client.rpc(
        'atomic_movement_with_balance',
        params: {
          'p_account_id': movement.accountId,
          'p_type': movement.type.name,
          'p_category':
              movement.category == MovementCategory.custom &&
                  movement.customCategoryName != null
              ? 'custom_${movement.customCategoryName!.replaceAll(' ', '_')}'
              : movement.category.name,
          'p_amount': movement.amount,
          'p_description': movement.description,
          'p_reference': movement.reference,
          'p_person_name': movement.personName,
          'p_date': movement.date.toIso8601String().split('T')[0],
        },
      );

      final movementId = result['movement_id'] as String;
      final response = await _client
          .from(_movementsTable)
          .select()
          .eq('id', movementId)
          .single();
      return _movementFromJson(response);
    } catch (e) {
      // Fallback si la RPC no existe aún
      if (e.toString().contains('function') &&
          e.toString().contains('not exist')) {
        return _createMovementWithBalanceLegacy(movement);
      }
      rethrow;
    }
  }

  /// Fallback legacy para movimiento + balance (read-then-write)
  static Future<CashMovement> _createMovementWithBalanceLegacy(
    CashMovement movement,
  ) async {
    final created = await createMovement(movement);
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

    // Desvincular de tablas relacionadas antes de eliminar
    // Desvincular de payroll
    await _client
        .from('payroll')
        .update({'cash_movement_id': null})
        .eq('cash_movement_id', id);

    // Desvincular de employee_loans
    await _client
        .from('employee_loans')
        .update({'cash_movement_id': null})
        .eq('cash_movement_id', id);

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
      category: parseCategoryFromJson(json['category'] ?? ''),
      customCategoryName: parseCustomCategoryName(json['category'] ?? ''),
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
      attachments: json['attachments'] != null && json['attachments'] is List
          ? (json['attachments'] as List)
                .map(
                  (a) => AttachmentInfo.fromJson(Map<String, dynamic>.from(a)),
                )
                .toList()
          : [],
    );
  }

  static Map<String, dynamic> _movementToJson(CashMovement movement) {
    return {
      'id': movement.id,
      'account_id': movement.accountId,
      'to_account_id': movement.toAccountId,
      'type': movement.type.name,
      'category':
          movement.category == MovementCategory.custom &&
              movement.customCategoryName != null
          ? 'custom_${movement.customCategoryName!.replaceAll(' ', '_')}'
          : movement.category.name,
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
          name: 'Davivienda',
          type: AccountType.bank,
          bankName: 'Davivienda',
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
