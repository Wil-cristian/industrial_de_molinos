import 'package:supabase_flutter/supabase_flutter.dart';

/// Concepto de nómina (ingreso/descuento)
class PayrollConcept {
  final String id;
  final String code;
  final String name;
  final String type; // 'ingreso', 'descuento'
  final String category;
  final bool isPercentage;
  final double defaultValue;
  final bool affectsTaxes;
  final bool isActive;
  final String? description;

  PayrollConcept({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.category,
    this.isPercentage = false,
    this.defaultValue = 0,
    this.affectsTaxes = true,
    this.isActive = true,
    this.description,
  });

  factory PayrollConcept.fromJson(Map<String, dynamic> json) {
    return PayrollConcept(
      id: json['id'],
      code: json['code'],
      name: json['name'],
      type: json['type'],
      category: json['category'],
      isPercentage: json['is_percentage'] ?? false,
      defaultValue: (json['default_value'] ?? 0).toDouble(),
      affectsTaxes: json['affects_taxes'] ?? true,
      isActive: json['is_active'] ?? true,
      description: json['description'],
    );
  }
}

/// Periodo de nómina
class PayrollPeriod {
  final String id;
  final String periodType;
  final int periodNumber;
  final int year;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime? paymentDate;
  final String status;
  final double totalEarnings;
  final double totalDeductions;
  final double totalNet;
  final String? notes;

  PayrollPeriod({
    required this.id,
    required this.periodType,
    required this.periodNumber,
    required this.year,
    required this.startDate,
    required this.endDate,
    this.paymentDate,
    required this.status,
    this.totalEarnings = 0,
    this.totalDeductions = 0,
    this.totalNet = 0,
    this.notes,
  });

  factory PayrollPeriod.fromJson(Map<String, dynamic> json) {
    return PayrollPeriod(
      id: json['id'],
      periodType: json['period_type'],
      periodNumber: json['period_number'],
      year: json['year'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      paymentDate: json['payment_date'] != null
          ? DateTime.parse(json['payment_date'])
          : null,
      status: json['status'],
      totalEarnings: (json['total_earnings'] ?? 0).toDouble(),
      totalDeductions: (json['total_deductions'] ?? 0).toDouble(),
      totalNet: (json['total_net'] ?? 0).toDouble(),
      notes: json['notes'],
    );
  }

  String get displayName {
    final typeLabel = periodType == 'mensual'
        ? 'Mes'
        : periodType == 'quincenal'
        ? 'Quincena'
        : 'Semana';
    return '$typeLabel $periodNumber/$year';
  }
}

/// Nómina de empleado
class EmployeePayroll {
  final String id;
  final String employeeId;
  final String periodId;
  final double baseSalary;
  final int daysWorked;
  final int daysAbsent;
  final int daysVacation;
  final int daysIncapacity;
  final double regularHours;
  final double overtimeHours25;
  final double overtimeHours35;
  final double overtimeHours100;
  final double totalEarnings;
  final double totalDeductions;
  final double netPay;
  final String status;
  final DateTime? paymentDate;
  final String? paymentMethod;
  final String? paymentReference;
  final String? accountId;
  final String? cashMovementId;
  final String? notes;
  final DateTime createdAt;

  // Datos relacionados
  final String? employeeName;
  final String? employeePosition;
  final String? periodName;
  final List<PayrollDetail> details;

  EmployeePayroll({
    required this.id,
    required this.employeeId,
    required this.periodId,
    this.baseSalary = 0,
    this.daysWorked = 0,
    this.daysAbsent = 0,
    this.daysVacation = 0,
    this.daysIncapacity = 0,
    this.regularHours = 0,
    this.overtimeHours25 = 0,
    this.overtimeHours35 = 0,
    this.overtimeHours100 = 0,
    this.totalEarnings = 0,
    this.totalDeductions = 0,
    this.netPay = 0,
    required this.status,
    this.paymentDate,
    this.paymentMethod,
    this.paymentReference,
    this.accountId,
    this.cashMovementId,
    this.notes,
    required this.createdAt,
    this.employeeName,
    this.employeePosition,
    this.periodName,
    this.details = const [],
  });

