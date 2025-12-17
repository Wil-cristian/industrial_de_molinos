// Tipos de cuenta
enum AccountType {
  cash,      // Efectivo (Caja)
  bank,      // Cuenta bancaria
}

// Entidad de Cuenta (Caja, Cuenta Bancaria)
class Account {
  final String id;
  final String name;
  final AccountType type;
  final double balance;
  final String? bankName;        // Solo para cuentas bancarias
  final String? accountNumber;   // Solo para cuentas bancarias
  final String? color;           // Color para identificar en UI
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Account({
    required this.id,
    required this.name,
    required this.type,
    this.balance = 0,
    this.bankName,
    this.accountNumber,
    this.color,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    double? balance,
    String? bankName,
    String? accountNumber,
    String? color,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'balance': balance,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'color': color,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: AccountType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AccountType.cash,
      ),
      balance: (json['balance'] ?? 0).toDouble(),
      bankName: json['bankName'],
      accountNumber: json['accountNumber'],
      color: json['color'],
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),
    );
  }

  String get typeLabel {
    switch (type) {
      case AccountType.cash:
        return 'Efectivo';
      case AccountType.bank:
        return 'Cuenta Bancaria';
    }
  }

  String get displayName {
    if (type == AccountType.bank && bankName != null) {
      return '$name ($bankName)';
    }
    return name;
  }
}
