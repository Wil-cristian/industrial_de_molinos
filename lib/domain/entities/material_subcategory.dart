import '../../core/utils/colombia_time.dart';
/// Entidad: Subcategoría de Material
/// Permite clasificar materiales dentro de una categoría principal
/// Ejemplo: Categoría "Rodamientos" → Subcategorías "6313", "6205", "6308"
class MaterialSubcategory {
  final String id;
  final String categoryId;
  final String name;
  final String slug;
  final String? description;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  MaterialSubcategory({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.slug,
    this.description,
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  MaterialSubcategory copyWith({
    String? id,
    String? categoryId,
    String? name,
    String? slug,
    String? description,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MaterialSubcategory(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory MaterialSubcategory.fromJson(Map<String, dynamic> json) {
    return MaterialSubcategory(
      id: json['id'],
      categoryId: json['category_id'] ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      isActive: json['is_active'] ?? true,
      sortOrder: json['sort_order'] ?? 0,
      createdAt: DateTime.parse(
        json['created_at'] ?? ColombiaTime.nowIso8601(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? ColombiaTime.nowIso8601(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'name': name,
      'slug': slug,
      'description': description,
      'is_active': isActive,
      'sort_order': sortOrder,
    };
  }

  @override
  String toString() => 'MaterialSubcategory($slug: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaterialSubcategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
