import '../../core/utils/colombia_time.dart';
class StorageLocation {
  final String id;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StorageLocation({
    required this.id,
    required this.name,
    this.description,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StorageLocation.fromJson(Map<String, dynamic> json) {
    return StorageLocation(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(
        json['created_at'] ?? ColombiaTime.nowIso8601(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? ColombiaTime.nowIso8601(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'description': description, 'is_active': isActive};
  }
}
