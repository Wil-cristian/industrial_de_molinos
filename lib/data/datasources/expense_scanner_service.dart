import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/logger.dart';
import '../../domain/entities/cash_movement.dart';
import 'supabase_datasource.dart';

// =====================================================
// SERVICIO: Escaneo de gastos con IA
// =====================================================
// Flujo: Foto/PDF → base64 → Edge Function (scan-expense)
//        → OpenAI Vision → JSON con categoría + monto
//
// Uso:
//   final result = await ExpenseScannerService.scanFromFile(file);
//   if (result.success) {
//     // result.data contiene ExpenseScanResult
//   }

/// Resultado de un ítem individual del gasto escaneado
class ScannedExpenseItem {
  final String description;
  final double quantity;
  final double unitPrice;
  final double total;

  ScannedExpenseItem({
    required this.description,
    this.quantity = 1,
    this.unitPrice = 0,
    this.total = 0,
  });

  factory ScannedExpenseItem.fromJson(Map<String, dynamic> json) {
    return ScannedExpenseItem(
      description: json['description'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Datos del proveedor extraídos del gasto
class ScannedExpenseSupplier {
  final String? name;
  final String? documentNumber;
  final String? city;

  ScannedExpenseSupplier({this.name, this.documentNumber, this.city});

  factory ScannedExpenseSupplier.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ScannedExpenseSupplier();
    return ScannedExpenseSupplier(
      name: json['name'] as String?,
      documentNumber: json['document_number'] as String?,
      city: json['city'] as String?,
    );
  }
}

/// Resultado completo del escaneo de gasto
class ExpenseScanResult {
  final double confidence;
  final MovementCategory category;
  final String categoryReason;
  final String documentType;
  final ScannedExpenseSupplier supplier;

  // Datos del gasto
  final String description;
  final DateTime? date;
  final String? reference;
  final double subtotal;
  final double ivaAmount;
  final double total;
  final String? paymentMethod;

  // Ítems desglosados
  final List<ScannedExpenseItem> items;
  final String? notes;

  // Metadata
  final int totalTokens;
  final String? estimatedCost;

  ExpenseScanResult({
    this.confidence = 0,
    required this.category,
    this.categoryReason = '',
    this.documentType = 'OTRO',
    required this.supplier,
    required this.description,
    this.date,
    this.reference,
    this.subtotal = 0,
    this.ivaAmount = 0,
    this.total = 0,
    this.paymentMethod,
    this.items = const [],
    this.notes,
    this.totalTokens = 0,
    this.estimatedCost,
  });

  factory ExpenseScanResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final usage = json['usage'] as Map<String, dynamic>?;
    final expense = data['expense'] as Map<String, dynamic>? ?? {};

    // Parsear categoría
    final categoryStr = data['category'] as String? ?? 'gastos_reducibles';
    final category = _parseCategory(categoryStr);

    // Parsear fecha
    DateTime? date;
    final dateStr = expense['date'] as String?;
    if (dateStr != null && dateStr.isNotEmpty) {
      try {
        date = DateTime.parse(dateStr);
      } catch (_) {}
    }

    // Parsear ítems
    final rawItems = data['items'] as List?;
    final items =
        rawItems
            ?.map((e) => ScannedExpenseItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return ExpenseScanResult(
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
      category: category,
      categoryReason: data['category_reason'] as String? ?? '',
      documentType: data['document_type'] as String? ?? 'OTRO',
      supplier: ScannedExpenseSupplier.fromJson(
        data['supplier'] as Map<String, dynamic>?,
      ),
      description: expense['description'] as String? ?? 'Gasto escaneado',
      date: date,
      reference: expense['reference'] as String?,
      subtotal: (expense['subtotal'] as num?)?.toDouble() ?? 0,
      ivaAmount: (expense['iva_amount'] as num?)?.toDouble() ?? 0,
      total: (expense['total'] as num?)?.toDouble() ?? 0,
      paymentMethod: expense['payment_method'] as String?,
      items: items,
      notes: data['notes'] as String?,
      totalTokens: (usage?['total_tokens'] as num?)?.toInt() ?? 0,
      estimatedCost: usage?['estimated_cost_usd'] as String?,
    );
  }

  static MovementCategory _parseCategory(String value) {
    switch (value) {
      case 'consumibles':
        return MovementCategory.consumibles;
      case 'servicios_publicos':
        return MovementCategory.servicios_publicos;
      case 'papeleria':
        return MovementCategory.papeleria;
      case 'nomina':
        return MovementCategory.nomina;
      case 'impuestos':
        return MovementCategory.impuestos;
      case 'cuidado_personal':
        return MovementCategory.cuidado_personal;
      case 'transporte':
        return MovementCategory.transporte;
      case 'gastos_reducibles':
      default:
        return MovementCategory.gastos_reducibles;
    }
  }
}

/// Respuesta del servicio de escaneo
class ExpenseScanResponse {
  final bool success;
  final ExpenseScanResult? data;
  final String? error;

  ExpenseScanResponse({required this.success, this.data, this.error});
}

/// Servicio principal de escaneo de gastos con IA
class ExpenseScannerService {
  static SupabaseClient get _client => SupabaseDataSource.client;
  static const String _functionName = 'scan-expense';
  static const int _maxRetries = 3;

  /// Escanear gasto desde un PlatformFile (file_picker)
  static Future<ExpenseScanResponse> scanFromFile(PlatformFile file) async {
    try {
      AppLogger.info('📸 Iniciando escaneo de gasto: ${file.name}');

      Uint8List fileBytes;
      if (file.bytes != null) {
        fileBytes = file.bytes!;
      } else if (file.path != null) {
        fileBytes = await File(file.path!).readAsBytes();
      } else {
        throw Exception('No se pudo leer el archivo: ${file.name}');
      }

      return _scanFromBytes(fileBytes, file.extension?.toLowerCase() ?? 'jpg');
    } catch (e) {
      AppLogger.error('❌ Error escaneando gasto: $e');
      return ExpenseScanResponse(success: false, error: e.toString());
    }
  }

  /// Escanear gasto desde bytes (cámara)
  static Future<ExpenseScanResponse> scanFromBytes(
    Uint8List bytes, {
    String extension = 'jpg',
  }) async {
    try {
      AppLogger.info('📸 Escaneando gasto desde bytes');
      return _scanFromBytes(bytes, extension);
    } catch (e) {
      AppLogger.error('❌ Error escaneando gasto: $e');
      return ExpenseScanResponse(success: false, error: e.toString());
    }
  }

  static Future<ExpenseScanResponse> _scanFromBytes(
    Uint8List bytes,
    String ext,
  ) async {
    // Detectar MIME type
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

    final base64Image = 'data:$mimeType;base64,${base64Encode(bytes)}';
    AppLogger.info(
      '☁️ Imagen codificada: ${(bytes.length / 1024).toStringAsFixed(0)} KB',
    );

    final result = await _callWithRetry(base64Image);

    if (result == null) {
      return ExpenseScanResponse(
        success: false,
        error: 'No se recibió respuesta de la función de escaneo',
      );
    }

    final scanResult = ExpenseScanResult.fromJson(result);

    AppLogger.success(
      '✅ Gasto escaneado: ${scanResult.description} | '
      'Categoría: ${scanResult.category.name} | '
      'Total: \$${scanResult.total} | '
      'Tokens: ${scanResult.totalTokens}',
    );

    return ExpenseScanResponse(success: true, data: scanResult);
  }

  static Future<Map<String, dynamic>?> _callFunction(String base64Data) async {
    final response = await _client.functions.invoke(
      _functionName,
      body: {'image_base64': base64Data},
    );

    if (response.status != 200) {
      if (response.status == 546) {
        throw Exception('WORKER_LIMIT: Reintente en unos segundos.');
      }
      if (response.status == 504) {
        throw Exception('GATEWAY_TIMEOUT: La función tardó demasiado.');
      }
      final errorMsg = response.data is Map
          ? response.data['error'] ?? 'Error ${response.status}'
          : 'Error ${response.status}';
      throw Exception('Edge Function error: $errorMsg');
    }

    final data = response.data;
    if (data is Map<String, dynamic> && data['success'] == true) {
      return data;
    }

    final errorMsg = data is Map
        ? data['error'] ?? 'Error desconocido'
        : 'Error desconocido';
    throw Exception(errorMsg.toString());
  }

  static Future<Map<String, dynamic>?> _callWithRetry(String base64Data) async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        return await _callFunction(base64Data);
      } catch (e) {
        final msg = e.toString();
        final isRetryable =
            msg.contains('WORKER_LIMIT') || msg.contains('GATEWAY_TIMEOUT');
        if (!isRetryable || attempt == _maxRetries) rethrow;

        final delay = 2 * attempt;
        AppLogger.warning(
          '⚠️ Reintentando escaneo de gasto ($attempt/$_maxRetries) en ${delay}s...',
        );
        await Future.delayed(Duration(seconds: delay));
      }
    }
    return null;
  }
}
