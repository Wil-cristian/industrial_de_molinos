import '../../core/utils/colombia_time.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/logger.dart';
import '../../domain/entities/shipment_order.dart';
import 'supabase_datasource.dart';
import 'audit_log_datasource.dart';

class ShipmentsDataSource {
  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Obtener todas las remisiones
  static Future<List<ShipmentOrder>> getAll({String? status}) async {
    try {
      var query = _client
          .from('shipment_orders')
          .select('*, invoices(series, number), production_orders(code)');

      if (status != null && status != 'todos') {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);
      final orders = response as List;

      if (orders.isEmpty) return [];

      // Cargar ítems para todas las remisiones
      final orderIds = orders
          .map<String>((o) => (o['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();

      final itemsResponse = await _client
          .from('shipment_order_items')
          .select('*')
          .inFilter('shipment_order_id', orderIds)
          .order('sequence_order');

      final itemsByOrder = <String, List<ShipmentOrderItem>>{};
      for (final row in (itemsResponse as List)) {
        final orderId = (row['shipment_order_id'] ?? '').toString();
        if (orderId.isEmpty) continue;
        itemsByOrder.putIfAbsent(orderId, () => []);
        itemsByOrder[orderId]!.add(ShipmentOrderItem.fromJson(row));
      }

      return orders
          .map<ShipmentOrder>(
            (row) => ShipmentOrder.fromJson(
              row,
              items: itemsByOrder[(row['id'] ?? '').toString()] ?? const [],
            ),
          )
          .toList();
    } catch (e) {
      AppLogger.error('Error cargando remisiones: $e');
      rethrow;
    }
  }

  /// Obtener remisión por ID con ítems
  static Future<ShipmentOrder?> getById(String id) async {
    try {
      final response = await _client
          .from('shipment_orders')
          .select('*, invoices(series, number), production_orders(code)')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      final itemsResponse = await _client
          .from('shipment_order_items')
          .select('*')
          .eq('shipment_order_id', id)
          .order('sequence_order');

      final items = (itemsResponse as List)
          .map((i) => ShipmentOrderItem.fromJson(i))
          .toList();

      return ShipmentOrder.fromJson(response, items: items);
    } catch (e) {
      AppLogger.error('Error cargando remisión $id: $e');
      rethrow;
    }
  }

  /// Obtener remisión asociada a una factura (la más reciente)
  static Future<Map<String, dynamic>?> getByInvoiceId(
    String invoiceId,
  ) async {
    try {
      final response = await _client
          .from('shipment_orders')
          .select('id, code, status, dispatch_date, delivered_at')
          .eq('invoice_id', invoiceId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      AppLogger.error(
        'Error buscando remisión para factura $invoiceId: $e',
      );
      return null;
    }
  }

  /// Obtener siguiente código de remisión
  static Future<String> getNextCode() async {
    try {
      final response = await _client.rpc('next_shipment_number') as String;
      return response;
    } catch (e) {
      AppLogger.error('Error obteniendo código de remisión: $e');
      // Fallback: generar basado en timestamp
      final ts = ColombiaTime.now().millisecondsSinceEpoch;
      return 'REM-${ts.toString().substring(ts.toString().length - 5)}';
    }
  }

  /// Crear nueva remisión con ítems
  static Future<ShipmentOrder?> create(ShipmentOrder order) async {
    try {
      final code = await getNextCode();
      final data = order.toJson();
      data['code'] = code;
      data.remove('id');

      final response = await _client
          .from('shipment_orders')
          .insert(data)
          .select('*, invoices(series, number), production_orders(code)')
          .single();

      final orderId = response['id'].toString();

      // Insertar ítems
      if (order.items.isNotEmpty) {
        final itemsData = order.items.asMap().entries.map((entry) {
          final item = entry.value;
          final json = item.toJson();
          json['shipment_order_id'] = orderId;
          json['sequence_order'] = entry.key;
          json.remove('id');
          return json;
        }).toList();

        await _client.from('shipment_order_items').insert(itemsData);
      }

      await AuditLogDatasource.log(
        action: 'crear_remision',
        module: 'remisiones',
        recordId: orderId,
        description: 'Remisión $code creada para ${order.customerName}',
      );

      return await getById(orderId);
    } catch (e) {
      AppLogger.error('Error creando remisión: $e');
      rethrow;
    }
  }

  /// Actualizar remisión (solo si borrador)
  static Future<void> update(ShipmentOrder order) async {
    try {
      // Verificar que la remisión sigue en borrador antes de editar
      final current = await _client
          .from('shipment_orders')
          .select('status')
          .eq('id', order.id)
          .maybeSingle();
      if (current != null && current['status'] != 'borrador') {
        throw Exception(
          'No se puede editar: la remisión ya está en estado "${current['status']}"',
        );
      }

      final data = order.toJson();
      data.remove('code'); // No cambiar código

      await _client.from('shipment_orders').update(data).eq('id', order.id);

      // Reemplazar ítems: borrar y reinsertar
      await _client
          .from('shipment_order_items')
          .delete()
          .eq('shipment_order_id', order.id);

      if (order.items.isNotEmpty) {
        final itemsData = order.items.asMap().entries.map((entry) {
          final item = entry.value;
          final json = item.toJson();
          json['shipment_order_id'] = order.id;
          json['sequence_order'] = entry.key;
          json.remove('id');
          return json;
        }).toList();

        await _client.from('shipment_order_items').insert(itemsData);
      }

      await AuditLogDatasource.log(
        action: 'actualizar_remision',
        module: 'remisiones',
        recordId: order.id,
        description: 'Remisión ${order.code} actualizada',
      );
    } catch (e) {
      AppLogger.error('Error actualizando remisión: $e');
      rethrow;
    }
  }

  /// Transiciones de estado válidas
  static const _validTransitions = <String, List<String>>{
    'borrador': ['despachada', 'anulada'],
    'despachada': ['en_transito', 'entregada', 'anulada'],
    'en_transito': ['entregada', 'anulada'],
    'entregada': [], // estado final
    'anulada': [], // estado final
  };

  /// Cambiar estado de remisión
  static Future<void> updateStatus(
    String id,
    String status, {
    String? receivedBy,
  }) async {
    try {
      // Verificar estado actual y validar transición
      final current = await _client
          .from('shipment_orders')
          .select('status')
          .eq('id', id)
          .single();

      final currentStatus = current['status']?.toString() ?? '';
      final allowed = _validTransitions[currentStatus] ?? [];
      if (!allowed.contains(status)) {
        throw Exception(
          'Transición inválida: $currentStatus → $status. '
          'Permitidas: ${allowed.join(", ")}',
        );
      }

      final data = <String, dynamic>{'status': status};
      if (status == 'entregada') {
        data['delivered_at'] = ColombiaTime.nowIso8601();
        if (receivedBy != null) data['received_by'] = receivedBy;
      }

      await _client.from('shipment_orders').update(data).eq('id', id);

      // Descontar stock al despachar
      if (status == 'despachada') {
        await _deductStockForShipment(id);
      }

      // Restaurar stock al anular una remisión despachada
      if (status == 'anulada' &&
          (currentStatus == 'despachada' || currentStatus == 'en_transito')) {
        await _restoreStockForShipment(id);
      }

      // Al confirmar entrega, actualizar delivery_date de la factura asociada
      if (status == 'entregada') {
        await _updateInvoiceDeliveryDate(id);
      }

      await AuditLogDatasource.log(
        action: 'cambiar_estado_remision',
        module: 'remisiones',
        recordId: id,
        description: 'Estado de remisión cambiado a $status',
        details: data,
      );
    } catch (e) {
      AppLogger.error('Error cambiando estado de remisión: $e');
      rethrow;
    }
  }

  /// Descontar stock de materiales al despachar una remisión
  static Future<void> _deductStockForShipment(String shipmentId) async {
    try {
      final itemsResponse = await _client
          .from('shipment_order_items')
          .select('material_id, product_id, quantity')
          .eq('shipment_order_id', shipmentId);

      for (final item in (itemsResponse as List)) {
        final materialId = item['material_id']?.toString();
        final productId = item['product_id']?.toString();
        final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
        if ((materialId == null && productId == null) || qty <= 0) continue;

        await _client.rpc(
          'deduct_inventory_item',
          params: {
            'p_material_id': materialId,
            'p_product_id': productId,
            'p_quantity': qty,
            'p_reference': 'REM-$shipmentId',
            'p_reason': 'Despacho de remisión',
          },
        );
      }

      AppLogger.info('Stock descontado para remisión $shipmentId');
    } catch (e) {
      AppLogger.error('Error descontando stock para remisión $shipmentId: $e');
      rethrow; // Bloquear despacho si falla el stock para evitar inventario fantasma
    }
  }

  /// Restaurar stock al anular una remisión que ya fue despachada
  static Future<void> _restoreStockForShipment(String shipmentId) async {
    try {
      final itemsResponse = await _client
          .from('shipment_order_items')
          .select('material_id, product_id, quantity')
          .eq('shipment_order_id', shipmentId);

      for (final item in (itemsResponse as List)) {
        final materialId = item['material_id']?.toString();
        final productId = item['product_id']?.toString();
        final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
        if ((materialId == null && productId == null) || qty <= 0) continue;

        // Restaurar = deducir cantidad negativa
        await _client.rpc(
          'deduct_inventory_item',
          params: {
            'p_material_id': materialId,
            'p_product_id': productId,
            'p_quantity': -qty,
            'p_reference': 'REM-ANULADA-$shipmentId',
            'p_reason': 'Restauración por anulación de remisión',
          },
        );
      }

      AppLogger.info('Stock restaurado para remisión anulada $shipmentId');
    } catch (e) {
      AppLogger.error(
        'Error restaurando stock para remisión anulada $shipmentId: $e',
      );
    }
  }

  /// Al confirmar entrega de remisión, marcar la factura asociada con delivery_date
  static Future<void> _updateInvoiceDeliveryDate(String shipmentId) async {
    try {
      // Obtener la remisión para saber qué factura tiene asociada
      final shipment = await _client
          .from('shipment_orders')
          .select('invoice_id, delivered_at')
          .eq('id', shipmentId)
          .maybeSingle();

      if (shipment == null) return;

      final invoiceId = shipment['invoice_id']?.toString();
      if (invoiceId == null || invoiceId.isEmpty) return;

      // Usar la fecha de entrega real (delivered_at) o ahora — solo la parte DATE
      final deliveredAtRaw = shipment['delivered_at']?.toString();
      final deliveryDate = deliveredAtRaw != null
          ? DateTime.parse(deliveredAtRaw)
          : ColombiaTime.now();
      final deliveryDateStr = ColombiaTime.dateString(deliveryDate);

      // Obtener credit_days de la factura para recalcular due_date
      final invoiceRow = await _client
          .from('invoices')
          .select('credit_days, sale_payment_type')
          .eq('id', invoiceId)
          .maybeSingle();

      final creditDays = (invoiceRow?['credit_days'] as num?)?.toInt() ?? 0;
      final salePaymentType = invoiceRow?['sale_payment_type']?.toString();

      // Construir update: siempre actualizar delivery_date
      final updateData = <String, dynamic>{
        'delivery_date': deliveryDateStr,
      };

      // Si tiene crédito, recalcular due_date desde la entrega real
      if (creditDays > 0 &&
          (salePaymentType == 'credit' || salePaymentType == 'advance')) {
        final newDueDate = deliveryDate.add(Duration(days: creditDays));
        updateData['due_date'] = ColombiaTime.dateString(newDueDate);
        AppLogger.info(
          'Recalculando vencimiento: entrega $deliveryDateStr + $creditDays días = ${updateData['due_date']}',
        );
      }

      await _client
          .from('invoices')
          .update(updateData)
          .eq('id', invoiceId);

      AppLogger.info(
        'Factura $invoiceId marcada como entregada desde remisión $shipmentId',
      );

      await AuditLogDatasource.log(
        action: 'marcar_factura_entregada',
        module: 'remisiones',
        recordId: invoiceId,
        description:
            'Factura marcada como entregada al confirmar remisión $shipmentId',
      );
    } catch (e) {
      AppLogger.error(
        'Error actualizando delivery_date de factura para remisión $shipmentId: $e',
      );
    }
  }

  /// Obtener entregas futuras (OPs vinculadas a facturas con delivery_date)
  static Future<List<FutureDelivery>> getFutureDeliveries() async {
    try {
      final response = await _client
          .from('production_orders')
          .select('''
            id, code, product_name, status, quantity, due_date,
            invoices!inner(id, series, number, customer_name, delivery_date, total, paid_amount),
            production_stages(id, status)
          ''')
          .inFilter('status', ['planificada', 'en_proceso', 'completada'])
          .not('invoice_id', 'is', null)
          .order('created_at', ascending: false);

      final results = <FutureDelivery>[];
      for (final row in (response as List)) {
        final invoice = row['invoices'] as Map<String, dynamic>?;
        if (invoice == null) continue;

        final stages = (row['production_stages'] as List?) ?? [];
        final completedStages = stages
            .where((s) => s['status'] == 'completada')
            .length;

        results.add(
          FutureDelivery(
            productionOrderId: (row['id'] ?? '').toString(),
            productionOrderCode: (row['code'] ?? '').toString(),
            productName: (row['product_name'] ?? '').toString(),
            productionStatus: (row['status'] ?? '').toString(),
            quantity: (row['quantity'] as num?)?.toDouble() ?? 0,
            productionDueDate: row['due_date'] != null
                ? DateTime.parse(row['due_date'].toString())
                : null,
            invoiceId: (invoice['id'] ?? '').toString(),
            invoiceNumber:
                '${invoice['series'] ?? ''}-${invoice['number'] ?? ''}',
            customerName: (invoice['customer_name'] ?? '').toString(),
            deliveryDate: invoice['delivery_date'] != null
                ? DateTime.parse(invoice['delivery_date'].toString())
                : null,
            invoiceTotal: (invoice['total'] as num?)?.toDouble() ?? 0,
            invoicePaid: (invoice['paid_amount'] as num?)?.toDouble() ?? 0,
            completedStages: completedStages,
            totalStages: stages.length,
          ),
        );
      }

      // Ordenar por fecha de entrega
      results.sort((a, b) {
        if (a.deliveryDate == null && b.deliveryDate == null) return 0;
        if (a.deliveryDate == null) return 1;
        if (b.deliveryDate == null) return -1;
        return a.deliveryDate!.compareTo(b.deliveryDate!);
      });

      return results;
    } catch (e) {
      AppLogger.error('Error cargando entregas futuras: $e');
      rethrow;
    }
  }

  /// Obtener contadores para summary cards
  static Future<Map<String, int>> getSummaryCounts() async {
    try {
      final response = await _client
          .from('shipment_orders')
          .select('id, status');

      final all = response as List;
      return {
        'total': all.length,
        'borrador': all.where((r) => r['status'] == 'borrador').length,
        'despachada': all.where((r) => r['status'] == 'despachada').length,
        'en_transito': all.where((r) => r['status'] == 'en_transito').length,
        'entregada': all.where((r) => r['status'] == 'entregada').length,
      };
    } catch (e) {
      AppLogger.error('Error obteniendo contadores: $e');
      return {
        'total': 0,
        'borrador': 0,
        'despachada': 0,
        'en_transito': 0,
        'entregada': 0,
      };
    }
  }

  /// Obtener materiales de una OP para pre-cargar ítems en una remisión
  static Future<List<ShipmentOrderItem>> getItemsFromProductionOrder(
    String productionOrderId,
  ) async {
    try {
      // Producto principal de la OP
      final opResponse = await _client
          .from('production_orders')
          .select('product_name, quantity')
          .eq('id', productionOrderId)
          .single();

      final items = <ShipmentOrderItem>[
        ShipmentOrderItem(
          id: '',
          shipmentOrderId: '',
          itemType: ShipmentItemType.producto,
          description: (opResponse['product_name'] ?? 'Producto').toString(),
          quantity: (opResponse['quantity'] as num?)?.toDouble() ?? 1,
          unit: 'UND',
          sequenceOrder: 0,
        ),
      ];

      // Materiales del BOM
      final materialsResponse = await _client
          .from('production_order_materials')
          .select(
            'material_name, required_quantity, unit, piece_title, dimensions',
          )
          .eq('production_order_id', productionOrderId);

      for (final (i, row) in (materialsResponse as List).indexed) {
        final pieceTitle = row['piece_title']?.toString();
        final dims = row['dimensions']?.toString();
        final desc = pieceTitle != null && pieceTitle.isNotEmpty
            ? '$pieceTitle - ${row['material_name']}'
            : (row['material_name'] ?? 'Material').toString();
        items.add(
          ShipmentOrderItem(
            id: '',
            shipmentOrderId: '',
            itemType: pieceTitle != null
                ? ShipmentItemType.pieza
                : ShipmentItemType.material,
            description: desc,
            quantity: (row['required_quantity'] as num?)?.toDouble() ?? 1,
            unit: (row['unit'] ?? 'UND').toString(),
            dimensions: dims,
            sequenceOrder: i + 1,
          ),
        );
      }

      return items;
    } catch (e) {
      AppLogger.error('Error cargando ítems desde OP: $e');
      return [];
    }
  }
}
