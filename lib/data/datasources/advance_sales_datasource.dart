import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/colombia_time.dart';
import '../../domain/entities/advance_sale.dart';
import 'audit_log_datasource.dart';

class AdvanceSalesDataSource {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Obtener todas las ventas anticipadas
  static Future<List<AdvanceSale>> getAll() async {
    final data = await _client
        .from('advance_sales')
        .select('*, advance_sale_payments(*)')
        .order('created_at', ascending: false);
    return (data as List).map((e) => AdvanceSale.fromJson(e)).toList();
  }

  /// Obtener por estado
  static Future<List<AdvanceSale>> getByStatus(String status) async {
    final data = await _client
        .from('advance_sales')
        .select('*, advance_sale_payments(*)')
        .eq('status', status)
        .order('created_at', ascending: false);
    return (data as List).map((e) => AdvanceSale.fromJson(e)).toList();
  }

  /// Obtener una venta anticipada por ID
  static Future<AdvanceSale?> getById(String id) async {
    final data = await _client
        .from('advance_sales')
        .select('*, advance_sale_payments(*)')
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return AdvanceSale.fromJson(data);
  }

  /// Generar número consecutivo
  static Future<String> generateNumber() async {
    final result = await _client.rpc(
      'generate_advance_sale_number',
      params: {'p_series': 'ANT'},
    );
    return result as String;
  }

  /// Crear nueva venta anticipada
  static Future<AdvanceSale> create({
    required String customerName,
    String? customerId,
    required String description,
    required double estimatedTotal,
    String? notes,
  }) async {
    if (customerName.trim().isEmpty) {
      throw Exception('El cliente es obligatorio');
    }
    if (description.trim().isEmpty) {
      throw Exception('La descripción es obligatoria');
    }
    if (estimatedTotal <= 0) {
      throw Exception('El valor estimado debe ser mayor a 0');
    }

    final number = await generateNumber();

    final data = await _client
        .from('advance_sales')
        .insert({
          'series': 'ANT',
          'number': number,
          'customer_id': customerId,
          'customer_name': customerName,
          'description': description,
          'estimated_total': estimatedTotal,
          'notes': notes,
          'created_by': _client.auth.currentUser?.id,
        })
        .select('*, advance_sale_payments(*)')
        .single();

    final sale = AdvanceSale.fromJson(data);

    await AuditLogDatasource.log(
      action: 'create',
      module: 'advance_sales',
      recordId: sale.id,
      description: 'Creó venta anticipada ${sale.fullNumber} - $customerName',
      details: {
        'series': 'ANT',
        'number': number,
        'customer': customerName,
        'estimated_total': estimatedTotal,
        'description': description,
      },
    );

    return sale;
  }

  /// Registrar un abono/pago
  static Future<AdvanceSale> registerPayment({
    required String advanceSaleId,
    required double amount,
    required String method,
    required DateTime paymentDate,
    required String accountId,
    required String accountName,
    String? reference,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw Exception('El abono debe ser mayor a 0');
    }

    // Insertar pago
    await _client.from('advance_sale_payments').insert({
      'advance_sale_id': advanceSaleId,
      'amount': amount,
      'method': method,
      'account_id': accountId,
      'account_name': accountName,
      'payment_date': paymentDate.toIso8601String().substring(0, 10),
      'reference': reference,
      'notes': notes,
      'created_by': _client.auth.currentUser?.id,
    });

    // Actualizar paid_amount
    final sale = await getById(advanceSaleId);
    if (sale == null) throw Exception('Venta anticipada no encontrada');

    final newPaidAmount = sale.paidAmount + amount;

    await _client
        .from('advance_sales')
        .update({
          'paid_amount': newPaidAmount,
          'updated_at': ColombiaTime.nowIso8601(),
        })
        .eq('id', advanceSaleId);

    await AuditLogDatasource.log(
      action: 'update',
      module: 'advance_sales',
      recordId: advanceSaleId,
      description: 'Registró abono de \$${amount.toStringAsFixed(0)} en ${sale.fullNumber}',
      details: {
        'advance_sale_number': sale.fullNumber,
        'customer': sale.customerName,
        'payment_amount': amount,
        'payment_method': method,
        'account_id': accountId,
        'account_name': accountName,
        'previously_paid': sale.paidAmount,
        'new_paid_amount': newPaidAmount,
      },
    );

    return (await getById(advanceSaleId))!;
  }

