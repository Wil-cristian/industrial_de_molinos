import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/company_settings.dart';
import '../../domain/entities/material_price.dart';
import 'supabase_datasource.dart';

class SettingsDataSource {
  static SupabaseClient get _client => SupabaseDataSource.client;

  // =====================================================
  // COMPANY SETTINGS
  // =====================================================

  /// Obtener configuración de la empresa
  static Future<CompanySettings> getCompanySettings() async {
    try {
      final response = await _client
          .from('company_settings')
          .select()
          .limit(1)
          .single();
      return CompanySettings.fromJson(response);
    } catch (e) {
      // Retornar valores por defecto si no existe
      return const CompanySettings();
    }
  }

  /// Actualizar configuración de la empresa
  static Future<CompanySettings> updateCompanySettings(CompanySettings settings) async {
    final data = settings.toJson();
    data.remove('id');
    data.remove('created_at');
    data.remove('updated_at');
    data['updated_at'] = DateTime.now().toIso8601String();

    // Verificar si existe un registro
    final existing = await _client.from('company_settings').select('id').limit(1);
    
    if (existing.isNotEmpty) {
      final response = await _client
          .from('company_settings')
          .update(data)
          .eq('id', existing[0]['id'])
          .select()
          .single();
      return CompanySettings.fromJson(response);
    } else {
      final response = await _client
          .from('company_settings')
          .insert(data)
          .select()
          .single();
      return CompanySettings.fromJson(response);
    }
  }

  // =====================================================
  // OPERATIONAL COSTS
  // =====================================================

  /// Obtener costos operativos
  static Future<OperationalCosts> getOperationalCosts() async {
    try {
      final response = await _client
          .from('operational_costs')
          .select()
          .limit(1)
          .single();
      return OperationalCosts.fromJson(response);
    } catch (e) {
      return const OperationalCosts();
    }
  }

  /// Actualizar costos operativos
  static Future<void> updateOperationalCosts(OperationalCosts costs) async {
    final data = costs.toJson();
    
    final existing = await _client.from('operational_costs').select('id').limit(1);
    
    if (existing.isNotEmpty) {
      await _client
          .from('operational_costs')
          .update(data)
          .eq('id', existing[0]['id']);
    } else {
      await _client.from('operational_costs').insert(data);
    }
  }

  // =====================================================
  // CATEGORIES
  // =====================================================

  /// Obtener todas las categorías
  static Future<List<ProductCategory>> getCategories() async {
    try {
      final response = await _client
          .from('categories')
          .select()
          .order('name');
      return response.map<ProductCategory>((json) => ProductCategory.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Crear categoría
  static Future<ProductCategory> createCategory(ProductCategory category) async {
    final data = category.toJson();
    final response = await _client
        .from('categories')
        .insert(data)
        .select()
        .single();
    return ProductCategory.fromJson(response);
  }

  /// Actualizar categoría
  static Future<ProductCategory> updateCategory(ProductCategory category) async {
    final data = category.toJson();
    final response = await _client
        .from('categories')
        .update(data)
        .eq('id', category.id)
        .select()
        .single();
    return ProductCategory.fromJson(response);
  }

  /// Eliminar categoría (soft delete)
  static Future<void> deleteCategory(String id) async {
    await _client.from('categories').update({'is_active': false}).eq('id', id);
  }

  // =====================================================
  // PAYROLL CONCEPTS
  // =====================================================

  /// Obtener conceptos de nómina
  static Future<List<PayrollConcept>> getPayrollConcepts() async {
    try {
      final response = await _client
          .from('payroll_concepts')
          .select()
          .order('type')
          .order('name');
      return response.map<PayrollConcept>((json) => PayrollConcept.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Obtener conceptos activos por tipo
  static Future<List<PayrollConcept>> getPayrollConceptsByType(String type) async {
    try {
      final response = await _client
          .from('payroll_concepts')
          .select()
          .eq('type', type)
          .eq('is_active', true)
          .order('name');
      return response.map<PayrollConcept>((json) => PayrollConcept.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Crear concepto de nómina
  static Future<PayrollConcept> createPayrollConcept(PayrollConcept concept) async {
    final data = concept.toJson();
    final response = await _client
        .from('payroll_concepts')
        .insert(data)
        .select()
        .single();
    return PayrollConcept.fromJson(response);
  }

  /// Actualizar concepto de nómina
  static Future<PayrollConcept> updatePayrollConcept(PayrollConcept concept) async {
    final data = concept.toJson();
    final response = await _client
        .from('payroll_concepts')
        .update(data)
        .eq('id', concept.id)
        .select()
        .single();
    return PayrollConcept.fromJson(response);
  }

  /// Eliminar concepto (soft delete)
  static Future<void> deletePayrollConcept(String id) async {
    await _client.from('payroll_concepts').update({'is_active': false}).eq('id', id);
  }

  // =====================================================
  // SYNC LOG
  // =====================================================

  /// Obtener última sincronización
  static Future<DateTime?> getLastSyncTime() async {
    try {
      final response = await _client
          .from('sync_log')
          .select('synced_at')
          .order('synced_at', ascending: false)
          .limit(1);
      
      if (response.isNotEmpty) {
        return DateTime.parse(response[0]['synced_at']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Registrar sincronización
  static Future<void> logSync(String tableName, String operation) async {
    await _client.from('sync_log').insert({
      'table_name': tableName,
      'operation': operation,
      'synced_at': DateTime.now().toIso8601String(),
    });
  }

  // =====================================================
  // ESTADÍSTICAS PARA DASHBOARD DE CONFIGURACIÓN
  // =====================================================

  /// Obtener resumen de datos
  static Future<Map<String, int>> getDataSummary() async {
    final summary = <String, int>{};
    
    try {
      // Contar registros de cada tabla principal
      final tables = [
        'customers',
        'employees',
        'products',
        'materials',
        'quotations',
        'invoices',
        'activities',
        'assets',
      ];

      for (final table in tables) {
        try {
          final response = await _client.from(table).select('id');
          summary[table] = response.length;
        } catch (e) {
          summary[table] = 0;
        }
      }
    } catch (e) {
      // Ignorar errores
    }

    return summary;
  }
}
