// Entidad: Proveedor
enum SupplierType { individual, business }

class Supplier {
  final String id;
  final SupplierType type;
  final String documentType; // RUC, DNI, CE
  final String documentNumber;
  final String name;
  final String? tradeName;
  final String? address;
  final String? phone;
  final String? email;
  final String? contactPerson;
  final String? bankAccount;
  final String? bankName;
  final double currentDebt; // Lo que le debemos al proveedor
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Supplier({
    required this.id,
    required this.type,
    required this.documentType,
    required this.documentNumber,
    required this.name,
    this.tradeName,
    this.address,
    this.phone,
    this.email,
    this.contactPerson,
    this.bankAccount,
    this.bankName,
    this.currentDebt = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // Nombre para mostrar
  String get displayName => tradeName ?? name;

  // Tiene deuda pendiente
  bool get hasDebt => currentDebt > 0;

  Supplier copyWith({
    String? id,
    SupplierType? type,
    String? documentType,
    String? documentNumber,
    String? name,
    String? tradeName,
    String? address,
    String? phone,
    String? email,
    String? contactPerson,
    String? bankAccount,
    String? bankName,
    double? currentDebt,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Supplier(
      id: id ?? this.id,
      type: type ?? this.type,
      documentType: documentType ?? this.documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      name: name ?? this.name,
      tradeName: tradeName ?? this.tradeName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      contactPerson: contactPerson ?? this.contactPerson,
      bankAccount: bankAccount ?? this.bankAccount,
      bankName: bankName ?? this.bankName,
      currentDebt: currentDebt ?? this.currentDebt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'document_type': documentType,
      'document_number': documentNumber,
      'name': name,
      'trade_name': tradeName,
      'address': address,
      'phone': phone,
      'email': email,
      'contact_person': contactPerson,
      'bank_account': bankAccount,
      'bank_name': bankName,
      'current_debt': currentDebt,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] as String,
      type: SupplierType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SupplierType.business,
      ),
      documentType: json['document_type'] as String? ?? 'RUC',
      documentNumber: json['document_number'] as String,
      name: json['name'] as String,
      tradeName: json['trade_name'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      contactPerson: json['contact_person'] as String?,
      bankAccount: json['bank_account'] as String?,
      bankName: json['bank_name'] as String?,
      currentDebt: (json['current_debt'] as num?)?.toDouble() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  String toString() => 'Supplier($displayName - $documentNumber)';
}
