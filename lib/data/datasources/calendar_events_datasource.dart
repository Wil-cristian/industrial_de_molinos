import '../../core/utils/colombia_time.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/calendar_event.dart';
import 'invoices_datasource.dart';
import 'quotations_datasource.dart';
import 'production_orders_datasource.dart';
import 'purchase_orders_datasource.dart';
import 'shipments_datasource.dart';

/// Datasource que genera eventos de calendario desde todas las fuentes
class CalendarEventsDatasource {
  /// Carga todos los eventos de todas las fuentes
  static Future<List<CalendarEvent>> loadAllEvents() async {
    final results = await Future.wait([
      _loadInvoiceEvents(),
      _loadQuotationEvents(),
      _loadProductionOrderEvents(),
      _loadPurchaseOrderEvents(),
      _loadShipmentEvents(),
    ]);

    final events = <CalendarEvent>[];
    for (final list in results) {
      events.addAll(list);
    }
    return events;
  }

  // ═══════ FACTURAS ═══════
  static Future<List<CalendarEvent>> _loadInvoiceEvents() async {
    try {
      final invoices = await InvoicesDataSource.getAll();
      final events = <CalendarEvent>[];
      final now = ColombiaTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (final inv in invoices) {
        // Ignorar anuladas
        if (inv.status.name == 'cancelled') continue;

        // Evento de vencimiento
        if (inv.dueDate != null && inv.status.name != 'paid') {
          final isOverdue = inv.dueDate!.isBefore(today);
          events.add(
            CalendarEvent(
              id: 'inv_due_${inv.id}',
              title: 'Vence Factura ${inv.series}-${inv.number}',
              subtitle: '${inv.customerName} - \$${_fmt(inv.total)}',
              date: inv.dueDate!,
              source: CalendarEventSource.invoice,
              sourceId: inv.id,
              color: isOverdue ? '#C62828' : '#FF6B6B',
              icon: Icons.receipt_long,
              isOverdue: isOverdue,
            ),
          );
        }

        // Evento de fecha de entrega
        if (inv.deliveryDate != null) {
          events.add(
            CalendarEvent(
              id: 'inv_del_${inv.id}',
              title: 'Entrega Factura ${inv.series}-${inv.number}',
              subtitle: inv.customerName,
              date: inv.deliveryDate!,
              source: CalendarEventSource.invoice,
              sourceId: inv.id,
              color: '#4CAF50',
              icon: Icons.local_shipping,
            ),
          );
        }
      }
      return events;
    } catch (e) {
      print('Error cargando eventos de facturas: $e');
      return [];
    }
  }

  // ═══════ COTIZACIONES ═══════
  static Future<List<CalendarEvent>> _loadQuotationEvents() async {
    try {
      final quotations = await QuotationsDataSource.getAll();
      final events = <CalendarEvent>[];
      final now = ColombiaTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (final q in quotations) {
        // Solo cotizaciones activas (borrador, enviada)
        if (q.status == 'Aprobada' ||
            q.status == 'Rechazada' ||
            q.status == 'Anulada') {
          continue;
        }

        final isOverdue = q.validUntil.isBefore(today);
        events.add(
          CalendarEvent(
            id: 'quot_${q.id}',
            title: 'Expira Cotizacion ${q.number}',
            subtitle: q.customerName,
            date: q.validUntil,
            source: CalendarEventSource.quotation,
            sourceId: q.id,
            color: isOverdue ? '#C62828' : '#42A5F5',
            icon: Icons.description,
            isOverdue: isOverdue,
          ),
        );
      }
      return events;
    } catch (e) {
      print('Error cargando eventos de cotizaciones: $e');
      return [];
    }
  }

