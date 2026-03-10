import 'account.dart';
import '../../data/datasources/storage_datasource.dart';

/// Mapea valores de categoría del DB (incluyendo nombres viejos) al enum actual.
MovementCategory parseCategoryFromJson(String value) {
  // Categorías personalizadas (prefijo custom_)
  if (value.startsWith('custom_')) return MovementCategory.custom;
  // Mapeo directo por nombre de enum actual
  for (final cat in MovementCategory.values) {
    if (cat.name == value) return cat;
  }
  // Compatibilidad con valores antiguos del DB
  switch (value) {
    case 'purchase':
      return MovementCategory.consumibles;
    case 'salary':
      return MovementCategory.nomina;
    case 'services':
      return MovementCategory.servicios_publicos;
    case 'transport':
      return MovementCategory.transporte;
    case 'maintenance':
      return MovementCategory.gastos_reducibles;
    case 'prestamo_empleado':
      return MovementCategory.gastos_reducibles;
    case 'adelanto_sueldo':
      return MovementCategory.nomina;
    case 'otherExpense':
      return MovementCategory.gastos_reducibles;
    default:
      return MovementCategory.otherIncome;
  }
}

/// Extrae el nombre legible de una categoría custom del string de DB.
String? parseCustomCategoryName(String value) {
  if (value.startsWith('custom_')) {
    return value.substring(7).replaceAll('_', ' ');
  }
  return null;
}

// Tipos de movimiento de caja
enum MovementType {
  income, // Ingreso
  expense, // Gasto
  transfer, // Traslado entre cuentas
}

// Categorías de movimiento
enum MovementCategory {
  // Ingresos
  sale, // Venta
  collection, // Cobranza
  pago_prestamo, // Pago/abono de préstamo empleado
  otherIncome, // Otros ingresos
  // Gastos
  cuidado_personal, // Implementos de cuidado personal
  servicios_publicos, // Servicios públicos (luz, agua, internet)
  papeleria, // Papelería
  nomina, // Nómina
  impuestos, // Impuestos
  consumibles, // Consumibles (materiales, productos)
  transporte, // Transporte
  gastos_reducibles, // Gastos reducibles
  // Traslados
  transferOut, // Salida por traslado
  transferIn, // Entrada por traslado
  // Personalizada
  custom, // Categoría creada por el usuario
}

// Movimiento de Caja (Ingreso, Gasto, Traslado)
class CashMovement {
  final String id;
  final String accountId; // Cuenta origen
  final String? toAccountId; // Cuenta destino (solo para traslados)
  final MovementType type;
  final MovementCategory category;
  final String? customCategoryName; // Nombre legible para categorías custom
  final double amount;
  final String description;
  final String? reference; // Referencia (número de factura, recibo, etc.)
  final String?
  personName; // Nombre de la persona (cliente, proveedor, empleado)
  final DateTime date;
  final DateTime createdAt;
  final String?
  linkedTransferId; // ID del movimiento relacionado (para traslados)

  // Archivos adjuntos (fotos, recibos, etc.) almacenados en Supabase Storage
  final List<AttachmentInfo> attachments;

  // Para mostrar en UI (no persistido)
  final Account? account;
  final Account? toAccount;

  CashMovement({
    required this.id,
    required this.accountId,
    this.toAccountId,
    required this.type,
    required this.category,
    this.customCategoryName,
    required this.amount,
    required this.description,
    this.reference,
    this.personName,
    required this.date,
    DateTime? createdAt,
    this.linkedTransferId,
    this.attachments = const [],
    this.account,
    this.toAccount,
  }) : createdAt = createdAt ?? DateTime.now();

  CashMovement copyWith({
    String? id,
    String? accountId,
    String? toAccountId,
    MovementType? type,
    MovementCategory? category,
    String? customCategoryName,
    double? amount,
    String? description,
    String? reference,
    String? personName,
    DateTime? date,
    DateTime? createdAt,
    String? linkedTransferId,
    List<AttachmentInfo>? attachments,
    Account? account,
    Account? toAccount,
  }) {
    return CashMovement(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      type: type ?? this.type,
      category: category ?? this.category,
      customCategoryName: customCategoryName ?? this.customCategoryName,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      reference: reference ?? this.reference,
      personName: personName ?? this.personName,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      linkedTransferId: linkedTransferId ?? this.linkedTransferId,
      attachments: attachments ?? this.attachments,
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
      'category':
          category == MovementCategory.custom && customCategoryName != null
          ? 'custom_${customCategoryName!.replaceAll(' ', '_')}'
          : category.name,
      'amount': amount,
      'description': description,
      'reference': reference,
      'personName': personName,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'linkedTransferId': linkedTransferId,
      'attachments': attachments.map((a) => a.toJson()).toList(),
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
      category: parseCategoryFromJson(json['category'] ?? ''),
      customCategoryName: parseCustomCategoryName(json['category'] ?? ''),

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
      attachments: json['attachments'] != null && json['attachments'] is List
          ? (json['attachments'] as List)
                .map(
                  (a) => AttachmentInfo.fromJson(Map<String, dynamic>.from(a)),
                )
                .toList()
          : [],
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
      case MovementCategory.pago_prestamo:
        return 'Pago Préstamo';
      case MovementCategory.otherIncome:
        return 'Otros Ingresos';
      case MovementCategory.cuidado_personal:
        return 'Cuidado Personal';
      case MovementCategory.servicios_publicos:
        return 'Servicios Públicos';
      case MovementCategory.papeleria:
        return 'Papelería';
      case MovementCategory.nomina:
        return 'Nómina';
      case MovementCategory.impuestos:
        return 'Impuestos';
      case MovementCategory.consumibles:
        return 'Consumibles';
      case MovementCategory.transporte:
        return 'Transporte';
      case MovementCategory.gastos_reducibles:
        return 'Gastos Reducibles';
      case MovementCategory.transferOut:
        return 'Traslado Salida';
      case MovementCategory.transferIn:
        return 'Traslado Entrada';
      case MovementCategory.custom:
        return customCategoryName ?? 'Otra';
    }
  }

  bool get isIncome =>
      type == MovementType.income || category == MovementCategory.transferIn;
  bool get isExpense =>
      type == MovementType.expense || category == MovementCategory.transferOut;
}

// Reporte Diario de Caja
class DailyCashReport {
  final DateTime date;
  final Map<String, double> openingBalances; // Saldo inicial por cuenta
  final Map<String, double> closingBalances; // Saldo final por cuenta
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
      movements:
          (json['movements'] as List?)
              ?.map((m) => CashMovement.fromJson(m))
              .toList() ??
          [],
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
