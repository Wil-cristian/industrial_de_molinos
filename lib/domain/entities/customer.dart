// Entidad: Cliente
enum CustomerType { individual, business }
enum DocumentType { dni, ruc, ce, passport }

class Customer {
  final String id;
  final CustomerType type;
  final DocumentType documentType;
  final String documentNumber;
  final String name;
  final String? tradeName;
  final String? address;
  final String? phone;
  final String? email;
  final double creditLimit;
  final double currentBalance;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Customer({
    required this.id,
    required this.type,
    required this.documentType,
    required this.documentNumber,
    required this.name,
    this.tradeName,
    this.address,
    this.phone,
    this.email,
    this.creditLimit = 0,
    this.currentBalance = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // Crédito disponible
  double get availableCredit => creditLimit - currentBalance;

  // Tiene deuda
  bool get hasDebt => currentBalance > 0;

  // Nombre para mostrar
  String get displayName => tradeName ?? name;

  Customer copyWith({
    String? id,
    CustomerType? type,
    DocumentType? documentType,
    String? documentNumber,
    String? name,
    String? tradeName,
    String? address,
    String? phone,
    String? email,
    double? creditLimit,
    double? currentBalance,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      type: type ?? this.type,
      documentType: documentType ?? this.documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      name: name ?? this.name,
      tradeName: tradeName ?? this.tradeName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      creditLimit: creditLimit ?? this.creditLimit,
      currentBalance: currentBalance ?? this.currentBalance,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