  // ═══════ ORDENES DE PRODUCCION ═══════
  static Future<List<CalendarEvent>> _loadProductionOrderEvents() async {
    try {
      final orders = await ProductionOrdersDataSource.getAll();
      final events = <CalendarEvent>[];
      final now = ColombiaTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (final op in orders) {
        // Solo ordenes activas
        if (op.status == 'completada' || op.status == 'cancelada') continue;

        // Fecha de inicio
        if (op.startDate != null) {
          events.add(
            CalendarEvent(
              id: 'op_start_${op.id}',
              title: 'Inicio OP ${op.code}',
              subtitle: op.productName,
              date: op.startDate!,
              source: CalendarEventSource.productionOrder,
              sourceId: op.id,
              color: '#FF8F00',
              icon: Icons.play_circle,
            ),
          );
        }

        // Fecha de entrega
        if (op.dueDate != null) {
          final isOverdue = op.dueDate!.isBefore(today);
          events.add(
            CalendarEvent(
              id: 'op_due_${op.id}',
              title: 'Entrega OP ${op.code}',
              subtitle: '${op.productName} x${op.quantity}',
              date: op.dueDate!,
              source: CalendarEventSource.productionOrder,
              sourceId: op.id,
              color: isOverdue ? '#C62828' : '#FF8F00',
              icon: Icons.precision_manufacturing,
              isOverdue: isOverdue,
            ),
          );
        }
      }
      return events;
    } catch (e) {
      print('Error cargando eventos de produccion: $e');
      return [];
    }
  }

  // ═══════ ORDENES DE COMPRA ═══════
  static Future<List<CalendarEvent>> _loadPurchaseOrderEvents() async {
    try {
      final orders = await PurchaseOrdersDataSource.getAll();
      final events = <CalendarEvent>[];
      final now = ColombiaTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (final oc in orders) {
        // Solo ordenes activas
        if (oc.status.name == 'cancelada' || oc.status.name == 'recibida') {
          continue;
        }

        // Fecha esperada de recepcion
        if (oc.expectedDate != null) {
          events.add(
            CalendarEvent(
              id: 'oc_exp_${oc.id}',
              title: 'Recepcion OC ${oc.orderNumber}',
              subtitle: null,
              date: oc.expectedDate!,
              source: CalendarEventSource.purchaseOrder,
              sourceId: oc.id,
              color: '#7B1FA2',
              icon: Icons.inventory,
            ),
          );
        }

        // Fecha de vencimiento de pago
        if (oc.dueDate != null) {
          final isOverdue = oc.dueDate!.isBefore(today);
          events.add(
            CalendarEvent(
              id: 'oc_due_${oc.id}',
              title: 'Vence pago OC ${oc.orderNumber}',
              subtitle: null,
              date: oc.dueDate!,
              source: CalendarEventSource.purchaseOrder,
              sourceId: oc.id,
              color: isOverdue ? '#C62828' : '#9C27B0',
              icon: Icons.payments,
              isOverdue: isOverdue,
            ),
          );
        }
      }
      return events;
    } catch (e) {
      print('Error cargando eventos de ordenes de compra: $e');
      return [];
    }
  }

  // ═══════ REMISIONES / ENVIOS ═══════
  static Future<List<CalendarEvent>> _loadShipmentEvents() async {
    try {
      final shipments = await ShipmentsDataSource.getAll();
      final events = <CalendarEvent>[];

      for (final s in shipments) {
        // Solo envios activos
        if (s.status.name == 'anulada' || s.status.name == 'entregada') {
          continue;
        }

        // Fecha de despacho
        events.add(
          CalendarEvent(
            id: 'ship_disp_${s.id}',
            title: 'Despacho ${s.code}',
            subtitle: s.customerName,
            date: s.dispatchDate,
            source: CalendarEventSource.shipment,
            sourceId: s.id,
            color: '#00897B',
            icon: Icons.local_shipping,
          ),
        );

        // Fecha de entrega esperada
        if (s.deliveryDate != null) {
          events.add(
            CalendarEvent(
              id: 'ship_del_${s.id}',
              title: 'Entrega ${s.code}',
              subtitle: s.customerName,
              date: s.deliveryDate!,
              source: CalendarEventSource.shipment,
              sourceId: s.id,
              color: '#4DB6AC',
              icon: Icons.where_to_vote,
            ),
          );
        }
      }
      return events;
    } catch (e) {
      print('Error cargando eventos de envios: $e');
      return [];
    }
  }

  static String _fmt(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }
}
