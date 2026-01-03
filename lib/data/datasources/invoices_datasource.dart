import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/cash_movement.dart';
import 'supabase_datasource.dart';
import 'products_datasource.dart';
import 'accounts_datasource.dart';
import 'customers_datasource.dart';

class InvoicesDataSource {
  static SupabaseClient get _client => SupabaseDataSource.client;

  // ==================== READ ====================
  
  /// Obtiene todos los recibos de caja menor
  static Future<List<Invoice>> getAll() async {
    final response = await _client
        .from('invoices')
        .select()
        .order('issue_date', ascending: false);
    
    return (response as List)
        .map((json) => Invoice.fromJson(json))
        .toList();
  }

  /// Obtiene recibos con filtro de estado
  static Future<List<Invoice>> getByStatus(String status) async {
    final response = await _client
        .from('invoices')
        .select()
        .eq('status', status)
        .order('issue_date', ascending: false);
    
    return (response as List)
        .map((json) => Invoice.fromJson(json))
        .toList();
  }

  /// Obtiene un recibo por ID
  static Future<Invoice?> getById(String id) async {
    final response = await _client
        .from('invoices')
        .select()
        .eq('id', id)
        .maybeSingle();
    
    if (response == null) return null;
    return Invoice.fromJson(response);
  }

  /// Obtiene recibos de un cliente
  static Future<List<Invoice>> getByCustomerId(String customerId) async {
    final response = await _client
        .from('invoices')
        .select()
        .eq('customer_id', customerId)
        .order('issue_date', ascending: false);
    
    return (response as List)
        .map((json) => Invoice.fromJson(json))
        .toList();
  }

  /// Obtiene recibos vencidos
  static Future<List<Invoice>> getOverdue() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final response = await _client
        .from('invoices')
        .select()
        .lt('due_date', today)
        .not('status', 'in', '(paid,cancelled)')
        .order('due_date', ascending: true);
    
