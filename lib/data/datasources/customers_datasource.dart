import '../../core/utils/colombia_time.dart';
import '../../core/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/customer.dart';
import 'supabase_datasource.dart';
import 'audit_log_datasource.dart';

class CustomersDataSource {
  static const String _table = 'customers';

  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Obtener todos los clientes
  static Future<List<Customer>> getAll({bool activeOnly = true}) async {
    var query = _client.from(_table).select();

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    final response = await query.order('name', ascending: true);
    return response.map<Customer>((json) => _fromJson(json)).toList();
  }

  /// Obtener cliente por ID
  static Future<Customer?> getById(String id) async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('id', id)
          .single();
      return _fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Buscar clientes por nombre o documento
  static Future<List<Customer>> search(String query) async {
    final response = await _client
        .from(_table)
        .select()
        .or(
          'name.ilike.%$query%,document_number.ilike.%$query%,trade_name.ilike.%$query%',
        )
        .order('name', ascending: true);
    return response.map<Customer>((json) => _fromJson(json)).toList();
  }

  /// Crear cliente
  static Future<Customer> create(Customer customer) async {
    try {
      final data = _toJson(customer);
      data.remove('id');
      data.remove('created_at');
      data.remove('updated_at');

      AppLogger.debug('?? Intentando crear cliente: ${customer.name}');
      AppLogger.debug('?? Datos a insertar: $data');

      final response = await _client
          .from(_table)
          .insert(data)
          .select()
          .single();
      AppLogger.success('? Cliente creado exitosamente: ${response['id']}');
      final created = _fromJson(response);
      AuditLogDatasource.log(
        action: 'create',
        module: 'customers',
        recordId: created.id,
        description: 'Creó cliente: ${customer.name}',
        details: {'name': customer.name, 'document': customer.documentNumber},
      );
      return created;
    } catch (e, stackTrace) {
      AppLogger.error('? Error creando cliente: $e');
      AppLogger.debug('?? Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Actualizar cliente
  static Future<Customer> update(Customer customer) async {
    final data = _toJson(customer);
    data.remove('id');
    data.remove('created_at');
    // Mantener updated_at para que se actualice en la BD
    data['updated_at'] = ColombiaTime.nowIso8601();

    final response = await _client
        .from(_table)
        .update(data)
        .eq('id', customer.id)
        .select()
        .single();

    // Actualizar nombre y documento en facturas existentes
    await _client
        .from('invoices')
        .update({
          'customer_name': customer.name,
          'customer_document': customer.documentNumber,
        })
        .eq('customer_id', customer.id);

    // Actualizar nombre y documento en cotizaciones existentes
    await _client
        .from('quotations')
        .update({
          'customer_name': customer.name,
          'customer_document': customer.documentNumber,
        })
        .eq('customer_id', customer.id);

    return _fromJson(response);
  }

  /// Eliminar cliente (hard delete — borra permanentemente con todas sus relaciones)
  static Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
    AuditLogDatasource.log(
      action: 'delete',
      module: 'customers',
      recordId: id,
      description: 'Eliminó cliente ID: $id',
    );
  }

  /// Eliminar permanentemente
  static Future<void> deletePermanent(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  /// Actualizar balance del cliente
  static Future<void> updateBalance(String id, double newBalance) async {
    AppLogger.debug('?? Actualizando balance de cliente $id a: $newBalance');
    await _client
        .from(_table)
        .update({'current_balance': newBalance})
        .eq('id', id);
    AppLogger.success('? Balance actualizado en BD');
  }

  /// Obtener deuda calculada desde facturas (sin actualizar BD)
  static Future<double> getCalculatedDebt(String customerId) async {
    try {
      final response = await _client
          .from('invoices')
          .select('total, paid_amount, status, sale_payment_type, delivery_date')
          .eq('customer_id', customerId);

      double totalPending = 0.0;
      final noDebtStatuses = ['paid', 'cancelled', 'anulada', 'draft'];

      for (final invoice in response) {
        final status = invoice['status']?.toString().toLowerCase() ?? '';
        if (!noDebtStatuses.contains(status)) {
          // Adelantos sin entregar no son deuda, son adelantos de trabajo
          final salePaymentType = invoice['sale_payment_type'] as String?;
          final deliveryDate = invoice['delivery_date'];
          if (salePaymentType == 'advance' && deliveryDate == null) continue;

          final total = (invoice['total'] as num?)?.toDouble() ?? 0.0;
          final paidAmount =
              (invoice['paid_amount'] as num?)?.toDouble() ?? 0.0;
          totalPending += (total - paidAmount);
        }
      }

      return totalPending;
    } catch (e) {
      AppLogger.error('? Error calculando deuda: $e');
      return 0.0;
    }
  }

  /// Calcular deuda de múltiples clientes en una sola consulta (batch)
  static Future<Map<String, double>> getCalculatedDebtBatch(
    List<String> customerIds,
  ) async {
    final debtMap = <String, double>{};
    if (customerIds.isEmpty) return debtMap;

    // Inicializar todos en 0
    for (final id in customerIds) {
      debtMap[id] = 0.0;
    }

    try {
      // Una sola consulta para TODAS las facturas de todos los clientes
      final response = await _client
          .from('invoices')
          .select('customer_id, total, paid_amount, status, sale_payment_type, delivery_date')
          .inFilter('customer_id', customerIds);

      final noDebtStatuses = ['paid', 'cancelled', 'anulada', 'draft'];

      for (final invoice in response) {
        final status = invoice['status']?.toString().toLowerCase() ?? '';
        if (!noDebtStatuses.contains(status)) {
          // Adelantos sin entregar no son deuda, son adelantos de trabajo
          final salePaymentType = invoice['sale_payment_type'] as String?;
          final deliveryDate = invoice['delivery_date'];
          if (salePaymentType == 'advance' && deliveryDate == null) continue;

          final customerId = invoice['customer_id'] as String;
          final total = (invoice['total'] as num?)?.toDouble() ?? 0.0;
          final paidAmount =
              (invoice['paid_amount'] as num?)?.toDouble() ?? 0.0;
          debtMap[customerId] =
              (debtMap[customerId] ?? 0.0) + (total - paidAmount);
        }
      }

      return debtMap;
    } catch (e) {
      AppLogger.error('? Error calculando deuda batch: $e');
      return debtMap;
    }
  }

  /// Recalcular balance del cliente basado en facturas pendientes
  static Future<double> recalculateBalance(String customerId) async {
    try {
      // Obtener TODAS las facturas del cliente
      final response = await _client
          .from('invoices')
          .select('total, paid_amount, status, sale_payment_type, delivery_date')
          .eq('customer_id', customerId);

      double totalPending = 0.0;
      AppLogger.debug(
        '?? Facturas encontradas para cliente $customerId: ${response.length}',
      );

      // Estados que NO generan deuda
      final noDebtStatuses = ['paid', 'cancelled', 'anulada', 'draft'];

      for (final invoice in response) {
        final status = invoice['status']?.toString().toLowerCase() ?? '';
        final total = (invoice['total'] as num?)?.toDouble() ?? 0.0;
        final paidAmount = (invoice['paid_amount'] as num?)?.toDouble() ?? 0.0;

        AppLogger.debug(
          ' - Status: "$status", Total: $total, Pagado: $paidAmount',
        );

        // Si el status NO está en la lista de "sin deuda", sumar la deuda pendiente
        if (!noDebtStatuses.contains(status)) {
          // Adelantos sin entregar no son deuda, son adelantos de trabajo
          final salePaymentType = invoice['sale_payment_type'] as String?;
          final deliveryDate = invoice['delivery_date'];
          if (salePaymentType == 'advance' && deliveryDate == null) {
            AppLogger.debug('   ? Ignorado (adelanto sin entregar)');
            continue;
          }

          final pending = total - paidAmount;
          totalPending += pending;
          AppLogger.debug('   ? Pendiente: $pending (sumado)');
        } else {
          AppLogger.debug('   ? Ignorado (status sin deuda)');
        }
      }

      // Actualizar el balance en la base de datos
      await updateBalance(customerId, totalPending);
      AppLogger.success(
        '? Balance TOTAL recalculado para cliente $customerId: $totalPending',
      );

      return totalPending;
    } catch (e) {
      AppLogger.error('? Error recalculando balance: $e');
      rethrow;
    }
  }

  /// Recalcular balances de TODOS los clientes
  static Future<void> recalculateAllBalances() async {
    try {
      final customers = await getAll();
      AppLogger.debug(
        '?? Recalculando balances de ${customers.length} clientes...',
      );

      for (final customer in customers) {
        await recalculateBalance(customer.id);
      }

      AppLogger.success('? Todos los balances han sido recalculados');
    } catch (e) {
      AppLogger.error('? Error recalculando todos los balances: $e');
      rethrow;
    }
  }

  /// Clientes con deuda
  static Future<List<Customer>> getWithDebt() async {
    final response = await _client
        .from(_table)
        .select()
        .gt('current_balance', 0)
        .eq('is_active', true)
        .order('current_balance', ascending: false);
    return response.map<Customer>((json) => _fromJson(json)).toList();
  }

  // Helpers de conversión

  // Mapeo de tipos de documento antiguos a nuevos (Colombia)
  static DocumentType _mapDocumentType(String? dbValue) {
    switch (dbValue?.toLowerCase()) {
      case 'cc':
        return DocumentType.cc;
      case 'nit':
        return DocumentType.nit;
      case 'ce':
        return DocumentType.ce;
      case 'pasaporte':
        return DocumentType.pasaporte;
      case 'ti':
        return DocumentType.ti;
      // Mapeo de valores antiguos a nuevos
      case 'ruc':
        return DocumentType.nit; // RUC -> NIT
      case 'dni':
        return DocumentType.cc; // DNI -> CC
      case 'passport':
        return DocumentType.pasaporte; // passport -> pasaporte
      default:
        return DocumentType.nit;
    }
  }

  static Customer _fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      type: CustomerType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CustomerType.business,
      ),
      documentType: _mapDocumentType(json['document_type']),
      documentNumber: json['document_number'] ?? '',
      name: json['name'] ?? '',
      tradeName: json['trade_name'],
      address: json['address'],
      phone: json['phone'],
      email: json['email'],
      creditLimit: (json['credit_limit'] ?? 0).toDouble(),
      currentBalance: (json['current_balance'] ?? 0).toDouble(),
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  static Map<String, dynamic> _toJson(Customer customer) {
    // Normalizar document_type para enviar solo valores válidos de BD
    final normalizedDocType = customer.documentType.normalized.name;

    return {
      'id': customer.id,
      'type': customer.type.name,
      'document_type': normalizedDocType,
      'document_number': customer.documentNumber,
      'name': customer.name,
      'trade_name': customer.tradeName,
      'address': customer.address,
      'phone': customer.phone,
      'email': customer.email,
      'credit_limit': customer.creditLimit,
      'current_balance': customer.currentBalance,
      'is_active': customer.isActive,
      'created_at': ColombiaTime.toIso8601(customer.createdAt),
      'updated_at': ColombiaTime.toIso8601(customer.updatedAt),
    };
  }
}
