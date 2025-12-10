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
      final response = await _client.from(_table).select().eq('id', id).single();
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
        .or('name.ilike.%$query%,document_number.ilike.%$query%,trade_name.ilike.%$query%')
        .order('name');
    return response.map<Customer>((json) => _fromJson(json)).toList();
  }

  /// Crear cliente
  static Future<Customer> create(Customer customer) async {
    final data = _toJson(customer);
    data.remove('id');
    data.remove('created_at');
    data.remove('updated_at');
    
    final response = await _client.from(_table).insert(data).select().single();
    return _fromJson(response);
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
    await _client.from(_table).update({'current_balance': newBalance}).eq('id', id);
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
  static Customer _fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      type: CustomerType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => CustomerType.business,
      ),
      documentType: DocumentType.values.firstWhere(
        (e) => e.name == json['document_type'],
        orElse: () => DocumentType.ruc,
      ),
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
    return {
      'id': customer.id,
      'type': customer.type.name,
      'document_type': customer.documentType.name,
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
