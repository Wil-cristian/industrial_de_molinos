import 'account.dart';

// Tipos de movimiento de caja
enum MovementType {
  income,    // Ingreso
  expense,   // Gasto
  transfer,  // Traslado entre cuentas
}

// Categorías de movimiento
enum MovementCategory {
  // Ingresos
  sale,              // Venta
  collection,        // Cobranza
  otherIncome,       // Otros ingresos
  
  // Gastos
  purchase,          // Compra de materiales/productos
  salary,            // Salarios
  services,          // Servicios (luz, agua, internet, etc.)
  transport,         // Transporte / Mensajería
  maintenance,       // Mantenimiento
  otherExpense,      // Otros gastos
  
  // Traslados
  transferOut,       // Salida por traslado
  transferIn,        // Entrada por traslado
}

// Movimiento de Caja (Ingreso, Gasto, Traslado)
class CashMovement {
  final String id;
  final String accountId;           // Cuenta origen
  final String? toAccountId;        // Cuenta destino (solo para traslados)
  final MovementType type;
  final MovementCategory category;
  final double amount;
  final String description;
  final String? reference;          // Referencia (número de factura, recibo, etc.)
  final String? personName;         // Nombre de la persona (cliente, proveedor, empleado)
  final DateTime date;
  final DateTime createdAt;
  final String? linkedTransferId;   // ID del movimiento relacionado (para traslados)
  
  // Para mostrar en UI (no persistido)
  final Account? account;
  final Account? toAccount;

  CashMovement({
    required this.id,
    required this.accountId,
    this.toAccountId,
    required this.type,
    required this.category,
    required this.amount,
    required this.description,
    this.reference,
    this.personName,
    required this.date,
    DateTime? createdAt,
    this.linkedTransferId,
    this.account,
    this.toAccount,
  }) : createdAt = createdAt ?? DateTime.now();

  CashMovement copyWith({
    String? id,
    String? accountId,
    String? toAccountId,
    MovementType? type,
    MovementCategory? category,
    double? amount,
    String? description,
    String? reference,
    String? personName,
    DateTime? date,
    DateTime? createdAt,
    String? linkedTransferId,
    Account? account,
    Account? toAccount,
  }) {
    return CashMovement(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      type: type ?? this.type,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      reference: reference ?? this.reference,
      personName: personName ?? this.personName,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      linkedTransferId: linkedTransferId ?? this.linkedTransferId,
      account: account ?? this.account,
      toAccount: toAccount ?? this.toAccount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountId': accountId,
      'toAccountId': toAccountId,
      'type': type.name,
      'category': category.name,
      'amount': amount,
      'description': description,
      'reference': reference,
      'personName': personName,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'linkedTransferId': linkedTransferId,
    };
  }

  factory CashMovement.fromJson(Map<String, dynamic> json) {
    return CashMovement(
      id: json['id'] ?? '',
      accountId: json['accountId'] ?? '',
      toAccountId: json['toAccountId'],
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
      personName: json['personName'],
      date: json['date'] != null 
          ? DateTime.parse(json['date']) 
          : DateTime.now(),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      linkedTransferId: json['linkedTransferId'],
    );
  }

  String get typeLabel {
    switch (type) {
      case MovementType.income:
        return 'Ingreso';
      case MovementType.expense:
        return 'Gasto';
      case MovementType.transfer:
        return 'Traslado';
    }
  }

  String get categoryLabel {
    switch (category) {
      case MovementCategory.sale:
        return 'Venta';
      case MovementCategory.collection:
        return 'Cobranza';
      case MovementCategory.otherIncome:
        return 'Otros Ingresos';
      case MovementCategory.purchase:
        return 'Compra';
      case MovementCategory.salary:
        return 'Salario';
      case MovementCategory.services:
        return 'Servicios';
      case MovementCategory.transport:
        return 'Transporte';
      case MovementCategory.maintenance:
        return 'Mantenimiento';
      case MovementCategory.otherExpense:
        return 'Otros Gastos';
      case MovementCategory.transferOut:
        return 'Traslado Salida';
      case MovementCategory.transferIn:
        return 'Traslado Entrada';
    }
  }

  bool get isIncome => type == MovementType.income || category == MovementCategory.transferIn;
  bool get isExpense => type == MovementType.expense || category == MovementCategory.transferOut;
}

// Reporte Diario de Caja
class DailyCashReport {
  final DateTime date;
  final Map<String, double> openingBalances;  // Saldo inicial por cuenta
  final Map<String, double> closingBalances;  // Saldo final por cuenta
  final List<CashMovement> movements;
  final double totalIncome;
  final double totalExpense;
  final double totalTransfersIn;
  final double totalTransfersOut;
  final bool isClosed;
  final DateTime? closedAt;
  final String? notes;

  DailyCashReport({
    required this.date,
    required this.openingBalances,
    required this.closingBalances,
    required this.movements,
    required this.totalIncome,
    required this.totalExpense,
    this.totalTransfersIn = 0,
    this.totalTransfersOut = 0,
    this.isClosed = false,
    this.closedAt,
    this.notes,
  });

  double get netChange => totalIncome - totalExpense;
  
  double get totalOpeningBalance => 
      openingBalances.values.fold(0.0, (sum, balance) => sum + balance);
  
  double get totalClosingBalance => 
      closingBalances.values.fold(0.0, (sum, balance) => sum + balance);

  int get movementCount => movements.length;
  
  int get incomeCount => 
      movements.where((m) => m.type == MovementType.income).length;
  
  int get expenseCount => 
      movements.where((m) => m.type == MovementType.expense).length;

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'openingBalances': openingBalances,
      'closingBalances': closingBalances,
      'movements': movements.map((m) => m.toJson()).toList(),
      'totalIncome': totalIncome,
      'totalExpense': totalExpense,
      'totalTransfersIn': totalTransfersIn,
      'totalTransfersOut': totalTransfersOut,
      'isClosed': isClosed,
      'closedAt': closedAt?.toIso8601String(),
      'notes': notes,
    };
  }

  factory DailyCashReport.fromJson(Map<String, dynamic> json) {
    return DailyCashReport(
      date: DateTime.parse(json['date']),
      openingBalances: Map<String, double>.from(json['openingBalances'] ?? {}),
      closingBalances: Map<String, double>.from(json['closingBalances'] ?? {}),
      movements: (json['movements'] as List?)
          ?.map((m) => CashMovement.fromJson(m))
          .toList() ?? [],
      totalIncome: (json['totalIncome'] ?? 0).toDouble(),
      totalExpense: (json['totalExpense'] ?? 0).toDouble(),
      totalTransfersIn: (json['totalTransfersIn'] ?? 0).toDouble(),
      totalTransfersOut: (json['totalTransfersOut'] ?? 0).toDouble(),
      isClosed: json['isClosed'] ?? false,
      closedAt: json['closedAt'] != null 
          ? DateTime.parse(json['closedAt']) 
          : null,
      notes: json['notes'],
    );
  }
}
