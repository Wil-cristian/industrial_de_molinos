import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/entities/shipment_order.dart';

/// Servicio de impresión de remisiones de envío.
class ShipmentPrintService {
  static const String _companyName = 'Industrial de Molinos';
  static const String _companyNit = 'NIT: 901946675-1';
  static const String _companyAddress = 'Vrd la playita - Supía, Caldas';
  static const String _companyPhone = 'Tel: 3043047353';
  static const String _companyEmail = 'industriasdemolinosasfact@gmail.com';

  static final _dateFormat = DateFormat('dd/MM/yyyy');

  static Future<void> printShipment(ShipmentOrder shipment) async {
    final pdf = await _buildPdf(shipment);
    await Printing.layoutPdf(
      onLayout: (_) => pdf.save(),
      name: 'Remision_${shipment.code}',
    );
  }

  static Future<void> shareShipment(ShipmentOrder shipment) async {
    final pdf = await _buildPdf(shipment);
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Remision_${shipment.code}.pdf',
    );
  }

  static Future<pw.Document> _buildPdf(ShipmentOrder s) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.robotoRegular(),
        bold: await PdfGoogleFonts.robotoMedium(),
      ),
    );

    final logo = await _loadLogo();

    // Una sola página carta con dos copias idénticas (empresa + transportista)
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        build: (context) {
          return pw.Column(
            children: [
              pw.Expanded(child: _buildCopyContent(logo, s)),
              _cutLine(),
              pw.Expanded(child: _buildCopyContent(logo, s)),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  /// Contenido compacto de una copia de la remisión.
  static pw.Widget _buildCopyContent(pw.MemoryImage? logo, ShipmentOrder s) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Barra superior
        pw.Container(
          width: double.infinity,
          height: 3,
          decoration: pw.BoxDecoration(
            color: PdfColors.blueGrey800,
            borderRadius: pw.BorderRadius.circular(1),
          ),
        ),
        pw.SizedBox(height: 8),

        _header(logo, s.code),
        pw.SizedBox(height: 8),

        // Destinatario + Estado
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey50,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfColors.grey200),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _label('DESTINATARIO'),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      s.customerName,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (s.customerAddress != null)
                      pw.Text(
                        s.customerAddress!,
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    if (s.customerPhone != null && s.customerPhone!.isNotEmpty)
                      pw.Text(
                        'Tel: ${s.customerPhone}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    if (s.invoiceFullNumber != null)
                      pw.Text(
                        'Factura: ${s.invoiceFullNumber}',
                        style: const pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.grey600,
                        ),
                      ),
                    if (s.productionOrderCode != null)
                      pw.Text(
                        'OP: ${s.productionOrderCode}',
                        style: const pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.grey600,
                        ),
                      ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _label('ESTADO'),
                  pw.SizedBox(height: 2),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: pw.BoxDecoration(
                      color: _statusColor(s.status),
                      borderRadius: pw.BorderRadius.circular(3),
                    ),
                    child: pw.Text(
                      s.statusLabel,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  _label('FECHA DESPACHO'),
                  pw.Text(
                    _dateFormat.format(s.dispatchDate),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 8),

        // Transporte — datos del conductor (persona, no empresa)
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfColors.blue100),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _label('INFORMACIÓN DE TRANSPORTE'),
              pw.SizedBox(height: 4),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _field(
                      'Conductor',
                      s.driverName ?? s.carrierName ?? 'No registrado',
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: _field(
                      'CC Conductor',
                      s.driverDocument ?? s.carrierDocument ?? 'No registrado',
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: _field('Placa', s.vehiclePlate ?? 'No registrada'),
                  ),
                ],
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 10),

        // Tabla de ítems
        _label('ÍTEMS DEL ENVÍO (${s.items.length})'),
        pw.SizedBox(height: 4),
        _buildItemsTable(s.items),

        // Totales en línea
        pw.SizedBox(height: 6),
        pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text('Total ítems: ', style: const pw.TextStyle(fontSize: 8)),
              pw.Text(
                '${s.totalItems}',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Text('Peso total: ', style: const pw.TextStyle(fontSize: 8)),
              pw.Text(
                '${s.totalWeight.toStringAsFixed(1)} kg',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // Observaciones
        if (s.notes != null && s.notes!.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: PdfColors.amber50,
              borderRadius: pw.BorderRadius.circular(3),
              border: pw.Border.all(color: PdfColors.amber200),
            ),
            child: pw.Text(s.notes!, style: const pw.TextStyle(fontSize: 7)),
          ),
        ],

        pw.Spacer(),

        // Firmas: 1-Conductor, 2-Oficina, 3-Cliente
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _signatureBlock('Conductor', s.driverName ?? s.carrierName),
            _signatureBlock('Oficina', s.preparedBy),
            _signatureBlock('Cliente', s.receivedBy),
          ],
        ),

        pw.SizedBox(height: 4),

        // Footer por copia
        pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
          ),
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                _companyName,
                style: const pw.TextStyle(
                  fontSize: 6,
                  color: PdfColors.grey500,
                ),
              ),
              pw.Text(
                '${_dateFormat.format(s.dispatchDate)} - ${s.code}',
                style: const pw.TextStyle(
                  fontSize: 6,
                  color: PdfColors.grey500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Helpers ──

  /// Línea de corte entre las dos copias.
  static pw.Widget _cutLine() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Container(height: 0.5, color: PdfColors.grey300),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            child: pw.Text(
              'CORTAR AQUÍ',
              style: pw.TextStyle(
                fontSize: 6,
                color: PdfColors.grey400,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Container(height: 0.5, color: PdfColors.grey300),
          ),
        ],
      ),
    );
  }

  static pw.Widget _header(pw.MemoryImage? logo, String code) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'REMISIÓN DE ENVÍO',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey900,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '#$code',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            if (logo != null)
              pw.Container(width: 36, height: 36, child: pw.Image(logo))
            else
              pw.Container(
                width: 36,
                height: 36,
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue800,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'IM',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            pw.SizedBox(height: 2),
            pw.Text(
              _companyName,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            ),
            pw.Text(
              _companyNit,
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
            ),
            pw.Text(
              _companyAddress,
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
            ),
            pw.Text(
              '$_companyPhone  |  $_companyEmail',
              style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildItemsTable(List<ShipmentOrderItem> items) {
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(
        fontSize: 7,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellStyle: const pw.TextStyle(fontSize: 7),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      cellAlignment: pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FixedColumnWidth(16), // #
        7: const pw.FixedColumnWidth(22), // Ok
      },
      headers: [
        '#',
        'Tipo',
        'Descripción',
        'Cant.',
        'Unid.',
        'Peso (kg)',
        'Dimensiones',
        'Ok',
      ],
      data: items.asMap().entries.map((entry) {
        final i = entry.value;
        return [
          '${entry.key + 1}',
          _itemTypeLabel(i.itemType),
          i.description,
          i.quantity.toStringAsFixed(
            i.quantity == i.quantity.roundToDouble() ? 0 : 2,
          ),
          i.unit,
          i.weightKg != null ? i.weightKg!.toStringAsFixed(1) : '-',
          i.dimensions ?? '-',
          '[ ]',
        ];
      }).toList(),
    );
  }

  static pw.Widget _signatureBlock(String title, String? name) {
    return pw.Container(
      width: 140,
      child: pw.Column(
        children: [
          pw.SizedBox(height: 25),
          pw.Container(
            width: double.infinity,
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey600)),
            ),
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Column(
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (name != null && name.isNotEmpty)
                  pw.Text(
                    name,
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _label(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 7,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.grey500,
        letterSpacing: 1,
      ),
    );
  }

  static pw.Widget _field(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 6,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey500,
          ),
        ),
        pw.SizedBox(height: 1),
        pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  static PdfColor _statusColor(ShipmentStatus status) {
    switch (status) {
      case ShipmentStatus.borrador:
        return PdfColors.grey;
      case ShipmentStatus.despachada:
        return PdfColors.blue;
      case ShipmentStatus.enTransito:
        return PdfColors.orange;
      case ShipmentStatus.entregada:
        return PdfColors.green;
      case ShipmentStatus.anulada:
        return PdfColors.red;
    }
  }

  static String _itemTypeLabel(ShipmentItemType t) {
    switch (t) {
      case ShipmentItemType.producto:
        return 'Producto';
      case ShipmentItemType.material:
        return 'Material';
      case ShipmentItemType.pieza:
        return 'Pieza';
      case ShipmentItemType.herramienta:
        return 'Herramienta';
      case ShipmentItemType.otro:
        return 'Otro';
    }
  }

  static Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final data = await rootBundle.load('lib/photo/logo_empresa.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }
}