  factory EmployeePayroll.fromJson(Map<String, dynamic> json) {
    final employee = json['employees'];
    final period = json['payroll_periods'];

    return EmployeePayroll(
      id: json['id'],
      employeeId: json['employee_id'],
      periodId: json['period_id'],
      baseSalary: (json['base_salary'] ?? 0).toDouble(),
      daysWorked: json['days_worked'] ?? 0,
      daysAbsent: json['days_absent'] ?? 0,
      daysVacation: json['days_vacation'] ?? 0,
      daysIncapacity: json['days_incapacity'] ?? 0,
      regularHours: (json['regular_hours'] ?? 0).toDouble(),
      overtimeHours25: (json['overtime_hours_25'] ?? 0).toDouble(),
      overtimeHours35: (json['overtime_hours_35'] ?? 0).toDouble(),
      overtimeHours100: (json['overtime_hours_100'] ?? 0).toDouble(),
      totalEarnings: (json['total_earnings'] ?? 0).toDouble(),
      totalDeductions: (json['total_deductions'] ?? 0).toDouble(),
      netPay: (json['net_pay'] ?? 0).toDouble(),
      status: json['status'] ?? 'borrador',
      paymentDate: json['payment_date'] != null
          ? DateTime.parse(json['payment_date'])
          : null,
      paymentMethod: json['payment_method'],
      paymentReference: json['payment_reference'],
      accountId: json['account_id'],
      cashMovementId: json['cash_movement_id'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      employeeName: employee != null
          ? '${employee['first_name']} ${employee['last_name']}'
          : null,
      employeePosition: employee?['position'],
      periodName: period != null
          ? '${period['period_type']} ${period['period_number']}/${period['year']}'
          : null,
    );
  }
}

/// Detalle de nómina (concepto aplicado)
class PayrollDetail {
  final String id;
  final String payrollId;
  final String conceptId;
  final String conceptCode;
  final String conceptName;
  final String type;
  final double quantity;
  final double unitValue;
  final double amount;
  final String? notes;

  PayrollDetail({
    required this.id,
    required this.payrollId,
    required this.conceptId,
    required this.conceptCode,
    required this.conceptName,
    required this.type,
    this.quantity = 1,
    this.unitValue = 0,
    required this.amount,
    this.notes,
  });

  factory PayrollDetail.fromJson(Map<String, dynamic> json) {
    return PayrollDetail(
      id: json['id'],
      payrollId: json['payroll_id'],
      conceptId: json['concept_id'],
      conceptCode: json['concept_code'],
      conceptName: json['concept_name'],
      type: json['type'],
      quantity: (json['quantity'] ?? 1).toDouble(),
      unitValue: (json['unit_value'] ?? 0).toDouble(),
      amount: (json['amount'] ?? 0).toDouble(),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'payroll_id': payrollId,
      'concept_id': conceptId,
      'concept_code': conceptCode,
      'concept_name': conceptName,
      'type': type,
      'quantity': quantity,
      'unit_value': unitValue,
      'amount': amount,
      'notes': notes,
    };
  }
}

/// Incapacidad de empleado
class EmployeeIncapacity {
  final String id;
  final String employeeId;
  final String type;
  final DateTime startDate;
  final DateTime endDate;
  final int daysTotal;
  final String? certificateNumber;
  final String? medicalEntity;
  final String? diagnosis;
  final double paymentPercentage;
  final int employerDays;
  final String status;
  final String? notes;
  final String? employeeName;

  EmployeeIncapacity({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.startDate,
    required this.endDate,
    required this.daysTotal,
    this.certificateNumber,
    this.medicalEntity,
    this.diagnosis,
    this.paymentPercentage = 100,
    this.employerDays = 0,
    this.status = 'activa',
    this.notes,
    this.employeeName,
  });

  factory EmployeeIncapacity.fromJson(Map<String, dynamic> json) {
    final employee = json['employees'];
    return EmployeeIncapacity(
      id: json['id'],
      employeeId: json['employee_id'],
      type: json['type'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      daysTotal: json['days_total'],
      certificateNumber: json['certificate_number'],
      medicalEntity: json['medical_entity'],
      diagnosis: json['diagnosis'],
      paymentPercentage: (json['payment_percentage'] ?? 100).toDouble(),
      employerDays: json['employer_days'] ?? 0,
      status: json['status'] ?? 'activa',
      notes: json['notes'],
      employeeName: employee != null
          ? '${employee['first_name']} ${employee['last_name']}'
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'type': type,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'days_total': daysTotal,
      'certificate_number': certificateNumber,
      'medical_entity': medicalEntity,
      'diagnosis': diagnosis,
      'payment_percentage': paymentPercentage,
      'employer_days': employerDays,
      'status': status,
      'notes': notes,
    };
  }

  String get typeLabel {
    switch (type) {
      case 'enfermedad':
        return 'Enfermedad';
      case 'accidente_laboral':
        return 'Accidente Laboral';
      case 'accidente_comun':
        return 'Accidente Común';
      case 'maternidad':
        return 'Maternidad';
      default:
        return type;
    }
  }
}

/// Préstamo a empleado
class EmployeeLoan {
  final String id;
  final String employeeId;
  final DateTime loanDate;
  final double totalAmount;
  final int installments;
  final double installmentAmount;
  final double paidAmount;
  final int paidInstallments;
  final double remainingAmount;
  final String? reason;
  final String status;
  final String? cashMovementId;
  final String? accountId;
  final String? notes;
  final String? employeeName;

