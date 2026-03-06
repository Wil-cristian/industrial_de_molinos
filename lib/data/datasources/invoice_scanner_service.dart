import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/logger.dart';
import '../../domain/entities/purchase_order.dart';
import 'supabase_datasource.dart';

// =====================================================
// SERVICIO: Escaneo de facturas con OpenAI Vision
// =====================================================
// Flujo: Foto → Supabase Storage → Edge Function → OpenAI Vision → JSON
//
// Uso:
//   final result = await InvoiceScannerService.scanFromFile(platformFile);
//   if (result.success) {
//     // result.data contiene InvoiceScanResult con todos los datos
//   }

/// Resultado individual de un ítem extraído de la factura
class ScannedInvoiceItem {
  final String? referenceCode;
  final String description;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double discount;
  final double taxRate;
  final double taxAmount;
  final double subtotal;
  final double total;

  ScannedInvoiceItem({
    this.referenceCode,
    required this.description,
    this.quantity = 1,
    this.unit = 'UND',
    this.unitPrice = 0,
    this.discount = 0,
    this.taxRate = 19.0,
    this.taxAmount = 0,
    this.subtotal = 0,
    this.total = 0,
  });

  factory ScannedInvoiceItem.fromJson(Map<String, dynamic> json) {
    return ScannedInvoiceItem(
      referenceCode: json['reference_code'] as String?,
      description: json['description'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unit: json['unit'] as String? ?? 'UND',
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 19.0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'reference_code': referenceCode,
    'description': description,
    'quantity': quantity,
    'unit': unit,
    'unit_price': unitPrice,
    'discount': discount,
    'tax_rate': taxRate,
    'tax_amount': taxAmount,
    'subtotal': subtotal,
    'total': total,
  };
}

/// Datos del proveedor extraídos
class ScannedSupplierInfo {
  final String? name;
  final String? tradeName;
  final String? documentType;
  final String? documentNumber;
  final String? address;
  final String? phone;
  final String? email;
  final String? city;

  ScannedSupplierInfo({
    this.name,
    this.tradeName,
    this.documentType,
    this.documentNumber,
    this.address,
    this.phone,
    this.email,
    this.city,
  });

  factory ScannedSupplierInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ScannedSupplierInfo();
    return ScannedSupplierInfo(
      name: json['name'] as String?,
      tradeName: json['trade_name'] as String?,
      documentType: json['document_type'] as String?,
      documentNumber: json['document_number'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      city: json['city'] as String?,
    );
  }
}

/// Datos completos extraídos de la factura escaneada
class InvoiceScanResult {
  final double confidence;
  final ScannedSupplierInfo supplier;
  final String? buyerName;
  final String? buyerDocument;

  // Datos de la factura
  final String? invoiceNumber;
  final DateTime? invoiceDate;
  final DateTime? dueDate;
  final String? cufe;
  final String? paymentMethod;
  final int creditDays;

  // Ítems
  final List<ScannedInvoiceItem> items;

  // Totales
  final double subtotal;
  final double discount;
  final double taxBase;
  final double taxRate;
  final double taxAmount;
  final double retentionRteFte;
  final double retentionIca;
  final double retentionIva;
  final double freight;
  final double total;

  final String? notes;

  // Metadata de uso de API
  final int totalTokens;
  final String? estimatedCost;

  // Imagen adjunta
  final String? imageUrl;
  final String? imagePath;

  InvoiceScanResult({
    this.confidence = 0,
    required this.supplier,
    this.buyerName,
    this.buyerDocument,
    this.invoiceNumber,
    this.invoiceDate,
    this.dueDate,
    this.cufe,
    this.paymentMethod,
    this.creditDays = 0,
    this.items = const [],
    this.subtotal = 0,
    this.discount = 0,
    this.taxBase = 0,
    this.taxRate = 19.0,
    this.taxAmount = 0,
    this.retentionRteFte = 0,
    this.retentionIca = 0,
    this.retentionIva = 0,
    this.freight = 0,
    this.total = 0,
    this.notes,
    this.totalTokens = 0,
    this.estimatedCost,
    this.imageUrl,
    this.imagePath,
  });

  factory InvoiceScanResult.fromJson(
    Map<String, dynamic> json, {
    String? imageUrl,
    String? imagePath,
  }) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final usage = json['usage'] as Map<String, dynamic>?;
    final totals = data['totals'] as Map<String, dynamic>? ?? {};
    final invoiceData = data['invoice'] as Map<String, dynamic>? ?? {};
    final buyer = data['buyer'] as Map<String, dynamic>?;

    DateTime? parseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return null;
      try {
        return DateTime.parse(dateStr);
      } catch (_) {
        return null;
      }
    }

    return InvoiceScanResult(
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
      supplier: ScannedSupplierInfo.fromJson(
        data['supplier'] as Map<String, dynamic>?,
      ),
      buyerName: buyer?['name'] as String?,
      buyerDocument: buyer?['document_number'] as String?,
      invoiceNumber: invoiceData['number'] as String?,
      invoiceDate: parseDate(invoiceData['date'] as String?),
      dueDate: parseDate(invoiceData['due_date'] as String?),
      cufe: invoiceData['cufe'] as String?,
      paymentMethod: invoiceData['payment_method'] as String?,
      creditDays: (invoiceData['credit_days'] as num?)?.toInt() ?? 0,
      items: (data['items'] as List?)
              ?.map((e) =>
                  ScannedInvoiceItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (totals['subtotal'] as num?)?.toDouble() ?? 0,
      discount: (totals['discount'] as num?)?.toDouble() ?? 0,
      taxBase: (totals['tax_base'] as num?)?.toDouble() ?? 0,
      taxRate: (totals['tax_rate'] as num?)?.toDouble() ?? 19.0,
      taxAmount: (totals['tax_amount'] as num?)?.toDouble() ?? 0,
      retentionRteFte:
          (totals['retention_rte_fte'] as num?)?.toDouble() ?? 0,
      retentionIca: (totals['retention_ica'] as num?)?.toDouble() ?? 0,
      retentionIva: (totals['retention_iva'] as num?)?.toDouble() ?? 0,
      freight: (totals['freight'] as num?)?.toDouble() ?? 0,
      total: (totals['total'] as num?)?.toDouble() ?? 0,
      notes: data['notes'] as String?,
      totalTokens: (usage?['total_tokens'] as num?)?.toInt() ?? 0,
      estimatedCost: usage?['estimated_cost_usd'] as String?,
      imageUrl: imageUrl,
      imagePath: imagePath,
    );
  }

  /// Convertir a PurchaseOrder prellenada (sin ID ni order_number)
  PurchaseOrder toPurchaseOrder({
    required String orderId,
    required String orderNumber,
    required String supplierId,
  }) {
    return PurchaseOrder(
      id: orderId,
      orderNumber: orderNumber,
      supplierId: supplierId,
      status: PurchaseOrderStatus.borrador,
      paymentStatus: PaymentStatus.pendiente,
      paymentMethod: paymentMethod,
      subtotal: subtotal,
      taxAmount: taxAmount,
      discountAmount: discount,
      total: total,
      amountPaid: 0,
      notes: notes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      supplierInvoiceNumber: invoiceNumber,
      supplierInvoiceDate: invoiceDate,
      cufe: cufe,
      taxRate: taxRate,
      retentionRteFte: retentionRteFte,
      retentionIca: retentionIca,
      retentionIva: retentionIva,
      freightAmount: freight,
      attachments: imagePath != null
          ? [
              {
                'name': 'factura_scan.jpg',
                'path': imagePath,
                'type': 'image/jpeg',
              }
            ]
          : [],
      creditDays: creditDays,
      dueDate: dueDate,
    );
  }

  /// Convertir ítems a PurchaseOrderItems
  List<PurchaseOrderItem> toPurchaseOrderItems(String orderId) {
    return items.map((item) {
      return PurchaseOrderItem(
        id: '', // se asigna en DB
        orderId: orderId,
        materialId: '', // se debe mapear manualmente
        quantity: item.quantity,
        unit: item.unit,
        unitPrice: item.unitPrice,
        subtotal: item.subtotal,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        taxRate: item.taxRate,
        taxAmount: item.taxAmount,
        discount: item.discount,
        referenceCode: item.referenceCode,
        description: item.description,
        itemTotal: item.total,
      );
    }).toList();
  }
}

/// Respuesta del servicio de escaneo
class ScanResponse {
  final bool success;
  final InvoiceScanResult? data;
  final String? error;

