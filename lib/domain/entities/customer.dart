// Entidad: Cliente
enum CustomerType { individual, business }

// Tipos de documento para Colombia (incluye valores legacy para compatibilidad)
enum DocumentType {
  cc, // Cédula de Ciudadanía
  nit, // NIT (empresas)
  ce, // Cédula de Extranjería
  pasaporte, // Pasaporte
  ti, // Tarjeta de Identidad
  // Valores legacy para compatibilidad con BD existente
  ruc, // -> se mostrará como NIT
  dni, // -> se mostrará como CC
  passport, // -> se mostrará como Pasaporte
}

// Extensión para mostrar nombres legibles
extension DocumentTypeExtension on DocumentType {
  String get displayName {
    switch (this) {
      case DocumentType.cc:
      case DocumentType.dni: // Legacy
        return 'CC';
      case DocumentType.nit:
      case DocumentType.ruc: // Legacy
        return 'NIT';
      case DocumentType.ce:
        return 'CE';
      case DocumentType.pasaporte:
      case DocumentType.passport: // Legacy
        return 'Pasaporte';
      case DocumentType.ti:
        return 'TI';
    }
  }

  String get fullName {
    switch (this) {
      case DocumentType.cc:
      case DocumentType.dni:
        return 'Cédula de Ciudadanía';
      case DocumentType.nit:
      case DocumentType.ruc:
        return 'NIT';
      case DocumentType.ce:
        return 'Cédula de Extranjería';
      case DocumentType.pasaporte:
      case DocumentType.passport:
        return 'Pasaporte';
      case DocumentType.ti:
        return 'Tarjeta de Identidad';
    }
  }

  // Convierte valores legacy a los nuevos valores de Colombia
  DocumentType get normalized {
    switch (this) {
      case DocumentType.dni:
        return DocumentType.cc;
      case DocumentType.ruc:
        return DocumentType.nit;
      case DocumentType.passport:
        return DocumentType.pasaporte;
      default:
        return this;
    }
  }

  // Verifica si es un valor legacy
  bool get isLegacy {
    return this == DocumentType.ruc ||
        this == DocumentType.dni ||
        this == DocumentType.passport;
  }
}

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
