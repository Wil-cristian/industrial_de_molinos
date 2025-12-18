import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/customer.dart';
import 'supabase_datasource.dart';
import 'products_datasource.dart';

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
    double taxRate = 18.0,
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
    double taxRate = 18.0,
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

    // Insertar items
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      await _client.from('invoice_items').insert({
        'invoice_id': invoice.id,
        'product_id': item.productId,
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
    }

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
    
    // Si se cancela un recibo que estaba emitido/parcial/pagado, restaurar stock
    if (status == 'cancelled' && currentInvoice != null) {
      final currentStatus = currentInvoice.status;
      if (currentStatus == InvoiceStatus.issued || 
          currentStatus == InvoiceStatus.partial ||
          currentStatus == InvoiceStatus.paid) {
        await _updateStockForInvoice(id, decrease: false); // Restaurar stock
      }
    }
    
    await _client
        .from('invoices')
        .update({'status': status})
        .eq('id', id);
  }

  /// Actualiza el stock de productos para un recibo
  static Future<void> _updateStockForInvoice(String invoiceId, {required bool decrease}) async {
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
    String? reference,
    String? notes,
    String paymentType = 'complete', // complete, partial, installments
    int? installmentNumber,
    int? totalInstallments,
  }) async {
    try {
      // Usar la función RPC para registrar pago
      await _client.rpc('register_payment', params: {
        'p_invoice_id': invoiceId,
        'p_amount': amount,
        'p_method': method,
        'p_reference': reference,
        'p_notes': notes,
      });
    } catch (e) {
      // Fallback al método anterior si la función RPC no existe
      print('⚠️ Usando método alternativo para registrar pago: $e');
      
      // Insertar pago
      await _client.from('payments').insert({
        'invoice_id': invoiceId,
        'amount': amount,
        'method': method,
        'reference': reference,
        'notes': notes,
        'payment_date': DateTime.now().toIso8601String().split('T')[0],
        'payment_type': paymentType,
        'installment_number': installmentNumber,
        'total_installments': totalInstallments,
      });

      // Obtener recibo actual
      final invoice = await getById(invoiceId);
      if (invoice == null) return;

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
      }).eq('id', invoiceId);
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