  EmployeeLoan({
    required this.id,
    required this.employeeId,
    required this.loanDate,
    required this.totalAmount,
    required this.installments,
    required this.installmentAmount,
    this.paidAmount = 0,
    this.paidInstallments = 0,
    required this.remainingAmount,
    this.reason,
    this.status = 'activo',
    this.cashMovementId,
    this.accountId,
    this.notes,
    this.employeeName,
  });

  factory EmployeeLoan.fromJson(Map<String, dynamic> json) {
    final employee = json['employees'];
    return EmployeeLoan(
      id: json['id'],
      employeeId: json['employee_id'],
      loanDate: DateTime.parse(json['loan_date']),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      installments: json['installments'] ?? 1,
      installmentAmount: (json['installment_amount'] ?? 0).toDouble(),
      paidAmount: (json['paid_amount'] ?? 0).toDouble(),
      paidInstallments: json['paid_installments'] ?? 0,
      remainingAmount: (json['remaining_amount'] ?? 0).toDouble(),
      reason: json['reason'],
      status: json['status'] ?? 'activo',
      cashMovementId: json['cash_movement_id'],
      accountId: json['account_id'],
      notes: json['notes'],
      employeeName: employee != null
          ? '${employee['first_name']} ${employee['last_name']}'
          : null,
    );
  }

  int get remainingInstallments => installments - paidInstallments;
  double get progress => totalAmount > 0 ? paidAmount / totalAmount : 0;
}

/// Datasource para sistema de nómina
class PayrollDatasource {
  static SupabaseClient get _client => Supabase.instance.client;

  // ==========================================
  // CONCEPTOS DE NÓMINA
  // ==========================================
  static Future<List<PayrollConcept>> getConcepts({String? type}) async {
    var query = _client.from('payroll_concepts').select().eq('is_active', true);

    if (type != null) {
      query = query.eq('type', type);
    }

    final response = await query.order('category').order('name');
    return (response as List).map((e) => PayrollConcept.fromJson(e)).toList();
  }

  // ==========================================
  // PERIODOS DE NÓMINA
  // ==========================================
  static Future<List<PayrollPeriod>> getPeriods({
    int? year,
    String? status,
  }) async {
    var query = _client.from('payroll_periods').select();

    if (year != null) {
      query = query.eq('year', year);
    }
    if (status != null) {
      query = query.eq('status', status);
    }

    final response = await query
        .order('year', ascending: false)
        .order('period_number', ascending: false);
    return (response as List).map((e) => PayrollPeriod.fromJson(e)).toList();
  }

  static Future<PayrollPeriod?> createPeriod({
    required String periodType,
    required int periodNumber,
    required int year,
    required DateTime startDate,
    required DateTime endDate,
    DateTime? paymentDate,
  }) async {
    final response = await _client
        .from('payroll_periods')
        .insert({
          'period_type': periodType,
          'period_number': periodNumber,
          'year': year,
          'start_date': startDate.toIso8601String().split('T')[0],
          'end_date': endDate.toIso8601String().split('T')[0],
          'payment_date': paymentDate?.toIso8601String().split('T')[0],
          'status': 'abierto',
        })
        .select()
        .single();

    return PayrollPeriod.fromJson(response);
  }

  static Future<PayrollPeriod?> getOrCreateCurrentPeriod() async {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    // Buscar periodo actual
    final existing = await _client
        .from('payroll_periods')
        .select()
        .eq('period_type', 'mensual')
        .eq('period_number', month)
        .eq('year', year)
        .maybeSingle();

    if (existing != null) {
      return PayrollPeriod.fromJson(existing);
    }

    // Crear nuevo periodo
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0);

    return createPeriod(
      periodType: 'mensual',
      periodNumber: month,
      year: year,
      startDate: startDate,
      endDate: endDate,
    );
  }

