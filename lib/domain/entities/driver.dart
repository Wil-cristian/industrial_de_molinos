import '../../core/utils/colombia_time.dart';
// Entidad: Conductor / Transportista

class Driver {
  final String id;
  final String name;
  final String document; // CC
  final String? phone;
  final String? vehiclePlate;
  final String? carrierCompany; // Empresa transportista
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Driver({
    required this.id,
    required this.name,
    required this.document,
    this.phone,
    this.vehiclePlate,
    this.carrierCompany,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      document: json['document']?.toString() ?? '',
      phone: json['phone']?.toString(),
      vehiclePlate: json['vehicle_plate']?.toString(),
      carrierCompany: json['carrier_company']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          ColombiaTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          ColombiaTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'document': document,
      'phone': phone,
      'vehicle_plate': vehiclePlate,
      'carrier_company': carrierCompany,
      'is_active': isActive,
    };
  }

  Driver copyWith({
    String? id,
    String? name,
    String? document,
    String? phone,
    String? vehiclePlate,
    String? carrierCompany,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Driver(
      id: id ?? this.id,
      name: name ?? this.name,
      document: document ?? this.document,
      phone: phone ?? this.phone,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      carrierCompany: carrierCompany ?? this.carrierCompany,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
