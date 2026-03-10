import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_datasource.dart';

/// Datasource para control de IVA: facturas, liquidaciones, configuración
class IvaDataSource {
  static SupabaseClient get _client => SupabaseDataSource.client;

  // ─────────────────────────────────────────────────────────
  // FACTURAS IVA
  // ─────────────────────────────────────────────────────────

  /// Obtener facturas IVA filtradas por periodo y/o tipo
  static Future<List<IvaInvoice>> getInvoices({
    String? period,
    String? type,
    int limit = 500,
  }) async {
    final params = <String, dynamic>{'p_limit': limit};
    if (period != null) params['p_period'] = period;
    if (type != null) params['p_type'] = type;

    final response = await _client.rpc('get_iva_invoices', params: params);
    return (response as List).map((j) => IvaInvoice.fromJson(j)).toList();
  }

  /// Crear factura IVA
  static Future<IvaInvoice> createInvoice(IvaInvoice invoice) async {
    final data = invoice.toInsertJson();
    final response = await _client
        .from('iva_invoices')
        .insert(data)
        .select()
        .single();
    return IvaInvoice.fromJson(response);
  }

  /// Buscar facturas existentes por número de factura
  static Future<List<IvaInvoice>> findByInvoiceNumber(String invoiceNumber) async {
    final trimmed = invoiceNumber.trim();
    if (trimmed.isEmpty) return [];
    final response = await _client
        .from('iva_invoices')
        .select()
        .eq('invoice_number', trimmed)
        .order('created_at', ascending: false);
    return (response as List).map((j) => IvaInvoice.fromJson(j)).toList();
  }

  /// Actualizar factura IVA
  static Future<IvaInvoice> updateInvoice(IvaInvoice invoice) async {
    final data = invoice.toInsertJson();
    final response = await _client
        .from('iva_invoices')
        .update(data)
        .eq('id', invoice.id!)
        .select()
        .single();
    return IvaInvoice.fromJson(response);
  }

  /// Eliminar factura IVA
  static Future<void> deleteInvoice(String id) async {
    await _client.from('iva_invoices').delete().eq('id', id);
  }

  // ─────────────────────────────────────────────────────────
  // LIQUIDACIÓN BIMESTRAL
  // ─────────────────────────────────────────────────────────

  /// Liquidar un bimestre (calcula IVA neto + anticipo simple)
  static Future<BimonthlySettlement> liquidarBimestre(String period) async {
    final response = await _client.rpc(
      'liquidar_bimestre',
      params: {'p_period': period},
    );
    return BimonthlySettlement.fromJson(response as Map<String, dynamic>);
  }

  /// Obtener resumen bimestral actual
  static Future<BimonthlySettlement> getCurrentSummary() async {
    final response = await _client.rpc('get_iva_current_summary');
    return BimonthlySettlement.fromJson(response as Map<String, dynamic>);
  }

  /// Obtener historial de liquidaciones
  static Future<List<SettlementRecord>> getSettlements({int? year}) async {
    final params = <String, dynamic>{};
    if (year != null) params['p_year'] = year;

    final response = await _client.rpc('get_iva_settlements', params: params);
    return (response as List).map((j) => SettlementRecord.fromJson(j)).toList();
  }

  /// Marcar liquidación como declarada
  static Future<void> markAsSettled(String period) async {
    await _client
        .from('iva_bimonthly_settlements')
        .update({
          'is_settled': true,
          'settled_at': DateTime.now().toIso8601String(),
        })
        .eq('bimonthly_period', period);
  }

  // ─────────────────────────────────────────────────────────
  // RESUMEN BIMESTRAL (VISTA)
  // ─────────────────────────────────────────────────────────

  /// Obtener resúmenes bimestrales desde la vista
  static Future<List<BimonthlySummaryView>> getBimonthlySummaries() async {
    final response = await _client
        .from('v_iva_bimonthly_summary')
        .select()
        .order('bimonthly_period', ascending: false);
    return (response as List)
        .map((j) => BimonthlySummaryView.fromJson(j))
        .toList();
  }

  // ─────────────────────────────────────────────────────────
  // CONFIGURACIÓN IVA
  // ─────────────────────────────────────────────────────────

  /// Obtener configuración del año
  static Future<IvaConfig?> getConfig(int year) async {
    final response = await _client
        .from('iva_config')
        .select()
        .eq('year', year)
        .maybeSingle();
    if (response == null) return null;
    return IvaConfig.fromJson(response);
  }

