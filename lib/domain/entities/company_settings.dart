/// Configuración de la empresa
class CompanySettings {
  final String? id;
  final String name;
  final String? tradeName;
  final String? ruc;
  final String? address;
  final String? phone;
  final String? email;
  final String? logoUrl;
  final String currency;
  final double taxRate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CompanySettings({
    this.id,
    this.name = 'Industrial de Molinos',
    this.tradeName,
    this.ruc,
    this.address,
    this.phone,
    this.email,
    this.logoUrl,
    this.currency = 'PEN',
    this.taxRate = 18.0,
    this.createdAt,
    this.updatedAt,
  });

  CompanySettings copyWith({
    String? id,
    String? name,
    String? tradeName,
    String? ruc,
    String? address,
    String? phone,
    String? email,
    String? logoUrl,
    String? currency,
    double? taxRate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanySettings(
      id: id ?? this.id,
      name: name ?? this.name,
      tradeName: tradeName ?? this.tradeName,
      ruc: ruc ?? this.ruc,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      logoUrl: logoUrl ?? this.logoUrl,
      currency: currency ?? this.currency,
      taxRate: taxRate ?? this.taxRate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    'trade_name': tradeName,
    'ruc': ruc,
    'address': address,
    'phone': phone,
    'email': email,
    'logo_url': logoUrl,
    'currency': currency,
    'tax_rate': taxRate,
  };

  factory CompanySettings.fromJson(Map<String, dynamic> json) => CompanySettings(
    id: json['id'],
    name: json['name'] ?? 'Industrial de Molinos',
    tradeName: json['trade_name'],
    ruc: json['ruc'],
    address: json['address'],
    phone: json['phone'],
    email: json['email'],
    logoUrl: json['logo_url'],
    currency: json['currency'] ?? 'PEN',
    taxRate: (json['tax_rate'] ?? 18.0).toDouble(),
    createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
  );
}

/// Categoría de productos
class ProductCategory {
  final String id;
  final String name;
  final String? description;
  final String? parentId;
  final bool isActive;
  final DateTime? createdAt;

  const ProductCategory({
    required this.id,
    required this.name,
    this.description,
    this.parentId,
    this.isActive = true,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'parent_id': parentId,
    'is_active': isActive,
  };

  factory ProductCategory.fromJson(Map<String, dynamic> json) => ProductCategory(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    parentId: json['parent_id'],
    isActive: json['is_active'] ?? true,
    createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
  );
}

/// Concepto de nómina
class PayrollConcept {
  final String id;
  final String code;
  final String name;
  final String type; // 'ingreso', 'descuento'
  final String category; // 'salario', 'hora_extra', 'bonificacion', 'descuento', 'incapacidad'
  final bool isPercentage;
  final double defaultValue;
  final bool affectsTaxes;
  final bool isActive;
  final String? description;

  const PayrollConcept({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.category,
    this.isPercentage = false,
    this.defaultValue = 0,
    this.affectsTaxes = true,
    this.isActive = true,
    this.description,
  });

  PayrollConcept copyWith({
    String? id,
    String? code,
    String? name,
    String? type,
    String? category,
    bool? isPercentage,
    double? defaultValue,
    bool? affectsTaxes,
    bool? isActive,
    String? description,
  }) {
    return PayrollConcept(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      type: type ?? this.type,
      category: category ?? this.category,
      isPercentage: isPercentage ?? this.isPercentage,
      defaultValue: defaultValue ?? this.defaultValue,
      affectsTaxes: affectsTaxes ?? this.affectsTaxes,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'type': type,
    'category': category,
    'is_percentage': isPercentage,
    'default_value': defaultValue,
    'affects_taxes': affectsTaxes,
    'is_active': isActive,
    'description': description,
  };

  factory PayrollConcept.fromJson(Map<String, dynamic> json) => PayrollConcept(
    id: json['id'],
    code: json['code'],
    name: json['name'],
    type: json['type'],
    category: json['category'],
    isPercentage: json['is_percentage'] ?? false,
    defaultValue: (json['default_value'] ?? 0).toDouble(),
    affectsTaxes: json['affects_taxes'] ?? true,
    isActive: json['is_active'] ?? true,
    description: json['description'],
  );
}

/// Configuración de mora/intereses
class InterestSettings {
  final double monthlyRate; // Tasa mensual de mora
  final int gracePeriodDays; // Días de gracia
  final double minimumAmount; // Monto mínimo para aplicar interés

  const InterestSettings({
    this.monthlyRate = 2.0,
    this.gracePeriodDays = 0,
    this.minimumAmount = 0,
  });

  InterestSettings copyWith({
    double? monthlyRate,
    int? gracePeriodDays,
    double? minimumAmount,
  }) {
    return InterestSettings(
      monthlyRate: monthlyRate ?? this.monthlyRate,
      gracePeriodDays: gracePeriodDays ?? this.gracePeriodDays,
      minimumAmount: minimumAmount ?? this.minimumAmount,
    );
  }
}
