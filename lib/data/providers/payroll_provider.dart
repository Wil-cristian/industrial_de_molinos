import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../datasources/payroll_datasource.dart';
import '../datasources/employees_datasource.dart';

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

      // Asegurar que el periodo actual esté en la lista
      final allPeriods = [...periods];
      if (currentPeriod != null &&
          !allPeriods.any((p) => p.id == currentPeriod.id)) {
        allPeriods.add(currentPeriod);
      }

      print('📋 Periodos cargados: ${allPeriods.length}');
      for (final p in allPeriods) {
        print(
          '   - ${p.displayName} (${p.periodType}, #${p.periodNumber}, ${p.year}) id=${p.id}',
        );
      }

      List<EmployeePayroll> payrolls = [];
      if (currentPeriod != null) {
        payrolls = await PayrollDatasource.getPayrolls(
          periodId: currentPeriod.id,
        );
      }
      print('📋 Nóminas en periodo actual: ${payrolls.length}');

      final incapacities = await PayrollDatasource.getIncapacities();
      final loans = await PayrollDatasource.getLoans();

      state = state.copyWith(
        concepts: concepts,
        periods: allPeriods,
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
      // Buscar periodo en state, o cargarlo desde DB si es nuevo
      PayrollPeriod? period = state.periods
          .where((p) => p.id == periodId)
          .firstOrNull;
      if (period == null) {
        // Periodo nuevo, recargar lista de periodos
        final allPeriods = await PayrollDatasource.getPeriods();
        period = allPeriods.where((p) => p.id == periodId).firstOrNull;
        state = state.copyWith(
          payrolls: payrolls,
          currentPeriod: period ?? state.currentPeriod,
          periods: allPeriods,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          payrolls: payrolls,
          currentPeriod: period,
          isLoading: false,
        );
      }
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

  /// Eliminar nómina (solo si está en borrador/pendiente)
  Future<bool> deletePayroll(String payrollId) async {
    try {
      await PayrollDatasource.deletePayroll(payrollId);
      state = state.copyWith(
        payrolls: state.payrolls.where((p) => p.id != payrollId).toList(),
      );
      return true;
    } catch (e) {
      print('❌ Error eliminando nómina: $e');
      return false;
    }
  }

  /// Agregar concepto a nómina (ingreso o descuento)
  /// Si [skipReload] es true, no recarga estado (útil en creación masiva).
  Future<bool> addConceptToPayroll({
    required String payrollId,
    required String conceptId,
    required double amount,
    double quantity = 1,
    double unitValue = 0,
    String? notes,
    bool skipReload = false,
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

      // Si skipReload, no recargar estado (el llamador hará reload al final)
      if (!skipReload) {
        // Recargar la nómina seleccionada
        await selectPayroll(payrollId);

        // Recargar lista de nóminas
        if (state.currentPeriod != null) {
          final payrolls = await PayrollDatasource.getPayrolls(
            periodId: state.currentPeriod!.id,
          );
          state = state.copyWith(payrolls: payrolls);
        }
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

        // ── Auto-generar time_adjustments para cada día de la incapacidad ──
        await _generateTimeAdjustmentsForIncapacity(created);

        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error creando incapacidad: $e');
      return false;
    }
  }

  /// Genera automáticamente los time_adjustments para cada día laboral
  /// de la incapacidad/permiso, siguiendo las reglas colombianas (Art. 227 CST).
  Future<void> _generateTimeAdjustmentsForIncapacity(
    EmployeeIncapacity incapacity,
  ) async {
    try {
      final employeeId = incapacity.employeeId;
      final type = incapacity
          .type; // enfermedad, accidente_laboral, accidente_comun, permiso, maternidad

      // Cargar ajustes existentes para evitar duplicados
      final existingAdj = await EmployeesDatasource.getTimeAdjustments(
        employeeId: employeeId,
        startDate: incapacity.startDate,
      );
      final existingDates = <String>{};
      for (final adj in existingAdj) {
        if (!adj.adjustmentDate.isAfter(incapacity.endDate)) {
          existingDates.add(adj.adjustmentDate.toIso8601String().split('T')[0]);
        }
      }

      // Iterar cada día del rango
      DateTime current = incapacity.startDate;
      int dayNumber = 0; // Contador de días laborales en esta incapacidad

      while (!current.isAfter(incapacity.endDate)) {
        // Saltar domingos (día de descanso)
        if (current.weekday == DateTime.sunday) {
          current = current.add(const Duration(days: 1));
          continue;
        }

        dayNumber++;
        final dateStr = '${current.day}/${current.month}/${current.year}';
        final dateKey = current.toIso8601String().split('T')[0];

        // Verificar si ya existe ajuste para esta fecha
        if (existingDates.contains(dateKey)) {
          print('⏭️ Ajuste ya existe para $dateKey — omitiendo');
          current = current.add(const Duration(days: 1));
          continue;
        }

        final isSaturday = current.weekday == DateTime.saturday;
        // Horas laborales: L-V = 7.7h, Sáb = 5.5h (jornada 44h/semana)
        final hoursToDeduct = isSaturday ? 5.5 : 7.7;
        final minutesToDeduct = (hoursToDeduct * 60).round(); // 462 o 330 min

        if (type == 'permiso') {
          // ─── PERMISO: 0% pago → descuento 100% del día + PIERDE_BONO ───
          await EmployeesDatasource.createTimeAdjustment(
            employeeId: employeeId,
            minutes: minutesToDeduct,
            type: 'deduction',
            date: current,
            reason: 'Permiso — $dateStr | PIERDE_BONO',
          );
          print('✅ Permiso ajuste creado: $dateKey ($minutesToDeduct min)');
        } else if (type == 'accidente_laboral') {
          // ─── ACCIDENTE LABORAL: ARL paga 100% desde día 1, sin descuento ───
          // No crear ajuste — pago completo
          print(
            'ℹ️ Accidente laboral día $dayNumber: sin descuento (ARL 100%)',
          );
        } else {
          // ─── ENFERMEDAD / ACCIDENTE COMÚN / MATERNIDAD ───
          // Art. 227 CST:
          //   Días 1-3: empresa paga 100% (sin descuento)
          //   Día 4+: pago 66.33% (descuento del 33.67%)
          if (dayNumber <= 3) {
            // Días 1-3: pago completo, NO crear adjustment (sin descuento)
            print(
              'ℹ️ Incapacidad día $dayNumber: empresa paga 100% — sin ajuste',
            );
          } else {
            // Día 4+: descuento del 33.67%
            final discountMinutes = (minutesToDeduct * 0.3367).round();
            await EmployeesDatasource.createTimeAdjustment(
              employeeId: employeeId,
              minutes: discountMinutes,
              type: 'deduction',
              date: current,
              reason: 'Incapacidad día $dayNumber — pago 66.33% — $dateStr',
            );
            print(
              '✅ Incapacidad día $dayNumber ajuste: $dateKey ($discountMinutes min)',
            );
          }
        }

        current = current.add(const Duration(days: 1));
      }

      print(
        '✅ Auto-generación de time_adjustments completada para ${incapacity.type} (${incapacity.startDate} → ${incapacity.endDate})',
      );
    } catch (e) {
      print('⚠️ Error generando time_adjustments automáticos: $e');
      // No lanzar excepción — la incapacidad ya se creó correctamente
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

  Future<bool> cancelLoan(String loanId) async {
    try {
      await PayrollDatasource.cancelLoan(loanId);
      await loadLoans();
      return true;
    } catch (e) {
      print('❌ Error anulando préstamo: $e');
      return false;
    }
  }

  // ==========================================
  // HORAS EXTRAS
  // ==========================================
  Future<bool> addOvertimeHours({
    required String payrollId,
    required double hours,
    required String
    type, // 'normal', '25' (diurna), '75' (nocturna), '100' (dom/fest), '150' (dom/fest noct)
    required double hourlyRate,
    bool skipReload = false,
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
        multiplier = 1.0; // Sin recargo
        typeLabel = 'Normal';
        break;
      case '25':
        multiplier = 1.25; // Diurna (6am-9pm)
        typeLabel = 'Diurna';
        break;
      case '75':
        multiplier = 1.75; // Nocturna (9pm-6am)
        typeLabel = 'Nocturna';
        break;
      case '100':
        multiplier = 2.0; // Dominical/Festivo diurna
        typeLabel = 'Dom/Fest Diurna';
        break;
      case '150':
        multiplier = 2.5; // Dominical/Festivo nocturna
        typeLabel = 'Dom/Fest Nocturna';
        break;
      default:
        multiplier = 1.0;
        typeLabel = 'Normal';
    }

    final amount = hours * hourlyRate * multiplier;
    final recargoText = multiplier > 1.0
        ? ' (+${((multiplier - 1) * 100).toInt()}%)'
        : ' (sin recargo)';

    return addConceptToPayroll(
      payrollId: payrollId,
      conceptId: concept.id,
      amount: amount,
      quantity: hours,
      unitValue: hourlyRate * multiplier,
      notes: '${hours.toStringAsFixed(1)} hrs $typeLabel$recargoText',
      skipReload: skipReload,
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
    bool skipReload = false,
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
      skipReload: skipReload,
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
    try {
      if (state.deductionConcepts.isEmpty) {
        print('❌ No hay conceptos de descuento cargados');
        // Aún así, registrar el pago del préstamo
        await _registerLoanPaymentDirect(loan: loan, payrollId: payrollId);
        return true;
      }

      final concept = state.deductionConcepts.firstWhere(
        (c) => c.code == 'DESC_PRESTAMO',
        orElse: () => state.deductionConcepts.first,
      );

      print(
        '📋 Concepto préstamo: ${concept.code} (${concept.name}) id=${concept.id}',
      );
      print(
        '💰 Monto cuota: ${loan.installmentAmount}, Cuota ${loan.paidInstallments + 1}/${loan.installments}',
      );

      // Intentar agregar como detalle de nómina (opcional, no bloquea el pago)
      await addConceptToPayroll(
        payrollId: payrollId,
        conceptId: concept.id,
        amount: loan.installmentAmount,
        notes:
            'Cuota ${loan.paidInstallments + 1}/${loan.installments} - Préstamo',
      );

      // SIEMPRE registrar el pago del préstamo (esto salda la deuda)
      await _registerLoanPaymentDirect(loan: loan, payrollId: payrollId);

      return true;
    } catch (e) {
      print('❌ Error en addLoanInstallmentDiscount: $e');
      // Último intento: registrar el pago directamente
      try {
        await _registerLoanPaymentDirect(loan: loan, payrollId: payrollId);
      } catch (e2) {
        print('❌ Error final registrando pago: $e2');
      }
      return false;
    }
  }

  /// Registrar pago de cuota y crear asiento contable para nómina
  Future<void> _registerLoanPaymentDirect({
    required EmployeeLoan loan,
    required String payrollId,
  }) async {
    // 1. Registrar pago en loan_payments + actualizar employee_loans
    await registerLoanPayment(
      loanId: loan.id,
      amount: loan.installmentAmount,
      installmentNumber: loan.paidInstallments + 1,
      payrollId: payrollId,
    );
    print('✅ Cuota de préstamo registrada - Préstamo saldado en nómina');

    // 2. Crear asiento contable: reducir 122 Préstamos a Empleados
    //    Cuando se descuenta de nómina, NO hay movimiento de efectivo.
    //    El empleado recibe MENOS sueldo, eso salda la deuda.
    //    Débito: 621 Sueldos (la parte retenida sigue siendo gasto salarial)
    //    Crédito: 122 Préstamos a Empleados (el activo baja)
    try {
      await PayrollDatasource.createLoanSettlementEntry(
        loanId: loan.id,
        amount: loan.installmentAmount,
        employeeName: loan.employeeName ?? 'Empleado',
        installmentNumber: loan.paidInstallments + 1,
        totalInstallments: loan.installments,
      );
      print('✅ Asiento contable creado: 122 Préstamos a Empleados reducido');
    } catch (e) {
      print('⚠️ Error creando asiento contable de préstamo: $e');
    }
  }
}

/// Provider de nómina
final payrollProvider = NotifierProvider<PayrollNotifier, PayrollState>(() {
  return PayrollNotifier();
});