  /// Guardar/actualizar configuración
  static Future<IvaConfig> saveConfig(IvaConfig config) async {
    final response = await _client
        .from('iva_config')
        .upsert(config.toJson(), onConflict: 'year')
        .select()
        .single();
    return IvaConfig.fromJson(response);
  }
}

// ═══════════════════════════════════════════════════════════
//  MODELOS
// ═══════════════════════════════════════════════════════════

/// Factura IVA (compra o venta)
class IvaInvoice {
  final String? id;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final String company;
  final String invoiceType; // 'COMPRA' | 'VENTA'
  final double baseAmount;
  final double ivaAmount;
  final double totalAmount;
  final bool hasReteiva;
  final double reteivaAmount;
  final String bimonthlyPeriod;
  final String? notes;
  final DateTime? createdAt;

  // Campos adicionales (migración 053)
  final String? companyDocument; // NIT del emisor
  final String? cufe; // Código Único Facturación Electrónica
  final String? purchaseOrderId; // Vínculo con purchase_orders
  final double rteFteAmount; // Retención en la Fuente
  final double reteIcaAmount; // Retención ICA

  IvaInvoice({
    this.id,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.company,
    required this.invoiceType,
    required this.baseAmount,
    required this.ivaAmount,
    required this.totalAmount,
    this.hasReteiva = false,
    this.reteivaAmount = 0,
    required this.bimonthlyPeriod,
    this.notes,
    this.createdAt,
    this.companyDocument,
    this.cufe,
    this.purchaseOrderId,
    this.rteFteAmount = 0,
    this.reteIcaAmount = 0,
  });

