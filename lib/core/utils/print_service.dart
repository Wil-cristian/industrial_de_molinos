import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

/// Servicio de impresión para facturas y cotizaciones.
/// Genera PDFs en tamaño carta con logo, datos de empresa, tabla de items y totales.
class PrintService {
  // ── Datos de la empresa ──
  static const String companyName = 'Industrial de Molinos';
  static const String companyNit = 'NIT: 901946675-1';
  static const String companyAddress = 'Vrd la playita - Supía, Caldas';
  static const String companyPhone = 'Tel: 3217551145 - 3136446632';
  static const String companyEmail = 'industriasdemolinosasfact@gmail.com';

  static final _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  static String _formatCurrency(double amount) =>
      _currencyFormat.format(amount);

  static String _formatDate(DateTime date) =>
      DateFormat('dd/MM/yyyy').format(date);

  // ═══════════════════════════════════════════════════════════════
  // IMPRIMIR FACTURA
  // ═══════════════════════════════════════════════════════════════
  static Future<void> printInvoice(Map<String, dynamic> invoice) async {
    final pdf = await _buildInvoicePdf(invoice);
    await Printing.layoutPdf(
      onLayout: (_) => pdf.save(),
      name: 'Factura_${invoice['number'] ?? 'SN'}',
    );
  }