  ScanResponse({required this.success, this.data, this.error});
}

/// Servicio principal de escaneo de facturas
class InvoiceScannerService {
  static SupabaseClient get _client => SupabaseDataSource.client;
  static const String _bucket = 'attachments';
  static const String _functionName = 'scan-invoice';

  /// Escanear factura desde un PlatformFile (file_picker)
  static Future<ScanResponse> scanFromFile(PlatformFile file) async {
    try {
      AppLogger.info('📸 Iniciando escaneo de factura: ${file.name}');

      // 1. Leer bytes del archivo
      Uint8List fileBytes;
      if (file.bytes != null) {
        fileBytes = file.bytes!;
      } else if (file.path != null) {
        fileBytes = await File(file.path!).readAsBytes();
      } else {
        throw Exception('No se pudo leer el archivo: ${file.name}');
      }

      // 2. Detectar MIME type
      final ext = file.extension?.toLowerCase() ?? 'jpg';
      String mimeType;
      switch (ext) {
        case 'png':
          mimeType = 'image/png';
          break;
        case 'webp':
          mimeType = 'image/webp';
          break;
        default:
          mimeType = 'image/jpeg';
      }

      // 3. Convertir a base64 y enviar directo (evita problemas de URL pública)
      final base64Image = 'data:$mimeType;base64,${base64Encode(fileBytes)}';
      AppLogger.info('☁️ Imagen codificada: ${(fileBytes.length / 1024).toStringAsFixed(0)} KB');

      // 4. Llamar Edge Function con base64
      final result = await _callScanFunction(base64Image, isBase64: true);

      if (result == null) {
        return ScanResponse(
          success: false,
          error: 'No se recibió respuesta de la función de escaneo',
        );
      }

      // 5. Parsear resultado
      final scanResult = InvoiceScanResult.fromJson(
        result,
      );

      AppLogger.success(
        '✅ Factura escaneada: ${scanResult.invoiceNumber} | '
        'Items: ${scanResult.items.length} | '
        'Total: \$${scanResult.total} | '
        'Tokens: ${scanResult.totalTokens}',
      );

      return ScanResponse(success: true, data: scanResult);
    } catch (e) {
      AppLogger.error('❌ Error escaneando factura: $e');
      return ScanResponse(success: false, error: e.toString());
    }
  }

