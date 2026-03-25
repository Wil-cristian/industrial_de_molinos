import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/datasources/accounts_datasource.dart';
import '../../../data/datasources/payroll_datasource.dart';
import '../../../data/providers/accounts_provider.dart';
import '../../../domain/entities/employee.dart';
import '../../../data/providers/payroll_provider.dart';
import '../../../domain/entities/cash_movement.dart';

/// Tab de préstamos y adelantos de empleados.
class EmployeesLoansTab extends ConsumerStatefulWidget {
  const EmployeesLoansTab({super.key});

  @override
  ConsumerState<EmployeesLoansTab> createState() => EmployeesLoansTabState();
}

class EmployeesLoansTabState extends ConsumerState<EmployeesLoansTab> {
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

  void _showAdelantoDialog(Employee employee) async {
    // Cargar cuentas para seleccionar de dónde sale el dinero
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
    double amount = 0;
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isValidAmount = amount > 0;

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.money, color: const Color(0xFF7B1FA2)),
                const SizedBox(width: 8),
                const Text('Adelanto de Sueldo'),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info del empleado
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(
                              0xFF7B1FA2,
                            ).withValues(alpha: 0.1),
                            child: Text(
                              employee.initials,
                              style: TextStyle(
                                color: const Color(0xFF7B1FA2),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employee.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                employee.position,
                                style: TextStyle(
                                  color: const Color(0xFF757575),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Dinero entregado por adelantado al empleado.',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF757575),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Monto
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Monto del adelanto',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final parsed =
                            double.tryParse(
                              value.replaceAll(',', '.').replaceAll(' ', ''),
                            ) ??
                            0;
                        setState(() => amount = parsed);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Cuenta de dónde sale el dinero
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Cuenta de salida',
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
                        labelText: 'Motivo (opcional)',
                        prefixIcon: Icon(Icons.note),
                        border: OutlineInputBorder(),
                        hintText: 'Ej: Para gastos médicos',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Resumen
                    if (amount > 0)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7B1FA2).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFF7B1FA2,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Se entrega al empleado:'),
                            Text(
                              Helpers.formatCurrency(amount),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF7B1FA2),
                                fontSize: 16,
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
                onPressed: !isValidAmount || selectedAccountId == null
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);

                        try {
                          // Crear movimiento de caja como GASTO (dinero sale)
                          final movement = CashMovement(
                            id: '',
                            accountId: selectedAccountId!,
                            type: MovementType.expense,
                            category: MovementCategory.nomina,
                            amount: amount,
                            description:
                                'Adelanto de sueldo - ${employee.fullName}${notesController.text.isNotEmpty ? " | ${notesController.text}" : ""}',
                            personName: employee.fullName,
                            date: DateTime.now(),
                          );
                          await AccountsDataSource.createMovementWithBalanceUpdate(
                            movement,
                          );

                          // Refrescar datos
                          ref.read(dailyCashProvider.notifier).load();

                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                '✅ Adelanto de ${Helpers.formatCurrency(amount)} entregado a ${employee.fullName}',
                              ),
                              backgroundColor: const Color(0xFF2E7D32),
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('❌ Error: $e'),
                              backgroundColor: const Color(0xFFC62828),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.check),
                label: const Text('Entregar Adelanto'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7B1FA2),
                ),
              ),
            ],
          );
        },
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
            content: SizedBox(
              width: 450,
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

  // ============================================================
  // TAB 5: INCAPACIDADES
  // ============================================================
}
