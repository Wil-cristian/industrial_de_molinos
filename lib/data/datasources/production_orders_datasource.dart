import '../../core/utils/colombia_time.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/logger.dart';
import '../../domain/entities/production_order.dart';
import '../../domain/entities/invoice.dart';
import 'supabase_datasource.dart';
import 'audit_log_datasource.dart';

class ProductionOrdersDataSource {
  static SupabaseClient get _client => SupabaseDataSource.client;

  static Future<List<ProductionOrder>> getAll() async {
    try {
      final ordersResponse = await _client
          .from('production_orders')
          .select('*, products(id, code, name)')
          .order('sort_order', ascending: true);

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
      final now = ColombiaTime.now();
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
            'start_date': ColombiaTime.dateString(now),
            'due_date': (input.dueDate != null
                ? ColombiaTime.dateString(input.dueDate!)
                : null),
            'notes': input.notes,
          })
          .select('id')
          .single();

      final orderId = (orderResponse['id'] ?? '').toString();
      if (orderId.isEmpty) return null;

      final materialRows = <Map<String, dynamic>>[];
      for (final component in input.product.components) {
        if (component.materialId.isEmpty) continue;

        if (component.quantity <= 0) {
          throw Exception(
            'El componente "${component.materialName ?? component.materialCode}" '
            'tiene cantidad inválida (${component.quantity}). '
            'Corrija la receta antes de crear la orden de producción.',
          );
        }

        final plannedQty =
            (component.quantity.toDouble() * input.quantity).toDouble();

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
          ? const [
              ProcessChainItem(processName: 'Corte'),
              ProcessChainItem(processName: 'Torno'),
              ProcessChainItem(processName: 'Soldadura'),
              ProcessChainItem(processName: 'Armado'),
              ProcessChainItem(processName: 'Control Calidad'),
            ]
          : input.processChain;

      final stageRows = <Map<String, dynamic>>[];
      for (var i = 0; i < chain.length; i++) {
        final item = chain[i];
        final process = item.processName.trim();
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
          if (item.employeeId != null) 'assigned_employee_id': item.employeeId,
        });
      }

      if (stageRows.isNotEmpty) {
        final insertedStages = await _client
            .from('production_stages')
            .insert(stageRows)
            .select('id, sequence_order, process_name, assigned_employee_id');

        // Crear tareas para empleados asignados a etapas
        final taskRows = <Map<String, dynamic>>[];
        for (final stage in (insertedStages as List)) {
          final empId = stage['assigned_employee_id'];
          if (empId == null) continue;
          final processName = stage['process_name'] ?? '';
          final stageId = stage['id'];
          taskRows.add({
            'employee_id': empId,
            'title': '$processName — $code',
            'description':
                'Etapa de producción: $processName\nProducto: ${input.product.name} x${input.quantity}',
            'assigned_date': ColombiaTime.dateString(now),
            'due_date': (input.dueDate != null
                ? ColombiaTime.dateString(input.dueDate!)
                : null),
            'status': 'pendiente',
            'priority': input.priority == 'urgente'
                ? 'urgente'
                : input.priority == 'alta'
                ? 'alta'
                : 'media',
            'category': 'produccion',
            'production_order_id': orderId,
            'production_stage_id': stageId,
          });
        }
        if (taskRows.isNotEmpty) {
          await _client.from('employee_tasks').insert(taskRows);
        }
      }

      final order = await getById(orderId);
      if (order != null) {
        AuditLogDatasource.log(
          action: 'create',
          module: 'production',
          recordId: orderId,
          description:
              'Creó orden de producción $code: ${input.product.name} x${input.quantity}',
          details: {
            'code': code,
            'product': input.product.name,
            'quantity': input.quantity,
          },
        );
      }
      return order;
    } catch (e) {
      AppLogger.error('Error creando OP: $e');
      rethrow;
    }
  }

  static Future<void> updateOrderStatus(String orderId, String status) async {
    final values = <String, dynamic>{'status': status};
    if (status == 'completada') {
      values['completed_at'] = ColombiaTime.nowIso8601();
    }

    await _client
        .from('production_orders')
        .update(values)
        .eq('id', orderId)
        .select()
        .single();
    AuditLogDatasource.log(
      action: 'update',
      module: 'production',
      recordId: orderId,
      description: 'Cambió estado de orden de producción a: $status',
      details: {'new_status': status},
    );
  }

  /// Eliminar una orden de producción y todo lo asociado (cascade en DB)
  static Future<void> deleteOrder(String orderId) async {
    // Primero borrar tareas de empleado asociadas
    await _client
        .from('employee_tasks')
        .delete()
        .eq('production_order_id', orderId);
    // El CASCADE en DB borra stages y materials
    await _client.from('production_orders').delete().eq('id', orderId);
    AuditLogDatasource.log(
      action: 'delete',
      module: 'production',
      recordId: orderId,
      description: 'Eliminó orden de producción',
    );
  }

  /// Actualizar sort_order de múltiples órdenes (drag-reorder)
  static Future<void> updateSortOrders(List<String> orderedIds) async {
    for (int i = 0; i < orderedIds.length; i++) {
      await _client
          .from('production_orders')
          .update({'sort_order': i + 1})
          .eq('id', orderedIds[i]);
    }
  }

  /// Actualizar prioridad de una orden de producción
  static Future<void> updatePriority(String orderId, String priority) async {
    await _client
        .from('production_orders')
        .update({'priority': priority})
        .eq('id', orderId);
    AuditLogDatasource.log(
      action: 'update',
      module: 'production',
      recordId: orderId,
      description: 'Cambió prioridad de orden a: $priority',
      details: {'new_priority': priority},
    );
  }

  /// Actualizar fecha de entrega de una orden de producción
  static Future<void> updateDueDate(String orderId, DateTime dueDate) async {
    await _client
        .from('production_orders')
        .update({'due_date': ColombiaTime.dateString(dueDate)})
        .eq('id', orderId);
    AuditLogDatasource.log(
      action: 'update',
      module: 'production',
      recordId: orderId,
      description: 'Cambió fecha de entrega',
      details: {'new_due_date': ColombiaTime.dateString(dueDate)},
    );
  }

  /// Vincular una factura a una orden de producción
  static Future<void> linkInvoice(String orderId, String invoiceId) async {
    await _client
        .from('production_orders')
        .update({'invoice_id': invoiceId})
        .eq('id', orderId)
        .select()
        .single();
    AuditLogDatasource.log(
      action: 'link_invoice',
      module: 'production',
      recordId: orderId,
      description: 'Vinculó factura a orden de producción',
      details: {'invoice_id': invoiceId},
    );
  }

  /// Desvincular factura de una orden de producción
  static Future<void> unlinkInvoice(String orderId) async {
    await _client
        .from('production_orders')
        .update({'invoice_id': null})
        .eq('id', orderId)
        .select()
        .single();
    AuditLogDatasource.log(
      action: 'unlink_invoice',
      module: 'production',
      recordId: orderId,
      description: 'Desvinculó factura de orden de producción',
    );
  }

  static Future<void> updateStage(ProductionStage stage) async {
    await _client
        .from('production_stages')
        .update(stage.toJson())
        .eq('id', stage.id)
        .select()
        .single();

    // Sincronizar tarea del empleado asignado
    await _syncStageTask(stage);
  }

  /// Crea o actualiza la tarea asociada a una etapa de producción.
  static Future<void> _syncStageTask(ProductionStage stage) async {
    try {
      // Buscar tarea existente para esta etapa
      final existing = await _client
          .from('employee_tasks')
          .select('id')
          .eq('production_stage_id', stage.id)
          .limit(1);

      final hasExisting = (existing as List).isNotEmpty;
      final existingId = hasExisting ? existing.first['id'] as String : null;

      if (stage.assignedEmployeeId == null) {
        // Sin empleado → eliminar tarea existente si hay
        if (hasExisting) {
          await _client.from('employee_tasks').delete().eq('id', existingId!);
        }
        return;
      }

      // Obtener info de la OP para el título
      final orderData = await _client
          .from('production_orders')
          .select('code, product_name, quantity, due_date, priority')
          .eq('id', stage.productionOrderId)
          .limit(1)
          .single();

      final code = orderData['code'] ?? '';
      final productName = orderData['product_name'] ?? '';
      final quantity = orderData['quantity'] ?? 0;
      final dueDate = orderData['due_date'];
      final priority = orderData['priority'] as String? ?? 'media';

      final taskData = <String, dynamic>{
        'employee_id': stage.assignedEmployeeId,
        'title': '${stage.processName} — $code',
        'description':
            'Etapa de producción: ${stage.processName}\nProducto: $productName x$quantity',
        'assigned_date': ColombiaTime.todayString(),
        'due_date': dueDate,
        'status': stage.status == 'completada' ? 'completada' : 'pendiente',
        'priority': priority == 'urgente'
            ? 'urgente'
            : priority == 'alta'
            ? 'alta'
            : 'media',
        'category': 'produccion',
        'production_order_id': stage.productionOrderId,
        'production_stage_id': stage.id,
      };

      if (hasExisting) {
        await _client
            .from('employee_tasks')
            .update(taskData)
            .eq('id', existingId!);
      } else {
        await _client.from('employee_tasks').insert(taskData);
      }
    } catch (e) {
      AppLogger.error('Error sincronizando tarea de etapa: $e');
    }
  }

  static Future<void> createStage({
    required String orderId,
    required String processName,
    required String workstation,
    required double estimatedHours,
    double actualHours = 0,
    String status = 'pendiente',
    String? assignedEmployeeId,
    List<String> resources = const [],
    List<String> materialIds = const [],
    List<String> assetIds = const [],
    String? report,
    String? notes,
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
      'actual_hours': actualHours,
      'status': status,
      'assigned_employee_id': assignedEmployeeId,
      'resources': resources,
      'material_ids': materialIds,
      'asset_ids': assetIds,
      'report': report,
      'notes': notes,
    });
  }

  static Future<void> deleteStage(String stageId) async {
    await _client.from('production_stages').delete().eq('id', stageId);
  }

  // ── BOM Materials CRUD ──────────────────────────────────────────────

  static Future<void> addMaterialToOrder({
    required String orderId,
    required String materialId,
    required String materialName,
    String? materialCode,
    required double requiredQuantity,
    String unit = 'UND',
    double estimatedCost = 0,
    String? pieceTitle,
    String? dimensions,
  }) async {
    await _client.from('production_order_materials').insert({
      'production_order_id': orderId,
      'material_id': materialId,
      'material_name': materialName,
      'material_code': materialCode,
      'required_quantity': requiredQuantity,
      'consumed_quantity': 0,
      'unit': unit,
      'estimated_cost': estimatedCost,
      if (pieceTitle != null) 'piece_title': pieceTitle,
      if (dimensions != null) 'dimensions': dimensions,
    });
  }

  static Future<void> removeMaterialFromOrder(String materialRowId) async {
    await _client
        .from('production_order_materials')
        .delete()
        .eq('id', materialRowId);
  }

  static Future<void> updateMaterialQuantity(
    String materialRowId,
    double newQuantity,
  ) async {
    await _client
        .from('production_order_materials')
        .update({'required_quantity': newQuantity})
        .eq('id', materialRowId);
  }

  /// Crea una orden de producción automáticamente a partir de una venta.
  /// Se vincula directamente con la factura.
  static Future<ProductionOrder?> createFromSale({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required List<ProcessChainItem> processChain,
    String priority = 'media',
    String? notes,
  }) async {
    try {
      if (processChain.isEmpty) return null;

      final now = ColombiaTime.now();
      final code =
          'OP-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(7)}';

      // Nombre del producto: si es 1 item usar su nombre, sino un resumen
      final productName = items.length == 1
          ? items.first.productName
          : '${items.first.productName} (+${items.length - 1} más)';
      final productCode = items.length == 1
          ? (items.first.productCode ?? '')
          : invoice.fullNumber;

      // Buscar product_id del primer item (puede ser null si es material suelto)
      final productId = items.first.productId;

      final orderResponse = await _client
          .from('production_orders')
          .insert({
            'code': code,
            if (productId != null && productId.isNotEmpty)
              'product_id': productId,
            'product_code': productCode,
            'product_name': productName,
            'quantity': items.fold<double>(0, (sum, i) => sum + i.quantity),
            'status': 'planificada',
            'priority': priority,
            'start_date': ColombiaTime.dateString(now),
            'invoice_id': invoice.id,
            'notes':
                notes ??
                'Generada automáticamente desde venta ${invoice.fullNumber}',
          })
          .select('id')
          .single();

      final orderId = (orderResponse['id'] ?? '').toString();
      if (orderId.isEmpty) return null;

      // Crear materiales desde los items de la factura
      final materialRows = <Map<String, dynamic>>[];
      for (final item in items) {
        final matId = item.materialId;
        if (matId == null || matId.isEmpty) continue;
        materialRows.add({
          'production_order_id': orderId,
          'material_id': matId,
          'material_name': item.productName,
          'material_code': item.productCode ?? '',
          'required_quantity': item.quantity,
          'consumed_quantity': 0,
          'unit': item.unit,
          'estimated_cost': item.total,
        });
      }

      if (materialRows.isNotEmpty) {
        await _client.from('production_order_materials').insert(materialRows);
      }

      // Crear etapas de producción
      final stageRows = <Map<String, dynamic>>[];
      for (var i = 0; i < processChain.length; i++) {
        final item = processChain[i];
        final process = item.processName.trim();
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
          if (item.employeeId != null) 'assigned_employee_id': item.employeeId,
        });
      }

      if (stageRows.isNotEmpty) {
        final insertedStages = await _client
            .from('production_stages')
            .insert(stageRows)
            .select('id, sequence_order, process_name, assigned_employee_id');

        // Crear tareas para empleados asignados
        final taskRows = <Map<String, dynamic>>[];
        for (final stage in (insertedStages as List)) {
          final empId = stage['assigned_employee_id'];
          if (empId == null) continue;
          final processName = stage['process_name'] ?? '';
          final stageId = stage['id'];
          taskRows.add({
            'employee_id': empId,
            'title': '$processName — $code',
            'description':
                'Etapa de producción: $processName\nVenta: ${invoice.fullNumber}\nProducto: $productName',
            'assigned_date': ColombiaTime.dateString(now),
            'status': 'pendiente',
            'priority': priority == 'urgente'
                ? 'urgente'
                : priority == 'alta'
                ? 'alta'
                : 'media',
            'category': 'produccion',
            'production_order_id': orderId,
            'production_stage_id': stageId,
          });
        }
        if (taskRows.isNotEmpty) {
          await _client.from('employee_tasks').insert(taskRows);
        }
      }

      final order = await getById(orderId);
      if (order != null) {
        AuditLogDatasource.log(
          action: 'create',
          module: 'production',
          recordId: orderId,
          description:
              'Orden de producción $code creada automáticamente desde venta ${invoice.fullNumber}',
          details: {
            'code': code,
            'invoice_id': invoice.id,
            'invoice_number': invoice.fullNumber,
            'product': productName,
            'stages': processChain.map((p) => p.processName).toList(),
          },
        );
      }
      return order;
    } catch (e) {
      AppLogger.error('Error creando OP desde venta: $e');
      rethrow;
    }
  }
}
