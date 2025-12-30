import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/customer.dart';
import 'supabase_datasource.dart';

class CustomersDataSource {
  static const String _table = 'customers';

  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Obtener todos los clientes
  static Future<List<Customer>> getAll({bool activeOnly = true}) async {
    var query = _client.from(_table).select();

    if (activeOnly) {
      query = query.eq('is_active', true);
    }

    final response = await query.order('name');
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
        .order('name');
    return response.map<Customer>((json) => _fromJson(json)).toList();
  }

  /// Crear cliente
  static Future<Customer> create(Customer customer) async {
    try {
      final data = _toJson(customer);
      data.remove('id');
      data.remove('created_at');
      data.remove('updated_at');
      
      print('📝 Intentando crear cliente: ${customer.name}');
      print('📝 Datos a insertar: $data');

      final response = await _client.from(_table).insert(data).select().single();
      print('✅ Cliente creado exitosamente: ${response['id']}');
      return _fromJson(response);
    } catch (e, stackTrace) {
      print('❌ Error creando cliente: $e');
      print('📋 Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Actualizar cliente
  static Future<Customer> update(Customer customer) async {
    final data = _toJson(customer);
    data.remove('id');
    data.remove('created_at');
    // Mantener updated_at para que se actualice en la BD
    data['updated_at'] = DateTime.now().toIso8601String();

    final response = await _client
        .from(_table)
        .update(data)
        .eq('id', customer.id)
        .select()
        .single();
    return _fromJson(response);
  }

  /// Eliminar cliente (soft delete)
  static Future<void> delete(String id) async {
    await _client.from(_table).update({'is_active': false}).eq('id', id);
  }

  /// Eliminar permanentemente
  static Future<void> deletePermanent(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  /// Actualizar balance del cliente
  static Future<void> updateBalance(String id, double newBalance) async {
    print('💾 Actualizando balance de cliente $id a: $newBalance');
    await _client
        .from(_table)
        .update({'current_balance': newBalance})
        .eq('id', id);
    print('✅ Balance actualizado en BD');
  }

  /// Obtener deuda calculada desde facturas (sin actualizar BD)
  static Future<double> getCalculatedDebt(String customerId) async {
    try {
      final response = await _client
          .from('invoices')
          .select('total, paid_amount, status')
          .eq('customer_id', customerId);
      
      double totalPending = 0.0;
      final noDebtStatuses = ['paid', 'cancelled', 'anulada'];
      
      for (final invoice in response) {
        final status = invoice['status']?.toString().toLowerCase() ?? '';
        if (!noDebtStatuses.contains(status)) {
          final total = (invoice['total'] as num?)?.toDouble() ?? 0.0;
          final paidAmount = (invoice['paid_amount'] as num?)?.toDouble() ?? 0.0;
          totalPending += (total - paidAmount);
        }
      }
      
      return totalPending;
    } catch (e) {
      print('❌ Error calculando deuda: $e');
      return 0.0;
    }
  }

  /// Recalcular balance del cliente basado en facturas pendientes
  static Future<double> recalculateBalance(String customerId) async {
    try {
      // Obtener TODAS las facturas del cliente
      final response = await _client
          .from('invoices')
          .select('total, paid_amount, status')
          .eq('customer_id', customerId);
      
      double totalPending = 0.0;
      print('📋 Facturas encontradas para cliente $customerId: ${response.length}');
      
      // Estados que NO generan deuda
      final noDebtStatuses = ['paid', 'cancelled', 'anulada'];
      
      for (final invoice in response) {
        final status = invoice['status']?.toString().toLowerCase() ?? '';
        final total = (invoice['total'] as num?)?.toDouble() ?? 0.0;
        final paidAmount = (invoice['paid_amount'] as num?)?.toDouble() ?? 0.0;
        
        print('   - Status: "$status", Total: $total, Pagado: $paidAmount');
        
        // Si el status NO está en la lista de "sin deuda", sumar la deuda pendiente
        if (!noDebtStatuses.contains(status)) {
          final pending = total - paidAmount;
          totalPending += pending;
          print('     → Pendiente: $pending (sumado)');
        } else {
          print('     → Ignorado (status sin deuda)');
        }
      }
      
      // Actualizar el balance en la base de datos
      await updateBalance(customerId, totalPending);
      print('✅ Balance TOTAL recalculado para cliente $customerId: $totalPending');
      
      return totalPending;
    } catch (e) {
      print('❌ Error recalculando balance: $e');
      rethrow;
    }
  }

  /// Recalcular balances de TODOS los clientes
  static Future<void> recalculateAllBalances() async {
    try {
      final customers = await getAll();
      print('🔄 Recalculando balances de ${customers.length} clientes...');
      
      for (final customer in customers) {
        await recalculateBalance(customer.id);
      }
      
      print('✅ Todos los balances han sido recalculados');
    } catch (e) {
      print('❌ Error recalculando todos los balances: $e');
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
      'created_at': customer.createdAt.toIso8601String(),
      'updated_at': customer.updatedAt.toIso8601String(),
    };
  }
}
