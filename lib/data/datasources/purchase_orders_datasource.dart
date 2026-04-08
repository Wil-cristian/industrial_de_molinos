import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/purchase_order.dart';
import 'supabase_datasource.dart';
import 'audit_log_datasource.dart';

class PurchaseOrdersDataSource {
  static const String _table = 'purchase_orders';
  static const String _itemsTable = 'purchase_order_items';

  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Generar número de orden
  static Future<String> generateOrderNumber() async {
    final response = await _client.rpc('generate_order_number');
    return response as String;
  }

  /// Obtener todas las órdenes con proveedor e ítems
  static Future<List<PurchaseOrder>> getAll({String? status}) async {
    var query = _client
        .from(_table)
        .select(
          '*, proveedores(name), purchase_order_items(*, materials(name, code))',
        );

    if (status != null) {
      query = query.eq('status', status);
    }

    final response = await query.order('created_at', ascending: false);
    return response
        .map<PurchaseOrder>((json) => PurchaseOrder.fromJson(json))
        .toList();
  }

  /// Obtener órdenes de un proveedor
  static Future<List<PurchaseOrder>> getBySupplier(String supplierId) async {
    final response = await _client
        .from(_table)
        .select(
          '*, proveedores(name), purchase_order_items(*, materials(name, code))',
        )
        .eq('supplier_id', supplierId)
        .order('created_at', ascending: false);
    return response
        .map<PurchaseOrder>((json) => PurchaseOrder.fromJson(json))
        .toList();
  }