  // ==========================================
  // NÓMINAS
  // ==========================================
  static Future<List<EmployeePayroll>> getPayrolls({
    String? periodId,
    String? employeeId,
    String? status,
  }) async {
    var query = _client.from('payroll').select('''
      *,
      employees(first_name, last_name, position),
      payroll_periods(period_type, period_number, year)
    ''');

    if (periodId != null) {
      query = query.eq('period_id', periodId);
    }
    if (employeeId != null) {
      query = query.eq('employee_id', employeeId);
    }
    if (status != null) {
      query = query.eq('status', status);
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List).map((e) => EmployeePayroll.fromJson(e)).toList();
  }

  static Future<EmployeePayroll?> getPayrollWithDetails(
    String payrollId,
  ) async {
    final response = await _client
        .from('payroll')
        .select('''
      *,
      employees(first_name, last_name, position),
      payroll_periods(period_type, period_number, year)
    ''')
        .eq('id', payrollId)
        .single();

    final details = await getPayrollDetails(payrollId);
    final payroll = EmployeePayroll.fromJson(response);

    return EmployeePayroll(
      id: payroll.id,
      employeeId: payroll.employeeId,
      periodId: payroll.periodId,
      baseSalary: payroll.baseSalary,
      daysWorked: payroll.daysWorked,
      daysAbsent: payroll.daysAbsent,
      daysVacation: payroll.daysVacation,
      daysIncapacity: payroll.daysIncapacity,
      regularHours: payroll.regularHours,
      overtimeHours25: payroll.overtimeHours25,
      overtimeHours35: payroll.overtimeHours35,
      overtimeHours100: payroll.overtimeHours100,
      totalEarnings: payroll.totalEarnings,
      totalDeductions: payroll.totalDeductions,
      netPay: payroll.netPay,
      status: payroll.status,
      paymentDate: payroll.paymentDate,
      paymentMethod: payroll.paymentMethod,
      paymentReference: payroll.paymentReference,
      accountId: payroll.accountId,
      cashMovementId: payroll.cashMovementId,
      notes: payroll.notes,
      createdAt: payroll.createdAt,
      employeeName: payroll.employeeName,
      employeePosition: payroll.employeePosition,
      periodName: payroll.periodName,
      details: details,
    );
  }

  static Future<EmployeePayroll?> createPayroll({
    required String employeeId,
    required String periodId,
    required double baseSalary,
    int daysWorked = 30,
  }) async {
    final response = await _client
        .from('payroll')
        .insert({
          'employee_id': employeeId,
          'period_id': periodId,
          'base_salary': baseSalary,
          'days_worked': daysWorked,
          'status': 'borrador',
        })
        .select('''
          *,
          employees(first_name, last_name, position),
          payroll_periods(period_type, period_number, year)
        ''')
        .single();

    return EmployeePayroll.fromJson(response);
  }

  static Future<void> updatePayroll(
    String payrollId,
    Map<String, dynamic> data,
  ) async {
    await _client.from('payroll').update(data).eq('id', payrollId);
  }

  // ==========================================
  // DETALLES DE NÓMINA
  // ==========================================
  static Future<List<PayrollDetail>> getPayrollDetails(String payrollId) async {
    final response = await _client
        .from('payroll_details')
        .select()
        .eq('payroll_id', payrollId)
        .order('type')
        .order('concept_name');

    return (response as List).map((e) => PayrollDetail.fromJson(e)).toList();
  }

  static Future<PayrollDetail?> addPayrollDetail({
    required String payrollId,
    required PayrollConcept concept,
    required double amount,
    double quantity = 1,
    double unitValue = 0,
    String? notes,
  }) async {
    final response = await _client
        .from('payroll_details')
        .insert({
          'payroll_id': payrollId,
          'concept_id': concept.id,
          'concept_code': concept.code,
          'concept_name': concept.name,
          'type': concept.type,
          'quantity': quantity,
          'unit_value': unitValue,
          'amount': amount,
          'notes': notes,
        })
        .select()
        .single();

    // Recalcular totales
    await _client.rpc(
      'calculate_payroll_totals',
      params: {'p_payroll_id': payrollId},
    );

    return PayrollDetail.fromJson(response);
  }

  static Future<void> removePayrollDetail(
    String detailId,
    String payrollId,
  ) async {
    await _client.from('payroll_details').delete().eq('id', detailId);

    // Recalcular totales
    await _client.rpc(
      'calculate_payroll_totals',
      params: {'p_payroll_id': payrollId},
    );
  }

