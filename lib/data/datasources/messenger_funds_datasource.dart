import '../../core/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/messenger_fund.dart';
import 'invoices_datasource.dart';
import 'purchase_orders_datasource.dart';
import 'supabase_datasource.dart';

class MessengerFundsDataSource {
  static const String _fundsTable = 'messenger_funds';
  static const String _itemsTable = 'messenger_fund_items';

  static SupabaseClient get _client => SupabaseDataSource.client;

  // ===================== FONDOS =====================

  /// Obtener todos los fondos (con items incluidos)
  static Future<List<MessengerFund>> getAll({String? status}) async {
    try {
      var query = _client.from(_fundsTable).select('*, messenger_fund_items(*)');

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);
      return response
          .map<MessengerFund>((json) => MessengerFund.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.error('Error obteniendo fondos de mensajería', e);
      return [];
    }
  }

  /// Obtener fondos abiertos (abierto o parcial)
  static Future<List<MessengerFund>> getOpenFunds() async {
    try {
      final response = await _client
          .from(_fundsTable)
          .select('*, messenger_fund_items(*)')
          .inFilter('status', ['abierto', 'parcial'])
          .order('created_at', ascending: false);
      return response
          .map<MessengerFund>((json) => MessengerFund.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.error('Error obteniendo fondos abiertos', e);
      return [];
    }
  }

  /// Obtener fondo por ID con items
  static Future<MessengerFund?> getById(String id) async {
    try {
      final response = await _client
          .from(_fundsTable)
          .select('*, messenger_fund_items(*)')
          .eq('id', id)
          .single();
      return MessengerFund.fromJson(response);
    } catch (e) {
      AppLogger.error('Error obteniendo fondo $id', e);
      return null;
    }
  }

  /// Obtener fondos por empleado
  static Future<List<MessengerFund>> getByEmployee(String employeeId) async {
    try {
      final response = await _client
          .from(_fundsTable)
          .select('*, messenger_fund_items(*)')
          .eq('employee_id', employeeId)
          .order('created_at', ascending: false);
      return response
          .map<MessengerFund>((json) => MessengerFund.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.error('Error obteniendo fondos del empleado', e);
      return [];
    }
  }

  // ===================== CREAR FONDO (RPC Atómico) =====================

  /// Crear fondo de mensajería (atómico: crea fondo + movimiento + actualiza balance)
  static Future<String?> createFund({
    required String employeeId,
    required String employeeName,
    required double amount,
    required String accountId,
    String? notes,
  }) async {
    try {
      final result = await _client.rpc('create_messenger_fund', params: {
        'p_employee_id': employeeId,
        'p_employee_name': employeeName,
        'p_amount': amount,
        'p_account_id': accountId,
        'p_notes': notes,
      });
      return result as String?;
    } catch (e) {
      AppLogger.error('Error creando fondo de mensajería', e);
      rethrow;
    }
  }

  // ===================== LEGALIZAR ITEMS =====================

  /// Legalizar un item del fondo (compra, pago, gasto o devolución)
  static Future<String?> legalizeItem({
    required String fundId,
    required FundItemType itemType,
    required double amount,
    required String description,
    String? reference,
    String? category,
    String? purchaseOrderId,
    String? invoiceId,
    String? attachmentUrl,
    String? attachmentName,
  }) async {
    try {
      final result = await _client.rpc('legalize_fund_item', params: {
        'p_fund_id': fundId,
        'p_item_type': itemType.name,
        'p_amount': amount,
        'p_description': description,
        'p_reference': reference,
        'p_category': category ?? 'consumibles',
        'p_purchase_order_id': purchaseOrderId,
        'p_invoice_id': invoiceId,
        'p_attachment_url': attachmentUrl,
        'p_attachment_name': attachmentName,
      });
      return result as String?;
    } catch (e) {
      AppLogger.error('Error legalizando item del fondo', e);
      rethrow;
    }
  }

  // ===================== CANCELAR FONDO =====================

  /// Cancelar fondo (devuelve dinero no gastado)
  static Future<void> cancelFund(String fundId) async {
    try {
      await _client.rpc('cancel_messenger_fund', params: {
        'p_fund_id': fundId,
      });
    } catch (e) {
      AppLogger.error('Error cancelando fondo de mensajería', e);
      rethrow;
    }
  }

  // ===================== ITEMS DIRECTOS =====================

  /// Obtener items de un fondo
  static Future<List<MessengerFundItem>> getItems(String fundId) async {
    try {
      final response = await _client
          .from(_itemsTable)
          .select()
          .eq('fund_id', fundId)
          .order('created_at', ascending: false);
      return response
          .map<MessengerFundItem>((json) => MessengerFundItem.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.error('Error obteniendo items del fondo', e);
      return [];
    }
  }

  // ===================== ESTADÍSTICAS =====================

  /// Obtener facturas pendientes para vincular legalizaciones
  static Future<List<Invoice>> getPendingInvoices() async {
    try {
      return await InvoicesDataSource.getPending();
    } catch (e) {
      AppLogger.error('Error obteniendo facturas pendientes', e);
      return [];
    }
  }

  /// Obtener órdenes de compra pendientes de pago
  static Future<List<PurchaseOrder>> getPendingPurchaseOrders() async {
    try {
      final orders = await PurchaseOrdersDataSource.getAll();
      return orders.where((o) => o.balance > 0.01).toList();
    } catch (e) {
      AppLogger.error('Error obteniendo órdenes pendientes', e);
      return [];
    }
  }

  /// Obtener resumen de fondos activos
  static Future<Map<String, dynamic>> getActiveSummary() async {
    try {
      final funds = await getOpenFunds();
      double totalGiven = 0;
      double totalSpent = 0;
      double totalPending = 0;
      for (final fund in funds) {
        totalGiven += fund.amountGiven;
        totalSpent += fund.amountSpent;
        totalPending += fund.remainingBalance;
      }
      return {
        'count': funds.length,
        'totalGiven': totalGiven,
        'totalSpent': totalSpent,
        'totalPending': totalPending,
      };
    } catch (e) {
      AppLogger.error('Error obteniendo resumen de fondos', e);
      return {'count': 0, 'totalGiven': 0.0, 'totalSpent': 0.0, 'totalPending': 0.0};
    }
  }
}
