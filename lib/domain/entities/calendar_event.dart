import 'package:flutter/material.dart';

/// Tipos de evento del calendario autogenerado
enum CalendarEventSource {
  invoice,
  quotation,
  productionOrder,
  purchaseOrder,
  shipment,
  activity,
}

/// Evento unificado del calendario (autogenerado desde distintas fuentes)
class CalendarEvent {
  final String id;
  final String title;
  final String? subtitle;
  final DateTime date;
  final CalendarEventSource source;
  final String sourceId;
  final String color;
  final IconData icon;
  final bool isOverdue;

  const CalendarEvent({
    required this.id,
    required this.title,
    this.subtitle,
    required this.date,
    required this.source,
    required this.sourceId,
    required this.color,
    required this.icon,
    this.isOverdue = false,
  });

  String get sourceLabel {
    switch (source) {
      case CalendarEventSource.invoice:
        return 'Factura';
      case CalendarEventSource.quotation:
        return 'Cotizacion';
      case CalendarEventSource.productionOrder:
        return 'Produccion';
      case CalendarEventSource.purchaseOrder:
        return 'Orden Compra';
      case CalendarEventSource.shipment:
        return 'Envio';
      case CalendarEventSource.activity:
        return 'Actividad';
    }
  }
}
