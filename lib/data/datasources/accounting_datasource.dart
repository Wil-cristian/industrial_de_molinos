import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_datasource.dart';

/// Datasource para contabilidad: asientos, libro diario, balance general, estado de resultados
class AccountingDataSource {
  static SupabaseClient get _client => SupabaseDataSource.client;

  // ─────────────────────────────────────────────────────────
  // LIBRO DIARIO (Lista de asientos)
  // ─────────────────────────────────────────────────────────

  /// Obtener asientos contables con sus líneas (vía RPC)
  static Future<List<JournalEntry>> getJournalEntries({
    DateTime? startDate,
    DateTime? endDate,
    String? accountCode,
    String? referenceType,
    int limit = 200,
  }) async {
    final params = <String, dynamic>{'p_limit': limit};
    if (startDate != null) {
      params['p_start_date'] = startDate.toIso8601String().substring(0, 10);
    }
    if (endDate != null) {
      params['p_end_date'] = endDate.toIso8601String().substring(0, 10);
    }
    if (accountCode != null) params['p_account_code'] = accountCode;
    if (referenceType != null) params['p_reference_type'] = referenceType;

    final response = await _client.rpc('get_journal_entries', params: params);

    return (response as List)
        .map((json) => JournalEntry.fromJson(json))
        .toList();
  }

  // ─────────────────────────────────────────────────────────
  // BALANCE GENERAL
  // ─────────────────────────────────────────────────────────