  /// Genera PDF de factura y lo comparte / guarda
  static Future<void> shareInvoicePdf(Map<String, dynamic> invoice) async {
    final pdf = await _buildInvoicePdf(invoice);
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Factura_${invoice['number'] ?? 'SN'}.pdf',
    );
  }

  static Future<pw.Document> _buildInvoicePdf(
    Map<String, dynamic> invoice,
  ) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: await _loadFont('Helvetica'),
        bold: await _loadFont('Helvetica-Bold'),
      ),
    );

    final logo = await _loadLogo();
    final products = (invoice['products'] as List<dynamic>?) ?? [];
    final number = invoice['number'] ?? 'S/N';
    final customer = invoice['customer'] ?? 'Sin cliente';
    final customerRuc = invoice['customerRuc'] ?? '';
    final date = invoice['date'] is DateTime
        ? invoice['date'] as DateTime
        : DateTime.now();
    final dueDate = invoice['dueDate'] is DateTime
        ? invoice['dueDate'] as DateTime
        : null;
    final subtotal = (invoice['subtotal'] as num?)?.toDouble() ?? 0;
    final tax = (invoice['tax'] as num?)?.toDouble() ?? 0;
    final total = (invoice['total'] as num?)?.toDouble() ?? 0;
    final paid = (invoice['paid'] as num?)?.toDouble() ?? 0;
    final pending = total - paid;
    final status = invoice['status'] ?? 'Pendiente';
    final notes = invoice['notes'] ?? '';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        header: (context) =>
            _buildPdfHeader(logo, 'RECIBO DE CAJA MENOR', number),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          // ── Info cliente y fechas ──
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildInfoBlock('CLIENTE', [
                  customer,
                  if (customerRuc.isNotEmpty) customerRuc,
                ]),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _buildInfoBlock('DETALLES', [
                  'Fecha: ${_formatDate(date)}',
                  if (dueDate != null) 'Vence: ${_formatDate(dueDate)}',
                  'Estado: $status',
                ]),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // ── Tabla de productos ──
          _buildInvoiceItemsTable(products),
          pw.SizedBox(height: 16),

          // ── Totales ──
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 250,
              child: pw.Column(
                children: [
                  _buildTotalRow('Subtotal', subtotal),
                  if (tax > 0) _buildTotalRow('IVA', tax),
                  pw.Divider(thickness: 1.5),
                  _buildTotalRow('TOTAL', total, isBold: true, fontSize: 14),
                  if (paid > 0) ...[
                    _buildTotalRow('Pagado', paid, color: PdfColors.green700),
                    _buildTotalRow(
                      'Pendiente',
                      pending,
                      color: PdfColors.red700,
                      isBold: true,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Notas ──
          if (notes.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'NOTAS',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(notes, style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ],

          // ── Firma ──
          pw.SizedBox(height: 40),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildSignatureLine('Firma Autorizada'),
              _buildSignatureLine('Recibido por'),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  // ═══════════════════════════════════════════════════════════════
  // IMPRIMIR COTIZACIÓN
  // ═══════════════════════════════════════════════════════════════
  static Future<void> printQuotation(Map<String, dynamic> quotation) async {
    final pdf = await _buildQuotationPdf(quotation);
    await Printing.layoutPdf(
      onLayout: (_) => pdf.save(),
      name: 'Cotizacion_${quotation['number'] ?? 'SN'}',
    );
  }

  /// Genera PDF de cotización y lo comparte / guarda
  static Future<void> shareQuotationPdf(Map<String, dynamic> quotation) async {
    final pdf = await _buildQuotationPdf(quotation);
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Cotizacion_${quotation['number'] ?? 'SN'}.pdf',
    );
  }

  static Future<pw.Document> _buildQuotationPdf(
    Map<String, dynamic> quotation,
  ) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: await _loadFont('Helvetica'),
        bold: await _loadFont('Helvetica-Bold'),
      ),
    );

    final logo = await _loadLogo();
    final items = (quotation['items'] as List<dynamic>?) ?? [];
    final number = quotation['number'] ?? 'S/N';
    final customer = quotation['customer'] ?? 'Sin cliente';
    final customerRuc = quotation['customerRuc'] ?? '';
    final date = quotation['date'] is DateTime
        ? quotation['date'] as DateTime
        : DateTime.now();
    final validUntil = quotation['validUntil'] is DateTime
        ? quotation['validUntil'] as DateTime
        : null;
    final status = quotation['status'] ?? 'Borrador';
    final materialsCost = (quotation['materialsCost'] as num?)?.toDouble() ?? 0;
    final laborCost = (quotation['laborCost'] as num?)?.toDouble() ?? 0;
    final indirectCosts = (quotation['indirectCosts'] as num?)?.toDouble() ?? 0;
    final profitMargin = (quotation['profitMargin'] as num?)?.toDouble() ?? 0;
    final total = (quotation['total'] as num?)?.toDouble() ?? 0;
    final weight = (quotation['weight'] as num?)?.toDouble() ?? 0;
    final notes = quotation['notes'] ?? '';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildPdfHeader(logo, 'COTIZACIÓN', number),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          // ── Info cliente y fechas ──
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildInfoBlock('CLIENTE', [
                  customer,
                  if (customerRuc.isNotEmpty) customerRuc,
                ]),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _buildInfoBlock('DETALLES', [
                  'Fecha: ${_formatDate(date)}',
                  if (validUntil != null)
                    'Válida hasta: ${_formatDate(validUntil)}',
                  'Estado: $status',
                  if (weight > 0) 'Peso total: ${weight.toStringAsFixed(1)} kg',
                ]),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // ── Tabla de items ──
          _buildQuotationItemsTable(items),
          pw.SizedBox(height: 16),

          // ── Desglose de costos ──
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 280,
              child: pw.Column(
                children: [
                  _buildTotalRow('Materiales', materialsCost),
                  if (laborCost > 0) _buildTotalRow('Mano de obra', laborCost),
                  if (indirectCosts > 0)
                    _buildTotalRow('Costos indirectos', indirectCosts),
                  pw.Divider(color: PdfColors.grey300),
                  _buildTotalRow(
                    'Subtotal',
                    materialsCost + laborCost + indirectCosts,
                  ),
                  _buildTotalRow(
                    'Margen (${profitMargin.toStringAsFixed(0)}%)',
                    (materialsCost + laborCost + indirectCosts) *
                        profitMargin /
                        100,
                  ),
                  pw.Divider(thickness: 1.5),
                  _buildTotalRow('TOTAL', total, isBold: true, fontSize: 14),
                ],
              ),
            ),
          ),

          // ── Notas ──
          if (notes.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'NOTAS / CONDICIONES',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(notes, style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ],

          // ── Condiciones estándar ──
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CONDICIONES GENERALES',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '- Los precios incluyen materiales segun especificaciones.\n'
                  '- Tiempo de entrega sujeto a disponibilidad de materiales.\n'
                  '- Forma de pago: 50% anticipo, 50% contra entrega.\n'
                  '- Cotizacion valida por ${validUntil != null ? '${validUntil.difference(date).inDays} dias' : '15 dias'}.',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),

          // ── Firma ──
          pw.SizedBox(height: 40),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildSignatureLine('Elaborado por'),
              _buildSignatureLine('Aceptado por'),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  // ═══════════════════════════════════════════════════════════════
  // COMPONENTES COMPARTIDOS DEL PDF
  // ═══════════════════════════════════════════════════════════════

  /// Carga el logo de la empresa como imagen para PDF.
  /// Retorna null si no se puede cargar.
  static Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final data = await rootBundle.load('lib/photo/logo_empresa.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  /// Carga una fuente con soporte Unicode completo (español, acentos, etc.)
  static Future<pw.Font> _loadFont(String fontName) async {
    switch (fontName) {
      case 'Helvetica-Bold':
        return PdfGoogleFonts.robotoMedium();
      default:
        return PdfGoogleFonts.robotoRegular();
    }
  }

  /// Header del PDF con logo, nombre empresa y número de documento
  static pw.Widget _buildPdfHeader(
    pw.MemoryImage? logo,
    String documentType,
    String documentNumber,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 16),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blue800, width: 3),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Logo
          if (logo != null)
            pw.Container(width: 60, height: 60, child: pw.Image(logo))
          else
            pw.Container(
              width: 60,
              height: 60,
              decoration: pw.BoxDecoration(
                color: PdfColors.blue800,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Center(
                child: pw.Text(
                  'IM',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
          pw.SizedBox(width: 16),

          // Info empresa
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  companyName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  companyNit,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  '$companyAddress  |  $companyPhone',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Text(
                  companyEmail,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.blue700,
                  ),
                ),
              ],
            ),
          ),

          // Tipo y número de documento
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue800,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  documentType,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '#$documentNumber',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Footer del PDF con paginación
  static pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            companyName,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  /// Bloque de información (título + líneas)
  static pw.Widget _buildInfoBlock(String title, List<String> lines) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 6),
          for (final line in lines)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(line, style: const pw.TextStyle(fontSize: 10)),
            ),
        ],
      ),
    );
  }

  /// Fila de total
  static pw.Widget _buildTotalRow(
    String label,
    double amount, {
    bool isBold = false,
    double fontSize = 10,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
          pw.Text(
            _formatCurrency(amount),
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Línea de firma
  static pw.Widget _buildSignatureLine(String label) {
    return pw.Column(
      children: [
        pw.Container(
          width: 200,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
          ),
          child: pw.SizedBox(height: 40),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TABLAS
  // ═══════════════════════════════════════════════════════════════

  /// Tabla de items de factura
  static pw.Widget _buildInvoiceItemsTable(List<dynamic> products) {
    return pw.TableHelper.fromTextArray(
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(1.8),
        3: const pw.FlexColumnWidth(1.8),
      },
      headers: ['Producto', 'Cant.', 'P. Unitario', 'Total'],
      data: products.map((p) {
        final product = p as Map<String, dynamic>;
        final qty = (product['quantity'] as num?)?.toDouble() ?? 1;
        final unitPrice = (product['unitPrice'] as num?)?.toDouble() ?? 0;
        final lineTotal =
            (product['total'] as num?)?.toDouble() ?? (qty * unitPrice);
        return [
          product['name'] ?? '',
          qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(2),
          _formatCurrency(unitPrice),
          _formatCurrency(lineTotal),
        ];
      }).toList(),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      headerAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );
  }

  /// Tabla de items de cotización
  static pw.Widget _buildQuotationItemsTable(List<dynamic> items) {
    return pw.TableHelper.fromTextArray(
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.5),
      },
      headers: ['Item', 'Cant.', 'Peso (kg)', 'Precio/kg', 'Total'],
      data: items.map((item) {
        final i = item as Map<String, dynamic>;
        final qty = (i['quantity'] as num?)?.toInt() ?? 1;
        final weight = (i['totalWeight'] as num?)?.toDouble() ?? 0;
        final pricePerKg = (i['pricePerKg'] as num?)?.toDouble() ?? 0;
        final lineTotal = (i['totalPrice'] as num?)?.toDouble() ?? 0;
        return [
          i['name'] ?? '',
          qty.toString(),
          weight > 0 ? weight.toStringAsFixed(1) : '-',
          pricePerKg > 0 ? _formatCurrency(pricePerKg) : '-',
          _formatCurrency(lineTotal),
        ];
      }).toList(),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      headerAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // INFORME MENSUAL DE RENTABILIDAD
  // ═══════════════════════════════════════════════════════════════

  /// Genera y comparte el informe mensual de rentabilidad como PDF.
  /// [profitLoss]       → Últimos meses de P&L (máx 6).
  /// [topProducts]      → Productos más vendidos.
  /// [activeLoans]      → Préstamos activos de empleados.
  /// [expenseByCategory]→ Mapa categ → monto del mes seleccionado.
  /// [month] / [year]   → Período del informe.
  static Future<void> shareMonthlyReport({
    required List<Map<String, dynamic>> profitLoss,
    required List<Map<String, dynamic>> topProducts,
    required List<Map<String, dynamic>> activeLoans,
    required Map<String, double> expenseByCategory,
    required int month,
    required int year,
  }) async {
    final pdf = await _buildMonthlyReportPdf(
      profitLoss: profitLoss,
      topProducts: topProducts,
      activeLoans: activeLoans,
      expenseByCategory: expenseByCategory,
      month: month,
      year: year,
    );
    final monthNames = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Informe_${monthNames[month]}_$year.pdf',
    );
  }

  static Future<pw.Document> _buildMonthlyReportPdf({
    required List<Map<String, dynamic>> profitLoss,
    required List<Map<String, dynamic>> topProducts,
    required List<Map<String, dynamic>> activeLoans,
    required Map<String, double> expenseByCategory,
    required int month,
    required int year,
  }) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: await _loadFont('Helvetica'),
        bold: await _loadFont('Helvetica-Bold'),
      ),
    );

    final logo = await _loadLogo();
    final monthNames = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    final monthName = monthNames[month];

    // ── Datos del mes actual ──
    final currentMonthData = profitLoss
        .where(
          (p) => (p['month'] as int?) == month && (p['year'] as int?) == year,
        )
        .toList();
    final revenue = currentMonthData.isNotEmpty
        ? (currentMonthData.first['revenue'] as num?)?.toDouble() ?? 0.0
        : 0.0;
    final totalExpenses = currentMonthData.isNotEmpty
        ? ((currentMonthData.first['fixed_expenses'] as num?)?.toDouble() ??
                  0) +
              ((currentMonthData.first['variable_expenses'] as num?)
                      ?.toDouble() ??
                  0)
        : 0.0;
    final grossProfit = currentMonthData.isNotEmpty
        ? (currentMonthData.first['gross_profit'] as num?)?.toDouble() ?? 0.0
        : 0.0;
    final profitMargin = revenue > 0 ? (grossProfit / revenue * 100) : 0.0;

    // ── Proyección mes siguiente (simple: promedio de últimos 3 meses) ──
    final recent = profitLoss.take(3).toList();
    final avgRevenue = recent.isNotEmpty
        ? recent.fold(
                0.0,
                (s, p) => s + ((p['revenue'] as num?)?.toDouble() ?? 0),
              ) /
              recent.length
        : 0.0;
    final avgExpenses = recent.isNotEmpty
        ? recent.fold(
                0.0,
                (s, p) =>
                    s +
                    ((p['fixed_expenses'] as num?)?.toDouble() ?? 0) +
                    ((p['variable_expenses'] as num?)?.toDouble() ?? 0),
              ) /
              recent.length
        : 0.0;
    final projRevenue = avgRevenue * 1.05; // +5% optimista
    final projExpenses = avgExpenses;
    final projProfit = projRevenue - projExpenses;

    // ── Totales de préstamos ──
    final totalLoanAmount = activeLoans.fold(
      0.0,
      (s, l) => s + ((l['total_amount'] as num?)?.toDouble() ?? 0),
    );
    final totalLoanRemaining = activeLoans.fold(
      0.0,
      (s, l) => s + ((l['remaining_amount'] as num?)?.toDouble() ?? 0),
    );
    final totalLoanPaid = totalLoanAmount - totalLoanRemaining;

    // ── Nombres de categorías ──
    final categoryLabels = <String, String>{
      'cuidado_personal': 'Cuidado Personal',
      'servicios_publicos': 'Servicios Públicos',
      'papeleria': 'Papelería',
      'nomina': 'Nómina',
      'impuestos': 'Impuestos',
      'consumibles': 'Consumibles',
      'transporte': 'Transporte',
      'gastos_reducibles': 'Gastos Reducibles',
    };

    final darkBlue = PdfColors.blue900;
    final lightBlue = const PdfColor(0.23, 0.47, 0.75);
    final accentGreen = PdfColors.green700;
    final accentRed = PdfColors.red700;
    final bgGrey = PdfColors.grey100;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(36),
        header: (context) =>
            _buildPdfHeader(logo, 'INFORME MENSUAL', '$monthName $year'),
        footer: (context) => _buildPdfFooter(context),
        build: (context) => [
          pw.SizedBox(height: 12),

          // ════ SECCIÓN 1: KPIs PRINCIPALES ════
          _buildReportSectionTitle('RESUMEN EJECUTIVO', darkBlue),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                flex: 1,
                child: _buildKpiBox('VENTAS', revenue, lightBlue),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                flex: 1,
                child: _buildKpiBox('COSTOS TOTALES', totalExpenses, accentRed),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                flex: 1,
                child: _buildKpiBox(
                  'GANANCIA BRUTA',
                  grossProfit,
                  grossProfit >= 0 ? accentGreen : accentRed,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                flex: 1,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: bgGrey,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        '% UTILIDAD',
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey600,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${profitMargin.toStringAsFixed(1)}%',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: profitMargin >= 0 ? accentGreen : accentRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // ════ SECCIÓN 2: DESGLOSE DE COSTOS ════
          _buildReportSectionTitle(
            'DESGLOSE DE COSTOS POR CATEGORÍA',
            darkBlue,
          ),
          pw.SizedBox(height: 8),
          _buildExpenseCategoryTable(
            expenseByCategory,
            categoryLabels,
            totalExpenses,
          ),
          pw.SizedBox(height: 16),

          // ════ SECCIÓN 3: HISTÓRICO MENSUAL ════
          if (profitLoss.isNotEmpty) ...[
            _buildReportSectionTitle(
              'COMPARATIVO MENSUAL (ÚLTIMOS MESES)',
              darkBlue,
            ),
            pw.SizedBox(height: 8),
            _buildMonthlyComparisonTable(profitLoss, monthNames),
            pw.SizedBox(height: 16),
          ],

          // ════ SECCIÓN 4: PRODUCTOS ESTRELLA ════
          if (topProducts.isNotEmpty) ...[
            _buildReportSectionTitle('PRODUCTOS ESTRELLA', darkBlue),
            pw.SizedBox(height: 8),
            _buildTopProductsTable(topProducts.take(8).toList()),
            pw.SizedBox(height: 16),
          ],

          // ════ SECCIÓN 5: PRÉSTAMOS EMPLEADOS ════
          _buildReportSectionTitle('PRÉSTAMOS A EMPLEADOS', darkBlue),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: bgGrey,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: activeLoans.isEmpty
                ? pw.Text(
                    'No hay préstamos activos registrados.',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  )
                : pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildLoanKpi(
                            'Préstamos Activos',
                            '${activeLoans.length}',
                            lightBlue,
                          ),
                          _buildLoanKpi(
                            'Total Prestado',
                            _formatCurrency(totalLoanAmount),
                            accentRed,
                          ),
                          _buildLoanKpi(
                            'Total Pagado',
                            _formatCurrency(totalLoanPaid),
                            accentGreen,
                          ),
                          _buildLoanKpi(
                            'Saldo Pendiente',
                            _formatCurrency(totalLoanRemaining),
                            PdfColors.orange700,
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                      _buildActiveLoansTable(activeLoans),
                    ],
                  ),
          ),
          pw.SizedBox(height: 16),

          // ════ SECCIÓN 6: PROYECCIONES ════
          _buildReportSectionTitle('PROYECCIONES PRÓXIMO MES', darkBlue),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: const PdfColor(0.95, 0.97, 1.0),
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: lightBlue),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Basado en el promedio de los últimos ${recent.length} meses con ajuste de tendencia (+5%)',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _buildKpiBox(
                        'VENTAS PROYECTADAS',
                        projRevenue,
                        lightBlue,
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: _buildKpiBox(
                        'COSTOS ESTIMADOS',
                        projExpenses,
                        accentRed,
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: _buildKpiBox(
                        'GANANCIA ESTIMADA',
                        projProfit,
                        projProfit >= 0 ? accentGreen : accentRed,
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(6),
                          border: pw.Border.all(color: PdfColors.grey300),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              '% MARGEN PROY.',
                              style: pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey600,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              projRevenue > 0
                                  ? '${(projProfit / projRevenue * 100).toStringAsFixed(1)}%'
                                  : '—',
                              style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: projProfit >= 0
                                    ? accentGreen
                                    : accentRed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // ── Firma ──
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildSignatureLine('Elaborado por'),
              _buildSignatureLine('Gerencia'),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  // ── Helpers del informe mensual ──

  static pw.Widget _buildReportSectionTitle(String title, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _buildKpiBox(String label, double value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey600,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _formatCurrency(value),
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildLoanKpi(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    );
  }

  static pw.Widget _buildExpenseCategoryTable(
    Map<String, double> expenseByCategory,
    Map<String, String> labels,
    double total,
  ) {
    final rows = <List<String>>[];
    for (final entry in labels.entries) {
      final amount = expenseByCategory[entry.key] ?? 0;
      final pct = total > 0 ? (amount / total * 100).toStringAsFixed(1) : '0.0';
      rows.add([entry.value, _formatCurrency(amount), '$pct%']);
    }
    rows.add(['TOTAL', _formatCurrency(total), '100%']);

    return pw.TableHelper.fromTextArray(
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1),
      },
      headers: ['Categoría', 'Monto', '% del Total'],
      data: rows,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.center,
      },
      headerAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.center,
      },
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    );
  }

  static pw.Widget _buildMonthlyComparisonTable(
    List<Map<String, dynamic>> profitLoss,
    List<String> monthNames,
  ) {
    final rows = profitLoss.take(6).map((p) {
      final m = (p['month'] as int?) ?? 0;
      final y = (p['year'] as int?) ?? 0;
      final rev = (p['revenue'] as num?)?.toDouble() ?? 0;
      final fix = (p['fixed_expenses'] as num?)?.toDouble() ?? 0;
      final vari = (p['variable_expenses'] as num?)?.toDouble() ?? 0;
      final costs = fix + vari;
      final profit = (p['gross_profit'] as num?)?.toDouble() ?? 0;
      final pct = rev > 0 ? '${(profit / rev * 100).toStringAsFixed(1)}%' : '—';
      return [
        '${m > 0 ? monthNames[m] : '?'} $y',
        _formatCurrency(costs),
        _formatCurrency(rev),
        _formatCurrency(profit),
        pct,
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(1.2),
      },
      headers: ['Mes', 'Costos', 'Ventas', 'G. Bruta', '% Utilidad'],
      data: rows,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.center,
      },
      headerAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.center,
      },
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    );
  }

  static pw.Widget _buildTopProductsTable(List<Map<String, dynamic>> products) {
    final rows = products.asMap().entries.map((e) {
      final i = e.key + 1;
      final p = e.value;
      return [
        '#$i',
        p['product_name']?.toString() ?? p['product_key']?.toString() ?? '—',
        (p['times_sold'] as num?)?.toString() ?? '0',
        _formatCurrency((p['total_revenue'] as num?)?.toDouble() ?? 0),
        _formatCurrency((p['avg_price'] as num?)?.toDouble() ?? 0),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
      columnWidths: {
        0: const pw.FixedColumnWidth(24),
        1: const pw.FlexColumnWidth(4),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(2),
      },
      headers: ['#', 'Producto', 'Ventas', 'Ingresos', 'Precio Prom.'],
      data: rows,
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      headerAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    );
  }

  static pw.Widget _buildActiveLoansTable(List<Map<String, dynamic>> loans) {
    final rows = loans.map((l) {
      return [
        l['employee_name']?.toString() ?? 'Empleado',
        _formatCurrency((l['total_amount'] as num?)?.toDouble() ?? 0),
        _formatCurrency((l['paid_amount'] as num?)?.toDouble() ?? 0),
        _formatCurrency((l['remaining_amount'] as num?)?.toDouble() ?? 0),
        l['status']?.toString() ?? '—',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: 8,
      ),
      cellStyle: const pw.TextStyle(fontSize: 8),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(1.5),
      },
      headers: ['Empleado', 'Total Préstamo', 'Pagado', 'Saldo', 'Estado'],
      data: rows,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.center,
      },
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // UTILIDAD: Info de impresoras disponibles
  // ═══════════════════════════════════════════════════════════════

  /// Abre el diálogo nativo de impresión del sistema operativo,
  /// que permite seleccionar impresora, configurar tamaño, etc.
  /// Retorna true si se lanzó correctamente.
  static Future<bool> showPrinterPicker() async {
    try {
      final info = await Printing.info();
      return info.canPrint;
    } catch (_) {
      return false;
    }
  }
}
