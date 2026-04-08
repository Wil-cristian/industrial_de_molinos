import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/datasources/accounts_datasource.dart';
import '../../../data/datasources/payroll_datasource.dart';
import '../../../data/providers/accounts_provider.dart';
import '../../../domain/entities/employee.dart';
import '../../../data/providers/payroll_provider.dart';
import '../../../data/providers/employees_provider.dart';
import '../../../domain/entities/cash_movement.dart';

/// Tab de préstamos y adelantos de empleados.
class EmployeesLoansTab extends ConsumerStatefulWidget {
  const EmployeesLoansTab({super.key});

  @override
  ConsumerState<EmployeesLoansTab> createState() => EmployeesLoansTabState();
}

class EmployeesLoansTabState extends ConsumerState<EmployeesLoansTab> {
  /// Public API for shell coordinator to trigger loan dialog
  void showLoanDialog({Employee? employee}) =>
      _showLoanDialog(employee: employee);

  @override
  Widget build(BuildContext context) {
    final payrollState = ref.watch(payrollProvider);
    final theme = Theme.of(context);
    return _buildLoansTab(theme, payrollState);
  }

  Widget _buildPayrollSummaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: const Color(0xFF757575),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoansTab(ThemeData theme, PayrollState payrollState) {
    if (payrollState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final activeLoans = payrollState.activeLoans;
    final paidLoans = payrollState.loans
        .where((l) => l.status == 'pagado')
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen
          Row(
            children: [
              Expanded(
                child: _buildPayrollSummaryCard(
                  'Préstamos Activos',
                  '${activeLoans.length}',
                  Icons.account_balance_wallet,
                  const Color(0xFFF9A825),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPayrollSummaryCard(
                  'Monto Total Prestado',
                  Helpers.formatCurrency(
                    activeLoans.fold(0.0, (sum, l) => sum + l.totalAmount),
                  ),
                  Icons.attach_money,
                  theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPayrollSummaryCard(
                  'Pendiente de Cobro',
                  Helpers.formatCurrency(
                    activeLoans.fold(0.0, (sum, l) => sum + l.remainingAmount),
                  ),
                  Icons.pending,
                  const Color(0xFFC62828),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Lista de préstamos activos
          const Text(
            'Préstamos Activos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (activeLoans.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 64,
                        color: const Color(0xFF81C784),
                      ),
                      const SizedBox(height: 16),
                      const Text('No hay préstamos activos'),
                    ],
                  ),
                ),
              ),
            )
          else
            ...activeLoans.map((loan) => _buildLoanCard(loan, theme)),

          if (paidLoans.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Préstamos Pagados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...paidLoans.map(
              (loan) => _buildLoanCard(loan, theme, isPaid: true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoanCard(
    EmployeeLoan loan,
    ThemeData theme, {
    bool isPaid = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isPaid
                      ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                      : const Color(0xFFF9A825).withValues(alpha: 0.1),
                  child: Icon(
                    isPaid ? Icons.check : Icons.account_balance_wallet,
                    color: isPaid
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFF9A825),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan.employeeName ?? 'Empleado',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Fecha: ${Helpers.formatDate(loan.loanDate)}',
                        style: TextStyle(
                          color: const Color(0xFF757575),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Helpers.formatCurrency(loan.totalAmount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      '${loan.installments} cuotas',
                      style: TextStyle(
                        color: const Color(0xFF757575),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            // Barra de progreso
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progreso: ${loan.paidInstallments}/${loan.installments} cuotas',
                          ),
                          Text('${(loan.progress * 100).toStringAsFixed(0)}%'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: loan.progress,
                        backgroundColor: const Color(0xFFEEEEEE),
                        color: isPaid
                            ? const Color(0xFF2E7D32)
                            : theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cuota: ${Helpers.formatCurrency(loan.installmentAmount)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  'Pendiente: ${Helpers.formatCurrency(loan.remainingAmount)}',
                  style: TextStyle(
                    color: const Color(0xFFD32F2F),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (loan.reason != null && loan.reason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Motivo: ${loan.reason}',
                style: TextStyle(color: const Color(0xFF757575), fontSize: 12),
              ),
            ],
            if (!isPaid) ...[
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Botón de pago manual (siempre disponible para préstamos activos)
                  TextButton.icon(
                    onPressed: () => _showManualLoanPaymentDialog(loan),
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text('Abonar Cuota'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF388E3C),
                    ),
                  ),
                  if (loan.paidInstallments == 0) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _confirmCancelLoan(loan),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Anular'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFC62828),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showManualLoanPaymentDialog(EmployeeLoan loan) async {
    // Cargar cuentas para seleccionar de dónde recibe el pago
    final accountsData = await Supabase.instance.client
        .from('accounts')
        .select('id, name, balance')
        .order('name');

    if (accountsData.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay cuentas configuradas'),
            backgroundColor: Color(0xFFC62828),
          ),
        );
      }
      return;
    }

    String? selectedAccountId = accountsData[0]['id'];
    double paymentAmount = loan.installmentAmount;
    String paymentMethod = 'efectivo';
    final amountController = TextEditingController(
      text: loan.installmentAmount.toStringAsFixed(0),
    );
    final notesController = TextEditingController();
    bool isCustomAmount = false;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final remaining = loan.remainingAmount;
          final isValidAmount =
              paymentAmount > 0 && paymentAmount <= remaining + 0.01;

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.payments, color: const Color(0xFF388E3C)),
                const SizedBox(width: 8),
                const Text('Abonar Cuota'),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 450, minWidth: 200),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info del préstamo
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loan.employeeName ?? 'Empleado',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total: ${Helpers.formatCurrency(loan.totalAmount)}',
                              ),
                              Text(
                                'Pendiente: ${Helpers.formatCurrency(remaining)}',
                                style: TextStyle(
                                  color: const Color(0xFFD32F2F),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Progreso: ${loan.paidInstallments}/${loan.installments} cuotas',
                            style: TextStyle(
                              color: const Color(0xFF757575),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tipo de monto
                    Text(
                      'Monto a abonar',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF424242),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: Text(
                              'Cuota: ${Helpers.formatCurrency(loan.installmentAmount)}',
                            ),
                            selected: !isCustomAmount,
                            onSelected: (v) {
                              setState(() {
                                isCustomAmount = false;
                                paymentAmount = loan.installmentAmount;
                                amountController.text = loan.installmentAmount
                                    .toStringAsFixed(0);
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Monto personalizado'),
                            selected: isCustomAmount,
                            onSelected: (v) {
                              setState(() {
                                isCustomAmount = true;
                                amountController.text = '';
                                paymentAmount = 0;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    if (isCustomAmount) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Monto',
                          prefixText: '\$ ',
                          border: const OutlineInputBorder(),
                          helperText:
                              'Máx: ${Helpers.formatCurrency(remaining)}',
                          errorText: paymentAmount > remaining + 0.01
                              ? 'Excede el saldo pendiente'
                              : null,
                        ),
                        onChanged: (value) {
                          final parsed =
                              double.tryParse(
                                value.replaceAll(',', '.').replaceAll(' ', ''),
                              ) ??
                              0;
                          setState(() => paymentAmount = parsed);
                        },
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Método de pago
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Método de pago',
                        prefixIcon: Icon(Icons.payment),
                        border: OutlineInputBorder(),
                      ),
                      value: paymentMethod,
                      items: const [
                        DropdownMenuItem(
                          value: 'efectivo',
                          child: Text('Efectivo'),
                        ),
                        DropdownMenuItem(
                          value: 'transferencia',
                          child: Text('Transferencia'),
                        ),
                        DropdownMenuItem(value: 'otro', child: Text('Otro')),
                      ],
                      onChanged: (v) =>
                          setState(() => paymentMethod = v ?? 'efectivo'),
                    ),
                    const SizedBox(height: 16),

                    // Cuenta donde ingresa el dinero
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Cuenta que recibe el pago',
                        prefixIcon: Icon(Icons.account_balance),
                        border: OutlineInputBorder(),
                      ),
                      value: selectedAccountId,
                      items: accountsData.map<DropdownMenuItem<String>>((acc) {
                        return DropdownMenuItem(
                          value: acc['id'] as String,
                          child: Text(
                            '${acc['name']} (${Helpers.formatCurrency((acc['balance'] ?? 0).toDouble())})',
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => selectedAccountId = v),
                    ),
                    const SizedBox(height: 16),

                    // Notas opcionales
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notas (opcional)',
                        prefixIcon: Icon(Icons.note),
                        border: OutlineInputBorder(),
                        hintText: 'Ej: Pago adelantado en efectivo',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Resumen
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Abono:'),
                              Text(
                                Helpers.formatCurrency(paymentAmount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF388E3C),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Nuevo saldo:'),
                              Text(
                                Helpers.formatCurrency(
                                  (remaining - paymentAmount).clamp(
                                    0,
                                    double.infinity,
                                  ),
                                ),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: (remaining - paymentAmount) <= 0.01
                                      ? const Color(0xFF388E3C)
                                      : const Color(0xFFF57C00),
                                ),
                              ),
                            ],
                          ),
                          if ((remaining - paymentAmount).abs() < 0.01) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF2E7D32,
                                ).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '🎉 Este pago liquida el préstamo completamente',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: !isValidAmount || selectedAccountId == null
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);

                        try {
                          // 1. Registrar el pago en loan_payments y actualizar employee_loans
                          final paySuccess = await ref
                              .read(payrollProvider.notifier)
                              .registerLoanPayment(
                                loanId: loan.id,
                                amount: paymentAmount,
                                installmentNumber: loan.paidInstallments + 1,
                              );

                          if (paySuccess) {
                            // 2. Registrar ingreso en caja con balance atómico
                            final movement = CashMovement(
                              id: '',
                              accountId: selectedAccountId!,
                              type: MovementType.income,
                              category: MovementCategory.pago_prestamo,
                              amount: paymentAmount,
                              description:
                                  'Abono préstamo - ${loan.employeeName ?? "Empleado"} - Cuota ${loan.paidInstallments + 1}/${loan.installments}${notesController.text.isNotEmpty ? " | ${notesController.text}" : ""}',
                              reference: loan.id,
                              personName: loan.employeeName,
                              date: DateTime.now(),
                            );
                            await AccountsDataSource.createMovementWithBalanceUpdate(
                              movement,
                            );

                            // 3. Refrescar datos
                            ref.read(dailyCashProvider.notifier).load();
                            await ref
                                .read(payrollProvider.notifier)
                                .loadLoans();

                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  '✅ Abono de ${Helpers.formatCurrency(paymentAmount)} registrado correctamente',
                                ),
                                backgroundColor: const Color(0xFF2E7D32),
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('❌ Error al registrar el pago'),
                                backgroundColor: Color(0xFFC62828),
                              ),
                            );
                          }
                        } catch (e) {
                          print('❌ Error en pago manual: $e');
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('❌ Error: $e'),
                              backgroundColor: const Color(0xFFC62828),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.check),
                label: const Text('Registrar Abono'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmCancelLoan(EmployeeLoan loan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFC62828)),
            SizedBox(width: 8),
            Text('Anular Préstamo'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de anular este préstamo?'),
            const SizedBox(height: 12),
            Text(
              'Empleado: ${loan.employeeName ?? ""}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              'Monto: ${Helpers.formatCurrency(loan.totalAmount)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9A825).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Se eliminará el préstamo y se devolverá el dinero a la cuenta de origen.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(ctx);
              Navigator.pop(ctx);

              final success = await ref
                  .read(payrollProvider.notifier)
                  .cancelLoan(loan.id);

              if (success) {
                ref.read(dailyCashProvider.notifier).load();
              }

              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? '✅ Préstamo anulado correctamente'
                        : '❌ Error al anular préstamo',
                  ),
                  backgroundColor: success
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFC62828),
                ),
              );
            },
            icon: const Icon(Icons.delete_forever),
            label: const Text('Anular'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
          ),
        ],
      ),
    );
  }

  void _showLoanDialog({Employee? employee}) async {
    // Cargar cuentas disponibles
    final accountsData = await Supabase.instance.client
        .from('accounts')
        .select()
        .eq('is_active', true)
        .order('name');

    if (accountsData.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay cuentas disponibles'),
            backgroundColor: Color(0xFFC62828),
          ),
        );
      }
      return;
    }

    final employees = ref.read(employeesProvider).activeEmployees;
    String? selectedEmployeeId = employee?.id;
    String? selectedAccountId = accountsData[0]['id'];
    double selectedAccountBalance = (accountsData[0]['balance'] ?? 0)
        .toDouble();
    double amount = 0;
    int installments = 1;
    final reasonController = TextEditingController();

    // Generar quincenas futuras para seleccionar inicio de descuento
    final now = DateTime.now();
    const meses = [
      '',
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];

    List<Map<String, dynamic>> futureQuincenas = [];
    {
      // Primero: quincena actual + futuras (12 = 6 meses)
      DateTime refDate = DateTime(now.year, now.month, now.day);
      for (int i = 0; i < 12; i++) {
        final int qMonth = refDate.month;
        final int qYear = refDate.year;
        final bool isQ1 = refDate.day <= 15;
        final int periodNumber = isQ1 ? (qMonth * 2 - 1) : (qMonth * 2);
        final String label = '${meses[qMonth]} Q${isQ1 ? 1 : 2} $qYear';

        futureQuincenas.add({
          'label': label,
          'periodNumber': periodNumber,
          'year': qYear,
          'month': qMonth,
          'isQ1': isQ1,
        });

        // Avanzar a la siguiente quincena
        if (isQ1) {
          refDate = DateTime(qYear, qMonth, 16);
        } else {
          refDate = DateTime(qYear, qMonth + 1, 1);
        }
      }

      // Después: quincenas pasadas (más reciente primero, scrolleando hacia abajo)
      DateTime pastDate = DateTime(now.year, now.month, now.day);
      for (int i = 0; i < 6; i++) {
        // Retroceder una quincena
        if (pastDate.day <= 15) {
          pastDate = pastDate.month == 1
              ? DateTime(pastDate.year - 1, 12, 16)
              : DateTime(pastDate.year, pastDate.month - 1, 16);
        } else {
          pastDate = DateTime(pastDate.year, pastDate.month, 1);
        }

        final int qMonth = pastDate.month;
        final int qYear = pastDate.year;
        final bool isQ1 = pastDate.day <= 15;
        final int periodNumber = isQ1 ? (qMonth * 2 - 1) : (qMonth * 2);
        final String label =
            '${meses[qMonth]} Q${isQ1 ? 1 : 2} $qYear (pasada)';

        futureQuincenas.add({
          'label': label,
          'periodNumber': periodNumber,
          'year': qYear,
          'month': qMonth,
          'isQ1': isQ1,
          'isPast': true,
        });
      }
    }

    int selectedStartQuincenaIndex =
        0; // Por defecto la quincena actual (primera)

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final installmentAmount = installments > 0
              ? amount / installments
              : 0.0;
          final hasEnoughBalance = selectedAccountBalance >= amount;

          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text('Nuevo Préstamo a Empleado'),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 480, minWidth: 200),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selección de empleado
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Empleado',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      value: selectedEmployeeId,
                      items: employees
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.id,
                              child: Text('${e.fullName} - ${e.position}'),
                            ),
                          )
                          .toList(),
                      onChanged: employee == null
                          ? (value) =>
                                setState(() => selectedEmployeeId = value)
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Monto y cuotas
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue: amount > 0 ? amount.toString() : '',
                            decoration: const InputDecoration(
                              labelText: 'Monto del Préstamo',
                              prefixIcon: Icon(Icons.attach_money),
                              prefixText: '\$ ',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => setState(
                              () => amount = double.tryParse(v) ?? 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: installments.toString(),
                            decoration: const InputDecoration(
                              labelText: 'Cuotas',
                              prefixIcon: Icon(Icons.calendar_view_month),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => setState(
                              () => installments = int.tryParse(v) ?? 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Preview de cuota
                    if (amount > 0 && installments > 0)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9A825).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFFF9A825,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Cuota quincenal a descontar:',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              Helpers.formatCurrency(installmentAmount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFFF9A825),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Selector de quincena de inicio de descuento
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Inicio de descuento',
                        prefixIcon: Icon(Icons.calendar_month),
                        border: OutlineInputBorder(),
                        helperText: 'Quincena donde empieza el descuento',
                      ),
                      value: selectedStartQuincenaIndex,
                      items:
                          futureQuincenas // 12 futuras + 6 pasadas
                              .toList()
                              .asMap()
                              .entries
                              .map((entry) {
                                final isPast = entry.value['isPast'] == true;
                                return DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(
                                    entry.value['label'] as String,
                                    style: TextStyle(
                                      color: isPast
                                          ? const Color(0xFF9E9E9E)
                                          : null,
                                      fontStyle: isPast
                                          ? FontStyle.italic
                                          : null,
                                    ),
                                  ),
                                );
                              })
                              .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedStartQuincenaIndex = value);
                        }
                      },
                    ),

                    // Cronograma de cuotas
                    if (amount > 0 && installments > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF1565C0,
                          ).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFF1565C0,
                            ).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: const Color(0xFF1976D2),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Cronograma de descuento ($installments cuotas)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: const Color(0xFF1565C0),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(installments > 12 ? 12 : installments, (
                              i,
                            ) {
                              // Calcular la quincena avanzando hacia adelante desde
                              // la quincena de inicio (no usar índice directo en
                              // futureQuincenas, que mezcla futuras y pasadas).
                              final startQ =
                                  futureQuincenas[selectedStartQuincenaIndex];
                              int qMonth = startQ['month'] as int;
                              int qYear = startQ['year'] as int;
                              bool isQ1 = startQ['isQ1'] as bool;
                              // Avanzar i quincenas hacia el futuro
                              for (int k = 0; k < i; k++) {
                                if (isQ1) {
                                  isQ1 = false; // Q1 → Q2 mismo mes
                                } else {
                                  isQ1 = true; // Q2 → Q1 mes siguiente
                                  qMonth++;
                                  if (qMonth > 12) {
                                    qMonth = 1;
                                    qYear++;
                                  }
                                }
                              }
                              const qMeses = [
                                '',
                                'Ene',
                                'Feb',
                                'Mar',
                                'Abr',
                                'May',
                                'Jun',
                                'Jul',
                                'Ago',
                                'Sep',
                                'Oct',
                                'Nov',
                                'Dic',
                              ];
                              final now2 = DateTime.now();
                              final isPast =
                                  DateTime(
                                    qYear,
                                    qMonth,
                                    isQ1 ? 15 : 28,
                                  ).isBefore(
                                    DateTime(now2.year, now2.month, now2.day),
                                  );
                              final qLabel =
                                  '${qMeses[qMonth]} Q${isQ1 ? 1 : 2} $qYear${isPast ? ' (pasada)' : ''}';
                              final isLast = i == installments - 1;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isLast
                                            ? const Color(
                                                0xFF2E7D32,
                                              ).withValues(alpha: 0.2)
                                            : const Color(
                                                0xFF1565C0,
                                              ).withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${i + 1}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isLast
                                              ? const Color(0xFF388E3C)
                                              : const Color(0xFF1976D2),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      qLabel,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const Spacer(),
                                    Text(
                                      Helpers.formatCurrency(installmentAmount),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFFF57C00),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            if (installments > 12)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '... y ${installments - 12} cuotas más',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: const Color(0xFF757575),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Selección de cuenta
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Cuenta de Egreso',
                        prefixIcon: Icon(Icons.account_balance),
                        border: OutlineInputBorder(),
                      ),
                      value: selectedAccountId,
                      items: accountsData.map<DropdownMenuItem<String>>((acc) {
                        final balance = (acc['balance'] ?? 0).toDouble();
                        return DropdownMenuItem(
                          value: acc['id'] as String,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(acc['name'] ?? 'Cuenta'),
                              Text(
                                Helpers.formatCurrency(balance),
                                style: TextStyle(
                                  color: balance >= amount
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFC62828),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          final acc = accountsData.firstWhere(
                            (a) => a['id'] == value,
                          );
                          setState(() {
                            selectedAccountId = value;
                            selectedAccountBalance = (acc['balance'] ?? 0)
                                .toDouble();
                          });
                        }
                      },
                    ),

                    if (!hasEnoughBalance && amount > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC62828).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning,
                              color: Color(0xFFC62828),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Saldo insuficiente',
                              style: TextStyle(
                                color: const Color(0xFFD32F2F),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Motivo
                    TextField(
                      controller: reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Motivo del préstamo (opcional)',
                        prefixIcon: Icon(Icons.note),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Color(0xFF1565C0),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'El préstamo se descontará automáticamente de la nómina en cada periodo',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: (selectedEmployeeId == null || amount <= 0)
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);

                        final startQ =
                            futureQuincenas[selectedStartQuincenaIndex];
                        final startLabel = startQ['label'] as String;
                        final reasonText = reasonController.text.isNotEmpty
                            ? reasonController.text
                            : null;
                        final notesWithSchedule =
                            'Inicio descuento: $startLabel${reasonText != null ? ' | Motivo: $reasonText' : ''}';

                        final success = await ref
                            .read(payrollProvider.notifier)
                            .createLoan(
                              employeeId: selectedEmployeeId!,
                              amount: amount,
                              installments: installments,
                              accountId: selectedAccountId!,
                              reason: notesWithSchedule,
                            );

                        // Refrescar Caja Diaria para que el saldo y movimiento aparezcan
                        if (success) {
                          ref.read(dailyCashProvider.notifier).load();
                        }

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? '✅ Préstamo de ${Helpers.formatCurrency(amount)} otorgado'
                                  : '❌ Error al crear préstamo',
                            ),
                            backgroundColor: success
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFC62828),
                          ),
                        );
                      },
                icon: const Icon(Icons.check),
                label: const Text('Crear Préstamo'),
              ),
            ],
          );
        },
      ),
    );
  }
}
