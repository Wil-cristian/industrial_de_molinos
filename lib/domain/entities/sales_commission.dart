import '../../core/utils/colombia_time.dart';
// Entidad: Comisión por Venta

class SalesCommission {
  final String id;
  final String invoiceId;
  final String employeeId;
  final String? invoiceNumber;
  final String? customerName;
  final double invoiceTotal;
  final double commissionPercentage;
  final double commissionAmount;
  final String status; // pendiente, pagada, anulada
  final String? payrollId;
  final DateTime? paidDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Datos extra para display (join con employees)
  final String? employeeName;

  SalesCommission({
    required this.id,
    required this.invoiceId,
    required this.employeeId,
    this.invoiceNumber,
    this.customerName,
    required this.invoiceTotal,
    required this.commissionPercentage,
    required this.commissionAmount,
    this.status = 'pendiente',
    this.payrollId,
    this.paidDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.employeeName,
  });

  bool get isPending => status == 'pendiente';
  bool get isPaid => status == 'pagada';
  bool get isCancelled => status == 'anulada';

  SalesCommission copyWith({
    String? id,
    String? invoiceId,
    String? employeeId,
    String? invoiceNumber,
    String? customerName,
    double? invoiceTotal,
    double? commissionPercentage,
    double? commissionAmount,
    String? status,
    String? payrollId,
    DateTime? paidDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? employeeName,
  }) {
    return SalesCommission(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      employeeId: employeeId ?? this.employeeId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerName: customerName ?? this.customerName,
      invoiceTotal: invoiceTotal ?? this.invoiceTotal,
      commissionPercentage: commissionPercentage ?? this.commissionPercentage,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      status: status ?? this.status,
      payrollId: payrollId ?? this.payrollId,
      paidDate: paidDate ?? this.paidDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      employeeName: employeeName ?? this.employeeName,
    );
  }

  factory SalesCommission.fromJson(Map<String, dynamic> json) {
    // Puede venir join con employees
    String? empName;
    if (json['employees'] != null && json['employees'] is Map) {
      final emp = json['employees'] as Map<String, dynamic>;
      empName = '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}'.trim();
    }

    return SalesCommission(
      id: json['id'] ?? '',
      invoiceId: json['invoice_id'] ?? '',
      employeeId: json['employee_id'] ?? '',
      invoiceNumber: json['invoice_number'],
      customerName: json['customer_name'],
      invoiceTotal: (json['invoice_total'] as num?)?.toDouble() ?? 0,
      commissionPercentage:
          (json['commission_percentage'] as num?)?.toDouble() ?? 0,
      commissionAmount: (json['commission_amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] ?? 'pendiente',
      payrollId: json['payroll_id'],
      paidDate: json['paid_date'] != null
          ? DateTime.parse(json['paid_date'])
          : null,
      notes: json['notes'],
      createdAt: DateTime.parse(
        json['created_at'] ?? ColombiaTime.nowIso8601(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? ColombiaTime.nowIso8601(),
      ),
      employeeName: empName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invoice_id': invoiceId,
      'employee_id': employeeId,
      'invoice_number': invoiceNumber,
      'customer_name': customerName,
      'invoice_total': invoiceTotal,
      'commission_percentage': commissionPercentage,
      'commission_amount': commissionAmount,
      'status': status,
      'payroll_id': payrollId,
      'paid_date': (paidDate != null ? ColombiaTime.dateString(paidDate!) : null),
      'notes': notes,
    };
  }
}

/// Configuración de comisión por empleado
class CommissionSetting {
  final String id;
  final String employeeId;
  final double commissionPercentage;
  final bool isActive;

  CommissionSetting({
    required this.id,
    required this.employeeId,
    required this.commissionPercentage,
    this.isActive = true,
  });

  factory CommissionSetting.fromJson(Map<String, dynamic> json) {
    return CommissionSetting(
      id: json['id'] ?? '',
      employeeId: json['employee_id'] ?? '',
      commissionPercentage:
          (json['commission_percentage'] as num?)?.toDouble() ?? 1.6667,
      isActive: json['is_active'] ?? true,
    );
  }
}
