import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../datasources/payroll_datasource.dart';

/// Estado del sistema de nómina
class PayrollState {
  final List<PayrollConcept> concepts;
  final List<PayrollPeriod> periods;
  final List<EmployeePayroll> payrolls;
  final List<EmployeeIncapacity> incapacities;
  final List<EmployeeLoan> loans;
  final PayrollPeriod? currentPeriod;
  final EmployeePayroll? selectedPayroll;
  final bool isLoading;
  final String? error;

  PayrollState({
    this.concepts = const [],
    this.periods = const [],
    this.payrolls = const [],
    this.incapacities = const [],
    this.loans = const [],
    this.currentPeriod,
    this.selectedPayroll,
    this.isLoading = false,
    this.error,
  });

  PayrollState copyWith({
    List<PayrollConcept>? concepts,
    List<PayrollPeriod>? periods,
    List<EmployeePayroll>? payrolls,
    List<EmployeeIncapacity>? incapacities,
    List<EmployeeLoan>? loans,
    PayrollPeriod? currentPeriod,
    EmployeePayroll? selectedPayroll,
    bool? isLoading,
    String? error,
  }) {
    return PayrollState(
      concepts: concepts ?? this.concepts,
      periods: periods ?? this.periods,
      payrolls: payrolls ?? this.payrolls,
      incapacities: incapacities ?? this.incapacities,
      loans: loans ?? this.loans,
      currentPeriod: currentPeriod ?? this.currentPeriod,
      selectedPayroll: selectedPayroll ?? this.selectedPayroll,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Conceptos de tipo ingreso
  List<PayrollConcept> get incomeConcepts =>
      concepts.where((c) => c.type == 'ingreso').toList();

  /// Conceptos de tipo descuento
  List<PayrollConcept> get deductionConcepts =>
      concepts.where((c) => c.type == 'descuento').toList();

  /// Préstamos activos
  List<EmployeeLoan> get activeLoans =>
      loans.where((l) => l.status == 'activo').toList();

  /// Incapacidades activas
  List<EmployeeIncapacity> get activeIncapacities =>
      incapacities.where((i) => i.status == 'activa').toList();

  /// Total a pagar en el periodo actual
  double get totalNetPayroll => payrolls.fold(0, (sum, p) => sum + p.netPay);

  /// Nóminas pendientes de pago
  List<EmployeePayroll> get pendingPayrolls =>
      payrolls.where((p) => p.status != 'pagado').toList();

  /// Nóminas pagadas
  List<EmployeePayroll> get paidPayrolls =>
      payrolls.where((p) => p.status == 'pagado').toList();
}

/// Notifier para el sistema de nómina
class PayrollNotifier extends Notifier<PayrollState> {
  @override
  PayrollState build() {
    return PayrollState();
  }

  /// Cargar todos los datos iniciales
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final concepts = await PayrollDatasource.getConcepts();
      final periods = await PayrollDatasource.getPeriods();
      final currentPeriod = await PayrollDatasource.getOrCreateCurrentPeriod();

      List<EmployeePayroll> payrolls = [];
      if (currentPeriod != null) {
        payrolls = await PayrollDatasource.getPayrolls(
          periodId: currentPeriod.id,
        );
      }

      final incapacities = await PayrollDatasource.getIncapacities();
      final loans = await PayrollDatasource.getLoans();

      state = state.copyWith(
        concepts: concepts,
        periods: periods,
        payrolls: payrolls,
        incapacities: incapacities,
        loans: loans,
        currentPeriod: currentPeriod,
        isLoading: false,
      );
    } catch (e) {
      print('❌ Error cargando nómina: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Cargar nóminas de un periodo específico
  Future<void> loadPayrollsForPeriod(String periodId) async {
    state = state.copyWith(isLoading: true);
    try {
      final payrolls = await PayrollDatasource.getPayrolls(periodId: periodId);
      final period = state.periods.firstWhere((p) => p.id == periodId);
      state = state.copyWith(
        payrolls: payrolls,
        currentPeriod: period,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Crear nueva nómina para empleado
  Future<EmployeePayroll?> createPayroll({
    required String employeeId,
    required String periodId,
    required double baseSalary,
    int daysWorked = 30,
  }) async {
    try {
      final payroll = await PayrollDatasource.createPayroll(
        employeeId: employeeId,
        periodId: periodId,
        baseSalary: baseSalary,
        daysWorked: daysWorked,
      );

      if (payroll != null) {
        state = state.copyWith(payrolls: [...state.payrolls, payroll]);
      }
      return payroll;
    } catch (e) {
      print('❌ Error creando nómina: $e');
      return null;
    }
  }

  /// Seleccionar una nómina para ver/editar detalles
  Future<void> selectPayroll(String payrollId) async {
    state = state.copyWith(isLoading: true);
    try {
      final payroll = await PayrollDatasource.getPayrollWithDetails(payrollId);
      state = state.copyWith(selectedPayroll: payroll, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Agregar concepto a nómina (ingreso o descuento)
  Future<bool> addConceptToPayroll({
    required String payrollId,
    required String conceptId,
    required double amount,
    double quantity = 1,
    double unitValue = 0,
    String? notes,
  }) async {
    try {
      final concept = state.concepts.firstWhere((c) => c.id == conceptId);

      await PayrollDatasource.addPayrollDetail(
        payrollId: payrollId,
        concept: concept,
        amount: amount,
        quantity: quantity,
        unitValue: unitValue,
        notes: notes,
      );

      // Recargar la nómina seleccionada
      await selectPayroll(payrollId);

      // Recargar lista de nóminas
      if (state.currentPeriod != null) {
        final payrolls = await PayrollDatasource.getPayrolls(
          periodId: state.currentPeriod!.id,
        );
        state = state.copyWith(payrolls: payrolls);
      }

      return true;
    } catch (e) {
      print('❌ Error agregando concepto: $e');
      return false;
    }
  }

  /// Eliminar concepto de nómina
  Future<bool> removeConceptFromPayroll(
    String detailId,
    String payrollId,
  ) async {
    try {
      await PayrollDatasource.removePayrollDetail(detailId, payrollId);
      await selectPayroll(payrollId);
      return true;
    } catch (e) {
      print('❌ Error eliminando concepto: $e');
      return false;
    }
  }

  /// Procesar pago de nómina
  Future<bool> processPayment({
    required String payrollId,
    required String accountId,
    DateTime? paymentDate,
  }) async {
    try {
      await PayrollDatasource.processPayrollPayment(
        payrollId: payrollId,
        accountId: accountId,
        paymentDate: paymentDate ?? DateTime.now(),
      );

      // Recargar nóminas
      if (state.currentPeriod != null) {
        await loadPayrollsForPeriod(state.currentPeriod!.id);
      }

      return true;
    } catch (e) {
      print('❌ Error procesando pago: $e');
      return false;
    }
  }

  // ==========================================
  // INCAPACIDADES
  // ==========================================
  Future<void> loadIncapacities({String? employeeId}) async {
    try {
      final incapacities = await PayrollDatasource.getIncapacities(
        employeeId: employeeId,
      );
      state = state.copyWith(incapacities: incapacities);
    } catch (e) {
      print('❌ Error cargando incapacidades: $e');
    }
  }

  Future<bool> createIncapacity(EmployeeIncapacity incapacity) async {
    try {
      final created = await PayrollDatasource.createIncapacity(incapacity);
      if (created != null) {
        state = state.copyWith(incapacities: [...state.incapacities, created]);
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error creando incapacidad: $e');
      return false;
    }
  }

  Future<bool> endIncapacity(String incapacityId) async {
    try {
      await PayrollDatasource.updateIncapacity(incapacityId, {
        'status': 'terminada',
        'end_date': DateTime.now().toIso8601String().split('T')[0],
      });
      await loadIncapacities();
      return true;
    } catch (e) {
      print('❌ Error terminando incapacidad: $e');
      return false;
    }
  }

  // ==========================================
  // PRÉSTAMOS
  // ==========================================
  Future<void> loadLoans({String? employeeId}) async {
    try {
      final loans = await PayrollDatasource.getLoans(employeeId: employeeId);
      state = state.copyWith(loans: loans);
    } catch (e) {
      print('❌ Error cargando préstamos: $e');
    }
  }

  Future<bool> createLoan({
    required String employeeId,
    required double amount,
    required int installments,
    required String accountId,
    String? reason,
  }) async {
    try {
      final loanId = await PayrollDatasource.createLoan(
        employeeId: employeeId,
        amount: amount,
        installments: installments,
        accountId: accountId,
        reason: reason,
      );

      if (loanId != null) {
        await loadLoans();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error creando préstamo: $e');
      return false;
    }
  }

  Future<bool> registerLoanPayment({
    required String loanId,
    required double amount,
    required int installmentNumber,
    String? payrollId,
  }) async {
    try {
      await PayrollDatasource.registerLoanPayment(
        loanId: loanId,
        amount: amount,
        installmentNumber: installmentNumber,
        payrollId: payrollId,
      );
      await loadLoans();
      return true;
    } catch (e) {
      print('❌ Error registrando pago de préstamo: $e');
      return false;
    }
  }

  // ==========================================
  // HORAS EXTRAS
  // ==========================================
  Future<bool> addOvertimeHours({
    required String payrollId,
    required double hours,
    required String type, // 'normal', '25' (diurna), '75' (nocturna), '100' (dom/fest), '150' (dom/fest noct)
    required double hourlyRate,
  }) async {
    final conceptCode = type == 'normal' ? 'HORA_EXTRA' : 'HORA_EXTRA_$type';
    final concept = state.concepts.firstWhere(
      (c) => c.code == conceptCode,
      orElse: () => state.incomeConcepts.first,
    );

    double multiplier = 1.0;
    String typeLabel = '';
    switch (type) {
      case 'normal':
        multiplier = 1.0;   // Sin recargo
        typeLabel = 'Normal';
        break;
      case '25':
        multiplier = 1.25;  // Diurna (6am-9pm)
        typeLabel = 'Diurna';
        break;
      case '75':
        multiplier = 1.75;  // Nocturna (9pm-6am)
        typeLabel = 'Nocturna';
        break;
      case '100':
        multiplier = 2.0;   // Dominical/Festivo diurna
        typeLabel = 'Dom/Fest Diurna';
        break;
      case '150':
        multiplier = 2.5;   // Dominical/Festivo nocturna
        typeLabel = 'Dom/Fest Nocturna';
        break;
      default:
        multiplier = 1.0;
        typeLabel = 'Normal';
    }

    final amount = hours * hourlyRate * multiplier;
    final recargoText = multiplier > 1.0 ? ' (+${((multiplier - 1) * 100).toInt()}%)' : ' (sin recargo)';

    return addConceptToPayroll(
      payrollId: payrollId,
      conceptId: concept.id,
      amount: amount,
      quantity: hours,
      unitValue: hourlyRate * multiplier,
      notes: '${hours.toStringAsFixed(1)} hrs $typeLabel$recargoText',
    );
  }

  // ==========================================
  // DESCUENTOS RÁPIDOS
  // ==========================================
  
  /// Descuento por horas faltantes (trabajó menos de 88h en la quincena)
  Future<bool> addUnderHoursDiscount({
    required String payrollId,
    required double hours,
    required double hourlyRate,
    String? notes,
  }) async {
    final concept = state.deductionConcepts.firstWhere(
      (c) => c.code == 'DESC_FALTAS',
      orElse: () => state.deductionConcepts.first,
    );

    return addConceptToPayroll(
      payrollId: payrollId,
      conceptId: concept.id,
      amount: hours * hourlyRate,
      quantity: hours,
      unitValue: hourlyRate,
      notes: notes ?? '${hours.toStringAsFixed(1)} horas faltantes',
    );
  }
  
  Future<bool> addAbsenceDiscount({
    required String payrollId,
    required int days,
    required double dailyRate,
    String? notes,
  }) async {
    final concept = state.deductionConcepts.firstWhere(
      (c) => c.code == 'DESC_FALTAS',
      orElse: () => state.deductionConcepts.first,
    );

    return addConceptToPayroll(
      payrollId: payrollId,
      conceptId: concept.id,
      amount: days * dailyRate,
      quantity: days.toDouble(),
      unitValue: dailyRate,
      notes: notes ?? '$days día(s) de ausencia',
    );
  }

  Future<bool> addLateDiscount({
    required String payrollId,
    required double amount,
    String? notes,
  }) async {
    final concept = state.deductionConcepts.firstWhere(
      (c) => c.code == 'DESC_TARDANZA',
      orElse: () => state.deductionConcepts.first,
    );

    return addConceptToPayroll(
      payrollId: payrollId,
      conceptId: concept.id,
      amount: amount,
      notes: notes ?? 'Descuento por tardanzas',
    );
  }

  Future<bool> addAdvanceDiscount({
    required String payrollId,
    required double amount,
    String? notes,
  }) async {
    final concept = state.deductionConcepts.firstWhere(
      (c) => c.code == 'DESC_ADELANTO',
      orElse: () => state.deductionConcepts.first,
    );

    return addConceptToPayroll(
      payrollId: payrollId,
      conceptId: concept.id,
      amount: amount,
      notes: notes ?? 'Adelanto de sueldo',
    );
  }

  /// Agregar cuota de préstamo como descuento
  Future<bool> addLoanInstallmentDiscount({
    required String payrollId,
    required EmployeeLoan loan,
  }) async {
    final concept = state.deductionConcepts.firstWhere(
      (c) => c.code == 'DESC_PRESTAMO',
      orElse: () => state.deductionConcepts.first,
    );

    final success = await addConceptToPayroll(
      payrollId: payrollId,
      conceptId: concept.id,
      amount: loan.installmentAmount,
      notes:
          'Cuota ${loan.paidInstallments + 1}/${loan.installments} - Préstamo',
    );

    if (success) {
      // Registrar pago de la cuota
      await registerLoanPayment(
        loanId: loan.id,
        amount: loan.installmentAmount,
        installmentNumber: loan.paidInstallments + 1,
        payrollId: payrollId,
      );
    }

    return success;
  }
}

/// Provider de nómina
final payrollProvider = NotifierProvider<PayrollNotifier, PayrollState>(() {
  return PayrollNotifier();
});