  /// Actualizar precio estimado
  static Future<AdvanceSale> updateEstimatedTotal(
    String id,
    double newTotal,
  ) async {
    if (newTotal <= 0) {
      throw Exception('El valor estimado debe ser mayor a 0');
    }

    final sale = await getById(id);
    if (sale == null) throw Exception('Venta anticipada no encontrada');

    await _client
        .from('advance_sales')
        .update({
          'estimated_total': newTotal,
          'updated_at': ColombiaTime.nowIso8601(),
        })
        .eq('id', id);

    await AuditLogDatasource.log(
      action: 'update',
      module: 'advance_sales',
      recordId: id,
      description: 'Actualizó precio estimado de ${sale.fullNumber}',
      details: {
        'advance_sale_number': sale.fullNumber,
        'old_estimated': sale.estimatedTotal,
        'new_estimated': newTotal,
      },
    );

    return (await getById(id))!;
  }

  /// Actualizar descripción y notas
  static Future<AdvanceSale> updateDetails(
    String id, {
    String? description,
    String? notes,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': ColombiaTime.nowIso8601(),
    };
    if (description != null) updates['description'] = description;
    if (notes != null) updates['notes'] = notes;

    await _client.from('advance_sales').update(updates).eq('id', id);

    return (await getById(id))!;
  }

  /// Confirmar venta anticipada → fijar precio final y generar factura
  static Future<AdvanceSale> confirm({
    required String id,
    required double finalTotal,
  }) async {
    if (finalTotal <= 0) {
      throw Exception('El valor final debe ser mayor a 0');
    }

    final sale = await getById(id);
    if (sale == null) throw Exception('Venta anticipada no encontrada');
    if (sale.status != AdvanceSaleStatus.pending) {
      throw Exception('Solo se pueden confirmar ventas pendientes');
    }

    await _client
        .from('advance_sales')
        .update({
          'final_total': finalTotal,
          'status': 'confirmed',
          'confirmed_at': ColombiaTime.nowIso8601(),
          'updated_at': ColombiaTime.nowIso8601(),
        })
        .eq('id', id);

    await AuditLogDatasource.log(
      action: 'update',
      module: 'advance_sales',
      recordId: id,
      description: 'Confirmó venta anticipada ${sale.fullNumber}',
      details: {
        'advance_sale_number': sale.fullNumber,
        'customer': sale.customerName,
        'estimated_total': sale.estimatedTotal,
        'final_total': finalTotal,
        'paid_amount': sale.paidAmount,
        'remaining': finalTotal - sale.paidAmount,
      },
    );

    return (await getById(id))!;
  }

  /// Cancelar venta anticipada
  static Future<AdvanceSale> cancel(String id) async {
    final sale = await getById(id);
    if (sale == null) throw Exception('Venta anticipada no encontrada');

    await _client
        .from('advance_sales')
        .update({
          'status': 'cancelled',
          'updated_at': ColombiaTime.nowIso8601(),
        })
        .eq('id', id);

    await AuditLogDatasource.log(
      action: 'update',
      module: 'advance_sales',
      recordId: id,
      description: 'Canceló venta anticipada ${sale.fullNumber}',
      details: {
        'advance_sale_number': sale.fullNumber,
        'customer': sale.customerName,
        'estimated_total': sale.estimatedTotal,
        'paid_amount': sale.paidAmount,
      },
    );

    return (await getById(id))!;
  }
}