  // ==========================================
  // PAGO DE NÓMINA
  // ==========================================
  static Future<String?> processPayrollPayment({
    required String payrollId,
    required String accountId,
    required String paymentMethod,
  }) async {
    final response = await _client.rpc(
      'register_payroll_payment',
      params: {
        'p_payroll_id': payrollId,
        'p_account_id': accountId,
        'p_payment_method': paymentMethod,
      },
    );

    return response as String?;
  }

  // ==========================================
  // INCAPACIDADES
  // ==========================================
  static Future<List<EmployeeIncapacity>> getIncapacities({
    String? employeeId,
    String? status,
  }) async {
    var query = _client.from('employee_incapacities').select('''
      *,
      employees(first_name, last_name)
    ''');

    if (employeeId != null) {
      query = query.eq('employee_id', employeeId);
    }
    if (status != null) {
      query = query.eq('status', status);
    }

    final response = await query.order('start_date', ascending: false);
    return (response as List)
        .map((e) => EmployeeIncapacity.fromJson(e))
        .toList();
  }

  static Future<EmployeeIncapacity?> createIncapacity(
    EmployeeIncapacity incapacity,
  ) async {
    final response = await _client
        .from('employee_incapacities')
        .insert(incapacity.toJson())
        .select('''
          *,
          employees(first_name, last_name)
        ''')
        .single();

    return EmployeeIncapacity.fromJson(response);
  }

  static Future<void> updateIncapacity(
    String id,
    Map<String, dynamic> data,
  ) async {
    await _client.from('employee_incapacities').update(data).eq('id', id);
  }

  // ==========================================
  // PRÉSTAMOS
  // ==========================================
  static Future<List<EmployeeLoan>> getLoans({
    String? employeeId,
    String? status,
  }) async {
    var query = _client.from('employee_loans').select('''
      *,
      employees(first_name, last_name)
    ''');

    if (employeeId != null) {
      query = query.eq('employee_id', employeeId);
    }
    if (status != null) {
      query = query.eq('status', status);
    }

    final response = await query.order('loan_date', ascending: false);
    return (response as List).map((e) => EmployeeLoan.fromJson(e)).toList();
  }

  static Future<String?> createLoan({
    required String employeeId,
    required double amount,
    required int installments,
    required String accountId,
    String? reason,
  }) async {
    final response = await _client.rpc(
      'register_employee_loan',
      params: {
        'p_employee_id': employeeId,
        'p_amount': amount,
        'p_installments': installments,
        'p_account_id': accountId,
        'p_reason': reason,
      },
    );

    return response as String?;
  }

  static Future<void> registerLoanPayment({
    required String loanId,
    required double amount,
    required int installmentNumber,
    String? payrollId,
    String paymentMethod = 'nomina',
  }) async {
    // Registrar pago
    await _client.from('loan_payments').insert({
      'loan_id': loanId,
      'payroll_id': payrollId,
      'payment_date': DateTime.now().toIso8601String().split('T')[0],
      'amount': amount,
      'installment_number': installmentNumber,
      'payment_method': paymentMethod,
    });

    // Actualizar préstamo
    final loan = await _client
        .from('employee_loans')
        .select()
        .eq('id', loanId)
        .single();

    final newPaidAmount = (loan['paid_amount'] ?? 0).toDouble() + amount;
    final newPaidInstallments = (loan['paid_installments'] ?? 0) + 1;
    final newRemainingAmount =
        (loan['total_amount'] ?? 0).toDouble() - newPaidAmount;

    await _client
        .from('employee_loans')
        .update({
          'paid_amount': newPaidAmount,
          'paid_installments': newPaidInstallments,
          'remaining_amount': newRemainingAmount,
          'status': newRemainingAmount <= 0 ? 'pagado' : 'activo',
        })
        .eq('id', loanId);
  }

  // ==========================================
  // RESUMEN
  // ==========================================
  static Future<Map<String, dynamic>> getPayrollSummary(String periodId) async {
    final payrolls = await getPayrolls(periodId: periodId);

    double totalEarnings = 0;
    double totalDeductions = 0;
    double totalNet = 0;
    int paid = 0;
    int pending = 0;

    for (var p in payrolls) {
      totalEarnings += p.totalEarnings;
      totalDeductions += p.totalDeductions;
      totalNet += p.netPay;
      if (p.status == 'pagado') {
        paid++;
      } else {
        pending++;
      }
    }

    return {
      'total_employees': payrolls.length,
      'total_earnings': totalEarnings,
      'total_deductions': totalDeductions,
      'total_net': totalNet,
      'paid_count': paid,
      'pending_count': pending,
    };
  }
}
