import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/asset.dart';

/// Datasource para gestión de activos fijos
class AssetsDatasource {
  static final _client = Supabase.instance.client;

  /// Obtener todos los activos
  static Future<List<Asset>> getAssets({
    String? category,
    String? status,
    String? searchQuery,
  }) async {
    try {
      var query = _client.from('assets').select();

      if (category != null && category.isNotEmpty && category != 'todas') {
        query = query.eq('category', category);
      }

      if (status != null && status.isNotEmpty && status != 'todos') {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);

      List<Asset> assets = (response as List)
          .map((json) => Asset.fromJson(json))
          .toList();

      // Filtrar por búsqueda en memoria
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        assets = assets.where((a) =>
          a.name.toLowerCase().contains(query) ||
          (a.description?.toLowerCase().contains(query) ?? false) ||
          (a.brand?.toLowerCase().contains(query) ?? false) ||
          (a.serialNumber?.toLowerCase().contains(query) ?? false)
        ).toList();
      }

      print('✅ Activos cargados: ${assets.length}');
      return assets;
    } catch (e) {
      print('❌ Error cargando activos: $e');
      return [];
    }
  }

  /// Obtener un activo por ID
  static Future<Asset?> getAssetById(String id) async {
    try {
      final response = await _client
          .from('assets')
          .select()
          .eq('id', id)
          .single();

      return Asset.fromJson(response);
    } catch (e) {
      print('❌ Error obteniendo activo: $e');
      return null;
    }
  }

  /// Crear activo
  static Future<Asset?> createAsset(Asset asset) async {
    try {
      print('🔄 Creando activo: ${asset.name}');
      final response = await _client
          .from('assets')
          .insert(asset.toJson())
          .select()
          .single();

      print('✅ Activo creado exitosamente');
      return Asset.fromJson(response);
    } catch (e) {
      print('❌ Error creando activo: $e');
      return null;
    }
  }

  /// Actualizar activo
  static Future<bool> updateAsset(Asset asset) async {
    try {
      await _client
          .from('assets')
          .update(asset.toJson())
          .eq('id', asset.id);

      print('✅ Activo actualizado');
      return true;
    } catch (e) {
      print('❌ Error actualizando activo: $e');
      return false;
    }
  }

  /// Eliminar activo
  static Future<bool> deleteAsset(String id) async {
    try {
      await _client.from('assets').delete().eq('id', id);
      print('✅ Activo eliminado');
      return true;
    } catch (e) {
      print('❌ Error eliminando activo: $e');
      return false;
    }
  }

  /// Cambiar estado del activo
  static Future<bool> updateAssetStatus(String id, String status) async {
    try {
      await _client
          .from('assets')
          .update({'status': status})
          .eq('id', id);

      print('✅ Estado actualizado a: $status');
      return true;
    } catch (e) {
      print('❌ Error actualizando estado: $e');
      return false;
    }
  }

  // ========== MANTENIMIENTO ==========

  /// Obtener historial de mantenimiento de un activo
  static Future<List<AssetMaintenance>> getMaintenanceHistory(String assetId) async {
    try {
      final response = await _client
          .from('asset_maintenance')
          .select()
          .eq('asset_id', assetId)
          .order('maintenance_date', ascending: false);

      return (response as List)
          .map((json) => AssetMaintenance.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error cargando mantenimientos: $e');
      return [];
    }
  }

  /// Registrar mantenimiento
  static Future<AssetMaintenance?> createMaintenance(AssetMaintenance maintenance) async {
    try {
      print('🔄 Registrando mantenimiento');
      final response = await _client
          .from('asset_maintenance')
          .insert(maintenance.toJson())
          .select()
          .single();

      // Actualizar estado del activo si es necesario
      if (maintenance.maintenanceType == 'correctivo' || 
          maintenance.maintenanceType == 'emergencia') {
        await _client
            .from('assets')
            .update({'status': 'mantenimiento'})
            .eq('id', maintenance.assetId);
      }

      print('✅ Mantenimiento registrado');
      return AssetMaintenance.fromJson(response);
    } catch (e) {
      print('❌ Error registrando mantenimiento: $e');
      return null;
    }
  }

  /// Obtener activos que necesitan mantenimiento
  static Future<List<Asset>> getAssetsNeedingMaintenance() async {
    try {
      // Obtener activos en mantenimiento o con mantenimiento próximo
      final response = await _client
          .from('assets')
          .select()
          .eq('status', 'mantenimiento');

      return (response as List)
          .map((json) => Asset.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error: $e');
      return [];
    }
  }

  /// Obtener estadísticas de activos
  static Future<Map<String, dynamic>> getAssetStats() async {
    try {
      final assets = await getAssets();
      
      double totalValue = 0;
      double totalInvestment = 0;
      int inMaintenance = 0;

      for (final asset in assets) {
        totalValue += asset.currentValue;
        totalInvestment += asset.purchasePrice;
        if (asset.status == 'mantenimiento') {
          inMaintenance++;
        }
      }

      return {
        'totalAssets': assets.length,
        'totalValue': totalValue,
        'totalInvestment': totalInvestment,
        'inMaintenance': inMaintenance,
      };
    } catch (e) {
      print('❌ Error calculando estadísticas: $e');
      return {
        'totalAssets': 0,
        'totalValue': 0.0,
        'totalInvestment': 0.0,
        'inMaintenance': 0,
      };
    }
  }
}