  /// Escanear desde bytes en memoria (para cámara web)
  static Future<ScanResponse> scanFromBytes(
    Uint8List bytes, {
    String fileName = 'photo.jpg',
  }) async {
    try {
      AppLogger.info('📸 Escaneando desde bytes ($fileName)');

      // 1. Subir a Storage
      final storagePath = 'invoices/scan_${DateTime.now().millisecondsSinceEpoch}_$fileName';
      
      await _client.storage.from(_bucket).uploadBinary(
        storagePath,
        bytes,
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: true,
        ),
      );

      // 2. URL pública
      final publicUrl =
          _client.storage.from(_bucket).getPublicUrl(storagePath);

      // 3. Llamar función
      final result = await _callScanFunction(publicUrl);

      if (result == null) {
        return ScanResponse(
          success: false,
          error: 'No se recibió respuesta',
        );
      }

      final scanResult = InvoiceScanResult.fromJson(
        result,
        imageUrl: publicUrl,
        imagePath: storagePath,
      );

      AppLogger.success('✅ Escaneo completado: ${scanResult.invoiceNumber}');
      return ScanResponse(success: true, data: scanResult);
    } catch (e) {
      AppLogger.error('❌ Error escaneando: $e');
      return ScanResponse(success: false, error: e.toString());
    }
  }

  /// Subir imagen al bucket de Storage
  static Future<String> _uploadImage(PlatformFile file) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = file.name
        .replaceAll(RegExp(r'[^\w\-.]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final storagePath = 'invoices/scan_${timestamp}_$safeName';

    Uint8List fileBytes;
    if (file.bytes != null) {
      fileBytes = file.bytes!;
    } else if (file.path != null) {
      fileBytes = await File(file.path!).readAsBytes();
    } else {
      throw Exception('No se pudo leer el archivo: ${file.name}');
    }

    // Detectar MIME type
    final ext = file.extension?.toLowerCase() ?? 'jpg';
    String mimeType;
    switch (ext) {
      case 'png':
        mimeType = 'image/png';
        break;
      case 'webp':
        mimeType = 'image/webp';
        break;
      case 'pdf':
        mimeType = 'application/pdf';
        break;
      default:
        mimeType = 'image/jpeg';
    }

    await _client.storage.from(_bucket).uploadBinary(
      storagePath,
      fileBytes,
      fileOptions: FileOptions(contentType: mimeType, upsert: true),
    );

    return storagePath;
  }

  /// Llamar a la Edge Function scan-invoice
  static Future<Map<String, dynamic>?> _callScanFunction(
    String imageData, {
    bool isBase64 = false,
  }) async {
    final body = isBase64
        ? {'image_base64': imageData}
        : {'image_url': imageData};

    final response = await _client.functions.invoke(
      _functionName,
      body: body,
    );

    if (response.status != 200) {
      final errorMsg = response.data is Map
          ? response.data['error'] ?? 'Error ${response.status}'
          : 'Error ${response.status}';
      throw Exception('Edge Function error: $errorMsg');
    }

    final data = response.data;
    if (data is Map<String, dynamic>) {
      if (data['success'] == true) {
        return data;
      } else {
        throw Exception(data['error'] ?? 'Error desconocido del servidor');
      }
    }

    return null;
  }

  /// Verificar si el servicio está disponible (API key configurada)
  static Future<bool> isAvailable() async {
    try {
      // Intento liviano: invoke con body vacío para ver si la función existe
      await _client.functions.invoke(
        _functionName,
        body: {'ping': true},
      );
      // Si responde (aunque sea error), la función existe
      return true;
    } catch (e) {
      AppLogger.warning('⚠️ Servicio de escaneo no disponible: $e');
      return false;
    }
  }
}
