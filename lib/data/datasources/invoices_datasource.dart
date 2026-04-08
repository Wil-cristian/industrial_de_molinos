import '../../core/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/cash_movement.dart';
import 'supabase_datasource.dart';
import 'accounts_datasource.dart';
import 'customers_datasource.dart';
import 'audit_log_datasource.dart';

class InvoicesDataSource {
  static SupabaseClient get _client => SupabaseDataSource.client;

  // ==================== READ ====================

  /// Obtiene todas las facturas de venta (excluye compras CMP)
  static Future<List<Invoice>> getAll() async {
    final response = await _client
        .from('invoices')
        .select('*, invoice_items(*)')
        .neq('series', 'CMP')
        .order('number', ascending: false);

    return (response as List).map((json) => Invoice.fromJson(json)).toList();
  }

  /// Obtiene facturas de venta con filtro de estado (excluye compras CMP)
  static Future<List<Invoice>> getByStatus(String status) async {
    final response = await _client
        .from('invoices')
        .select('*, invoice_items(*)')
        .neq('series', 'CMP')
        .eq('status', status)
        .order('number', ascending: false);

    return (response as List).map((json) => Invoice.fromJson(json)).toList();
  }

  /// Obtiene un recibo por ID
  static Future<Invoice?> getById(String id) async {
    final response = await _client
        .from('invoices')
        .select('*, invoice_items(*)')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Invoice.fromJson(response);
  }

  /// Obtiene recibos de un cliente
  static Future<List<Invoice>> getByCustomerId(String customerId) async {
    final response = await _client
        .from('invoices')
        .select('*, invoice_items(*)')
        .eq('customer_id', customerId)
        .order('number', ascending: false);

    return (response as List).map((json) => Invoice.fromJson(json)).toList();
  }

  /// Obtiene facturas de venta vencidas (excluye compras CMP)
  static Future<List<Invoice>> getOverdue() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final response = await _client
        .from('invoices')
        .select('*, invoice_items(*)')
        .neq('series', 'CMP')
        .lt('due_date', today)
        .not('status', 'in', '(paid,cancelled)')
        .order('due_date', ascending: true);