  /// Obtener balance general hasta una fecha
  static Future<List<BalanceItem>> getBalanceGeneral({
    DateTime? hastaFecha,
  }) async {
    final params = <String, dynamic>{};
    if (hastaFecha != null) {
      params['p_hasta_fecha'] = hastaFecha.toIso8601String().substring(0, 10);
    }

    try {
      final response = await _client.rpc('get_balance_general', params: params);
      print('📊 Balance General RPC response type: ${response.runtimeType}');
      print('📊 Balance General RPC response: $response');

      final items = (response as List)
          .map((json) => BalanceItem.fromJson(json))
          .toList();
      print('📊 Balance General items parseados: ${items.length}');
      for (final item in items) {
        print(
          '  → ${item.tipo} | ${item.codigo} | ${item.cuenta} | ${item.saldo}',
        );
      }
      return items;
    } catch (e) {
      print('❌ Error en getBalanceGeneral: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────
  // ESTADO DE RESULTADOS
  // ─────────────────────────────────────────────────────────

  /// Obtener estado de resultados por rango de fechas
  static Future<List<ResultItem>> getEstadoResultados({
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final params = <String, dynamic>{};
    if (desde != null) {
      params['p_desde'] = desde.toIso8601String().substring(0, 10);
    }
    if (hasta != null) {
      params['p_hasta'] = hasta.toIso8601String().substring(0, 10);
    }

    final response = await _client.rpc('get_estado_resultados', params: params);

    return (response as List).map((json) => ResultItem.fromJson(json)).toList();
  }

  // ─────────────────────────────────────────────────────────
  // BALANCE DE COMPROBACIÓN
  // ─────────────────────────────────────────────────────────

  /// Obtener balance de comprobación (saldos por cuenta)
  static Future<List<TrialBalanceItem>> getBalanceComprobacion() async {
    final response = await _client
        .from('v_balance_comprobacion')
        .select()
        .order('codigo');

    return (response as List)
        .map((json) => TrialBalanceItem.fromJson(json))
        .toList();
  }

  // ─────────────────────────────────────────────────────────
  // LIBRO MAYOR (movimientos por cuenta)
  // ─────────────────────────────────────────────────────────

  /// Obtener libro mayor para una cuenta específica
  static Future<List<LedgerItem>> getLibroMayor({String? accountCode}) async {
    var query = _client.from('v_libro_mayor').select();
    if (accountCode != null) {
      query = query.eq('codigo', accountCode);
    }
    final response = await query.order('fecha').order('asiento');

    return (response as List).map((json) => LedgerItem.fromJson(json)).toList();
  }

  // ─────────────────────────────────────────────────────────
  // PLAN DE CUENTAS
  // ─────────────────────────────────────────────────────────

  /// Obtener plan de cuentas completo
  static Future<List<ChartAccount>> getChartOfAccounts() async {
    final response = await _client
        .from('chart_of_accounts')
        .select()
        .eq('is_active', true)
        .order('code');

    return (response as List)
        .map((json) => ChartAccount.fromJson(json))
        .toList();
  }

  // ─────────────────────────────────────────────────────────
  // P&L MENSUAL
  // ─────────────────────────────────────────────────────────

  /// Obtener P&L mensual (resumen)
  static Future<List<MonthlyPL>> getPyLMensual() async {
    final response = await _client
        .from('v_pyl_mensual')
        .select()
        .order('mes', ascending: false)
        .limit(12);

    return (response as List).map((json) => MonthlyPL.fromJson(json)).toList();
  }

  // ─────────────────────────────────────────────────────────
  // ESTADÍSTICAS GENERALES
  // ─────────────────────────────────────────────────────────

  /// Contar asientos totales
  static Future<int> countEntries() async {
    final response = await _client
        .from('journal_entries')
        .select('id')
        .eq('status', 'posted');
    return (response as List).length;
  }
}

// ═════════════════════════════════════════════════════════
// MODELOS DE DATOS
// ═════════════════════════════════════════════════════════

/// Línea de asiento contable
class JournalEntryLine {
  final String accountCode;
  final String accountName;
  final double debit;
  final double credit;

  JournalEntryLine({
    required this.accountCode,
    required this.accountName,
    required this.debit,
    required this.credit,
  });

  factory JournalEntryLine.fromJson(Map<String, dynamic> json) {
    return JournalEntryLine(
      accountCode: json['account_code'] ?? '',
      accountName: json['account_name'] ?? '',
      debit: (json['debit'] as num?)?.toDouble() ?? 0,
      credit: (json['credit'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Asiento contable con sus líneas
class JournalEntry {
  final String id;
  final String entryNumber;
  final DateTime entryDate;
  final String description;
  final String? referenceType;
  final String? referenceId;
  final double totalDebit;
  final double totalCredit;
  final bool isAuto;
  final String status;
  final DateTime createdAt;
  final List<JournalEntryLine> lines;

  JournalEntry({
    required this.id,
    required this.entryNumber,
    required this.entryDate,
    required this.description,
    this.referenceType,
    this.referenceId,
    required this.totalDebit,
    required this.totalCredit,
    required this.isAuto,
    required this.status,
    required this.createdAt,
    required this.lines,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    final linesJson = json['lines'] as List? ?? [];
    return JournalEntry(
      id: json['entry_id']?.toString() ?? '',
      entryNumber: json['entry_number'] ?? '',
      entryDate:
          DateTime.tryParse(json['entry_date']?.toString() ?? '') ??
          DateTime.now(),
      description: json['description'] ?? '',
      referenceType: json['reference_type'],
      referenceId: json['reference_id']?.toString(),
      totalDebit: (json['total_debit'] as num?)?.toDouble() ?? 0,
      totalCredit: (json['total_credit'] as num?)?.toDouble() ?? 0,
      isAuto: json['is_auto'] ?? true,
      status: json['status'] ?? 'posted',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      lines: linesJson
          .map((l) => JournalEntryLine.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isBalanced => (totalDebit - totalCredit).abs() < 0.01;

  String get referenceTypeLabel {
    switch (referenceType) {
      case 'cash_movement':
        return 'Movimiento de Caja';
      case 'payment':
        return 'Pago/Cobro';
      case 'invoice':
        return 'Factura';
      case 'invoice_cancel':
        return 'Anulación';
      case 'payroll':
        return 'Nómina';
      case 'loan':
        return 'Préstamo';
      default:
        return referenceType ?? 'Manual';
    }
  }
}

/// Item del balance general
class BalanceItem {
  final String seccion;
  final String tipo;
  final String codigo;
  final String cuenta;
  final double saldo;

  BalanceItem({
    required this.seccion,
    required this.tipo,
    required this.codigo,
    required this.cuenta,
    required this.saldo,
  });

  factory BalanceItem.fromJson(Map<String, dynamic> json) {
    return BalanceItem(
      seccion: json['seccion'] ?? '',
      tipo: json['tipo'] ?? '',
      codigo: json['codigo'] ?? '',
      cuenta: json['cuenta'] ?? '',
      saldo: (json['saldo'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Item del estado de resultados
class ResultItem {
  final String seccion;
  final String tipo;
  final String codigo;
  final String cuenta;
  final double monto;

  ResultItem({
    required this.seccion,
    required this.tipo,
    required this.codigo,
    required this.cuenta,
    required this.monto,
  });

  factory ResultItem.fromJson(Map<String, dynamic> json) {
    return ResultItem(
      seccion: json['seccion'] ?? '',
      tipo: json['tipo'] ?? '',
      codigo: json['codigo'] ?? '',
      cuenta: json['cuenta'] ?? '',
      monto: (json['monto'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Item del balance de comprobación
class TrialBalanceItem {
  final String codigo;
  final String cuenta;
  final String tipo;
  final int nivel;
  final double totalDebe;
  final double totalHaber;
  final double saldo;

  TrialBalanceItem({
    required this.codigo,
    required this.cuenta,
    required this.tipo,
    required this.nivel,
    required this.totalDebe,
    required this.totalHaber,
    required this.saldo,
  });

  factory TrialBalanceItem.fromJson(Map<String, dynamic> json) {
    return TrialBalanceItem(
      codigo: json['codigo'] ?? '',
      cuenta: json['cuenta'] ?? '',
      tipo: json['tipo'] ?? 'unknown',
      nivel: json['nivel'] ?? 3,
      totalDebe: (json['total_debe'] as num?)?.toDouble() ?? 0,
      totalHaber: (json['total_haber'] as num?)?.toDouble() ?? 0,
      saldo: (json['saldo'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Item del libro mayor
class LedgerItem {
  final String codigo;
  final String cuenta;
  final DateTime fecha;
  final String asiento;
  final String descripcion;
  final double debe;
  final double haber;
  final double saldoAcumulado;

  LedgerItem({
    required this.codigo,
    required this.cuenta,
    required this.fecha,
    required this.asiento,
    required this.descripcion,
    required this.debe,
    required this.haber,
    required this.saldoAcumulado,
  });

  factory LedgerItem.fromJson(Map<String, dynamic> json) {
    return LedgerItem(
      codigo: json['codigo'] ?? '',
      cuenta: json['cuenta'] ?? '',
      fecha:
          DateTime.tryParse(json['fecha']?.toString() ?? '') ?? DateTime.now(),
      asiento: json['asiento'] ?? '',
      descripcion: json['descripcion'] ?? '',
      debe: (json['debe'] as num?)?.toDouble() ?? 0,
      haber: (json['haber'] as num?)?.toDouble() ?? 0,
      saldoAcumulado: (json['saldo_acumulado'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Cuenta del plan contable
class ChartAccount {
  final String id;
  final String code;
  final String name;
  final String type;
  final String? parentCode;
  final int level;
  final bool isActive;
  final bool acceptsEntries;

  ChartAccount({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.parentCode,
    required this.level,
    required this.isActive,
    required this.acceptsEntries,
  });

  factory ChartAccount.fromJson(Map<String, dynamic> json) {
    return ChartAccount(
      id: json['id']?.toString() ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      parentCode: json['parent_code'],
      level: json['level'] ?? 1,
      isActive: json['is_active'] ?? true,
      acceptsEntries: json['accepts_entries'] ?? true,
    );
  }

  String get typeLabel {
    switch (type) {
      case 'asset':
        return 'Activo';
      case 'liability':
        return 'Pasivo';
      case 'equity':
        return 'Patrimonio';
      case 'income':
        return 'Ingreso';
      case 'expense':
        return 'Gasto';
      default:
        return type;
    }
  }
}

/// P&L mensual
class MonthlyPL {
  final DateTime mes;
  final double ingresos;
  final double gastos;
  final double utilidadNeta;
  final double margenPct;

  MonthlyPL({
    required this.mes,
    required this.ingresos,
    required this.gastos,
    required this.utilidadNeta,
    required this.margenPct,
  });

  factory MonthlyPL.fromJson(Map<String, dynamic> json) {
    return MonthlyPL(
      mes: DateTime.tryParse(json['mes']?.toString() ?? '') ?? DateTime.now(),
      ingresos: (json['ingresos'] as num?)?.toDouble() ?? 0,
      gastos: (json['gastos'] as num?)?.toDouble() ?? 0,
      utilidadNeta: (json['utilidad_neta'] as num?)?.toDouble() ?? 0,
      margenPct: (json['margen_pct'] as num?)?.toDouble() ?? 0,
    );
  }
}
