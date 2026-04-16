import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_datasource.dart';
import 'invoice_scanner_service.dart';

// =====================================================
// DATASOURCE: Correcciones de escaneo IA
// =====================================================
// Guarda las diferencias entre lo que la IA leyó y lo que
// el usuario corrigió. Se usan como few-shot examples.

class ScanCorrectionsDataSource {
  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Guarda una corrección comparando datos originales de la IA vs lo que el usuario guardó.
  /// Solo guarda si hay diferencias significativas.
  static Future<void> saveCorrection({
    required String correctionType, // 'purchase' o 'sale'
    required InvoiceScanResult originalResult,
    required double correctedTotal,
    required double correctedSubtotal,
    required double correctedTaxRate,
    required double correctedTaxAmount,
    required String correctedInvoiceNumber,
    String? supplierName,
    String? imageRef,
  }) async {
    final diffs = <String>[];

    // Comparar total
    if ((originalResult.total - correctedTotal).abs() > 1) {
      diffs.add(
        'Total: ${originalResult.total.toStringAsFixed(0)} → ${correctedTotal.toStringAsFixed(0)}',
      );
    }

    // Comparar subtotal
    if ((originalResult.subtotal - correctedSubtotal).abs() > 1) {
      diffs.add(
        'Subtotal: ${originalResult.subtotal.toStringAsFixed(0)} → ${correctedSubtotal.toStringAsFixed(0)}',
      );
    }

    // Comparar IVA
    if ((originalResult.taxRate - correctedTaxRate).abs() > 0.01) {
      diffs.add(
        'IVA%: ${originalResult.taxRate.toStringAsFixed(1)} → ${correctedTaxRate.toStringAsFixed(1)}',
      );
    }
    if ((originalResult.taxAmount - correctedTaxAmount).abs() > 1) {
      diffs.add(
        'IVA\$: ${originalResult.taxAmount.toStringAsFixed(0)} → ${correctedTaxAmount.toStringAsFixed(0)}',
      );
    }

    // Comparar número de factura
    final origNum = originalResult.invoiceNumber ?? '';
    if (origNum != correctedInvoiceNumber &&
        correctedInvoiceNumber.isNotEmpty &&
        correctedInvoiceNumber != 'SIN-NUM') {
      diffs.add('Nro factura: "$origNum" → "$correctedInvoiceNumber"');
    }

    // Solo guardar si hubo correcciones
    if (diffs.isEmpty) return;

    final summary = diffs.join('; ');

    // Items originales en JSON simplificado
    final originalItemsJson = originalResult.items
        .map(
          (i) => {
            'desc': i.description,
            'qty': i.quantity,
            'price': i.unitPrice,
            'total': i.total,
          },
        )
        .toList();

    await _client.from('scan_corrections').insert({
      'correction_type': correctionType,
      'supplier_name': supplierName,
      'original_total': originalResult.total,
      'original_subtotal': originalResult.subtotal,
      'original_tax_rate': originalResult.taxRate,
      'original_tax_amount': originalResult.taxAmount,
      'original_invoice_number': originalResult.invoiceNumber,
      'original_items_json': originalItemsJson,
      'corrected_total': correctedTotal,
      'corrected_subtotal': correctedSubtotal,
      'corrected_tax_rate': correctedTaxRate,
      'corrected_tax_amount': correctedTaxAmount,
      'corrected_invoice_number': correctedInvoiceNumber,
      'corrections_summary': summary,
      'image_ref': imageRef,
    });
  }

  /// Obtiene las últimas N correcciones como texto legible para incluir en el prompt.
  static Future<List<String>> getRecentCorrections({int limit = 10}) async {
    final response = await _client
        .from('scan_corrections')
        .select('supplier_name, corrections_summary, correction_type')
        .order('created_at', ascending: false)
        .limit(limit);

    final list = response as List;
    return list.map<String>((row) {
      final supplier = row['supplier_name'] ?? 'Desconocido';
      final summary = row['corrections_summary'] ?? '';
      final type = row['correction_type'] == 'purchase' ? 'Compra' : 'Venta';
      return '- $type de "$supplier": $summary';
    }).toList();
  }
}
