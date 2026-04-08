/// Utilidades compartidas para el flujo de escaneo de facturas.
/// Extraídas del diálogo de escaneo para poder testearlas unitariamente.
library;

/// Normaliza unidades de medida escaneadas a formato estándar del inventario.
String normalizeScannedUnit(String unit) {
  final u = unit.toUpperCase().trim();
  const unitMap = {
    'KG': 'KG',
    'KGS': 'KG',
    'KILO': 'KG',
    'KILOS': 'KG',
    'KILOGRAMO': 'KG',
    'KILOGRAMOS': 'KG',
    'UND': 'UND',
    'UN': 'UND',
    'UNIDAD': 'UND',
    'UNIDADES': 'UND',
    'PZA': 'UND',
    'PIEZA': 'UND',
    'PIEZAS': 'UND',
    'PZ': 'UND',
    'M': 'M',
    'MT': 'M',
    'MTS': 'M',
    'METRO': 'M',
    'METROS': 'M',
    'ML': 'M',
    'METRO LINEAL': 'M',
    'L': 'L',
    'LT': 'L',
    'LTS': 'L',
    'LITRO': 'L',
    'LITROS': 'L',
    'GAL': 'GAL',
    'GALON': 'GAL',
    'GALONES': 'GAL',
    'M2': 'M2',
    'MT2': 'M2',
    'METRO CUADRADO': 'M2',
    'GLB': 'GLB',
    'GLOBAL': 'GLB',
    'SERVICIO': 'GLB',
    'SV': 'GLB',
    'ROLLO': 'UND',
    'BOLSA': 'UND',
    'CAJA': 'UND',
    'PAQUETE': 'UND',
  };
  return unitMap[u] ?? 'UND';
}

/// Infiere la categoría para un ítem escaneado basándose en su descripción.
String inferCategoryFromDescription(String description) {
  final d = description.toLowerCase();
  if (d.contains('bola') || d.contains('esfera')) return 'Bolas';
  if (d.contains('tubo') ||
      d.contains('tubería') ||
      d.contains('tuberia') ||
      d.contains('caño')) {
    return 'Tubería';
  }
  if (d.contains('lámina') ||
      d.contains('lamina') ||
      d.contains('chapa') ||
      d.contains('placa')) {
    return 'Láminas';
  }
  if (d.contains('eje') || d.contains('barra') || d.contains('varilla')) {
    return 'Ejes y Barras';
  }
  if (d.contains('tornillo') ||
      d.contains('perno') ||
      d.contains('tuerca') ||
      d.contains('arandela')) {
    return 'Tornillería';
  }
  if (d.contains('sold') || d.contains('electrod')) return 'Soldadura';
  if (d.contains('pintura') ||
      d.contains('anticorr') ||
      d.contains('esmalte')) {
    return 'Pintura';
  }
  if (d.contains('rodamiento') ||
      d.contains('balero') ||
      d.contains('chumacera')) {
    return 'Rodamientos';
  }
  if (d.contains('disco') ||
      d.contains('lija') ||
      d.contains('grasa') ||
      d.contains('aceite')) {
    return 'Consumibles';
  }
  if (d.contains('filtro')) return 'Consumibles';
  return 'General';
}

/// Construye el mapa de datos para insertar un invoice_item en Supabase.
Map<String, dynamic> buildInvoiceItemRow({
  required String invoiceId,
  required int sortOrder,
  required String description,
  String? referenceCode,
  String? materialId,
  required double quantity,
  required String unit,
  required double unitPrice,
  double discount = 0,
  double taxRate = 0,
  double taxAmount = 0,
  required double subtotal,
  required double total,
}) {
  return {
    'invoice_id': invoiceId,
    'product_id': null,
    'material_id': materialId,
    'product_code': referenceCode,
    'product_name': description,
    'description': description,
    'quantity': quantity,
    'unit': unit.isEmpty ? 'UND' : unit.toUpperCase(),
    'unit_price': unitPrice,
    'discount': discount,
    'tax_rate': taxRate,
    'subtotal': subtotal,
    'tax_amount': taxAmount,
    'total': total,
    'sort_order': sortOrder,
  };
}

/// Calcula el nuevo stock tras recibir material de una factura.
double computeNewStock(double currentStock, double receivedQty) {
  return currentStock + receivedQty;
}
