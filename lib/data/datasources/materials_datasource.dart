import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/material_price.dart';
import 'supabase_datasource.dart';

class MaterialsDataSource {
  static const String _table = 'material_prices';
  static const String _costsTable = 'operational_costs';

  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Obtener todos los materiales
  static Future<List<MaterialPrice>> getAll({bool activeOnly = true}) async {
    var query = _client.from(_table).select();
    
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    
    final response = await query.order('category').order('name');
    return response.map<MaterialPrice>((json) => _fromJson(json)).toList();
  }

  /// Obtener materiales por categoría
  static Future<List<MaterialPrice>> getByCategory(String category) async {
    final response = await _client
        .from(_table)
        .select()
        .eq('category', category)
        .eq('is_active', true)
        .order('name');
    return response.map<MaterialPrice>((json) => _fromJson(json)).toList();
  }

  /// Obtener material por ID
  static Future<MaterialPrice?> getById(String id) async {
    try {
      final response = await _client.from(_table).select().eq('id', id).single();
      return _fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Obtener categorías disponibles
  static Future<List<String>> getCategories() async {
    final response = await _client
        .from(_table)
        .select('category')
        .eq('is_active', true);
    
    final categories = <String>{};
    for (var item in response) {
      categories.add(item['category'] as String);
    }
    return categories.toList()..sort();
  }

  /// Crear material
  static Future<MaterialPrice> create(MaterialPrice material) async {
    final data = _toJson(material);
    data.remove('id');
    data.remove('updated_at');
    data.remove('created_at');
    
    final response = await _client.from(_table).insert(data).select().single();
    return _fromJson(response);
  }

  /// Actualizar material
  static Future<MaterialPrice> update(MaterialPrice material) async {
    final data = _toJson(material);
    data.remove('id');
    data.remove('updated_at');
    data.remove('created_at');
    
    final response = await _client
        .from(_table)
        .update(data)
        .eq('id', material.id)
        .select()
        .single();
    return _fromJson(response);
  }

  /// Eliminar material (soft delete)
  static Future<void> delete(String id) async {
    await _client.from(_table).update({'is_active': false}).eq('id', id);
  }

  /// Actualizar precio de material
  static Future<void> updatePrice(String id, double newPrice) async {
    await _client.from(_table).update({'price_per_kg': newPrice}).eq('id', id);
  }

  /// Obtener costos operativos
  static Future<OperationalCosts> getOperationalCosts() async {
    try {
      final response = await _client.from(_costsTable).select().single();
      return OperationalCosts(
        laborRatePerHour: (response['labor_rate_per_hour'] ?? 25.0).toDouble(),
        energyRatePerKwh: (response['energy_rate_per_kwh'] ?? 0.5).toDouble(),
        gasRatePerM3: (response['gas_rate_per_m3'] ?? 2.0).toDouble(),
        defaultProfitMargin: (response['default_profit_margin'] ?? 20.0).toDouble(),
      );
    } catch (e) {
      return OperationalCosts();
    }
  }

  /// Actualizar costos operativos
  static Future<void> updateOperationalCosts(OperationalCosts costs) async {
    final data = {
      'labor_rate_per_hour': costs.laborRatePerHour,
      'energy_rate_per_kwh': costs.energyRatePerKwh,
      'gas_rate_per_m3': costs.gasRatePerM3,
      'default_profit_margin': costs.defaultProfitMargin,
    };
    
    // Actualizar el único registro de costos operativos
    final existing = await _client.from(_costsTable).select('id').limit(1);
    if (existing.isNotEmpty) {
      await _client.from(_costsTable).update(data).eq('id', existing[0]['id']);
    } else {
      await _client.from(_costsTable).insert(data);
    }
  }

  // Helpers de conversión
  static MaterialPrice _fromJson(Map<String, dynamic> json) {
    return MaterialPrice(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      type: json['type'] ?? '',
      thickness: (json['thickness'] ?? 0).toDouble(),
      pricePerKg: (json['price_per_kg'] ?? 0).toDouble(),
      density: (json['density'] ?? 7.85).toDouble(),
      unit: json['unit'] ?? 'kg',
      isActive: json['is_active'] ?? true,
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  static Map<String, dynamic> _toJson(MaterialPrice material) {
    return {
      'id': material.id,
      'name': material.name,
      'category': material.category,
      'type': material.type,
      'thickness': material.thickness,
      'price_per_kg': material.pricePerKg,
      'density': material.density,
      'unit': material.unit,
      'is_active': material.isActive,
      'updated_at': material.updatedAt.toIso8601String(),
    };
  }
}
