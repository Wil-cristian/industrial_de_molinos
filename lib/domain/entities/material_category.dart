import 'package:flutter/material.dart';

/// Entidad: Categoría de Material
/// Permite categorías personalizadas definidas por el usuario
class MaterialCategory {
  final String id;
  final String name; // Nombre para mostrar (ej: "Tubos")
  final String slug; // Clave interna (ej: "tubo")
  final String? description;
  final String defaultUnit; // Unidad por defecto: KG, UND, M, L
  final String color; // Color hex (ej: "#2196F3")
  final String iconName; // Nombre del ícono Material Icons
  final bool
  hasDimensions; // Si materiales de esta categoría tienen dimensiones
  final String? dimensionType; // cylinder, plate, solid_cylinder, etc.
  final bool isSystem; // Categorías del sistema (no editables/eliminables)
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  MaterialCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.defaultUnit = 'KG',
    this.color = '#607D8B',
    this.iconName = 'category',
    this.hasDimensions = false,
    this.dimensionType,
    this.isSystem = false,
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Color como objeto Flutter
  Color get displayColor {
    try {
      final hex = color.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  /// Ícono del Material Icons
  IconData get displayIcon {
    return _iconMap[iconName] ?? Icons.category;
  }

  /// Mapa de nombres de íconos a IconData
  static const Map<String, IconData> _iconMap = {
    'category': Icons.category,
    'circle_outlined': Icons.circle_outlined,
    'crop_square': Icons.crop_square,
    'minimize': Icons.minimize,
    'settings': Icons.settings,
    'build': Icons.build,
    'local_fire_department': Icons.local_fire_department,
    'flash_on': Icons.flash_on,
    'format_paint': Icons.format_paint,
    'view_column': Icons.view_column,
    'precision_manufacturing': Icons.precision_manufacturing,
    'hardware': Icons.hardware,
    'plumbing': Icons.plumbing,
    'electrical_services': Icons.electrical_services,
    'construction': Icons.construction,
    'handyman': Icons.handyman,
    'inventory_2': Icons.inventory_2,
    'warehouse': Icons.warehouse,
    'bolt': Icons.bolt,
    'water_drop': Icons.water_drop,
    'oil_barrel': Icons.oil_barrel,
    'cleaning_services': Icons.cleaning_services,
    'straighten': Icons.straighten,
    'square_foot': Icons.square_foot,
    'layers': Icons.layers,
    'dashboard': Icons.dashboard,
    'widgets': Icons.widgets,
    'engineering': Icons.engineering,
    'science': Icons.science,
    'recycling': Icons.recycling,
    'auto_fix_high': Icons.auto_fix_high,
  };

  /// Lista de íconos disponibles para selección
  static List<MapEntry<String, IconData>> get availableIcons =>
      _iconMap.entries.toList();

  /// Lista de colores disponibles para selección
  static const List<String> availableColors = [
    '#F44336', // Red
    '#E91E63', // Pink
    '#9C27B0', // Purple
    '#673AB7', // Deep Purple
    '#3F51B5', // Indigo
    '#2196F3', // Blue
    '#03A9F4', // Light Blue
    '#00BCD4', // Cyan
    '#009688', // Teal
    '#4CAF50', // Green
    '#8BC34A', // Light Green
    '#FF9800', // Orange
    '#FF5722', // Deep Orange
    '#795548', // Brown
    '#607D8B', // Blue Grey
  ];

  /// Unidades disponibles
  static const Map<String, String> availableUnits = {
    'KG': 'Kilogramos (KG)',
    'UND': 'Unidades (UND)',
    'M': 'Metros (M)',
    'L': 'Litros (L)',
    'M2': 'Metros² (M²)',
    'GAL': 'Galones (GAL)',
  };

  /// Tipos de dimensión disponibles
  static const Map<String, String> availableDimensionTypes = {
    'cylinder': 'Cilindro/Tubo hueco',
    'solid_cylinder': 'Cilindro sólido/Eje',
    'plate': 'Lámina/Placa',
  };

  MaterialCategory copyWith({
    String? id,
    String? name,
    String? slug,
    String? description,
    String? defaultUnit,
    String? color,
    String? iconName,
    bool? hasDimensions,
    String? dimensionType,
    bool? isSystem,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MaterialCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      defaultUnit: defaultUnit ?? this.defaultUnit,
      color: color ?? this.color,
      iconName: iconName ?? this.iconName,
      hasDimensions: hasDimensions ?? this.hasDimensions,
      dimensionType: dimensionType ?? this.dimensionType,
      isSystem: isSystem ?? this.isSystem,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory MaterialCategory.fromJson(Map<String, dynamic> json) {
    return MaterialCategory(
      id: json['id'],
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      defaultUnit: json['default_unit'] ?? 'KG',
      color: json['color'] ?? '#607D8B',
      iconName: json['icon_name'] ?? 'category',
      hasDimensions: json['has_dimensions'] ?? false,
      dimensionType: json['dimension_type'],
      isSystem: json['is_system'] ?? false,
      isActive: json['is_active'] ?? true,
      sortOrder: json['sort_order'] ?? 0,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'slug': slug,
      'description': description,
      'default_unit': defaultUnit,
      'color': color,
      'icon_name': iconName,
      'has_dimensions': hasDimensions,
      'dimension_type': dimensionType,
      'is_system': isSystem,
      'is_active': isActive,
      'sort_order': sortOrder,
    };
  }

  @override
  String toString() => 'MaterialCategory($slug: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaterialCategory &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