    return (response as List).map((json) => Invoice.fromJson(json)).toList();
  }

  /// Obtiene facturas de venta pendientes de pago (excluye compras CMP)
  static Future<List<Invoice>> getPending() async {
    final response = await _client
        .from('invoices')
        .select('*, invoice_items(*)')
        .neq('series', 'CMP')
        .not('status', 'in', '(paid,cancelled)')
        .order('number', ascending: false);

    return (response as List).map((json) => Invoice.fromJson(json)).toList();
  }

  /// Obtiene items de un recibo
  static Future<List<InvoiceItem>> getItems(String invoiceId) async {
    final response = await _client
        .from('invoice_items')
        .select()
        .eq('invoice_id', invoiceId)
        .order('sort_order', ascending: true);

    return (response as List)
        .map((json) => InvoiceItem.fromJson(json))
        .toList();
  }

  // ==================== ITEM-LEVEL CRUD ====================

  /// Actualiza un ítem de factura y recalcula totales
  static Future<void> updateItem(InvoiceItem item) async {
    await _client
        .from('invoice_items')
        .update({
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'discount': item.discount,
          'tax_rate': item.taxRate,
          'subtotal': item.subtotal,
          'tax_amount': item.taxAmount,
          'total': item.total,
        })
        .eq('id', item.id)
        .select()
        .single();
    await _recalculateInvoiceTotals(item.invoiceId);
    await AuditLogDatasource.log(
      action: 'update',
      module: 'invoices',
      recordId: item.invoiceId,
      description: 'Modificó ítem: ${item.productName}',
      details: {
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'total': item.total,
      },
    );
  }

  /// Elimina un ítem de factura y recalcula totales
  static Future<void> deleteItem(String itemId, String invoiceId) async {
    await _client.from('invoice_items').delete().eq('id', itemId);
    await _recalculateInvoiceTotals(invoiceId);
    await AuditLogDatasource.log(
      action: 'delete',
      module: 'invoices',
      recordId: invoiceId,
      description: 'Eliminó ítem de factura',
      details: {'item_id': itemId},
    );
  }

  /// Divide un ítem en dos: el original queda con [keepQty] y se crea uno nuevo con el resto
  static Future<void> splitItem(
    String itemId,
    String invoiceId,
    double keepQty,
  ) async {
    final response = await _client
        .from('invoice_items')
        .select()
        .eq('id', itemId)
        .single();
    final original = InvoiceItem.fromJson(response);

    final remainQty = original.quantity - keepQty;
    if (remainQty <= 0 || keepQty <= 0) return;

    // Actualizar el original con la cantidad reducida
    final origSubtotal = keepQty * original.unitPrice;
    final origTax = origSubtotal * original.taxRate;
    await _client
        .from('invoice_items')
        .update({
          'quantity': keepQty,
          'subtotal': origSubtotal,
          'tax_amount': origTax,
          'total': origSubtotal + origTax - original.discount,
        })
        .eq('id', itemId);

    // Crear el nuevo ítem con el resto
    final newSubtotal = remainQty * original.unitPrice;
    final newTax = newSubtotal * original.taxRate;
    await _client.from('invoice_items').insert({
      'invoice_id': invoiceId,
      'product_id': original.productId,
      'material_id': original.materialId,
      'product_code': original.productCode,
      'product_name': original.productName,
      'description': original.description,
      'quantity': remainQty,
      'unit': original.unit,
      'unit_price': original.unitPrice,
      'discount': 0,
      'tax_rate': original.taxRate,
      'subtotal': newSubtotal,
      'tax_amount': newTax,
      'total': newSubtotal + newTax,
      'sort_order': 999,
    });

    await _recalculateInvoiceTotals(invoiceId);
  }

  /// Recalcula subtotal, tax_amount y total de la factura a partir de sus ítems
  static Future<void> _recalculateInvoiceTotals(String invoiceId) async {
    final items = await getItems(invoiceId);
    double subtotal = 0;
    double taxAmount = 0;
    for (final item in items) {
      subtotal += item.subtotal;
      taxAmount += item.taxAmount;
    }

    final currentInvoice = await _client
        .from('invoices')
        .select('discount')
        .eq('id', invoiceId)
        .single();
    final discount = (currentInvoice['discount'] as num?)?.toDouble() ?? 0;
    final total = subtotal + taxAmount - discount;

    await _client
        .from('invoices')
        .update({'subtotal': subtotal, 'tax_amount': taxAmount, 'total': total})
        .eq('id', invoiceId);
  }

  /// Genera el siguiente número de recibo para una serie
  static Future<String> generateNumber(String series) async {
    final response = await _client.rpc(
      'generate_invoice_number',
      params: {'p_series': series},
    );
    return response as String;
  }

  // ==================== DUPLICATE DETECTION ====================

  /// Verifica si ya existe una factura duplicada.
  /// Busca por: mismo cliente + mismo total + misma fecha (±1 día) + no cancelada.
  /// Opcionalmente busca por número de factura original en las notas.
  /// Retorna la factura duplicada si existe, null si no hay duplicado.
  static Future<Invoice?> findDuplicate({
    required String customerId,
    required double total,
    required DateTime issueDate,
    String? originalInvoiceNumber,
  }) async {
    // Tolerancia de ±1 día para la fecha
    final dateFrom = issueDate.subtract(const Duration(days: 1));
    final dateTo = issueDate.add(const Duration(days: 1));

    final response = await _client
        .from('invoices')
        .select('*, invoice_items(*)')
        .eq('customer_id', customerId)
        .neq('status', 'cancelled')
        .gte('issue_date', dateFrom.toIso8601String().split('T')[0])
        .lte('issue_date', dateTo.toIso8601String().split('T')[0])
        .order('created_at', ascending: false);

    final invoices = (response as List)
        .map((json) => Invoice.fromJson(json))
        .toList();

    // Buscar por total idéntico (con tolerancia de ±0.01)
    for (final inv in invoices) {
      if ((inv.total - total).abs() < 0.02) {
        return inv;
      }
    }

    // Si se pasó un número de factura original, buscar en notas
    if (originalInvoiceNumber != null && originalInvoiceNumber.isNotEmpty) {
      final notesResponse = await _client
          .from('invoices')
          .select('*, invoice_items(*)')
          .neq('status', 'cancelled')
          .ilike('notes', '%$originalInvoiceNumber%')
          .limit(1);

      final noteMatches = (notesResponse as List)
          .map((j) => Invoice.fromJson(j))
          .toList();
      if (noteMatches.isNotEmpty) return noteMatches.first;
    }

    return null;
  }

  // ==================== CREATE ====================

  /// Crea un nuevo recibo
  static Future<Invoice> create({
    required String type,
    required String series,
    required Customer customer,
    required DateTime issueDate,
    DateTime? dueDate,
    DateTime? deliveryDate,
    String salePaymentType = 'cash',
    required double subtotal,
    double taxRate = 0.0,
    double discount = 0.0,
    String? quotationId,
    String? notes,
  }) async {
    // Generar número
    final number = await generateNumber(series);

    // Calcular montos
    final taxAmount = (subtotal - discount) * (taxRate / 100);
    final total = subtotal - discount + taxAmount;

    final data = {
      'type': type,
      'series': series,
      'number': number,
      'customer_id': customer.id,
      'customer_name': customer.name,
      'customer_document': customer.documentNumber,
      'customer_address': customer.address,
      'issue_date': issueDate.toIso8601String().split('T')[0],
      'due_date': dueDate?.toIso8601String().split('T')[0],
      'subtotal': subtotal,
      'tax_rate': taxRate,
      'tax_amount': taxAmount,
      'discount': discount,
      'total': total,
      'paid_amount': 0.0,
      'status': 'draft',
      'quotation_id': quotationId,
      'notes': notes,
      'delivery_date': deliveryDate?.toIso8601String().split('T')[0],
      'sale_payment_type': salePaymentType,
    };

    final response = await _client
        .from('invoices')
        .insert(data)
        .select()
        .single();

    final invoice = Invoice.fromJson(response);
    await AuditLogDatasource.log(
      action: 'create',
      module: 'invoices',
      recordId: invoice.id,
      description:
          'Creó factura ${invoice.series}-${invoice.number} para ${customer.name} por \$${subtotal.toStringAsFixed(0)}',
      details: {
        'series': series,
        'number': invoice.number,
        'customer': customer.name,
        'total': subtotal,
      },
    );

    return invoice;
  }

  /// Crea un recibo con sus items
  static Future<Invoice> createWithItems({
    required String type,
    required String series,
    required Customer customer,
    required DateTime issueDate,
    DateTime? dueDate,
    DateTime? deliveryDate,
    String salePaymentType = 'cash',
    required List<InvoiceItem> items,
    double taxRate = 0.0,
    double discount = 0.0,
    String? quotationId,
    String? notes,
  }) async {
    // Calcular subtotal de items
    double subtotal = 0;
    for (var item in items) {
      subtotal += item.subtotal;
    }

    // Crear recibo de caja menor
    final invoice = await create(
      type: type,
      series: series,
      customer: customer,
      issueDate: issueDate,
      dueDate: dueDate,
      deliveryDate: deliveryDate,
      salePaymentType: salePaymentType,
      subtotal: subtotal,
      taxRate: taxRate,
      discount: discount,
      quotationId: quotationId,
      notes: notes,
    );

    AppLogger.debug('?? Creada factura: ${invoice.number}');

    AuditLogDatasource.log(
      action: 'create',
      module: 'invoices',
      recordId: invoice.id,
      description:
          'Creó factura ${invoice.series}-${invoice.number} para ${customer.name} por \$${subtotal.toStringAsFixed(0)}',
      details: {
        'series': series,
        'number': invoice.number,
        'customer': customer.name,
        'total': subtotal,
      },
    );

    // Insertar items
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      await _client.from('invoice_items').insert({
        'invoice_id': invoice.id,
        'product_id': item.productId,
        'material_id': item.materialId,
        'product_code': item.productCode,
        'product_name': item.productName,
        'description': item.description,
        'quantity': item.quantity,
        'unit': item.unit,
        'unit_price': item.unitPrice,
        'discount': item.discount,
        'tax_rate': item.taxRate,
        'subtotal': item.subtotal,
        'tax_amount': item.taxAmount,
        'total': item.total,
        'sort_order': i,
      });
      AppLogger.success(
        '? Item insertado: ${item.productName} x${item.quantity}',
      );
      await AuditLogDatasource.log(
        action: 'create',
        module: 'invoices',
        recordId: invoice.id,
        description:
            'Agregó ítem a factura: ${item.productName} x${item.quantity}',
        details: {
          'product': item.productName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'total': item.total,
        },
      );
    }

    // NOTA: El descuento de inventario se hace en updateStatus() cuando
    // el estado cambia a 'issued', NO aquí al crear el borrador.
    // Esto evita el descuento doble.

    return invoice;
  }

  // ==================== UPDATE ====================

  /// Actualiza un recibo
  static Future<Invoice> update(Invoice invoice) async {
    final response = await _client
        .from('invoices')
        .update(invoice.toJson())
        .eq('id', invoice.id)
        .select()
        .single();

    return Invoice.fromJson(response);
  }

  /// Cambia el estado SIN efectos colaterales (sin stock, sin recalcular).
  /// Usar solo para facturas históricas escaneadas.
  static Future<void> setStatusDirect(String id, String status) async {
    await _client.from('invoices').update({'status': status}).eq('id', id);
  }

  /// Actualiza el estado de un recibo
  static Future<void> updateStatus(String id, String status) async {
    // Obtener estado actual para manejar stock
    final currentInvoice = await getById(id);

    // Si se está emitiendo el recibo, descontar stock
    if (status == 'issued') {
      await _updateStockForInvoice(id, decrease: true);
    }

    // Si se cancela un recibo que estaba emitido/parcial/pagado, restaurar stock y revertir pagos
    if (status == 'cancelled' && currentInvoice != null) {
      final currentStatus = currentInvoice.status;
      if (currentStatus == InvoiceStatus.issued ||
          currentStatus == InvoiceStatus.partial ||
          currentStatus == InvoiceStatus.paid) {
        await _updateStockForInvoice(id, decrease: false); // Restaurar stock
      }

      // Revertir pagos si había alguno
      if (currentInvoice.paidAmount > 0) {
        await _revertPayments(id, currentInvoice);
      }
    }

    await _client.from('invoices').update({'status': status}).eq('id', id);

    await AuditLogDatasource.log(
      action: status == 'cancelled' ? 'cancel' : 'update',
      module: 'invoices',
      recordId: id,
      description:
          'Cambió estado de factura ${currentInvoice?.series ?? ""}-${currentInvoice?.number ?? ""} a $status',
      details: {
        'new_status': status,
        'previous_status': currentInvoice?.status.name,
      },
    );

    // Recalcular balance del cliente después de cualquier cambio de estado
    if (currentInvoice?.customerId != null &&
        currentInvoice!.customerId!.isNotEmpty) {
      try {
        final newBalance = await CustomersDataSource.recalculateBalance(
          currentInvoice.customerId!,
        );
        AppLogger.success(
          '? Balance del cliente recalculado después de cambio de estado: $newBalance',
        );
      } catch (e) {
        AppLogger.warning('?? No se pudo recalcular balance del cliente: $e');
      }
    }
  }

  /// Revierte los pagos de una factura anulada (usa RPC atómica)
  static Future<void> _revertPayments(String invoiceId, Invoice invoice) async {
    // Verificar que no haya reversiones previas
    final existingReversals = await _client
        .from('cash_movements')
        .select('id')
        .eq('reference', 'ANULACION-${invoice.series}-${invoice.number}');
    if ((existingReversals as List).isNotEmpty) {
      throw Exception(
        'Los pagos de esta factura ya fueron revertidos anteriormente',
      );
    }

    try {
      // Intentar usar la RPC atómica
      await _client.rpc(
        'atomic_revert_invoice_payments',
        params: {'p_invoice_id': invoiceId},
      );
      AppLogger.success(
        '? Pagos revertidos atómicamente para factura $invoiceId',
      );
    } catch (e) {
      // Fallback: si la RPC no existe, usar el método clásico
      if (e.toString().contains('function') &&
          e.toString().contains('not exist')) {
        await _revertPaymentsLegacy(invoiceId, invoice);
      } else {
        AppLogger.error('? Error al revertir pagos: $e');
        rethrow;
      }
    }
  }

  /// Fallback legacy para revertir pagos (read-then-write)
  static Future<void> _revertPaymentsLegacy(
    String invoiceId,
    Invoice invoice,
  ) async {
    try {
      final movements = await _client
          .from('cash_movements')
          .select()
          .eq('reference', '${invoice.series}-${invoice.number}');

      for (var movement in movements) {
        final accountId = movement['account_id'] as String?;
        final amount = (movement['amount'] as num).toDouble();
        final type = movement['type'] as String?;

        if (accountId != null && type == 'income') {
          final reverseMovement = CashMovement(
            id: '',
            accountId: accountId,
            type: MovementType.expense,
            category: MovementCategory.gastos_reducibles,
            amount: amount,
            description:
                'Reversión por anulación - ${invoice.series}-${invoice.number}',
            reference: 'ANULACION-${invoice.series}-${invoice.number}',
            personName: invoice.customerName,
            date: DateTime.now(),
          );

          await AccountsDataSource.createMovementWithBalanceUpdate(
            reverseMovement,
          );
          AppLogger.success('? Pago revertido: $amount de cuenta $accountId');
        }
      }

      await _client
          .from('invoices')
          .update({'paid_amount': 0})
          .eq('id', invoiceId);

      AppLogger.success('? Pagos revertidos (legacy) para factura $invoiceId');
    } catch (e) {
      AppLogger.error('? Error al revertir pagos: $e');
      rethrow;
    }
  }

  /// Actualiza el stock de productos para un recibo
  static Future<void> _updateStockForInvoice(
    String invoiceId, {
    required bool decrease,
  }) async {
    if (decrease) {
      try {
        // Usar la función unificada de descuento (server-side, atómica)
        await _client.rpc(
          'deduct_inventory_for_invoice',
          params: {'p_invoice_id': invoiceId},
        );
        AppLogger.success('? Stock descontado vía RPC para factura $invoiceId');
      } catch (e) {
        AppLogger.error('? Error al descontar inventario vía RPC: $e');
        rethrow; // No usar fallback manual — la RPC es la fuente de verdad
      }
    } else {
      // Restaurar stock (cancelación)
      try {
        await _client.rpc(
          'revert_invoice_material_deduction',
          params: {'p_invoice_id': invoiceId},
        );
        AppLogger.success('? Stock restaurado vía RPC para factura $invoiceId');
      } catch (e) {
        AppLogger.error('? Error al restaurar stock vía RPC: $e');
        rethrow;
      }
    }
  }

  /// Registra un pago y actualiza el recibo
  static Future<void> registerPayment({
    required String invoiceId,
    required double amount,
    required String method,
    String? accountId,
    String? reference,
    String? notes,
    String paymentType = 'complete', // complete, partial, installments
    int? installmentNumber,
    int? totalInstallments,
  }) async {
    // Validaciones de entrada
    if (amount <= 0) throw Exception('El monto del pago debe ser mayor a 0');

    try {
      // Obtener recibo para info del cliente
      final invoice = await getById(invoiceId);
      if (invoice == null) throw Exception('Recibo no encontrado');

      // Validar estado del recibo
      if (invoice.status.name == 'anulada') {
        throw Exception('No se puede registrar pago en un recibo anulado');
      }
      if (invoice.status.name == 'paid') {
        throw Exception('El recibo ya está completamente pagado');
      }

      // Validar que no exceda el monto pendiente
      final remaining = invoice.total - invoice.paidAmount;
      if (amount > remaining + 0.01) {
        throw Exception(
          'El monto (\$${amount.toStringAsFixed(2)}) excede el saldo pendiente (\$${remaining.toStringAsFixed(2)})',
        );
      }

      // Insertar pago - solo campos básicos que seguro existen
      final paymentData = <String, dynamic>{
        'invoice_id': invoiceId,
        'amount': amount,
        'method': method,
        'payment_date': DateTime.now().toIso8601String().split('T')[0],
      };

      // Agregar campos opcionales si tienen valor
      if (reference != null && reference.isNotEmpty) {
        paymentData['reference'] = reference;
      }
      if (notes != null && notes.isNotEmpty) {
        paymentData['notes'] = notes;
      }

      await _client.from('payments').insert(paymentData);

      // Calcular nuevo monto pagado
      final newPaidAmount = invoice.paidAmount + amount;

      // Determinar nuevo estado
      String newStatus;
      if (newPaidAmount >= invoice.total) {
        newStatus = 'paid';
      } else if (newPaidAmount > 0) {
        newStatus = 'partial';
      } else {
        newStatus = invoice.status.name;
      }

      // Actualizar recibo
      await _client
          .from('invoices')
          .update({
            'paid_amount': newPaidAmount,
            'status': newStatus,
            'payment_method': method,
          })
          .eq('id', invoiceId);

      // Si se especificó una cuenta, crear movimiento de caja
      if (accountId != null && accountId.isNotEmpty) {
        final movement = CashMovement(
          id: '',
          accountId: accountId,
          type: MovementType.income,
          category: MovementCategory.collection,
          amount: amount,
          description: 'Cobro recibo ${invoice.series}-${invoice.number}',
          reference: '${invoice.series}-${invoice.number}',
          personName: invoice.customerName,
          date: DateTime.now(),
        );

        await AccountsDataSource.createMovementWithBalanceUpdate(movement);
        AppLogger.success('? Movimiento de caja creado para cuenta $accountId');
      }

      // Actualizar balance del cliente (recalcular desde facturas pendientes)
      if (invoice.customerId != null && invoice.customerId!.isNotEmpty) {
        try {
          final newBalance = await CustomersDataSource.recalculateBalance(
            invoice.customerId!,
          );
          AppLogger.success('? Balance del cliente recalculado: $newBalance');
        } catch (e) {
          AppLogger.warning('?? No se pudo actualizar balance del cliente: $e');
        }
      }

      AppLogger.success(
        '? Pago registrado: $amount en recibo ${invoice.number}',
      );
    } catch (e) {
      AppLogger.error('? Error registrando pago: $e');
      rethrow;
    }
  }

  /// Obtener historial de pagos de una factura
  static Future<List<Map<String, dynamic>>> getPayments(
    String invoiceId,
  ) async {
    final response = await _client
        .from('payments')
        .select()
        .eq('invoice_id', invoiceId)
        .order('payment_date', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Obtener todos los pagos de un cliente (a través de sus facturas)
  static Future<List<Map<String, dynamic>>> getPaymentsByCustomerId(
    String customerId,
  ) async {
    // Primero obtener las facturas del cliente
    final invoices = await _client
        .from('invoices')
        .select('id, series, number')
        .eq('customer_id', customerId);

    final invoiceList = List<Map<String, dynamic>>.from(invoices);
    if (invoiceList.isEmpty) return [];

    final invoiceIds = invoiceList.map((i) => i['id'] as String).toList();

    // Crear un mapa de invoice_id -> número de factura
    final invoiceMap = <String, String>{};
    for (final inv in invoiceList) {
      invoiceMap[inv['id']] = '${inv['series']}-${inv['number']}';
    }

    // Obtener todos los pagos de esas facturas
    final payments = await _client
        .from('payments')
        .select()
        .inFilter('invoice_id', invoiceIds)
        .order('payment_date', ascending: false);

    // Enriquecer cada pago con el número de factura
    final result = List<Map<String, dynamic>>.from(payments).map((p) {
      return {...p, 'invoice_number': invoiceMap[p['invoice_id']] ?? 'N/A'};
    }).toList();

    return result;
  }

  /// Obtener resumen de ventas
  static Future<Map<String, dynamic>> getSalesSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await _client.rpc(
        'get_sales_summary',
        params: {
          'p_start_date': startDate?.toIso8601String().split('T')[0],
          'p_end_date': endDate?.toIso8601String().split('T')[0],
        },
      );
      if (response != null && response is List && response.isNotEmpty) {
        return Map<String, dynamic>.from(response[0]);
      }
      return {
        'total_sales': 0.0,
        'total_paid': 0.0,
        'total_pending': 0.0,
        'total_count': 0,
        'paid_count': 0,
        'pending_count': 0,
        'overdue_count': 0,
      };
    } catch (e) {
      AppLogger.warning('?? Error obteniendo resumen: $e');
      return await getMonthlyStats();
    }
  }

  // ==================== DELETE ====================

  /// Elimina un recibo (solo si está en borrador)
  static Future<bool> delete(String id) async {
    // Verificar que esté en borrador
    final invoice = await getById(id);
    if (invoice == null || invoice.status != InvoiceStatus.draft) {
      return false;
    }

    await _client.from('invoices').delete().eq('id', id);
    await AuditLogDatasource.log(
      action: 'delete',
      module: 'invoices',
      recordId: id,
      description:
          'Eliminó factura borrador ${invoice.series}-${invoice.number}',
    );
    return true;
  }

  /// Cancela un recibo (LEGACY - usar secureCancelInvoice en su lugar)
  static Future<void> cancel(String id) async {
    await updateStatus(id, 'cancelled');
  }

  // ==================== ANULACIÓN SEGURA (BLINDAJE) ====================

  /// Verifica si una factura puede ser anulada (consulta server-side)
  static Future<Map<String, dynamic>> canCancelInvoice(String invoiceId) async {
    try {
      final response = await _client.rpc(
        'can_cancel_invoice',
        params: {'p_invoice_id': invoiceId},
      );
      return Map<String, dynamic>.from(response ?? {});
    } catch (e) {
      AppLogger.error('? Error verificando si puede anular: $e');
      return {
        'can_cancel': false,
        'reasons': ['Error al verificar: $e'],
      };
    }
  }

  /// Anula una factura de forma segura con todas las validaciones
  /// Retorna un mapa con 'success', 'blocked', 'reason', etc.
  static Future<Map<String, dynamic>> secureCancelInvoice(
    String invoiceId, {
    required String reason,
  }) async {
    try {
      AppLogger.debug('?? Anulación segura de factura: $invoiceId');
      final response = await _client.rpc(
        'secure_cancel_invoice',
        params: {'p_invoice_id': invoiceId, 'p_reason': reason},
      );
      final result = Map<String, dynamic>.from(response ?? {});

      if (result['success'] == true) {
        AppLogger.success(
          '? Factura anulada de forma segura: ${result['invoice_number']}',
        );
      } else if (result['blocked'] == true) {
        AppLogger.warning('?? Anulación BLOQUEADA: ${result['reason']}');
      }

      return result;
    } catch (e) {
      AppLogger.error('? Error en anulación segura: $e');
      rethrow;
    }
  }

  /// Obtiene historial de anulaciones (auditoría)
  static Future<List<Map<String, dynamic>>> getCancellationHistory({
    int limit = 50,
  }) async {
    try {
      final response = await _client.rpc(
        'get_cancellation_history',
        params: {'p_limit': limit},
      );
      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      AppLogger.error('? Error obteniendo historial de anulaciones: $e');
      return [];
    }
  }

  // ==================== STATISTICS ====================

  /// Obtiene estadísticas de ventas del mes actual
  static Future<Map<String, dynamic>> getMonthlyStats() async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final startDate = firstDayOfMonth.toIso8601String().split('T')[0];

    final response = await _client
        .from('invoices')
        .select('total, paid_amount, status')
        .neq('series', 'CMP')
        .gte('issue_date', startDate)
        .neq('status', 'cancelled');

    final List invoices = response as List;

    double totalAmount = 0;
    double paidAmount = 0;
    int totalCount = 0;
    int paidCount = 0;
    int pendingCount = 0;
    int overdueCount = 0;

    for (var inv in invoices) {
      totalAmount += (inv['total'] as num).toDouble();
      paidAmount += (inv['paid_amount'] as num).toDouble();
      totalCount++;

      switch (inv['status']) {
        case 'paid':
          paidCount++;
          break;
        case 'overdue':
          overdueCount++;
          pendingCount++;
          break;
        default:
          if (inv['status'] != 'cancelled') {
            pendingCount++;
          }
      }
    }

    return {
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'pendingAmount': totalAmount - paidAmount,
      'totalCount': totalCount,
      'paidCount': paidCount,
      'pendingCount': pendingCount,
      'overdueCount': overdueCount,
    };
  }

  /// Actualiza los costos de materiales de una factura
  static Future<void> updateMaterialCosts(
    String invoiceId, {
    required double materialCostTotal,
    required double materialCostPending,
  }) async {
    await _client
        .from('invoices')
        .update({
          'material_cost_total': materialCostTotal,
          'material_cost_pending': materialCostPending,
        })
        .eq('id', invoiceId);
  }

  /// Obtiene facturas con adelanto para entregas pendientes
  static Future<List<Invoice>> getPendingDeliveries() async {
    final response = await _client
        .from('invoices')
        .select('*, invoice_items(*)')
        .not('delivery_date', 'is', null)
        .inFilter('status', ['partial', 'issued', 'paid'])
        .order('delivery_date', ascending: true)
        .order('issue_date', ascending: false);

    return (response as List).map((json) => Invoice.fromJson(json)).toList();
  }

  /// Obtiene los últimos N recibos
  static Future<List<Invoice>> getRecent({int limit = 5}) async {
    final response = await _client
        .from('invoices')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List).map((json) => Invoice.fromJson(json)).toList();
  }
}
