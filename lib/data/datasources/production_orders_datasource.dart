import 'package:supabase/src/supabase_client.dart';

import '../../core/utils/logger.dart';
import '../../domain/entities/production_order.dart';
import 'supabase_datasource.dart';

class ProductionOrdersDataSource {
  static SupabaseClient get _client => SupabaseDataSource.client;

  static Future<List<ProductionOrder>> getAll() async {
    try {
      final ordersResponse = await _client
          .from('production_orders')
          .select('*, products(id, code, name)')
          .order('created_at', ascending: false);

      if ((ordersResponse as List).isEmpty) {
        return [];
      }

      final orderIds = ordersResponse
          .map<String>((o) => (o['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();

      final materialsResponse = await _client
          .from('production_order_materials')
          .select('*, materials(name, code)')
          .inFilter('production_order_id', orderIds);

      final stagesResponse = await _client
          .from('production_stages')
          .select('*, employees(first_name, last_name)')
          .inFilter('production_order_id', orderIds)
          .order('sequence_order');

      final materialsByOrder = <String, List<ProductionOrderMaterial>>{};
      for (final row in (materialsResponse as List)) {
        final orderId = (row['production_order_id'] ?? '').toString();
        if (orderId.isEmpty) continue;
        materialsByOrder.putIfAbsent(orderId, () => []);
        materialsByOrder[orderId]!.add(ProductionOrderMaterial.fromJson(row));
      }

      final stagesByOrder = <String, List<ProductionStage>>{};
      for (final row in (stagesResponse as List)) {
        final orderId = (row['production_order_id'] ?? '').toString();
        if (orderId.isEmpty) continue;
        stagesByOrder.putIfAbsent(orderId, () => []);
        stagesByOrder[orderId]!.add(ProductionStage.fromJson(row));
      }

      return ordersResponse
          .map<ProductionOrder>(
            (row) => ProductionOrder.fromJson(
              row,
              materials:
                  materialsByOrder[(row['id'] ?? '').toString()] ?? const [],
              stages: stagesByOrder[(row['id'] ?? '').toString()] ?? const [],
            ),
          )
          .toList();
    } catch (e) {
      AppLogger.error('Error cargando ordenes de produccion: $e');
      rethrow;
    }
  }

  static Future<ProductionOrder?> getById(String id) async {
    try {
      final orderResponse = await _client
          .from('production_orders')
          .select('*, products(id, code, name)')
          .eq('id', id)
          .maybeSingle();

      if (orderResponse == null) return null;

      final materialsResponse = await _client
          .from('production_order_materials')
          .select('*, materials(name, code)')
          .eq('production_order_id', id);

      final stagesResponse = await _client
          .from('production_stages')
          .select('*, employees(first_name, last_name)')
          .eq('production_order_id', id)
          .order('sequence_order');

      final materials = (materialsResponse as List)
          .map((m) => ProductionOrderMaterial.fromJson(m))
          .toList();
      final stages = (stagesResponse as List)
          .map((s) => ProductionStage.fromJson(s))
          .toList();

      return ProductionOrder.fromJson(
        orderResponse,
        materials: materials,
        stages: stages,
      );
    } catch (e) {
      AppLogger.error('Error cargando detalle de OP: $e');
      rethrow;
    }
  }

  static Future<ProductionOrder?> createFromProduct(
    ProductionOrderCreationInput input,
  ) async {
    try {
      final now = DateTime.now();
      final code =
          'OP-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(7)}';

      final orderResponse = await _client
          .from('production_orders')
          .insert({
            'code': code,
            'product_id': input.product.id,
            'product_code': input.product.code,
            'product_name': input.product.name,
            'quantity': input.quantity,
            'status': 'planificada',
            'priority': input.priority,
            'start_date': now.toIso8601String().split('T')[0],
            'due_date': input.dueDate?.toIso8601String().split('T')[0],
            'notes': input.notes,
          })
          .select('id')
          .single();

      final orderId = (orderResponse['id'] ?? '').toString();
      if (orderId.isEmpty) return null;

      final materialRows = <Map<String, dynamic>>[];
      for (final component in input.product.components) {
        if (component.materialId.isEmpty) continue;

        final plannedQty =
            ((component.quantity > 0 ? component.quantity.toDouble() : 1) *
                    input.quantity)
                .toDouble();

        materialRows.add({
          'production_order_id': orderId,
          'material_id': component.materialId,
          'material_name': component.materialName ?? 'Material',
          'material_code': component.materialCode,
          'required_quantity': plannedQty,
          'consumed_quantity': 0,
          'unit': 'UND',
          'estimated_cost': component.totalCostPrice * input.quantity,
        });
      }

      if (materialRows.isNotEmpty) {
        await _client.from('production_order_materials').insert(materialRows);
      }

      final chain = input.processChain.isEmpty
          ? const ['Corte', 'Torno', 'Soldadura', 'Armado', 'Control Calidad']
          : input.processChain;

      final stageRows = <Map<String, dynamic>>[];
      for (var i = 0; i < chain.length; i++) {
        final process = chain[i].trim();
        if (process.isEmpty) continue;
        stageRows.add({
          'production_order_id': orderId,
          'sequence_order': i + 1,
          'process_name': process,
          'workstation': process,
          'estimated_hours': 2,
          'actual_hours': 0,
          'status': 'pendiente',
          'resources': const <String>[],
        });
      }

      if (stageRows.isNotEmpty) {
        await _client.from('production_stages').insert(stageRows);
      }

      return await getById(orderId);
    } catch (e) {
      AppLogger.error('Error creando OP: $e');
      rethrow;
    }
  }

  static Future<void> updateOrderStatus(String orderId, String status) async {
    final values = <String, dynamic>{'status': status};
    if (status == 'completada') {
      values['completed_at'] = DateTime.now().toIso8601String();
    }

    await _client.from('production_orders').update(values).eq('id', orderId);
  }

  static Future<void> updateStage(ProductionStage stage) async {
    await _client
        .from('production_stages')
        .update(stage.toJson())
        .eq('id', stage.id);
  }

  static Future<void> createStage({
    required String orderId,
    required String processName,
    required String workstation,
    required double estimatedHours,
  }) async {
    final response = await _client
        .from('production_stages')
        .select('sequence_order')
        .eq('production_order_id', orderId)
        .order('sequence_order', ascending: false)
        .limit(1);

    final maxSequence = (response as List).isEmpty
        ? 0
        : ((response.first['sequence_order'] as num?)?.toInt() ?? 0);

    await _client.from('production_stages').insert({
      'production_order_id': orderId,
      'sequence_order': maxSequence + 1,
      'process_name': processName,
      'workstation': workstation,
      'estimated_hours': estimatedHours,
      'actual_hours': 0,
      'status': 'pendiente',
      'resources': const <String>[],
    });
  }

  static Future<void> deleteStage(String stageId) async {
    await _client.from('production_stages').delete().eq('id', stageId);
  }
}