    return (response as List)
        .map((json) => Invoice.fromJson(json))
        .toList();
  }

  /// Obtiene recibos pendientes de pago
  static Future<List<Invoice>> getPending() async {
    final response = await _client
        .from('invoices')
        .select()
        .not('status', 'in', '(paid,cancelled)')
        .order('issue_date', ascending: false);
    
    return (response as List)
        .map((json) => Invoice.fromJson(json))
        .toList();
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

  /// Genera el siguiente número de recibo para una serie
  static Future<String> generateNumber(String series) async {
    final response = await _client.rpc(
      'generate_invoice_number',
      params: {'p_series': series},
    );
    return response as String;
  }

  // ==================== CREATE ====================
  
  /// Crea un nuevo recibo
  static Future<Invoice> create({
    required String type,
    required String series,
    required Customer customer,
    required DateTime issueDate,
    DateTime? dueDate,
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
    };

    final response = await _client
        .from('invoices')
        .insert(data)
        .select()
        .single();
    
    return Invoice.fromJson(response);
  }

  /// Crea un recibo con sus items
  static Future<Invoice> createWithItems({
    required String type,
    required String series,
    required Customer customer,
    required DateTime issueDate,
    DateTime? dueDate,
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
      subtotal: subtotal,
      taxRate: taxRate,
      discount: discount,
      quotationId: quotationId,
      notes: notes,
    );

    print('💾 Creada factura: ${invoice.number}');

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
      print('  ✅ Item insertado: ${item.productName} x${item.quantity}');
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
    
    await _client
        .from('invoices')
        .update({'status': status})
        .eq('id', id);
    
    // Recalcular balance del cliente después de cualquier cambio de estado
    if (currentInvoice?.customerId != null && currentInvoice!.customerId!.isNotEmpty) {
      try {
        final newBalance = await CustomersDataSource.recalculateBalance(currentInvoice.customerId!);
        print('✅ Balance del cliente recalculado después de cambio de estado: $newBalance');
      } catch (e) {
        print('⚠️ No se pudo recalcular balance del cliente: $e');
      }
    }
  }

  /// Revierte los pagos de una factura anulada
  static Future<void> _revertPayments(String invoiceId, Invoice invoice) async {
    try {
      // Buscar los movimientos de caja asociados a esta factura
      final movements = await _client
          .from('cash_movements')
          .select()
          .eq('reference', '${invoice.series}-${invoice.number}');
      
      for (var movement in movements) {
        final accountId = movement['account_id'] as String?;
        final amount = (movement['amount'] as num).toDouble();
        final type = movement['type'] as String?;
        
        if (accountId != null && type == 'income') {
          // Crear movimiento de reversión (egreso)
          final reverseMovement = CashMovement(
            id: '',
            accountId: accountId,
            type: MovementType.expense,
            category: MovementCategory.otherExpense,
            amount: amount,
            description: 'Reversión por anulación - ${invoice.series}-${invoice.number}',
            reference: 'ANULACION-${invoice.series}-${invoice.number}',
            personName: invoice.customerName,
            date: DateTime.now(),
          );
          
          await AccountsDataSource.createMovementWithBalanceUpdate(reverseMovement);
          print('✅ Pago revertido: $amount de cuenta $accountId');
        }
      }
      
      // También resetear el monto pagado en la factura
      await _client.from('invoices').update({
        'paid_amount': 0,
      }).eq('id', invoiceId);
      
      print('✅ Pagos revertidos para factura $invoiceId');
    } catch (e) {
      print('⚠️ Error al revertir pagos: $e');
    }
  }

  /// Actualiza el stock de productos para un recibo
  static Future<void> _updateStockForInvoice(String invoiceId, {required bool decrease}) async {
    if (decrease) {
      try {
        // Usar la nueva función unificada de descuento
        await _client.rpc('deduct_inventory_for_invoice', params: {
          'p_invoice_id': invoiceId,
        });
      } catch (e) {
        print('⚠️ Error al descontar inventario vía RPC: $e');
        // Fallback al método manual si falla
        await _fallbackUpdateStock(invoiceId, decrease: true);
      }
    } else {
      // Para restaurar stock (cancelación), por ahora usamos el método manual
      await _fallbackUpdateStock(invoiceId, decrease: false);
    }
  }

  static Future<void> _fallbackUpdateStock(String invoiceId, {required bool decrease}) async {
    // Obtener los items del recibo
    final items = await getItems(invoiceId);
    
    for (var item in items) {
      if (item.productId != null && item.productId!.isNotEmpty) {
        // Obtener producto actual
        final productResponse = await _client
            .from('products')
            .select('stock')
            .eq('id', item.productId!)
            .maybeSingle();
        
        if (productResponse != null) {
          final currentStock = (productResponse['stock'] as num).toDouble();
          final newStock = decrease 
              ? currentStock - item.quantity 
              : currentStock + item.quantity;
          
          // Actualizar stock (no permitir negativos)
          await ProductsDataSource.updateStock(
            item.productId!, 
            newStock < 0 ? 0 : newStock,
          );
        }
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
    try {
      // Obtener recibo para info del cliente
      final invoice = await getById(invoiceId);
      if (invoice == null) throw Exception('Recibo no encontrado');

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
      await _client.from('invoices').update({
        'paid_amount': newPaidAmount,
        'status': newStatus,
        'payment_method': method,
      }).eq('id', invoiceId);

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
        print('✅ Movimiento de caja creado para cuenta $accountId');
      }
      
      // Actualizar balance del cliente (recalcular desde facturas pendientes)
      if (invoice.customerId != null && invoice.customerId!.isNotEmpty) {
        try {
          final newBalance = await CustomersDataSource.recalculateBalance(invoice.customerId!);
          print('✅ Balance del cliente recalculado: $newBalance');
        } catch (e) {
          print('⚠️ No se pudo actualizar balance del cliente: $e');
        }
      }
      
      print('✅ Pago registrado: $amount en recibo ${invoice.number}');
    } catch (e) {
      print('❌ Error registrando pago: $e');
      rethrow;
    }
  }

  /// Obtener historial de pagos de una factura
  static Future<List<Map<String, dynamic>>> getPayments(String invoiceId) async {
    final response = await _client
        .from('payments')
        .select()
        .eq('invoice_id', invoiceId)
        .order('payment_date', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Obtener resumen de ventas
  static Future<Map<String, dynamic>> getSalesSummary({DateTime? startDate, DateTime? endDate}) async {
    try {
      final response = await _client.rpc('get_sales_summary', params: {
        'p_start_date': startDate?.toIso8601String().split('T')[0],
        'p_end_date': endDate?.toIso8601String().split('T')[0],
      });
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
      print('⚠️ Error obteniendo resumen: $e');
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
    return true;
  }

  /// Cancela un recibo
  static Future<void> cancel(String id) async {
    await updateStatus(id, 'cancelled');
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

  /// Obtiene los últimos N recibos
  static Future<List<Invoice>> getRecent({int limit = 5}) async {
    final response = await _client
        .from('invoices')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    
    return (response as List)
        .map((json) => Invoice.fromJson(json))
        .toList();
  }
}