  factory IvaInvoice.fromJson(Map<String, dynamic> json) {
    return IvaInvoice(
      id: json['id'] as String?,
      invoiceNumber: json['invoice_number'] as String? ?? '',
      invoiceDate: DateTime.parse(json['invoice_date'] as String),
      company: json['company'] as String? ?? '',
      invoiceType: json['invoice_type'] as String? ?? 'COMPRA',
      baseAmount: (json['base_amount'] as num?)?.toDouble() ?? 0,
      ivaAmount: (json['iva_amount'] as num?)?.toDouble() ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      hasReteiva: json['has_reteiva'] as bool? ?? false,
      reteivaAmount: (json['reteiva_amount'] as num?)?.toDouble() ?? 0,
      bimonthlyPeriod: json['bimonthly_period'] as String? ?? '',
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      // Campos migración 053
      companyDocument: json['company_document'] as String?,
      cufe: json['cufe'] as String?,
      purchaseOrderId: json['purchase_order_id'] as String?,
      rteFteAmount: (json['rte_fte_amount'] as num?)?.toDouble() ?? 0,
      reteIcaAmount: (json['rete_ica_amount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'invoice_number': invoiceNumber,
    'invoice_date': invoiceDate.toIso8601String().substring(0, 10),
    'company': company,
    'invoice_type': invoiceType,
    'base_amount': baseAmount,
    'iva_amount': ivaAmount,
    'total_amount': totalAmount,
    'has_reteiva': hasReteiva,
    'reteiva_amount': reteivaAmount,
    'bimonthly_period': bimonthlyPeriod,
    'notes': notes,
    // Campos migración 053
    'company_document': companyDocument,
    'cufe': cufe,
    'purchase_order_id': purchaseOrderId,
    'rte_fte_amount': rteFteAmount,
    'rete_ica_amount': reteIcaAmount,
  };

  IvaInvoice copyWith({
    String? id,
    String? invoiceNumber,
    DateTime? invoiceDate,
    String? company,
    String? invoiceType,
    double? baseAmount,
    double? ivaAmount,
    double? totalAmount,
    bool? hasReteiva,
    double? reteivaAmount,
    String? bimonthlyPeriod,
    String? notes,
    String? companyDocument,
    String? cufe,
    String? purchaseOrderId,
    double? rteFteAmount,
    double? reteIcaAmount,
  }) {
    return IvaInvoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      company: company ?? this.company,
      invoiceType: invoiceType ?? this.invoiceType,
      baseAmount: baseAmount ?? this.baseAmount,
      ivaAmount: ivaAmount ?? this.ivaAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      hasReteiva: hasReteiva ?? this.hasReteiva,
      reteivaAmount: reteivaAmount ?? this.reteivaAmount,
      bimonthlyPeriod: bimonthlyPeriod ?? this.bimonthlyPeriod,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      companyDocument: companyDocument ?? this.companyDocument,
      cufe: cufe ?? this.cufe,
      purchaseOrderId: purchaseOrderId ?? this.purchaseOrderId,
      rteFteAmount: rteFteAmount ?? this.rteFteAmount,
      reteIcaAmount: reteIcaAmount ?? this.reteIcaAmount,
    );
  }
}

/// Liquidación bimestral (resultado del RPC)
class BimonthlySettlement {
  final String period;
  final String bimesterName;
  final int year;
  final double baseVentas;
  final double ivaVentas;
  final double baseCompras;
  final double ivaCompras;
  final double ivaNeto;
  final double anticipoSimple;
  final double reteiva;
  final double totalAPagar;
  final double tarifaSimple;
  // Retenciones adicionales (migración 053)
  final double rteFte;
  final double reteIca;

  BimonthlySettlement({
    required this.period,
    required this.bimesterName,
    required this.year,
    required this.baseVentas,
    required this.ivaVentas,
    required this.baseCompras,
    required this.ivaCompras,
    required this.ivaNeto,
    required this.anticipoSimple,
    required this.reteiva,
    required this.totalAPagar,
    required this.tarifaSimple,
    this.rteFte = 0,
    this.reteIca = 0,
  });

  factory BimonthlySettlement.fromJson(Map<String, dynamic> json) {
    return BimonthlySettlement(
      period: json['period'] as String? ?? '',
      bimesterName: json['bimester_name'] as String? ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      baseVentas: (json['base_ventas'] as num?)?.toDouble() ?? 0,
      ivaVentas: (json['iva_ventas'] as num?)?.toDouble() ?? 0,
      baseCompras: (json['base_compras'] as num?)?.toDouble() ?? 0,
      ivaCompras: (json['iva_compras'] as num?)?.toDouble() ?? 0,
      ivaNeto: (json['iva_neto'] as num?)?.toDouble() ?? 0,
      anticipoSimple: (json['anticipo_simple'] as num?)?.toDouble() ?? 0,
      reteiva: (json['reteiva'] as num?)?.toDouble() ?? 0,
      totalAPagar: (json['total_a_pagar'] as num?)?.toDouble() ?? 0,
      tarifaSimple: (json['tarifa_simple'] as num?)?.toDouble() ?? 0.02,
      rteFte: (json['rte_fte'] as num?)?.toDouble() ?? 0,
      reteIca: (json['rete_ica'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Registro de liquidación guardada
class SettlementRecord {
  final String id;
  final String bimonthlyPeriod;
  final int year;
  final int bimester;
  final double totalBaseVentas;
  final double totalIvaVentas;
  final double totalBaseCompras;
  final double totalIvaCompras;
  final double ivaNeto;
  final double anticipoSimple;
  final double reteivaTotal;
  final double totalAPagar;
  final bool isSettled;
  final DateTime? settledAt;

  SettlementRecord({
    required this.id,
    required this.bimonthlyPeriod,
    required this.year,
    required this.bimester,
    required this.totalBaseVentas,
    required this.totalIvaVentas,
    required this.totalBaseCompras,
    required this.totalIvaCompras,
    required this.ivaNeto,
    required this.anticipoSimple,
    required this.reteivaTotal,
    required this.totalAPagar,
    required this.isSettled,
    this.settledAt,
  });

  factory SettlementRecord.fromJson(Map<String, dynamic> json) {
    return SettlementRecord(
      id: json['id'] as String? ?? '',
      bimonthlyPeriod: json['bimonthly_period'] as String? ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      bimester: (json['bimester'] as num?)?.toInt() ?? 0,
      totalBaseVentas: (json['total_base_ventas'] as num?)?.toDouble() ?? 0,
      totalIvaVentas: (json['total_iva_ventas'] as num?)?.toDouble() ?? 0,
      totalBaseCompras: (json['total_base_compras'] as num?)?.toDouble() ?? 0,
      totalIvaCompras: (json['total_iva_compras'] as num?)?.toDouble() ?? 0,
      ivaNeto: (json['iva_neto'] as num?)?.toDouble() ?? 0,
      anticipoSimple: (json['anticipo_simple'] as num?)?.toDouble() ?? 0,
      reteivaTotal: (json['reteiva_total'] as num?)?.toDouble() ?? 0,
      totalAPagar: (json['total_a_pagar'] as num?)?.toDouble() ?? 0,
      isSettled: json['is_settled'] as bool? ?? false,
      settledAt: json['settled_at'] != null
          ? DateTime.parse(json['settled_at'] as String)
          : null,
    );
  }

  String get bimesterName {
    const names = [
      '',
      'Ene-Feb',
      'Mar-Abr',
      'May-Jun',
      'Jul-Ago',
      'Sep-Oct',
      'Nov-Dic',
    ];
    return bimester >= 1 && bimester <= 6 ? names[bimester] : 'Desconocido';
  }
}

/// Resumen bimestral desde la vista
class BimonthlySummaryView {
  final String bimonthlyPeriod;
  final int year;
  final int bimester;
  final String bimesterName;
  final double baseVentas;
  final double ivaVentas;
  final double totalVentas;
  final int numVentas;
  final double baseCompras;
  final double ivaCompras;
  final double totalCompras;
  final int numCompras;
  final double totalReteiva;
  final int totalFacturas;
  // Campos de retenciones (migración 053)
  final double totalRteFte;
  final double totalReteIca;

  BimonthlySummaryView({
    required this.bimonthlyPeriod,
    required this.year,
    required this.bimester,
    required this.bimesterName,
    required this.baseVentas,
    required this.ivaVentas,
    required this.totalVentas,
    required this.numVentas,
    required this.baseCompras,
    required this.ivaCompras,
    required this.totalCompras,
    required this.numCompras,
    required this.totalReteiva,
    required this.totalFacturas,
    this.totalRteFte = 0,
    this.totalReteIca = 0,
  });

  factory BimonthlySummaryView.fromJson(Map<String, dynamic> json) {
    return BimonthlySummaryView(
      bimonthlyPeriod: json['bimonthly_period'] as String? ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      bimester: (json['bimester'] as num?)?.toInt() ?? 0,
      bimesterName: json['bimester_name'] as String? ?? '',
      baseVentas: (json['base_ventas'] as num?)?.toDouble() ?? 0,
      ivaVentas: (json['iva_ventas'] as num?)?.toDouble() ?? 0,
      totalVentas: (json['total_ventas'] as num?)?.toDouble() ?? 0,
      numVentas: (json['num_ventas'] as num?)?.toInt() ?? 0,
      baseCompras: (json['base_compras'] as num?)?.toDouble() ?? 0,
      ivaCompras: (json['iva_compras'] as num?)?.toDouble() ?? 0,
      totalCompras: (json['total_compras'] as num?)?.toDouble() ?? 0,
      numCompras: (json['num_compras'] as num?)?.toInt() ?? 0,
      totalReteiva: (json['total_reteiva'] as num?)?.toDouble() ?? 0,
      totalFacturas: (json['total_facturas'] as num?)?.toInt() ?? 0,
      totalRteFte: (json['total_rte_fte'] as num?)?.toDouble() ?? 0,
      totalReteIca: (json['total_rete_ica'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Configuración IVA por año
class IvaConfig {
  final String? id;
  final int year;
  final double uvtValue;
  final int grupoRst;
  final double tarifaSimple;
  final double ivaRate;
  final String? notes;

  IvaConfig({
    this.id,
    required this.year,
    required this.uvtValue,
    required this.grupoRst,
    required this.tarifaSimple,
    required this.ivaRate,
    this.notes,
  });

  factory IvaConfig.fromJson(Map<String, dynamic> json) {
    return IvaConfig(
      id: json['id'] as String?,
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      uvtValue: (json['uvt_value'] as num?)?.toDouble() ?? 49799,
      grupoRst: (json['grupo_rst'] as num?)?.toInt() ?? 2,
      tarifaSimple: (json['tarifa_simple'] as num?)?.toDouble() ?? 0.02,
      ivaRate: (json['iva_rate'] as num?)?.toDouble() ?? 0.19,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'year': year,
    'uvt_value': uvtValue,
    'grupo_rst': grupoRst,
    'tarifa_simple': tarifaSimple,
    'iva_rate': ivaRate,
    'notes': notes,
  };
}

/// Helper: calcular periodo bimestral desde una fecha
String getBimonthlyPeriod(DateTime date) {
  final bimester = ((date.month - 1) ~/ 2) + 1;
  return '${date.year}-$bimester';
}

/// Helper: nombre del bimestre
String getBimesterName(int bimester) {
  const names = [
    '',
    'Ene-Feb',
    'Mar-Abr',
    'May-Jun',
    'Jul-Ago',
    'Sep-Oct',
    'Nov-Dic',
  ];
  return bimester >= 1 && bimester <= 6 ? names[bimester] : 'Desconocido';
}