  /// Obtener una orden por ID
  static Future<PurchaseOrder?> getById(String id) async {
    try {
      final response = await _client
          .from(_table)
          .select(
            '*, proveedores(name), purchase_order_items(*, materials(name, code, unit))',
          )
          .eq('id', id)
          .single();
      return PurchaseOrder.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Crear orden de compra
  static Future<PurchaseOrder> create(PurchaseOrder order) async {
    final data = order.toJson();
    data.remove('id');

    final response = await _client
        .from(_table)
        .insert(data)
        .select(
          '*, proveedores(name), purchase_order_items(*, materials(name, code))',
        )
        .single();
    final created = PurchaseOrder.fromJson(response);
    await AuditLogDatasource.log(
      action: 'create',
      module: 'expenses',
      recordId: created.id,
      description:
          'Creó orden de compra por \$${order.total.toStringAsFixed(0)}',
      details: {'total': order.total, 'supplier_id': order.supplierId},
    );
    return created;
  }

  /// Actualizar orden
  static Future<PurchaseOrder> update(PurchaseOrder order) async {
    final data = order.toJson();
    data['updated_at'] = DateTime.now().toIso8601String();

    final response = await _client
        .from(_table)
        .update(data)
        .eq('id', order.id)
        .select(
          '*, proveedores(name), purchase_order_items(*, materials(name, code))',
        )
        .single();
    return PurchaseOrder.fromJson(response);
  }

  /// Cambiar status de orden
  static Future<PurchaseOrder> updateStatus(
    String orderId,
    PurchaseOrderStatus status,
  ) async {
    final response = await _client
        .from(_table)
        .update({
          'status': status.name,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId)
        .select(
          '*, proveedores(name), purchase_order_items(*, materials(name, code))',
        )
        .single();
    final updated = PurchaseOrder.fromJson(response);
    await AuditLogDatasource.log(
      action: 'update',
      module: 'expenses',
      recordId: orderId,
      description: 'Cambió estado de orden a: ${status.name}',
      details: {'status': status.name},
    );
    return updated;
  }

  /// Registrar pago
  static Future<PurchaseOrder> registerPayment(
    String orderId,
    double amount,
    String method,
  ) async {
    // Obtener orden actual
    final current = await getById(orderId);
    if (current == null) throw Exception('Orden no encontrada');

    final newPaid = current.amountPaid + amount;
    final newPaymentStatus = newPaid >= current.total ? 'pagada' : 'parcial';

    final response = await _client
        .from(_table)
        .update({
          'amount_paid': newPaid,
          'payment_status': newPaymentStatus,
          'payment_method': method,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId)
        .select(
          '*, proveedores(name), purchase_order_items(*, materials(name, code))',
        )
        .single();
    final updated = PurchaseOrder.fromJson(response);
    await AuditLogDatasource.log(
      action: 'update',
      module: 'expenses',
      recordId: orderId,
      description:
          'Registró pago de \$${amount.toStringAsFixed(0)} por $method',
      details: {
        'amount': amount,
        'method': method,
        'total_paid': newPaid,
        'payment_status': newPaymentStatus,
      },
    );
    return updated;
  }

  /// Eliminar orden (solo borradores)
  static Future<void> delete(String id) async {
    // Primero eliminar ítems
    await _client.from(_itemsTable).delete().eq('order_id', id);
    // Luego la orden
    await _client.from(_table).delete().eq('id', id);
    AuditLogDatasource.log(
      action: 'delete',
      module: 'expenses',
      recordId: id,
      description: 'Eliminó orden de compra ID: $id',
    );
  }

  // =====================
  // ÍTEMS DE ORDEN
  // =====================

  /// Agregar ítem a orden
  static Future<PurchaseOrderItem> addItem(PurchaseOrderItem item) async {
    final data = item.toJson();
    data.remove('id');
    data.remove('created_at');
    data.remove('updated_at');

    final response = await _client
        .from(_itemsTable)
        .insert(data)
        .select('*, materials(name, code)')
        .single();
    final newItem = PurchaseOrderItem.fromJson(response);
    await AuditLogDatasource.log(
      action: 'create',
      module: 'expenses',
      recordId: item.orderId,
      description:
          'Agregó ítem a orden: ${item.description} (${item.quantity} x \$${item.unitPrice})',
      details: {
        'item_id': newItem.id,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'subtotal': item.quantity * item.unitPrice,
      },
    );
    return newItem;
  }

  /// Actualizar ítem
  static Future<PurchaseOrderItem> updateItem(PurchaseOrderItem item) async {
    final data = {
      'quantity': item.quantity,
      'unit': item.unit,
      'unit_price': item.unitPrice,
      'subtotal': item.quantity * item.unitPrice,
      'quantity_received': item.quantityReceived,
      'notes': item.notes,
      'tax_rate': item.taxRate,
      'tax_amount': item.taxAmount,
      'discount': item.discount,
      'reference_code': item.referenceCode,
      'description': item.description,
      'total': item.itemTotal,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from(_itemsTable)
        .update(data)
        .eq('id', item.id)
        .select('*, materials(name, code)')
        .single();
    final updated = PurchaseOrderItem.fromJson(response);
    await AuditLogDatasource.log(
      action: 'update',
      module: 'expenses',
      recordId: item.orderId,
      description:
          'Modificó ítem: ${item.description} (${item.quantity} x \$${item.unitPrice})',
      details: {
        'item_id': item.id,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'received': item.quantityReceived,
        'total': item.itemTotal,
      },
    );
    return updated;
  }

  /// Eliminar ítem
  static Future<void> deleteItem(String itemId, String orderId) async {
    await _client.from(_itemsTable).delete().eq('id', itemId);
    await AuditLogDatasource.log(
      action: 'delete',
      module: 'expenses',
      recordId: orderId,
      description: 'Eliminó ítem de orden',
      details: {'item_id': itemId},
    );
  }

  /// Obtener ítems de una orden
  static Future<List<PurchaseOrderItem>> getItems(String orderId) async {
    final response = await _client
        .from(_itemsTable)
        .select('*, materials(name, code, unit)')
        .eq('order_id', orderId)
        .order('created_at');
    return response
        .map<PurchaseOrderItem>((json) => PurchaseOrderItem.fromJson(json))
        .toList();
  }

  /// Crear órdenes de compra a partir de materiales faltantes de una cotización
  /// Agrupa por proveedor preferido (supplier_materials.is_preferred)
  /// Retorna lista de órdenes creadas
  ///
  /// Crear registro IVA automáticamente desde una orden de compra aprobada.
  /// Usa la función SQL create_iva_from_purchase_order() de la migración 053.
  static Future<String?> createIvaFromPurchaseOrder(String orderId) async {
    try {
      final response = await _client.rpc(
        'create_iva_from_purchase_order',
        params: {'p_order_id': orderId},
      );
      return response as String?;
    } catch (e) {
      AppLogger.error('❌ Error creando registro IVA desde OC: $e');
      return null;
    }
  }

  static Future<List<PurchaseOrder>> createFromShortage({
    required List<Map<String, dynamic>> missingMaterials,
    required String quotationNumber,
  }) async {
    try {
      // 1. Obtener IDs de materiales faltantes
      final materialIds = missingMaterials
          .where((m) => m['material_id'] != null)
          .map<String>((m) => m['material_id'] as String)
          .toList();

      if (materialIds.isEmpty) {
        throw Exception('No se encontraron IDs de materiales faltantes');
      }

      // 2. Buscar proveedores preferidos para cada material
      final supplierMaterials = await _client
          .from('supplier_materials')
          .select('*, proveedores(id, name)')
          .inFilter('material_id', materialIds);

      // 2b. Obtener cost_price actual de materials como precio de referencia
      // SOLO usar cost_price (precio de compra), NUNCA price_per_kg (precio de venta)
      final materialsData = await _client
          .from('materials')
          .select('id, cost_price')
          .inFilter('id', materialIds);
      final materialCostPrices = <String, double>{};
      for (final mat in materialsData) {
        final id = mat['id'] as String;
        final costPrice = (mat['cost_price'] as num?)?.toDouble() ?? 0;
        materialCostPrices[id] = costPrice;
      }

      // 3. Agrupar materiales por proveedor
      // Estructura: { supplierId: { name, items: [{materialId, qty, unit, price}] } }
      final Map<String, Map<String, dynamic>> bySupplier = {};

      for (final m in missingMaterials) {
        final matId = m['material_id'] as String?;
        if (matId == null) continue;

        final shortage = (m['shortage'] as num?)?.toDouble() ?? 0;
        if (shortage <= 0) continue;

        final unit = m['unit'] ?? 'KG';
        final materialName = m['material_name'] ?? '';

        // Buscar proveedor preferido, o el primero disponible
        Map<String, dynamic>? supplierMatch;
        for (final sm in supplierMaterials) {
          if (sm['material_id'] == matId) {
            if (supplierMatch == null || sm['is_preferred'] == true) {
              supplierMatch = sm;
            }
          }
        }

        if (supplierMatch != null) {
          final supplierId = supplierMatch['supplier_id'] as String;
          final supplierName =
              supplierMatch['proveedores']?['name'] ?? 'Proveedor';
          // Precio: materials.cost_price → supplier_materials.unit_price → 0
          // cost_price es el precio de compra actualizado del inventario
          final costPrice = materialCostPrices[matId] ?? 0;
          final supplierPrice =
              (supplierMatch['unit_price'] as num?)?.toDouble() ?? 0;
          final unitPrice = costPrice > 0
              ? costPrice
              : (supplierPrice > 0 ? supplierPrice : 0);

          bySupplier.putIfAbsent(
            supplierId,
            () => {'name': supplierName, 'items': <Map<String, dynamic>>[]},
          );

          (bySupplier[supplierId]!['items'] as List).add({
            'material_id': matId,
            'material_name': materialName,
            'quantity': shortage,
            'unit': unit,
            'unit_price': unitPrice,
          });
        } else {
          // Sin proveedor asignado → agrupar en "sin_proveedor"
          bySupplier.putIfAbsent(
            'sin_proveedor',
            () => {
              'name': 'Sin proveedor asignado',
              'items': <Map<String, dynamic>>[],
            },
          );

          (bySupplier['sin_proveedor']!['items'] as List).add({
            'material_id': matId,
            'material_name': materialName,
            'quantity': shortage,
            'unit': unit,
            'unit_price': materialCostPrices[matId] ?? 0.0,
          });
        }
      }

      // 4. Crear una orden por cada proveedor
      final List<PurchaseOrder> createdOrders = [];

      for (final entry in bySupplier.entries) {
        final supplierId = entry.key;
        final supplierData = entry.value;
        final items = supplierData['items'] as List<Map<String, dynamic>>;

        if (supplierId == 'sin_proveedor') {
          // Saltar materiales sin proveedor (se reportarán al usuario)
          continue;
        }

        // Generar número de orden
        final orderNumber = await generateOrderNumber();

        // Calcular subtotal
        double subtotal = 0;
        for (final item in items) {
          subtotal +=
              (item['quantity'] as double) * (item['unit_price'] as double);
        }

        // Crear la orden
        final orderData = {
          'order_number': orderNumber,
          'supplier_id': supplierId,
          'status': 'borrador',
          'payment_status': 'pendiente',
          'subtotal': subtotal,
          'total': subtotal,
          'notes':
              'Auto-generada desde cotización $quotationNumber — Materiales faltantes',
        };

        final orderResponse = await _client
            .from(_table)
            .insert(orderData)
            .select('*, proveedores(name)')
            .single();

        final orderId = orderResponse['id'] as String;

        // Crear items de la orden
        for (final item in items) {
          final itemData = {
            'order_id': orderId,
            'material_id': item['material_id'],
            'quantity': item['quantity'],
            'unit': item['unit'],
            'unit_price': item['unit_price'],
            'subtotal':
                (item['quantity'] as double) * (item['unit_price'] as double),
            'quantity_received': 0,
            'notes': 'Faltante para cotización $quotationNumber',
          };
          await _client.from(_itemsTable).insert(itemData);
        }

        // Recargar la orden completa
        final fullOrder = await getById(orderId);
        if (fullOrder != null) {
          createdOrders.add(fullOrder);
        }
      }

      // Reportar materiales sin proveedor
      final sinProveedor = bySupplier['sin_proveedor'];
      if (sinProveedor != null) {
        final items = sinProveedor['items'] as List;
        final names = items.map((i) => i['material_name']).join(', ');
        AppLogger.warning('⚠️ Materiales sin proveedor asignado: $names');
      }

      return createdOrders;
    } catch (e) {
      AppLogger.error('❌ Error creando órdenes de compra: $e');
      rethrow;
    }
  }
}
