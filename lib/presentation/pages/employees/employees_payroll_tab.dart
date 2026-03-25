import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/print_service.dart';
import '../../../data/datasources/accounts_datasource.dart';
import '../../../data/datasources/employees_datasource.dart';
import '../../../data/datasources/payroll_datasource.dart';
import '../../../data/providers/accounts_provider.dart';
import '../../../data/providers/employees_provider.dart';
import '../../../data/providers/payroll_provider.dart';
import '../../../domain/entities/employee.dart';

/// Tab de nómina de empleados.
class EmployeesPayrollTab extends ConsumerStatefulWidget {
  const EmployeesPayrollTab({super.key});

  @override
  ConsumerState<EmployeesPayrollTab> createState() =>
      EmployeesPayrollTabState();
}

class EmployeesPayrollTabState extends ConsumerState<EmployeesPayrollTab> {
  /// Public API for shell coordinator to open payroll creation dialog.
  void showCreatePayrollDialog() => _showCreatePayrollDialog();

  @override
  Widget build(BuildContext context) {
    final empState = ref.watch(employeesProvider);
    final payrollState = ref.watch(payrollProvider);
    final theme = Theme.of(context);
    return _buildPayrollTab(theme, empState, payrollState);
  }

  Widget _buildPayrollTab(
    ThemeData theme,
    EmployeesState empState,
    PayrollState payrollState,
  ) {
    if (payrollState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // ── Calcular estadísticas reales ──
    // Total quincenal = suma de (salario/2) de cada empleado activo
    final empleadosActivos = empState.employees
        .where((e) => e.status == EmployeeStatus.activo)
        .toList();
    final costoTotalQuincenal = empleadosActivos.fold(
      0.0,
      (sum, e) => sum + (e.salary ?? 0) / 2,
    );

    // Pagado = sum of netPay de nóminas pagadas en este periodo
    final nominasPagadas = payrollState.payrolls
        .where((p) => p.status == 'pagado')
        .toList();
    final totalPagado = nominasPagadas.fold(0.0, (sum, p) => sum + p.netPay);

    // Pendiente
    final nominasPendientes = payrollState.payrolls
        .where((p) => p.status != 'pagado')
        .toList();

    // Empleados sin nómina creada en este periodo
    final empleadosConNomina = payrollState.payrolls
        .map((p) => p.employeeId)
        .toSet();
    final empleadosSinNomina = empleadosActivos
        .where((e) => !empleadosConNomina.contains(e.id))
        .toList();

    // Bono de asistencia: para nóminas creadas, verificar si tienen bono
    // (bono = diferencia entre totalEarnings y baseSalary, ya que baseSalary es quincenal)
    int empleadosConBono = 0;
    double totalBonoCreadas = 0;
    for (final p in payrollState.payrolls) {
      // baseSalary ya es quincenal (salary/2), así que comparamos totalEarnings vs baseSalary
      final diferencia = p.totalEarnings - p.baseSalary;
      if (diferencia >= 149000) {
        empleadosConBono++;
        totalBonoCreadas +=
            diferencia; // Usar la diferencia real (puede ser bono + HE)
      }
    }
    // Para empleados sin nómina, estimar bono de asistencia estándar
    final bonoEstimadoSinCrear = empleadosSinNomina.length * 150000.0;
    final totalBonoQuincenal = totalBonoCreadas + bonoEstimadoSinCrear;

    // Costo bruto = salario base + bono (lo que la empresa "debe" antes de deducciones)
    final costoTotalConBono = costoTotalQuincenal + totalBonoQuincenal;

    // Deducciones totales (préstamos, adelantos descontados en nómina)
    final totalDeducciones = payrollState.payrolls.fold(
      0.0,
      (sum, p) => sum + p.totalDeductions,
    );

    // Neto a Pagar = Costo Bruto - Deducciones (fórmula correcta)
    final netoAPagar = costoTotalConBono - totalDeducciones;
    // Pendiente = lo que falta por pagar
    final totalPendiente = netoAPagar - totalPagado;
    final progreso = netoAPagar > 0
        ? (totalPagado / netoAPagar).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Header compacto
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Panel de Nómina',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Navegación de periodos
                    IconButton(
                      onPressed: () {
                        final periods =
                            payrollState.periods
                                .where((p) => p.periodType == 'quincenal')
                                .toList()
                              ..sort((a, b) {
                                final yearCmp = a.year.compareTo(b.year);
                                if (yearCmp != 0) return yearCmp;
                                return a.periodNumber.compareTo(b.periodNumber);
                              });
                        final currentIdx = periods.indexWhere(
                          (p) => p.id == payrollState.currentPeriod?.id,
                        );
                        if (currentIdx > 0) {
                          ref
                              .read(payrollProvider.notifier)
                              .loadPayrollsForPeriod(
                                periods[currentIdx - 1].id,
                              );
                        }
                      },
                      icon: const Icon(Icons.chevron_left, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      tooltip: 'Periodo anterior',
                    ),
                    Text(
                      payrollState.currentPeriod?.displayName ?? 'Sin periodo',
                      style: TextStyle(
                        color: const Color(0xFF757575),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        final periods =
                            payrollState.periods
                                .where((p) => p.periodType == 'quincenal')
                                .toList()
                              ..sort((a, b) {
                                final yearCmp = a.year.compareTo(b.year);
                                if (yearCmp != 0) return yearCmp;
                                return a.periodNumber.compareTo(b.periodNumber);
                              });
                        final currentIdx = periods.indexWhere(
                          (p) => p.id == payrollState.currentPeriod?.id,
                        );
                        if (currentIdx >= 0 &&
                            currentIdx < periods.length - 1) {
                          ref
                              .read(payrollProvider.notifier)
                              .loadPayrollsForPeriod(
                                periods[currentIdx + 1].id,
                              );
                        }
                      },
                      icon: const Icon(Icons.chevron_right, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      tooltip: 'Periodo siguiente',
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Exportando...'))),
                icon: const Icon(Icons.download, size: 14),
                label: const Text('Exportar'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: _showCreatePayrollDialog,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Nuevo Pago'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Tarjetas resumen de nómina ──
          SizedBox(
            height: 100,
            child: Row(
              children: [
                // Costo Bruto (Salario + Bono)
                Expanded(
                  flex: 2,
                  child: Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.groups,
                                size: 14,
                                color: const Color(0xFF757575),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Costo Bruto (${empleadosActivos.length} emp)',
                                  style: TextStyle(
                                    color: const Color(0xFF757575),
                                    fontSize: 9,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            Helpers.formatCurrency(costoTotalConBono),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Base ${Helpers.formatCurrency(costoTotalQuincenal)} + Bono ${Helpers.formatCurrency(totalBonoQuincenal)}',
                            style: TextStyle(
                              fontSize: 8,
                              color: const Color(0xFF9E9E9E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Deducciones
                Expanded(
                  flex: 2,
                  child: Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: const Color(0xFFEF9A9A)),
                    ),
                    color: const Color(0xFFFFEBEE),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.remove_circle_outline,
                                size: 14,
                                color: const Color(0xFFD32F2F),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '- Deducciones',
                                  style: TextStyle(
                                    color: const Color(0xFFD32F2F),
                                    fontSize: 9,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            Helpers.formatCurrency(totalDeducciones),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFC62828),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Neto a Pagar (= Pagado + Pendiente)
                Expanded(
                  flex: 2,
                  child: Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    color: theme.colorScheme.primary.withValues(alpha: 0.05),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '= Neto a Pagar',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            Helpers.formatCurrency(netoAPagar),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progreso,
                              minHeight: 5,
                              backgroundColor: const Color(0xFFEEEEEE),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                progreso >= 1.0
                                    ? const Color(0xFF2E7D32)
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${(progreso * 100).toStringAsFixed(0)}% pagado',
                            style: TextStyle(
                              fontSize: 9,
                              color: const Color(0xFF9E9E9E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Pagado
                Expanded(
                  flex: 2,
                  child: Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: const Color(0xFFA5D6A7)),
                    ),
                    color: const Color(0xFFE8F5E9),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 14,
                                color: const Color(0xFF388E3C),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Pagado (${nominasPagadas.length})',
                                style: TextStyle(
                                  color: const Color(0xFF388E3C),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            Helpers.formatCurrency(totalPagado),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Pendiente
                Expanded(
                  flex: 2,
                  child: Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: const Color(0xFFFFCC80)),
                    ),
                    color: const Color(0xFFFFF3E0),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.pending,
                                size: 14,
                                color: const Color(0xFFF57C00),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Pendiente (${nominasPendientes.length + empleadosSinNomina.length})',
                                  style: TextStyle(
                                    color: const Color(0xFFF57C00),
                                    fontSize: 10,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            Helpers.formatCurrency(totalPendiente),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFEF6C00),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Tabla de pagos (ocupa el espacio restante)
          Expanded(
            child: _buildPayrollEmployeesTable(
              theme,
              payrollState,
              empState,
              empleadosSinNomina,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatCard(
    IconData icon,
    String label,
    String value,
    String change,
    ThemeData theme,
  ) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: const Color(0xFFEEEEEE)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: const Color(0xFF757575),
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      change,
                      style: TextStyle(
                        color: const Color(0xFF43A047),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.arrow_upward,
                      size: 8,
                      color: const Color(0xFF43A047),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactTrendCard(ThemeData theme, PayrollState payrollState) {
    final months = ['Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final values = [0.45, 0.30, 0.35, 0.80, 0.55, 0.70, 0.65];
    final currentMonth = 6; // Dic

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: const Color(0xFFEEEEEE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tendencia de Costos',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  Helpers.formatCurrency(payrollState.totalNetPayroll * 6),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Últimos 6 meses',
                  style: TextStyle(color: const Color(0xFF757575), fontSize: 9),
                ),
                Text(
                  '+5.2% vs anterior',
                  style: TextStyle(
                    color: const Color(0xFF43A047),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(months.length, (i) {
                  final isCurrent = i == currentMonth;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: values[i],
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.primary.withValues(
                                            alpha: 0.2,
                                          ),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            months[i],
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isCurrent
                                  ? theme.colorScheme.primary
                                  : const Color(0xFF757575),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactDistributionCard(
    ThemeData theme,
    EmployeesState empState,
  ) {
    final departments = <String, int>{};
    for (final emp in empState.employees.where(
      (e) => e.status == EmployeeStatus.activo,
    )) {
      final dept = emp.department ?? 'Otros';
      departments[dept] = (departments[dept] ?? 0) + 1;
    }

    final colors = [
      theme.colorScheme.primary,
      const Color(0xFF64B5F6),
      const Color(0xFF90CAF9),
      const Color(0xFFBDBDBD),
    ];
    final total = empState.employees
        .where((e) => e.status == EmployeeStatus.activo)
        .length;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: const Color(0xFFEEEEEE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Distribución Salarial',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$total',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Por departamento',
                  style: TextStyle(color: const Color(0xFF757575), fontSize: 9),
                ),
                Text(
                  'Empleados activos',
                  style: TextStyle(
                    color: const Color(0xFF43A047),
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.05,
                        ),
                      ),
                      child: CustomPaint(
                        painter: _WaveChartPainter(theme.colorScheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: departments.entries
                          .take(4)
                          .toList()
                          .asMap()
                          .entries
                          .map((entry) {
                            final i = entry.key;
                            final dept = entry.value;
                            return Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: colors[i % colors.length],
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    dept.key,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: const Color(0xFF616161),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${dept.value}',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          })
                          .toList(),
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

  Widget _buildCompactPaymentsTable(
    ThemeData theme,
    PayrollState payrollState,
    EmployeesState empState,
  ) {
    final pendingPayrolls = payrollState.payrolls
        .where((p) => p.status != 'pagado')
        .take(5)
        .toList();

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Próximos Pagos',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                  ),
                  child: Text(
                    'Ver todos',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: const Color(0xFFFAFAFA),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'EMPLEADO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'DEPARTAMENTO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'FECHA PAGO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'MONTO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'ESTADO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ),
                SizedBox(width: 28),
              ],
            ),
          ),
          Expanded(
            child: pendingPayrolls.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          size: 20,
                          color: const Color(0xFFBDBDBD),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No hay pagos pendientes',
                          style: TextStyle(
                            color: const Color(0xFF757575),
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: _showCreatePayrollDialog,
                          icon: const Icon(Icons.add, size: 10),
                          label: const Text('Crear Nómina'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            textStyle: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: pendingPayrolls.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: const Color(0xFFEEEEEE)),
                    itemBuilder: (context, index) {
                      final payroll = pendingPayrolls[index];
                      final employee = empState.employees
                          .where((e) => e.id == payroll.employeeId)
                          .firstOrNull;
                      final statusColor = payroll.status == 'pagado'
                          ? const Color(0xFF2E7D32)
                          : payroll.status == 'aprobado'
                          ? const Color(0xFF1565C0)
                          : const Color(0xFFF9A825);

                      return InkWell(
                        onTap: () => _showPayrollDetailDialog(payroll),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: theme.colorScheme.primary
                                          .withValues(alpha: 0.1),
                                      child: Text(
                                        (payroll.employeeName ?? 'E')[0]
                                            .toUpperCase(),
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            payroll.employeeName ?? 'Empleado',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            payroll.employeePosition ?? '',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: const Color(0xFF757575),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  employee?.department ?? '-',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: const Color(0xFF616161),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  payroll.paymentDate != null
                                      ? Helpers.formatDate(payroll.paymentDate!)
                                      : 'Por definir',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: const Color(0xFF616161),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  Helpers.formatCurrency(payroll.netPay),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    payroll.status == 'pagado'
                                        ? 'Pagado'
                                        : payroll.status == 'aprobado'
                                        ? 'Aprobado'
                                        : 'Pendiente',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert,
                                  size: 18,
                                  color: const Color(0xFF757575),
                                ),
                                padding: EdgeInsets.zero,
                                onSelected: (v) {
                                  if (v == 'ver') {
                                    _showPayrollDetailDialog(payroll);
                                  }
                                  if (v == 'editar') {
                                    _showAddConceptDialog(payroll);
                                  }
                                  if (v == 'pagar') {
                                    _showPayPayrollDialog(payroll);
                                  }
                                  if (v == 'pago_mensual') {
                                    _showMonthlyPaymentDialog(payroll);
                                  }
                                  if (v == 'imprimir') {
                                    _printPayroll(payroll);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'ver',
                                    child: Text(
                                      'Ver detalles',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'editar',
                                    child: Text(
                                      'Editar',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  if (payroll.status != 'pagado')
                                    const PopupMenuItem(
                                      value: 'pagar',
                                      child: Text(
                                        'Pagar',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  if (payroll.status != 'pagado')
                                    const PopupMenuItem(
                                      value: 'pago_mensual',
                                      child: Text(
                                        'Pago Mensual',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF1565C0),
                                        ),
                                      ),
                                    ),
                                  if (payroll.status == 'pagado')
                                    const PopupMenuItem(
                                      value: 'imprimir',
                                      child: Text(
                                        'Imprimir comprobante',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF2E7D32),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollEmployeesTable(
    ThemeData theme,
    PayrollState payrollState,
    EmployeesState empState,
    List<Employee> empleadosSinNomina,
  ) {
    // Construir lista unificada: empleados con nómina + empleados sin nómina
    // Primero pagados, luego pendientes, luego sin crear
    final pagados = payrollState.payrolls
        .where((p) => p.status == 'pagado')
        .toList();
    final pendientes = payrollState.payrolls
        .where((p) => p.status != 'pagado')
        .toList();

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nóminas del Periodo (${payrollState.payrolls.length + empleadosSinNomina.length} empleados)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Header de tabla
          Container(
            color: const Color(0xFFFAFAFA),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'EMPLEADO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'SALARIO QUINC.',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'NETO A PAGAR',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'ESTADO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ),
                SizedBox(width: 28),
              ],
            ),
          ),
          // Lista de empleados
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Pendientes primero (necesitan acción)
                ...pendientes.map((payroll) {
                  final employee = empState.employees
                      .where((e) => e.id == payroll.employeeId)
                      .firstOrNull;
                  return _buildPayrollRow(
                    theme: theme,
                    name: payroll.employeeName ?? 'Empleado',
                    position: payroll.employeePosition ?? '',
                    salarioQuincenal:
                        (employee?.salary ?? payroll.baseSalary * 2) / 2,
                    netoPagar: payroll.netPay,
                    status: payroll.status == 'aprobado'
                        ? 'Aprobado'
                        : 'Pendiente',
                    statusColor: payroll.status == 'aprobado'
                        ? const Color(0xFF1565C0)
                        : const Color(0xFFF9A825),
                    onTap: () => _showPayrollDetailDialog(payroll),
                    onPagar: () => _showPayPayrollDialog(payroll),
                    onEditar: () => _showAddConceptDialog(payroll),
                    showActions: true,
                    onPagoMensual: () => _showMonthlyPaymentDialog(payroll),
                    onEliminar: () => _confirmDeletePayroll(payroll),
                  );
                }),
                // Sin nómina creada
                ...empleadosSinNomina.map((employee) {
                  return _buildPayrollRow(
                    theme: theme,
                    name: '${employee.firstName} ${employee.lastName}',
                    position: employee.position,
                    salarioQuincenal: (employee.salary ?? 0) / 2,
                    netoPagar: null,
                    status: 'Sin crear',
                    statusColor: const Color(0xFF9E9E9E),
                    onTap: null,
                    onPagar: null,
                    onEditar: null,
                    showActions: false,
                    onCrear: () =>
                        _showCreatePayrollDialog(preSelectedEmployee: employee),
                  );
                }),
                // Pagados al final
                ...pagados.map((payroll) {
                  final employee = empState.employees
                      .where((e) => e.id == payroll.employeeId)
                      .firstOrNull;
                  return _buildPayrollRow(
                    theme: theme,
                    name: payroll.employeeName ?? 'Empleado',
                    position: payroll.employeePosition ?? '',
                    salarioQuincenal:
                        (employee?.salary ?? payroll.baseSalary * 2) / 2,
                    netoPagar: payroll.netPay,
                    status: 'Pagado',
                    statusColor: const Color(0xFF2E7D32),
                    onTap: () => _showPayrollDetailDialog(payroll),
                    onPagar: null,
                    onEditar: null,
                    showActions: true,
                    onImprimir: () => _printPayroll(payroll),
                    onEliminar: () => _confirmDeletePayroll(payroll),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollRow({
    required ThemeData theme,
    required String name,
    required String position,
    required double salarioQuincenal,
    required double? netoPagar,
    required String status,
    required Color statusColor,
    required VoidCallback? onTap,
    required VoidCallback? onPagar,
    required VoidCallback? onEditar,
    required bool showActions,
    VoidCallback? onCrear,
    VoidCallback? onPagoMensual,
    VoidCallback? onImprimir,
    VoidCallback? onEliminar,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: const Color(0xFFEEEEEE))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: statusColor.withValues(alpha: 0.1),
                    child: Text(
                      name[0].toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: status == 'Pagado'
                                ? const Color(0xFF757575)
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          position,
                          style: TextStyle(
                            fontSize: 10,
                            color: const Color(0xFF757575),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                Helpers.formatCurrency(salarioQuincenal),
                style: TextStyle(fontSize: 11, color: const Color(0xFF616161)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                netoPagar != null ? Helpers.formatCurrency(netoPagar) : '-',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: status == 'Pagado' ? const Color(0xFF388E3C) : null,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: onCrear != null ? 80 : 28,
              child: onCrear != null
                  ? SizedBox(
                      height: 28,
                      child: FilledButton.icon(
                        onPressed: onCrear,
                        icon: const Icon(Icons.add, size: 12),
                        label: const Text('Crear'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(fontSize: 10),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    )
                  : showActions
                  ? PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: const Color(0xFF757575),
                      ),
                      padding: EdgeInsets.zero,
                      onSelected: (v) {
                        if (v == 'ver' && onTap != null) onTap();
                        if (v == 'editar' && onEditar != null) onEditar();
                        if (v == 'pagar' && onPagar != null) onPagar();
                        if (v == 'pago_mensual' && onPagoMensual != null) {
                          onPagoMensual();
                        }
                        if (v == 'imprimir' && onImprimir != null) onImprimir();
                        if (v == 'eliminar' && onEliminar != null) onEliminar();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'ver',
                          child: Text(
                            'Ver detalles',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'editar',
                          child: Text('Editar', style: TextStyle(fontSize: 12)),
                        ),
                        if (onPagar != null)
                          const PopupMenuItem(
                            value: 'pagar',
                            child: Text(
                              'Pagar',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        if (onPagoMensual != null)
                          const PopupMenuItem(
                            value: 'pago_mensual',
                            child: Text(
                              'Pago Mensual',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                          ),
                        if (onImprimir != null)
                          const PopupMenuItem(
                            value: 'imprimir',
                            child: Text(
                              'Imprimir comprobante',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                        if (onEliminar != null)
                          const PopupMenuItem(
                            value: 'eliminar',
                            child: Text(
                              'Eliminar nómina',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFC62828),
                              ),
                            ),
                          ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayrollDetailDialog(EmployeePayroll payroll) {
    // Cargar detalles de la nómina desde la BD
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<List<PayrollDetail>>(
        future: PayrollDatasource.getPayrollDetails(payroll.id),
        builder: (context, snapshot) {
          final details = snapshot.data ?? [];
          final incomes = details.where((d) => d.type == 'ingreso').toList();
          final deductions = details
              .where((d) => d.type == 'descuento')
              .toList();

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 600,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1),
                          child: Text(
                            (payroll.employeeName ?? 'E')
                                .substring(0, 1)
                                .toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                payroll.employeeName ?? 'Empleado',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                payroll.employeePosition ?? '',
                                style: TextStyle(
                                  color: const Color(0xFF757575),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: payroll.status == 'pagado'
                                ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                                : const Color(
                                    0xFFF9A825,
                                  ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            payroll.status == 'pagado' ? 'Pagado' : 'Pendiente',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: payroll.status == 'pagado'
                                  ? const Color(0xFF388E3C)
                                  : const Color(0xFFF57C00),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),

                    // Salario base y días
                    _buildDetailRowDialog(
                      'Salario Quincenal',
                      Helpers.formatCurrency(payroll.baseSalary),
                    ),
                    _buildDetailRowDialog(
                      'Días Trabajados',
                      '${payroll.daysWorked} días',
                    ),
                    if (payroll.daysAbsent > 0)
                      _buildDetailRowDialog(
                        'Días Ausencia',
                        '${payroll.daysAbsent} días',
                        const Color(0xFFF57C00),
                      ),
                    if (payroll.daysIncapacity > 0)
                      _buildDetailRowDialog(
                        'Días Incapacidad',
                        '${payroll.daysIncapacity} días',
                        const Color(0xFF1976D2),
                      ),

                    // Ingresos adicionales (detalles)
                    if (incomes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'INGRESOS ADICIONALES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF388E3C),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...incomes.map(
                        (d) => _buildDetailRowDialog(
                          d.conceptName +
                              (d.notes != null && d.notes!.isNotEmpty
                                  ? ' (${d.notes})'
                                  : ''),
                          '+ ${Helpers.formatCurrency(d.amount)}',
                          const Color(0xFF388E3C),
                        ),
                      ),
                    ],

                    // Descuentos (detalles)
                    if (deductions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'DESCUENTOS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFD32F2F),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...deductions.map(
                        (d) => _buildDetailRowDialog(
                          d.conceptName +
                              (d.notes != null && d.notes!.isNotEmpty
                                  ? ' (${d.notes})'
                                  : ''),
                          '- ${Helpers.formatCurrency(d.amount)}',
                          const Color(0xFFD32F2F),
                        ),
                      ),
                    ],

                    const Divider(height: 32),
                    _buildDetailRowDialog(
                      'Total Ingresos',
                      Helpers.formatCurrency(payroll.totalEarnings),
                      const Color(0xFF2E7D32),
                    ),
                    _buildDetailRowDialog(
                      'Total Descuentos',
                      Helpers.formatCurrency(payroll.totalDeductions),
                      const Color(0xFFC62828),
                    ),
                    const Divider(height: 32),
                    _buildDetailRowDialog(
                      'Neto a Pagar',
                      Helpers.formatCurrency(payroll.netPay),
                      Theme.of(context).colorScheme.primary,
                      true,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        // Eliminar nómina (solo si no está pagada)
                        if (payroll.status != 'pagado')
                          TextButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Eliminar Nómina'),
                                  content: Text(
                                    '¿Eliminar la nómina de ${payroll.employeeName}?\n\nEsto permite recrearla con los datos actualizados.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancelar'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFC62828,
                                        ),
                                      ),
                                      child: const Text('Eliminar'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                final success = await ref
                                    .read(payrollProvider.notifier)
                                    .deletePayroll(payroll.id);

                                if (mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? '✅ Nómina eliminada. Puedes recrearla con +Nóm'
                                            : '❌ Error al eliminar',
                                      ),
                                      backgroundColor: success
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFC62828),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: Icon(
                              Icons.delete_outline,
                              color: const Color(0xFFEF5350),
                              size: 18,
                            ),
                            label: Text(
                              'Eliminar',
                              style: TextStyle(color: const Color(0xFFEF5350)),
                            ),
                          ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cerrar'),
                        ),
                        if (payroll.status != 'pagado') ...[
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showPayPayrollDialog(payroll);
                            },
                            icon: const Icon(Icons.payments, size: 18),
                            label: const Text('Procesar Pago'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRowDialog(
    String label,
    String value, [
    Color? color,
    bool isBold = false,
  ]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF757575),
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: isBold ? 18 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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

  Widget _buildPayrollCard(EmployeePayroll payroll, ThemeData theme) {
    final statusColor = payroll.status == 'pagado'
        ? const Color(0xFF2E7D32)
        : payroll.status == 'aprobado'
        ? const Color(0xFF1565C0)
        : const Color(0xFFF9A825);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.1),
          child: Icon(
            payroll.status == 'pagado' ? Icons.check : Icons.pending,
            color: statusColor,
          ),
        ),
        title: Text(
          payroll.employeeName ?? 'Empleado',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(payroll.employeePosition ?? ''),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Helpers.formatCurrency(payroll.netPay),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                payroll.status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildPayrollDetailRow(
                        'Salario Base',
                        Helpers.formatCurrency(payroll.baseSalary),
                      ),
                    ),
                    Expanded(
                      child: _buildPayrollDetailRow(
                        'Días Trabajados',
                        '${payroll.daysWorked}',
                      ),
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: _buildPayrollDetailRow(
                        'Total Ingresos',
                        Helpers.formatCurrency(payroll.totalEarnings),
                        const Color(0xFF2E7D32),
                      ),
                    ),
                    Expanded(
                      child: _buildPayrollDetailRow(
                        'Total Descuentos',
                        Helpers.formatCurrency(payroll.totalDeductions),
                        const Color(0xFFC62828),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (payroll.status != 'pagado') ...[
                      OutlinedButton.icon(
                        onPressed: () => _showAddConceptDialog(payroll),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Agregar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _showPayPayrollDialog(payroll),
                        icon: const Icon(Icons.payments, size: 18),
                        label: const Text('Pagar'),
                      ),
                    ] else
                      Text(
                        'Pagado: ${Helpers.formatDate(payroll.paymentDate!)}',
                        style: TextStyle(color: const Color(0xFF757575)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollDetailRow(String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: const Color(0xFF757575))),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 4: PRÉSTAMOS
  // ============================================================
  void _showCreatePayrollDialog({Employee? preSelectedEmployee}) async {
    final employees = ref.read(employeesProvider).activeEmployees;
    final payrollState = ref.read(payrollProvider);

    // Si no hay periodo, intentar cargarlo
    if (payrollState.currentPeriod == null) {
      await ref.read(payrollProvider.notifier).loadAll();
      final newState = ref.read(payrollProvider);
      if (newState.currentPeriod == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo cargar el periodo activo. Verifica la conexión.',
              ),
              backgroundColor: Color(0xFFC62828),
            ),
          );
        }
        return;
      }
    } else {
      // Recargar préstamos y conceptos para tener datos frescos
      await Future.wait([
        ref.read(payrollProvider.notifier).loadLoans(),
        ref.read(payrollProvider.notifier).loadConcepts(),
      ]);
    }

    var currentPayrollState = ref.read(payrollProvider);

    // Generar lista de quincenas disponibles (últimas 6 quincenas)
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

    List<Map<String, dynamic>> availableQuincenas = [];
    for (int i = 0; i < 6; i++) {
      // Recorrer quincenas hacia atrás desde la actual
      DateTime refDate = DateTime(now.year, now.month, now.day);
      // Restar quincenas: cada iteración retrocede ~15 días
      for (int j = 0; j < i; j++) {
        if (refDate.day <= 15) {
          // Estamos en Q1, ir a Q2 del mes anterior
          refDate = DateTime(refDate.year, refDate.month - 1, 16);
        } else {
          // Estamos en Q2, ir a Q1 del mismo mes
          refDate = DateTime(refDate.year, refDate.month, 1);
        }
      }

      final int qMonth = refDate.month;
      final int qYear = refDate.year;
      final bool isQ1 = refDate.day <= 15;
      final int periodNumber = isQ1 ? (qMonth * 2 - 1) : (qMonth * 2);
      final DateTime qStart = isQ1
          ? DateTime(qYear, qMonth, 1)
          : DateTime(qYear, qMonth, 16);
      final DateTime qEnd = isQ1
          ? DateTime(qYear, qMonth, 15)
          : DateTime(qYear, qMonth + 1, 0);
      final String label = (i == 0)
          ? '${meses[qMonth]} Q${isQ1 ? 1 : 2} $qYear (${qStart.day}-${now.day}/${qMonth.toString().padLeft(2, '0')}) parcial'
          : '${meses[qMonth]} Q${isQ1 ? 1 : 2} $qYear (${qStart.day}-${qEnd.day}/${qMonth.toString().padLeft(2, '0')})';

      availableQuincenas.add({
        'label': label,
        'periodNumber': periodNumber,
        'year': qYear,
        'month': qMonth,
        'isQ1': isQ1,
        'startDate': qStart,
        'endDate': qEnd,
        'isCurrent': i == 0,
      });
    }

    // Por defecto seleccionar la quincena anterior (la actual no ha terminado)
    // Si viene un empleado pre-seleccionado, usar la quincena actual (index 0)
    int selectedQuincenaIndex = preSelectedEmployee != null
        ? 0
        : (availableQuincenas.length > 1 ? 1 : 0);

    // Cargar empleados que ya tienen nómina en la quincena seleccionada por defecto
    final defaultQ = availableQuincenas[selectedQuincenaIndex];
    final defaultPNum = defaultQ['periodNumber'] as int;
    final defaultPYear = defaultQ['year'] as int;
    final defaultPeriods = await PayrollDatasource.getPeriods(
      year: defaultPYear,
    );
    // Buscar TODOS los periodos que coinciden (puede haber duplicados)
    final matchingPeriods = defaultPeriods
        .where(
          (p) => p.periodType == 'quincenal' && p.periodNumber == defaultPNum,
        )
        .toList();

    Set<String> employeesWithPayroll = {};
    List<EmployeePayroll> existingPayrollsList = [];
    for (final period in matchingPeriods) {
      final payrolls = await PayrollDatasource.getPayrolls(periodId: period.id);
      employeesWithPayroll.addAll(payrolls.map((p) => p.employeeId));
      existingPayrollsList.addAll(payrolls);
    }

    var availableEmployees = employees
        .where((e) => !employeesWithPayroll.contains(e.id))
        .toList();

    if (availableEmployees.isEmpty && availableQuincenas.length > 1) {
      // Todos tienen nómina en el periodo actual, pero puede haber otra quincena
      // No bloquear — dejar que cambien de quincena
    }

    String? selectedEmployeeId = preSelectedEmployee?.id;
    Employee? selectedEmployee = preSelectedEmployee;
    double baseSalary = preSelectedEmployee?.salary ?? 0;

    // Validar que el empleado pre-seleccionado está en la lista de disponibles
    if (selectedEmployeeId != null &&
        !availableEmployees.any((e) => e.id == selectedEmployeeId)) {
      selectedEmployeeId = null;
      selectedEmployee = null;
      baseSalary = 0;
    }
    double totalHoursWorked = 0;
    double baseHoursQuincena = 88.0;
    double overtimeHours = 0;
    double underHours = 0;
    String overtimeType = 'normal';
    int totalWorkdays = 12;
    int daysWorked = 12;
    int daysAbsent = 0;
    int ausenciaDays = 0;
    int permisoDays = 0;
    int incapacidadDays = 0;
    int domingoDeductions = 0;
    int calendarDays = 15; // Días calendario (incluye domingos pagados)
    int fullCalendarDays = 15; // Días calendario de la quincena completa
    bool pierdeBono = false;
    bool?
    bonoManualOverride; // null = automático, true = forzar bono, false = quitar bono
    bool includeActiveLoans = true;
    bool isLoadingHours = false;
    Set<String> absentDates = {}; // Fechas con ausencia/permiso/incapacidad

    // Horas extras manuales (para agregar retroactivamente)
    double?
    manualOvertimeHours; // null = usar auto-detectadas, número = override manual
    bool showOvertimeEditor = false;
    final overtimeController = TextEditingController();

    // Fecha de corte personalizable (para quincena actual)
    DateTime? customEndDate;

    // Modo complemento: para pagar días restantes cuando ya hay nómina
    bool isComplemento = false;
    DateTime? complementStartDate;

    // Constantes para cálculo quincenal
    const double baseHoursPerFortnight = 88.0; // 44h x 2 semanas
    const double hoursPerMonth =
        240.0; // 30 días × 8h (incluye descansos pagados) — Art. 132 CST

    // Multiplicadores de horas extra según tipo
    double getOvertimeMultiplier(String type) {
      switch (type) {
        case 'normal':
          return 1.0; // Sin recargo
        case '25':
          return 1.25; // Diurna (6am-9pm)
        case '75':
          return 1.75; // Nocturna (9pm-6am)
        case '100':
          return 2.0; // Dominical/Festivo diurna
        case '150':
          return 2.5; // Dominical/Festivo nocturna
        default:
          return 1.0;
      }
    }

    String getOvertimeLabel(String type) {
      switch (type) {
        case 'normal':
          return 'Normal (sin recargo)';
        case '25':
          return 'Diurna (+25%)';
        case '75':
          return 'Nocturna (+75%)';
        case '100':
          return 'Dom/Fest Diurna (+100%)';
        case '150':
          return 'Dom/Fest Nocturna (+150%)';
        default:
          return 'Normal (sin recargo)';
      }
    }

    // Función para cargar asistencia del empleado en la quincena seleccionada
    Future<Map<String, dynamic>> loadEmployeeAttendance(
      String employeeId,
      DateTime quinStart,
      DateTime quinEnd,
    ) async {
      // Contar días laborales (L-S), horas base, y días calendario (incluye domingos)
      int workdays = 0;
      int calDays = 0;
      double baseHrs = 0;
      DateTime d = quinStart;
      while (!d.isAfter(quinEnd)) {
        calDays++; // Todos los días calendario (L-D) cuentan para el pago
        if (d.weekday == DateTime.saturday) {
          workdays++;
          baseHrs += 5.5;
        } else if (d.weekday != DateTime.sunday) {
          workdays++;
          baseHrs += 7.7;
        }
        d = d.add(const Duration(days: 1));
      }

      // Cargar ajustes directamente de Supabase para este empleado y rango
      final adjustments = await EmployeesDatasource.getTimeAdjustments(
        employeeId: employeeId,
        startDate: quinStart,
      );

      // Filtrar solo los de la quincena
      final quinAdjustments = adjustments
          .where(
            (a) =>
                !a.adjustmentDate.isBefore(quinStart) &&
                !a.adjustmentDate.isAfter(quinEnd),
          )
          .toList();

      int ausencias = 0;
      int permisos = 0;
      int incapacidades = 0;
      int domingos = 0;
      bool perdioBonoFlag = false;
      double totalDeductionMin = 0;
      double overtimeMin = 0;
      final absentDatesSet = <String>{};

      for (final adj in quinAdjustments) {
        final reason = (adj.reason ?? '').toLowerCase();
        if (reason.startsWith('ausencia')) {
          ausencias++;
          perdioBonoFlag = true;
          totalDeductionMin += adj.minutes;
          final dk =
              '${adj.adjustmentDate.year}-${adj.adjustmentDate.month.toString().padLeft(2, '0')}-${adj.adjustmentDate.day.toString().padLeft(2, '0')}';
          absentDatesSet.add(dk);
        } else if (reason.startsWith('descuento dominical')) {
          domingos++;
          totalDeductionMin += adj.minutes;
        } else if (reason.startsWith('permiso')) {
          permisos++;
          perdioBonoFlag = true;
          totalDeductionMin += adj.minutes;
          final dk =
              '${adj.adjustmentDate.year}-${adj.adjustmentDate.month.toString().padLeft(2, '0')}-${adj.adjustmentDate.day.toString().padLeft(2, '0')}';
          absentDatesSet.add(dk);
        } else if (reason.startsWith('incapacidad')) {
          incapacidades++;
          perdioBonoFlag = true;
          totalDeductionMin += adj.minutes;
          final dk =
              '${adj.adjustmentDate.year}-${adj.adjustmentDate.month.toString().padLeft(2, '0')}-${adj.adjustmentDate.day.toString().padLeft(2, '0')}';
          absentDatesSet.add(dk);
        } else if (adj.type == 'overtime') {
          overtimeMin += adj.minutes;
        } else if (adj.type == 'deduction') {
          totalDeductionMin += adj.minutes;
        }
      }

      final deductionHrs = totalDeductionMin / 60.0;
      final overtimeHrs = overtimeMin / 60.0;
      final worked = baseHrs - deductionHrs + overtimeHrs;
      final actualDaysWorked = workdays - ausencias - permisos - incapacidades;

      return {
        'workedHours': worked,
        'baseHours': baseHrs,
        'calendarDays': calDays,
        'totalWorkdays': workdays,
        'daysWorked': actualDaysWorked > 0 ? actualDaysWorked : 0,
        'ausenciaDays': ausencias,
        'permisoDays': permisos,
        'incapacidadDays': incapacidades,
        'domingoDeductions': domingos,
        'pierdeBono': perdioBonoFlag,
        'overtimeHours': overtimeHrs,
        'absentDates': absentDatesSet,
      };
    }

    // Bonos extras manuales: lista de {descripcion, monto}
    List<Map<String, dynamic>> extraBonuses = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Detectar si es empleado de pago diario
          final bool isDailyPay = selectedEmployee?.isDailyPay ?? false;
          final double empDailyRate = selectedEmployee?.dailyRate ?? 0;
          final double empAttendanceBonus =
              selectedEmployee?.attendanceBonus ?? 0;
          final int empBonusDays = selectedEmployee?.attendanceBonusDays ?? 6;

          // Calcular valores — Tarifa hora: salario / 240 (Art. 132 CST)
          // Tarifa diaria: salario / 30 (incluye domingos pagados)
          final hourlyRate = baseSalary > 0 ? baseSalary / hoursPerMonth : 0.0;
          final dailyRate = baseSalary > 0 ? baseSalary / 30.0 : 0.0;

          // Determinar si es quincena parcial (fecha de corte antes del fin)
          final selectedQ = availableQuincenas[selectedQuincenaIndex];
          final qEnd = selectedQ['endDate'] as DateTime;
          final qStart = (isComplemento && complementStartDate != null)
              ? complementStartDate!
              : selectedQ['startDate'] as DateTime;
          final qOriginalStart = selectedQ['startDate'] as DateTime;
          // Fecha de corte efectiva
          final effectiveCutDate =
              customEndDate ??
              ((selectedQ['isCurrent'] == true && DateTime.now().isBefore(qEnd))
                  ? DateTime.now()
                  : qEnd);
          final bool isPartialQuincena =
              effectiveCutDate.isBefore(qEnd) || isComplemento;

          // === CÁLCULO DIFERENCIADO POR TIPO DE PAGO ===
          double fortnightSalary;
          double overtimePay;
          double underHoursDiscount;
          double bonoAsistencia;
          bool ganaBono;
          int weekBonusCount = 0;

          if (isDailyPay && empDailyRate > 0) {
            // PAGO DIARIO: días trabajados × tarifa diaria
            fortnightSalary = daysWorked * empDailyRate;
            overtimePay = 0;
            underHoursDiscount = 0;

            // Bono semanal: solo si vino los 6 días SEGUIDOS de L a S
            // Sin faltar NI UN día en la semana. Si falta 1, pierde bono esa semana.
            weekBonusCount = 0;

            // Recorrer semanas completas (L-S) dentro de la quincena
            DateTime weekStart = qStart;
            // Avanzar al lunes más cercano
            while (weekStart.weekday != DateTime.monday &&
                !weekStart.isAfter(effectiveCutDate)) {
              weekStart = weekStart.add(const Duration(days: 1));
            }

            while (!weekStart.isAfter(effectiveCutDate)) {
              final saturday = weekStart.add(
                const Duration(days: 5),
              ); // Mon+5 = Sat
              // Solo contar semanas completas (L-S dentro del rango)
              if (!saturday.isAfter(effectiveCutDate)) {
                bool allPresent = true;
                // Verificar cada día L-S (6 días)
                for (int i = 0; i < 6; i++) {
                  final day = weekStart.add(Duration(days: i));
                  final dateKey =
                      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                  if (absentDates.contains(dateKey)) {
                    allPresent = false;
                    break;
                  }
                }
                if (allPresent) weekBonusCount++;
              }
              weekStart = weekStart.add(const Duration(days: 7));
            }

            ganaBono =
                bonoManualOverride ?? (weekBonusCount > 0 && !pierdeBono);
            bonoAsistencia = ganaBono ? empAttendanceBonus * weekBonusCount : 0;
          } else {
            // PAGO POR HORAS (empleados normales)
            // Salario base: proporcional por días calendario (domingos incluidos)
            fortnightSalary = isPartialQuincena
                ? dailyRate * calendarDays
                : baseSalary / 2;
            final overtimeMultiplier = getOvertimeMultiplier(overtimeType);
            // Usar horas extras manuales si fueron ingresadas, sino las auto-detectadas
            final effectiveOvertimeHours = manualOvertimeHours ?? overtimeHours;
            overtimePay =
                effectiveOvertimeHours * hourlyRate * overtimeMultiplier;
            underHoursDiscount =
                (manualOvertimeHours != null && manualOvertimeHours! > 0)
                ? 0
                : underHours * hourlyRate;
            // Bono: si hay override manual, usar ese; si no, automático
            ganaBono = bonoManualOverride ?? !pierdeBono;
            bonoAsistencia = (ganaBono && selectedEmployee != null)
                ? 150000.0
                : 0.0;
          }

          // Buscar préstamos activos del empleado
          final activeLoans = selectedEmployeeId != null
              ? currentPayrollState.loans
                    .where(
                      (l) =>
                          l.employeeId == selectedEmployeeId &&
                          l.status == 'activo',
                    )
                    .toList()
              : <EmployeeLoan>[];
          final loanDeduction = includeActiveLoans
              ? activeLoans.fold(0.0, (sum, l) => sum + l.installmentAmount)
              : 0.0;

          // Debug: verificar préstamos cargados
          if (selectedEmployeeId != null) {
            print(
              '🔍 Préstamos en estado: ${currentPayrollState.loans.length} total, ${activeLoans.length} activos para empleado $selectedEmployeeId',
            );
            for (final l in activeLoans) {
              print(
                '   💰 Préstamo ${l.id}: cuota=${l.installmentAmount}, status=${l.status}, ${l.paidInstallments}/${l.installments}',
              );
            }
            print(
              '   📊 loanDeduction=$loanDeduction, includeActiveLoans=$includeActiveLoans',
            );
          }

          final extraBonusTotal = extraBonuses.fold(
            0.0,
            (sum, b) => sum + (b['monto'] as double),
          );
          final totalEarnings =
              fortnightSalary + overtimePay + bonoAsistencia + extraBonusTotal;
          final totalDeductions = underHoursDiscount + loanDeduction;
          final netPay = totalEarnings - totalDeductions;

          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isComplemento ? Icons.playlist_add_check : Icons.receipt_long,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(isComplemento ? 'Pago Complementario' : 'Crear Nómina'),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selector de quincena
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Quincena a pagar',
                        prefixIcon: Icon(Icons.calendar_month),
                        border: OutlineInputBorder(),
                      ),
                      value: selectedQuincenaIndex,
                      items: availableQuincenas
                          .asMap()
                          .entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(entry.value['label'] as String),
                                  if (entry.value['isCurrent'] == true) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFE0B2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'En curso',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFFF9A825),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value != null) {
                          // Buscar qué empleados ya tienen nómina en esta quincena
                          final selectedQ = availableQuincenas[value];
                          final pNum = selectedQ['periodNumber'] as int;
                          final pYear = selectedQ['year'] as int;

                          // Buscar periodo existente para ver nóminas
                          final periods = await PayrollDatasource.getPeriods(
                            year: pYear,
                          );
                          // Buscar TODOS los periodos que coinciden (puede haber duplicados)
                          final matchingPeriods = periods
                              .where(
                                (p) =>
                                    p.periodType == 'quincenal' &&
                                    p.periodNumber == pNum,
                              )
                              .toList();

                          Set<String> withPayroll = {};
                          List<EmployeePayroll> fetchedPayrolls = [];
                          for (final mp in matchingPeriods) {
                            final payrolls =
                                await PayrollDatasource.getPayrolls(
                                  periodId: mp.id,
                                );
                            withPayroll.addAll(
                              payrolls.map((p) => p.employeeId),
                            );
                            fetchedPayrolls.addAll(payrolls);
                          }

                          setState(() {
                            selectedQuincenaIndex = value;
                            customEndDate = null; // Resetear fecha de corte
                            isComplemento = false; // Resetear modo complemento
                            complementStartDate = null;
                            availableEmployees = employees
                                .where((e) => !withPayroll.contains(e.id))
                                .toList();
                            employeesWithPayroll =
                                withPayroll; // Actualizar set
                            existingPayrollsList = fetchedPayrolls;
                            // Resetear selección de empleado al cambiar quincena
                            selectedEmployeeId = null;
                            selectedEmployee = null;
                            baseSalary = 0;
                            totalHoursWorked = 0;
                            baseHoursQuincena = 88.0;
                            overtimeHours = 0;
                            underHours = 0;
                            daysWorked = 12;
                            daysAbsent = 0;
                            ausenciaDays = 0;
                            permisoDays = 0;
                            incapacidadDays = 0;
                            domingoDeductions = 0;
                            calendarDays = 15;
                            fullCalendarDays = 15;
                            pierdeBono = false;
                            manualOvertimeHours = null;
                            showOvertimeEditor = false;
                            overtimeController.clear();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Mensaje si todos tienen nómina + opción complemento
                    if (availableEmployees.isEmpty && !isComplemento)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFCC80)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Color(0xFFF9A825),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Todos los empleados ya tienen nómina en esta quincena.',
                                    style: TextStyle(color: Color(0xFFF9A825)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              '¿Pagaste la nómina adelantada y quedaron días sin cubrir?',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xDD000000),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    isComplemento = true;
                                    complementStartDate =
                                        null; // Se calcula al seleccionar empleado
                                    // En modo complemento, todos los empleados son seleccionables
                                    availableEmployees = employees.toList();
                                    selectedEmployeeId = null;
                                    selectedEmployee = null;
                                  });
                                },
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Crear Pago Complementario (días restantes)',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1976D2),
                                  side: BorderSide(
                                    color: const Color(0xFF64B5F6),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Banner de modo complemento
                    if (isComplemento)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF64B5F6)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.playlist_add_check,
                              color: const Color(0xFF1976D2),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pago Complementario — días restantes de la quincena',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1565C0),
                                    ),
                                  ),
                                  if (selectedEmployeeId != null) ...[
                                    const SizedBox(height: 2),
                                    Builder(
                                      builder: (context) {
                                        final existing = existingPayrollsList
                                            .where(
                                              (p) =>
                                                  p.employeeId ==
                                                  selectedEmployeeId,
                                            )
                                            .firstOrNull;
                                        if (existing == null) {
                                          return const SizedBox.shrink();
                                        }
                                        // Mostrar rango pagado desde las columnas de BD
                                        String paidRangeStr = '';
                                        if (existing.paidStartDate != null &&
                                            existing.paidEndDate != null) {
                                          paidRangeStr =
                                              '(${existing.paidStartDate!.day}/${existing.paidStartDate!.month.toString().padLeft(2, '0')} al ${existing.paidEndDate!.day}/${existing.paidEndDate!.month.toString().padLeft(2, '0')}/${existing.paidEndDate!.year})';
                                        } else if (existing.notes != null &&
                                            existing.notes!.contains(
                                              'PAGADO:',
                                            )) {
                                          paidRangeStr =
                                              existing.notes!
                                                  .split('\n')
                                                  .where(
                                                    (l) =>
                                                        l.startsWith('PAGADO:'),
                                                  )
                                                  .firstOrNull ??
                                              '';
                                        }
                                        return Text(
                                          'Ya pagado: ${existing.daysWorked} días — ${Helpers.formatCurrency(existing.netPay)}${paidRangeStr.isNotEmpty ? '\n$paidRangeStr' : ''}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: const Color(0xFF1E88E5),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  isComplemento = false;
                                  complementStartDate = null;
                                  availableEmployees = employees
                                      .where(
                                        (e) => !employeesWithPayroll.contains(
                                          e.id,
                                        ),
                                      )
                                      .toList();
                                  selectedEmployeeId = null;
                                  selectedEmployee = null;
                                });
                              },
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: 'Salir de modo complementario',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),

                    // Selección de empleado
                    if (availableEmployees.isNotEmpty || isComplemento)
                      DropdownButtonFormField<String>(
                        key: ValueKey('emp_quin_$selectedQuincenaIndex'),
                        decoration: const InputDecoration(
                          labelText: 'Empleado',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        value: selectedEmployeeId,
                        items: availableEmployees
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.id,
                                child: Text('${e.fullName} - ${e.position}'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) async {
                          if (value != null) {
                            final emp = availableEmployees.firstWhere(
                              (e) => e.id == value,
                            );

                            setState(() {
                              selectedEmployeeId = value;
                              selectedEmployee = emp;
                              baseSalary = emp.salary ?? 0;
                              isLoadingHours = true;
                              // Resetear complementStartDate para recalcular por empleado
                              if (isComplemento) complementStartDate = null;
                              // Resetear horas extras manuales al cambiar empleado
                              manualOvertimeHours = null;
                              showOvertimeEditor = false;
                              overtimeController.clear();
                            });

                            // Cargar asistencia real de la quincena seleccionada
                            final selectedQ =
                                availableQuincenas[selectedQuincenaIndex];
                            final qOrigStart =
                                selectedQ['startDate'] as DateTime;

                            // Si es complemento, calcular fecha inicio desde la nómina existente
                            if (isComplemento && complementStartDate == null) {
                              final existingPayroll = existingPayrollsList
                                  .where((p) => p.employeeId == value)
                                  .firstOrNull;
                              final qEndDate = selectedQ['endDate'] as DateTime;
                              if (existingPayroll != null) {
                                // 1) Usar paid_end_date de la base de datos (columna real)
                                DateTime? paidEnd = existingPayroll.paidEndDate;

                                // 2) Fallback: parsear nota "PAGADO: DD/MM al DD/MM/YYYY"
                                if (paidEnd == null) {
                                  final notes = existingPayroll.notes ?? '';
                                  final paidMatch = RegExp(
                                    r'PAGADO:.*al\s+(\d{1,2})/(\d{1,2})/(\d{4})',
                                  ).firstMatch(notes);
                                  if (paidMatch != null) {
                                    paidEnd = DateTime(
                                      int.parse(paidMatch.group(3)!),
                                      int.parse(paidMatch.group(2)!),
                                      int.parse(paidMatch.group(1)!),
                                    );
                                  }
                                }

                                // 3) Fallback: preguntar al usuario
                                if (paidEnd == null) {
                                  final pickedPaidEnd = await showDatePicker(
                                    context: context,
                                    initialDate: qOrigStart,
                                    firstDate: qOrigStart,
                                    lastDate: qEndDate,
                                    helpText: '¿Hasta qué fecha ya pagaste?',
                                  );
                                  if (pickedPaidEnd != null) {
                                    paidEnd = pickedPaidEnd;
                                    // Guardar en BD para no preguntar de nuevo
                                    await PayrollDatasource.updatePayroll(
                                      existingPayroll.id,
                                      {
                                        'paid_start_date':
                                            '${qOrigStart.year}-${qOrigStart.month.toString().padLeft(2, '0')}-${qOrigStart.day.toString().padLeft(2, '0')}',
                                        'paid_end_date':
                                            '${pickedPaidEnd.year}-${pickedPaidEnd.month.toString().padLeft(2, '0')}-${pickedPaidEnd.day.toString().padLeft(2, '0')}',
                                      },
                                    );
                                  }
                                }

                                if (paidEnd != null) {
                                  // Avanzar al siguiente día laboral después de la fecha pagada
                                  DateTime calcStart = paidEnd.add(
                                    const Duration(days: 1),
                                  );
                                  while (calcStart.weekday == DateTime.sunday) {
                                    calcStart = calcStart.add(
                                      const Duration(days: 1),
                                    );
                                  }
                                  complementStartDate = calcStart;
                                } else {
                                  // Canceló — usar inicio de quincena
                                  complementStartDate = qOrigStart;
                                }
                                // Clamp: no pasar del fin de la quincena
                                if (complementStartDate!.isAfter(qEndDate)) {
                                  complementStartDate = qEndDate;
                                }
                                // Si la fecha calculada >= fin de quincena, ya está todo pagado
                                if (paidEnd != null &&
                                    !paidEnd.isBefore(qEndDate)) {
                                  // Empleado ya tiene quincena completa pagada
                                  setState(() {
                                    isLoadingHours = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${emp.fullName} ya tiene la quincena completa pagada (hasta ${paidEnd.day}/${paidEnd.month.toString().padLeft(2, '0')})',
                                      ),
                                      backgroundColor: const Color(0xFFF9A825),
                                    ),
                                  );
                                  return;
                                }
                              } else {
                                // Sin nómina previa (raro en complemento), usar inicio quincena
                                complementStartDate = qOrigStart;
                              }
                            }

                            // Fecha de inicio: complemento o inicio regular
                            final effectiveStart =
                                (isComplemento && complementStartDate != null)
                                ? complementStartDate!
                                : qOrigStart;
                            // Fecha de corte: en complemento usar fin de quincena, sino hoy si es actual
                            final effectiveEnd =
                                customEndDate ??
                                (isComplemento
                                    ? selectedQ['endDate'] as DateTime
                                    : ((selectedQ['isCurrent'] == true &&
                                              DateTime.now().isBefore(
                                                selectedQ['endDate']
                                                    as DateTime,
                                              ))
                                          ? DateTime.now()
                                          : selectedQ['endDate'] as DateTime));
                            final data = await loadEmployeeAttendance(
                              value,
                              effectiveStart,
                              effectiveEnd,
                            );

                            // Contar días calendario
                            final qFullEnd = selectedQ['endDate'] as DateTime;
                            final fullCal =
                                qFullEnd.difference(effectiveStart).inDays + 1;

                            setState(() {
                              isLoadingHours = false;
                              totalHoursWorked =
                                  (data['workedHours'] as double);
                              baseHoursQuincena = (data['baseHours'] as double);
                              totalWorkdays = data['totalWorkdays'] as int;
                              daysWorked = data['daysWorked'] as int;
                              calendarDays = data['calendarDays'] as int;
                              fullCalendarDays = fullCal;
                              ausenciaDays = data['ausenciaDays'] as int;
                              permisoDays = data['permisoDays'] as int;
                              incapacidadDays = data['incapacidadDays'] as int;
                              domingoDeductions =
                                  data['domingoDeductions'] as int;
                              pierdeBono = data['pierdeBono'] as bool;
                              absentDates =
                                  (data['absentDates'] as Set<String>?) ?? {};
                              daysAbsent =
                                  ausenciaDays + permisoDays + incapacidadDays;

                              // Calcular horas extra o faltantes
                              if (totalHoursWorked > baseHoursQuincena) {
                                overtimeHours =
                                    totalHoursWorked - baseHoursQuincena;
                                underHours = 0;
                              } else {
                                overtimeHours = 0;
                                underHours =
                                    baseHoursQuincena - totalHoursWorked;
                              }
                            });
                          }
                        },
                      ),
                    const SizedBox(height: 16),

                    // Info del empleado seleccionado
                    if (selectedEmployee != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Cargo: ${selectedEmployee!.position}'),
                                Text(
                                  'Depto: ${selectedEmployee!.department ?? "N/A"}',
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (isDailyPay) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE1BEE7),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'PAGO DIARIO',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF7B1FA2),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Tarifa: ${Helpers.formatCurrency(empDailyRate)}/día',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Bono: ${Helpers.formatCurrency(empAttendanceBonus)} ($empBonusDays días/sem)',
                                    style: TextStyle(
                                      color: const Color(0xFF757575),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Salario Mensual: ${Helpers.formatCurrency(baseSalary)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Quincenal: ${Helpers.formatCurrency(baseSalary / 2)}',
                                    style: TextStyle(
                                      color: const Color(0xFF757575),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Selector de fecha de corte (para pago parcial)
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
                                const Icon(
                                  Icons.date_range,
                                  color: Color(0xFF1565C0),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Periodo de pago',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1565C0),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (isComplemento)
                                      GestureDetector(
                                        onTap: () async {
                                          // firstDate = primer día no pagado (complementStartDate)
                                          // NO usar qOriginalStart para evitar cobrar días ya pagados
                                          final dpFirstDate =
                                              complementStartDate ??
                                              qOriginalStart;
                                          final dpLastDate =
                                              effectiveCutDate.isBefore(
                                                dpFirstDate,
                                              )
                                              ? qEnd
                                              : effectiveCutDate;
                                          // Clamp initialDate dentro del rango
                                          var dpInitial = qStart;
                                          if (dpInitial.isBefore(dpFirstDate)) {
                                            dpInitial = dpFirstDate;
                                          }
                                          if (dpInitial.isAfter(dpLastDate)) {
                                            dpInitial = dpLastDate;
                                          }
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: dpInitial,
                                            firstDate: dpFirstDate,
                                            lastDate: dpLastDate,
                                            helpText: 'Desde qué día pagar',
                                          );
                                          if (picked != null &&
                                              selectedEmployeeId != null) {
                                            setState(() {
                                              complementStartDate = picked;
                                              isLoadingHours = true;
                                            });
                                            final data =
                                                await loadEmployeeAttendance(
                                                  selectedEmployeeId!,
                                                  picked,
                                                  effectiveCutDate,
                                                );
                                            final fullCal =
                                                qEnd.difference(picked).inDays +
                                                1;
                                            setState(() {
                                              isLoadingHours = false;
                                              totalHoursWorked =
                                                  (data['workedHours']
                                                      as double);
                                              baseHoursQuincena =
                                                  (data['baseHours'] as double);
                                              totalWorkdays =
                                                  data['totalWorkdays'] as int;
                                              daysWorked =
                                                  data['daysWorked'] as int;
                                              calendarDays =
                                                  data['calendarDays'] as int;
                                              fullCalendarDays = fullCal;
                                              ausenciaDays =
                                                  data['ausenciaDays'] as int;
                                              permisoDays =
                                                  data['permisoDays'] as int;
                                              incapacidadDays =
                                                  data['incapacidadDays']
                                                      as int;
                                              domingoDeductions =
                                                  data['domingoDeductions']
                                                      as int;
                                              pierdeBono =
                                                  data['pierdeBono'] as bool;
                                              absentDates =
                                                  (data['absentDates']
                                                      as Set<String>?) ??
                                                  {};
                                              daysAbsent =
                                                  ausenciaDays +
                                                  permisoDays +
                                                  incapacidadDays;
                                              if (totalHoursWorked >
                                                  baseHoursQuincena) {
                                                overtimeHours =
                                                    totalHoursWorked -
                                                    baseHoursQuincena;
                                                underHours = 0;
                                              } else {
                                                overtimeHours = 0;
                                                underHours =
                                                    baseHoursQuincena -
                                                    totalHoursWorked;
                                              }
                                            });
                                          }
                                        },
                                        child: Row(
                                          children: [
                                            Text(
                                              'Desde: ${qStart.day}/${qStart.month.toString().padLeft(2, '0')}/${qStart.year}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: const Color(0xFF1976D2),
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.edit_calendar,
                                              size: 14,
                                              color: const Color(0xFF1976D2),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Text(
                                        'Desde: ${qStart.day}/${qStart.month.toString().padLeft(2, '0')}/${qStart.year}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'Hasta: ${effectiveCutDate.day}/${effectiveCutDate.month.toString().padLeft(2, '0')}/${effectiveCutDate.year}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (isPartialQuincena)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFE0B2),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '$calendarDays de $fullCalendarDays días',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: const Color(0xFFEF6C00),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final qStartDate = qStart;
                                    final qEndDate =
                                        selectedQ['endDate'] as DateTime;
                                    // Clamp initialDate dentro del rango
                                    var cutInitial = effectiveCutDate;
                                    if (cutInitial.isBefore(qStartDate)) {
                                      cutInitial = qStartDate;
                                    }
                                    if (cutInitial.isAfter(qEndDate)) {
                                      cutInitial = qEndDate;
                                    }
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: cutInitial,
                                      firstDate: qStartDate,
                                      lastDate: qEndDate,
                                      helpText: 'Fecha de corte de pago',
                                    );
                                    if (picked != null &&
                                        selectedEmployeeId != null) {
                                      setState(() {
                                        customEndDate = picked;
                                        isLoadingHours = true;
                                      });
                                      final data = await loadEmployeeAttendance(
                                        selectedEmployeeId!,
                                        qStartDate,
                                        picked,
                                      );
                                      final fullCal =
                                          qEndDate
                                              .difference(qStartDate)
                                              .inDays +
                                          1;
                                      setState(() {
                                        isLoadingHours = false;
                                        totalHoursWorked =
                                            (data['workedHours'] as double);
                                        baseHoursQuincena =
                                            (data['baseHours'] as double);
                                        totalWorkdays =
                                            data['totalWorkdays'] as int;
                                        daysWorked = data['daysWorked'] as int;
                                        calendarDays =
                                            data['calendarDays'] as int;
                                        fullCalendarDays = fullCal;
                                        ausenciaDays =
                                            data['ausenciaDays'] as int;
                                        permisoDays =
                                            data['permisoDays'] as int;
                                        incapacidadDays =
                                            data['incapacidadDays'] as int;
                                        domingoDeductions =
                                            data['domingoDeductions'] as int;
                                        pierdeBono = data['pierdeBono'] as bool;
                                        daysAbsent =
                                            ausenciaDays +
                                            permisoDays +
                                            incapacidadDays;
                                        if (totalHoursWorked >
                                            baseHoursQuincena) {
                                          overtimeHours =
                                              totalHoursWorked -
                                              baseHoursQuincena;
                                          underHours = 0;
                                        } else {
                                          overtimeHours = 0;
                                          underHours =
                                              baseHoursQuincena -
                                              totalHoursWorked;
                                        }
                                      });
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.edit_calendar,
                                    size: 18,
                                  ),
                                  label: const Text('Cambiar'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1976D2),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isDailyPay
                                  ? '$daysWorked días × ${Helpers.formatCurrency(empDailyRate)} = ${Helpers.formatCurrency(fortnightSalary)}'
                                  : 'Salario/30 × $calendarDays días = ${Helpers.formatCurrency(fortnightSalary)} (domingos incluidos)',
                              style: TextStyle(
                                fontSize: 11,
                                color: const Color(0xFF757575),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Cargando datos de asistencia
                      if (isLoadingHours)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        ),

                      // Resumen de horas de la quincena
                      if (!isLoadingHours)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: daysAbsent == 0
                                ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                                : const Color(
                                    0xFFF9A825,
                                  ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: daysAbsent == 0
                                  ? const Color(
                                      0xFF2E7D32,
                                    ).withValues(alpha: 0.3)
                                  : const Color(
                                      0xFFF9A825,
                                    ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    color: daysAbsent == 0
                                        ? const Color(0xFF388E3C)
                                        : const Color(0xFFF57C00),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Asistencia Quincena',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: daysAbsent == 0
                                            ? const Color(0xFF2E7D32)
                                            : const Color(0xFFEF6C00),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        'Trabajados',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: const Color(0xFF757575),
                                        ),
                                      ),
                                      Text(
                                        isDailyPay
                                            ? '$daysWorked días'
                                            : '${totalHoursWorked.toStringAsFixed(1)}h',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (!isDailyPay)
                                        Text(
                                          '$daysWorked días',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: const Color(0xFF757575),
                                          ),
                                        ),
                                      if (isDailyPay)
                                        Text(
                                          Helpers.formatCurrency(
                                            fortnightSalary,
                                          ),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: const Color(0xFF388E3C),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: const Color(0xFFE0E0E0),
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        isDailyPay ? 'Laborales' : 'Base',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: const Color(0xFF757575),
                                        ),
                                      ),
                                      Text(
                                        isDailyPay
                                            ? '$totalWorkdays días'
                                            : '${baseHoursQuincena.toStringAsFixed(1)}h',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF616161),
                                        ),
                                      ),
                                      Text(
                                        '$totalWorkdays días (L-S)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: const Color(0xFF757575),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: const Color(0xFFE0E0E0),
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        daysAbsent > 0 ? 'Faltas' : 'Completo',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: const Color(0xFF757575),
                                        ),
                                      ),
                                      Text(
                                        daysAbsent > 0
                                            ? '$daysAbsent día${daysAbsent > 1 ? "s" : ""}'
                                            : '✓',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: daysAbsent > 0
                                              ? const Color(0xFFF57C00)
                                              : const Color(0xFF388E3C),
                                        ),
                                      ),
                                      if (underHours > 0 && !isDailyPay)
                                        Text(
                                          '-${underHours.toStringAsFixed(1)}h',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: const Color(0xFFF57C00),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              // Desglose de faltas
                              if (daysAbsent > 0) ...[
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                if (ausenciaDays > 0)
                                  _buildAttendanceDetailRow(
                                    Icons.cancel,
                                    const Color(0xFFC62828),
                                    'Ausencias',
                                    '$ausenciaDays día${ausenciaDays > 1 ? "s" : ""}',
                                    isDailyPay
                                        ? '(no se paga el día)'
                                        : '(pierde descanso dominical + bono)',
                                  ),
                                if (domingoDeductions > 0)
                                  _buildAttendanceDetailRow(
                                    Icons.weekend,
                                    const Color(0xFFE57373),
                                    'Domingos descontados',
                                    '$domingoDeductions',
                                    'por ausencia',
                                  ),
                                if (permisoDays > 0)
                                  _buildAttendanceDetailRow(
                                    Icons.back_hand,
                                    const Color(0xFFF9A825),
                                    'Permisos',
                                    '$permisoDays día${permisoDays > 1 ? "s" : ""}',
                                    '(pierde bono, NO pierde domingo)',
                                  ),
                                if (incapacidadDays > 0)
                                  _buildAttendanceDetailRow(
                                    Icons.local_hospital,
                                    const Color(0xFF1565C0),
                                    'Incapacidad',
                                    '$incapacidadDays día${incapacidadDays > 1 ? "s" : ""}',
                                    '(pierde bono, NO pierde domingo)',
                                  ),
                              ],
                              // Bono de asistencia con toggle
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: ganaBono
                                      ? const Color(
                                          0xFF2E7D32,
                                        ).withValues(alpha: 0.1)
                                      : const Color(
                                          0xFFC62828,
                                        ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      ganaBono
                                          ? Icons.attach_money
                                          : Icons.money_off,
                                      size: 16,
                                      color: ganaBono
                                          ? const Color(0xFF388E3C)
                                          : const Color(0xFFD32F2F),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isDailyPay
                                                ? (ganaBono
                                                      ? 'GANA Bono Semanal (${Helpers.formatCurrency(empAttendanceBonus)} × $weekBonusCount sem)'
                                                      : 'SIN Bono Semanal — debe venir L-S sin faltar')
                                                : (ganaBono
                                                      ? 'GANA Bono Asistencia (+\$150,000)'
                                                      : 'PIERDE Bono Asistencia (\$150,000)'),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: ganaBono
                                                  ? const Color(0xFF388E3C)
                                                  : const Color(0xFFD32F2F),
                                            ),
                                          ),
                                          if (bonoManualOverride != null)
                                            Text(
                                              '(modificado manualmente)',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: const Color(0xFF9E9E9E),
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: ganaBono,
                                      onChanged: (v) {
                                        setState(() {
                                          bonoManualOverride = v;
                                        });
                                      },
                                      activeColor: const Color(0xFF388E3C),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 16),

                    // === SECCIÓN DE HORAS EXTRAS (siempre visible para empleados no diarios) ===
                    if (selectedEmployee != null && !isDailyPay) ...[
                      // Caso 1: Hay horas extras (auto-detectadas o manuales) → mostrar detalle
                      if ((manualOvertimeHours ?? overtimeHours) > 0 ||
                          showOvertimeEditor)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2E7D32,
                            ).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(
                                0xFF2E7D32,
                              ).withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.more_time,
                                    color: const Color(0xFF388E3C),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      overtimeHours > 0 &&
                                              manualOvertimeHours == null
                                          ? 'Horas Extra Detectadas'
                                          : 'Horas Extra',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF2E7D32),
                                      ),
                                    ),
                                  ),
                                  if (!showOvertimeEditor) ...[
                                    Text(
                                      '+${(manualOvertimeHours ?? overtimeHours).toStringAsFixed(1)}h',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF388E3C),
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          showOvertimeEditor = true;
                                          overtimeController.text =
                                              (manualOvertimeHours ??
                                                      overtimeHours)
                                                  .toStringAsFixed(1);
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(4),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.edit,
                                          size: 18,
                                          color: const Color(0xFF388E3C),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (manualOvertimeHours != null)
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          manualOvertimeHours = null;
                                          showOvertimeEditor = false;
                                          overtimeController.clear();
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(4),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.close,
                                          size: 18,
                                          color: const Color(0xFFC62828),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              // Editor de horas extras
                              if (showOvertimeEditor) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: overtimeController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: InputDecoration(
                                          labelText: 'Horas extra',
                                          hintText: 'Ej: 4.5',
                                          prefixIcon: const Icon(
                                            Icons.timer,
                                            size: 20,
                                          ),
                                          border: const OutlineInputBorder(),
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                          helperText: overtimeHours > 0
                                              ? 'Auto-detectadas: ${overtimeHours.toStringAsFixed(1)}h'
                                              : null,
                                          helperStyle: TextStyle(
                                            fontSize: 11,
                                            color: const Color(0xFF757575),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    FilledButton(
                                      onPressed: () {
                                        final value = double.tryParse(
                                          overtimeController.text.trim(),
                                        );
                                        if (value != null && value > 0) {
                                          setState(() {
                                            manualOvertimeHours = value;
                                            showOvertimeEditor = false;
                                          });
                                        } else if (overtimeController.text
                                                .trim()
                                                .isEmpty ||
                                            value == 0) {
                                          setState(() {
                                            manualOvertimeHours = null;
                                            showOvertimeEditor = false;
                                          });
                                        }
                                      },
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF388E3C,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                      ),
                                      child: const Text('Aplicar'),
                                    ),
                                  ],
                                ),
                              ],
                              if ((manualOvertimeHours ?? overtimeHours) > 0 &&
                                  !showOvertimeEditor) ...[
                                if (manualOvertimeHours != null &&
                                    overtimeHours > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Auto-detectadas: ${overtimeHours.toStringAsFixed(1)}h → Manual: ${manualOvertimeHours!.toStringAsFixed(1)}h',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: const Color(0xFF757575),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                Text(
                                  'Tipo de recargo:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xFF757575),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  value: overtimeType,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'normal',
                                      child: Text(
                                        'Normal (sin recargo)',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: '25',
                                      child: Text(
                                        'Diurna +25%',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: '75',
                                      child: Text(
                                        'Nocturna +75%',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: '100',
                                      child: Text(
                                        'Dom/Fest Diurna +100%',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: '150',
                                      child: Text(
                                        'Dom/Fest Nocturna +150%',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) => setState(
                                    () => overtimeType = v ?? 'normal',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF2E7D32,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${(manualOvertimeHours ?? overtimeHours).toStringAsFixed(1)}h × ${Helpers.formatCurrency(hourlyRate)} × ${getOvertimeMultiplier(overtimeType)}x',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: const Color(0xFF616161),
                                        ),
                                      ),
                                      Text(
                                        '+ ${Helpers.formatCurrency(overtimePay)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF388E3C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      // Caso 2: No hay horas extras → mostrar botón para agregar
                      if ((manualOvertimeHours ?? overtimeHours) <= 0 &&
                          !showOvertimeEditor)
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              showOvertimeEditor = true;
                              overtimeController.clear();
                            });
                          },
                          icon: const Icon(Icons.more_time, size: 18),
                          label: const Text('Agregar Horas Extra'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF388E3C),
                            side: BorderSide(
                              color: const Color(
                                0xFF388E3C,
                              ).withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                    ],

                    // Descuento por horas faltantes (solo si faltan horas y no hay override manual)
                    if (selectedEmployee != null &&
                        underHours > 0 &&
                        !isDailyPay &&
                        (manualOvertimeHours == null ||
                            manualOvertimeHours! <= 0))
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF9A825,
                          ).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFFF9A825,
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
                                  color: const Color(0xFFF57C00),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Horas Faltantes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFEF6C00),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '-${underHours.toStringAsFixed(1)}h',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFF57C00),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFF9A825,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${underHours.toStringAsFixed(1)}h × ${Helpers.formatCurrency(hourlyRate)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: const Color(0xFF616161),
                                    ),
                                  ),
                                  Text(
                                    '- ${Helpers.formatCurrency(underHoursDiscount)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFF57C00),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (selectedEmployee != null) const SizedBox(height: 16),

                    // Préstamos activos
                    if (activeLoans.isNotEmpty) ...[
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet,
                                  color: const Color(0xFFF57C00),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Préstamos Activos (${activeLoans.length})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFEF6C00),
                                  ),
                                ),
                                const Spacer(),
                                Switch(
                                  value: includeActiveLoans,
                                  onChanged: (v) =>
                                      setState(() => includeActiveLoans = v),
                                  activeColor: const Color(0xFFF57C00),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cuotas de préstamos formales (se descuentan automáticamente cada quincena)',
                              style: TextStyle(
                                fontSize: 11,
                                color: const Color(0xFF757575),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...activeLoans.map(
                              (loan) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Cuota ${loan.paidInstallments + 1}/${loan.installments}',
                                          style: TextStyle(
                                            color: const Color(0xFF616161),
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (loan.reason != null &&
                                            loan.reason!.isNotEmpty)
                                          Text(
                                            loan.reason!,
                                            style: TextStyle(
                                              color: const Color(0xFF9E9E9E),
                                              fontSize: 10,
                                            ),
                                          ),
                                      ],
                                    ),
                                    Text(
                                      '- ${Helpers.formatCurrency(loan.installmentAmount)}',
                                      style: TextStyle(
                                        color: const Color(0xFFE53935),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (activeLoans.length > 1) ...[
                              const Divider(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Descuento',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF424242),
                                    ),
                                  ),
                                  Text(
                                    '- ${Helpers.formatCurrency(loanDeduction)}',
                                    style: TextStyle(
                                      color: const Color(0xFFD32F2F),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    if (selectedEmployee != null) ...[
                      const Divider(height: 24),

                      // ── Bonos Extras ──────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E5F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCE93D8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.card_giftcard,
                                  size: 18,
                                  color: Color(0xFF7B1FA2),
                                ),
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: Text(
                                    'Bonos / Extras',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Color(0xFF6A1B9A),
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    final descCtrl = TextEditingController();
                                    final montoCtrl = TextEditingController();
                                    showDialog(
                                      context: context,
                                      builder: (subCtx) => AlertDialog(
                                        title: const Text(
                                          'Agregar Bono / Extra',
                                        ),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextField(
                                              controller: descCtrl,
                                              decoration: const InputDecoration(
                                                labelText:
                                                    'Descripción (opcional)',
                                                hintText:
                                                    'Ej: Prima, Comisión, etc.',
                                                border: OutlineInputBorder(),
                                              ),
                                              autofocus: true,
                                              textCapitalization:
                                                  TextCapitalization.sentences,
                                            ),
                                            const SizedBox(height: 12),
                                            TextField(
                                              controller: montoCtrl,
                                              decoration: const InputDecoration(
                                                labelText: 'Monto (\$)',
                                                prefixText: '\$ ',
                                                border: OutlineInputBorder(),
                                              ),
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(subCtx),
                                            child: const Text('Cancelar'),
                                          ),
                                          FilledButton(
                                            onPressed: () {
                                              final desc = descCtrl.text.trim();
                                              final monto = double.tryParse(
                                                montoCtrl.text
                                                    .replaceAll('.', '')
                                                    .replaceAll(',', '.'),
                                              );
                                              if (monto != null && monto > 0) {
                                                setState(() {
                                                  extraBonuses.add({
                                                    'descripcion':
                                                        desc.isNotEmpty
                                                        ? desc
                                                        : 'Bono Extra',
                                                    'monto': monto,
                                                  });
                                                });
                                                Navigator.pop(subCtx);
                                              }
                                            },
                                            child: const Text('Agregar'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Agregar'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF7B1FA2),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (extraBonuses.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Sin bonos extras. Usa + Agregar para incluir primas, comisiones u otros.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              )
                            else
                              ...extraBonuses.asMap().entries.map((entry) {
                                final i = entry.key;
                                final b = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.add_circle_outline,
                                        size: 14,
                                        color: Color(0xFF7B1FA2),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          b['descripcion'] as String,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      Text(
                                        Helpers.formatCurrency(
                                          b['monto'] as double,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF388E3C),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Color(0xFF9E9E9E),
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 28,
                                          minHeight: 28,
                                        ),
                                        onPressed: () => setState(() {
                                          extraBonuses.removeAt(i);
                                        }),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Resumen de cálculos
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildPayrollSummaryRow(
                              isDailyPay
                                  ? 'Pago Diario ($daysWorked días × ${Helpers.formatCurrency(empDailyRate)})'
                                  : (isPartialQuincena
                                        ? 'Salario Parcial ($calendarDays de $fullCalendarDays días)'
                                        : 'Salario Quincenal'),
                              fortnightSalary,
                              false,
                            ),
                            if (bonoAsistencia > 0)
                              _buildPayrollSummaryRow(
                                isDailyPay
                                    ? 'Bono Semanal ($weekBonusCount sem × ${Helpers.formatCurrency(empAttendanceBonus)})'
                                    : 'Bono Asistencia',
                                bonoAsistencia,
                                false,
                              ),
                            for (final b in extraBonuses)
                              _buildPayrollSummaryRow(
                                b['descripcion'] as String,
                                b['monto'] as double,
                                false,
                              ),
                            if (overtimePay > 0)
                              _buildPayrollSummaryRow(
                                'Horas Extra (${(manualOvertimeHours ?? overtimeHours).toStringAsFixed(1)}h ${getOvertimeLabel(overtimeType)})',
                                overtimePay,
                                false,
                              ),
                            const Divider(height: 16),
                            _buildPayrollSummaryRow(
                              'Total Ingresos',
                              totalEarnings,
                              false,
                            ),
                            if (underHoursDiscount > 0)
                              _buildPayrollSummaryRow(
                                'Desc. Ausencias/Permisos (${underHours.toStringAsFixed(1)}h × ${Helpers.formatCurrency(hourlyRate)})',
                                -underHoursDiscount,
                                true,
                              ),
                            if (loanDeduction > 0)
                              _buildPayrollSummaryRow(
                                'Cuotas Préstamos',
                                -loanDeduction,
                                true,
                              ),
                            const Divider(height: 16),
                            _buildPayrollSummaryRow(
                              'NETO A PAGAR',
                              netPay,
                              false,
                              isTotal: true,
                            ),
                          ],
                        ),
                      ),
                    ],
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
                onPressed: selectedEmployeeId == null
                    ? null
                    : () async {
                        // Guardar referencia al messenger ANTES de cerrar el dialog
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);

                        // Obtener o crear el periodo para la quincena seleccionada
                        final selectedQ =
                            availableQuincenas[selectedQuincenaIndex];
                        final periodNumber = selectedQ['periodNumber'] as int;
                        final periodYear = selectedQ['year'] as int;
                        final periodStart = selectedQ['startDate'] as DateTime;
                        final periodEnd = selectedQ['endDate'] as DateTime;

                        // Buscar si el periodo ya existe
                        PayrollPeriod? selectedPeriod;
                        final existingPeriods =
                            await PayrollDatasource.getPeriods(
                              year: periodYear,
                            );
                        selectedPeriod = existingPeriods
                            .where(
                              (p) =>
                                  p.periodType == 'quincenal' &&
                                  p.periodNumber == periodNumber &&
                                  p.year == periodYear,
                            )
                            .firstOrNull;

                        selectedPeriod ??= await PayrollDatasource.createPeriod(
                          periodType: 'quincenal',
                          periodNumber: periodNumber,
                          year: periodYear,
                          startDate: periodStart,
                          endDate: periodEnd,
                        );

                        if (selectedPeriod == null) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Error al crear el periodo'),
                              backgroundColor: Color(0xFFC62828),
                            ),
                          );
                          return;
                        }

                        // Verificar si ya existe nómina para este empleado en el periodo
                        // (por si la lista local está desactualizada)
                        final freshPayrolls =
                            await PayrollDatasource.getPayrolls(
                              periodId: selectedPeriod.id,
                            );
                        final existingPayrollFresh = freshPayrolls
                            .where((p) => p.employeeId == selectedEmployeeId)
                            .firstOrNull;

                        // Si ya existe nómina, SIEMPRE hacer update (complemento)
                        final shouldComplement =
                            isComplemento || existingPayrollFresh != null;
                        final existingPayrollToUpdate =
                            existingPayrollFresh ??
                            existingPayrollsList
                                .where(
                                  (p) => p.employeeId == selectedEmployeeId,
                                )
                                .firstOrNull;

                        // Crear o actualizar la nómina
                        EmployeePayroll? payroll;

                        if (shouldComplement &&
                            existingPayrollToUpdate != null) {
                          // COMPLEMENTO: actualizar la nómina existente sumando los nuevos valores
                          final newDaysWorked =
                              existingPayrollToUpdate.daysWorked + daysWorked;
                          final newTotalEarnings =
                              existingPayrollToUpdate.totalEarnings +
                              totalEarnings;
                          final newTotalDeductions =
                              existingPayrollToUpdate.totalDeductions +
                              totalDeductions;
                          final newNetPay =
                              existingPayrollToUpdate.netPay + netPay;
                          final complementNote =
                              'COMPLEMENTO: +$daysWorked días (${qStart.day}/${qStart.month.toString().padLeft(2, '0')} al ${effectiveCutDate.day}/${effectiveCutDate.month.toString().padLeft(2, '0')}/${effectiveCutDate.year}) = +${Helpers.formatCurrency(netPay)}';
                          final existingNotes =
                              existingPayrollToUpdate.notes ?? '';
                          final combinedNotes = existingNotes.isEmpty
                              ? complementNote
                              : '$existingNotes\n$complementNote';

                          await PayrollDatasource.updatePayroll(
                            existingPayrollToUpdate.id,
                            {
                              'days_worked': newDaysWorked,
                              'total_earnings': newTotalEarnings,
                              'total_deductions': newTotalDeductions,
                              'net_pay': newNetPay,
                              'notes': combinedNotes,
                              // Actualizar paid_end_date al nuevo fin (el complemento extiende el rango)
                              'paid_end_date':
                                  '${effectiveCutDate.year}-${effectiveCutDate.month.toString().padLeft(2, '0')}-${effectiveCutDate.day.toString().padLeft(2, '0')}',
                            },
                          );

                          // Recargar nóminas del periodo
                          await ref
                              .read(payrollProvider.notifier)
                              .loadPayrollsForPeriod(selectedPeriod.id);

                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                '✅ Complemento agregado: +${Helpers.formatCurrency(netPay)} ($daysWorked días)',
                              ),
                              backgroundColor: const Color(0xFF2E7D32),
                            ),
                          );
                        } else if (shouldComplement &&
                            existingPayrollToUpdate == null) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No se encontró la nómina original para complementar',
                              ),
                              backgroundColor: Color(0xFFC62828),
                            ),
                          );
                        } else {
                          // NÓMINA NORMAL: crear nuevo registro
                          payroll = await ref
                              .read(payrollProvider.notifier)
                              .createPayroll(
                                employeeId: selectedEmployeeId!,
                                periodId: selectedPeriod.id,
                                baseSalary:
                                    fortnightSalary, // Salario quincenal o parcial
                                daysWorked: daysWorked,
                              );

                          if (payroll != null) {
                            // Guardar rango de fechas pagado para registro y prevención de cobro doble
                            final paidRangeNote =
                                'PAGADO: ${qStart.day}/${qStart.month.toString().padLeft(2, '0')} al ${effectiveCutDate.day}/${effectiveCutDate.month.toString().padLeft(2, '0')}/${effectiveCutDate.year} ($daysWorked días lab.)';

                            // Actualizar días de ausencia e incapacidad en el registro
                            // Y FORZAR los totales correctos calculados en la UI
                            await PayrollDatasource.updatePayroll(payroll.id, {
                              'days_absent': ausenciaDays + permisoDays,
                              'days_incapacity': incapacidadDays,
                              'total_earnings': totalEarnings,
                              'total_deductions': totalDeductions,
                              'net_pay': netPay,
                              'notes': paidRangeNote,
                              'paid_start_date':
                                  '${qStart.year}-${qStart.month.toString().padLeft(2, '0')}-${qStart.day.toString().padLeft(2, '0')}',
                              'paid_end_date':
                                  '${effectiveCutDate.year}-${effectiveCutDate.month.toString().padLeft(2, '0')}-${effectiveCutDate.day.toString().padLeft(2, '0')}',
                            });

                            // Agregar detalles SIN recargar estado (skipReload: true)
                            // para evitar reloads intermedios que sobreescriben totales

                            // Re-leer conceptos frescos del provider
                            final freshPayrollState = ref.read(payrollProvider);
                            // Si conceptos vacíos, cargar solo conceptos (no loadAll)
                            if (freshPayrollState.concepts.isEmpty) {
                              print(
                                '⚠️ Conceptos vacíos, cargando conceptos...',
                              );
                              await ref
                                  .read(payrollProvider.notifier)
                                  .loadConcepts();
                            }

                            // Intentar agregar BONO DE ASISTENCIA como detalle
                            if (bonoAsistencia > 0) {
                              final latestState = ref.read(payrollProvider);
                              final bonoConcept = latestState.concepts
                                  .where((c) => c.code == 'BONO_ASISTENCIA')
                                  .firstOrNull;
                              if (bonoConcept != null) {
                                await ref
                                    .read(payrollProvider.notifier)
                                    .addConceptToPayroll(
                                      payrollId: payroll.id,
                                      conceptId: bonoConcept.id,
                                      amount: bonoAsistencia,
                                      skipReload: true,
                                      notes: isDailyPay
                                          ? 'Bono semanal ($weekBonusCount sem × ${Helpers.formatCurrency(empAttendanceBonus)})'
                                          : 'Bono asistencia quincenal (asistencia perfecta)',
                                    );
                                print(
                                  '✅ Bono de asistencia agregado: ${Helpers.formatCurrency(bonoAsistencia)}',
                                );
                              } else {
                                // Fallback: insertar directamente sin concepto
                                print(
                                  '⚠️ Concepto BONO_ASISTENCIA no encontrado, insertando directamente',
                                );
                                await PayrollDatasource.addPayrollDetailDirect(
                                  payrollId: payroll.id,
                                  conceptCode: 'BONO_ASISTENCIA',
                                  conceptName: 'Bono por Asistencia',
                                  type: 'ingreso',
                                  amount: bonoAsistencia,
                                  notes: isDailyPay
                                      ? 'Bono semanal ($weekBonusCount sem × ${Helpers.formatCurrency(empAttendanceBonus)})'
                                      : 'Bono asistencia quincenal (asistencia perfecta)',
                                );
                                print(
                                  '✅ Bono insertado directamente: ${Helpers.formatCurrency(bonoAsistencia)}',
                                );
                              }
                            }

                            // Agregar horas extras si hay (manuales o auto-detectadas)
                            final effectiveOT =
                                manualOvertimeHours ?? overtimeHours;
                            if (effectiveOT > 0 && !isDailyPay) {
                              await ref
                                  .read(payrollProvider.notifier)
                                  .addOvertimeHours(
                                    payrollId: payroll.id,
                                    hours: effectiveOT,
                                    type: overtimeType,
                                    hourlyRate: baseSalary / hoursPerMonth,
                                    skipReload: true,
                                  );

                              // Si las horas son manuales (no auto-detectadas), registrarlas
                              // como ajuste de tiempo para que queden en el historial de asistencia
                              if (manualOvertimeHours != null &&
                                  manualOvertimeHours! > 0) {
                                final otMinutes = (manualOvertimeHours! * 60)
                                    .round();
                                // Distribuir las horas en la fecha de fin de la quincena
                                await EmployeesDatasource.createTimeAdjustment(
                                  employeeId: selectedEmployeeId!,
                                  minutes: otMinutes,
                                  type: 'overtime',
                                  date: effectiveCutDate,
                                  reason:
                                      'Horas extra nómina (${manualOvertimeHours!.toStringAsFixed(1)}h ${getOvertimeLabel(overtimeType)})',
                                  notes:
                                      'Registrado al crear nómina - periodo ${qStart.day}/${qStart.month} al ${effectiveCutDate.day}/${effectiveCutDate.month}/${effectiveCutDate.year}',
                                );
                                print(
                                  '✅ Registradas ${manualOvertimeHours!.toStringAsFixed(1)}h extras como ajuste de tiempo',
                                );
                              }
                            }

                            // Agregar descuento por horas faltantes si hay (solo si no hay override manual)
                            if (underHours > 0 &&
                                !isDailyPay &&
                                (manualOvertimeHours == null ||
                                    manualOvertimeHours! <= 0)) {
                              await ref
                                  .read(payrollProvider.notifier)
                                  .addUnderHoursDiscount(
                                    payrollId: payroll.id,
                                    hours: underHours,
                                    hourlyRate: baseSalary / hoursPerMonth,
                                    skipReload: true,
                                  );
                            }

                            // Agregar cuotas de préstamos
                            if (includeActiveLoans && activeLoans.isNotEmpty) {
                              print(
                                '💰 Descontando ${activeLoans.length} préstamo(s) por total: $loanDeduction',
                              );
                              for (final loan in activeLoans) {
                                final loanSuccess = await ref
                                    .read(payrollProvider.notifier)
                                    .addLoanInstallmentDiscount(
                                      payrollId: payroll.id,
                                      loan: loan,
                                      skipReload: true,
                                    );
                                if (!loanSuccess) {
                                  print(
                                    '⚠️ Error descontando préstamo ${loan.id}',
                                  );
                                } else {
                                  print(
                                    '✅ Cuota ${loan.paidInstallments + 1}/${loan.installments} descontada: ${loan.installmentAmount}',
                                  );
                                }
                              }
                            } else {
                              print(
                                'ℹ️ Sin préstamos a descontar: includeActiveLoans=$includeActiveLoans, activeLoans=${activeLoans.length}',
                              );
                            }

                            // Agregar bonos extras manuales
                            for (final b in extraBonuses) {
                              await PayrollDatasource.addPayrollDetailDirect(
                                payrollId: payroll.id,
                                conceptCode: 'BONO_EXTRA',
                                conceptName: b['descripcion'] as String,
                                type: 'ingreso',
                                amount: b['monto'] as double,
                                notes: 'Bono extra manual',
                              );
                              print(
                                '✅ Bono extra agregado: ${b['descripcion']} = ${Helpers.formatCurrency(b['monto'] as double)}',
                              );
                            }

                            // FORZAR totales finales con los valores correctos de la UI
                            // (los detalles ya están en BD, esto asegura que net_pay sea correcto)
                            await PayrollDatasource.updatePayroll(payroll.id, {
                              'total_earnings': totalEarnings,
                              'total_deductions': totalDeductions,
                              'net_pay': netPay,
                            });

                            // ÚNICO reload: cargar nóminas del periodo correcto
                            await ref
                                .read(payrollProvider.notifier)
                                .loadPayrollsForPeriod(selectedPeriod.id);

                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  '✅ Nómina creada: ${Helpers.formatCurrency(netPay)}',
                                ),
                                backgroundColor: const Color(0xFF2E7D32),
                              ),
                            );
                          } else {
                            // createPayroll falló (posible duplicado u otro error)
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '❌ Error al crear nómina. El empleado puede ya tener nómina en este periodo.',
                                ),
                                backgroundColor: Color(0xFFC62828),
                              ),
                            );
                          }
                        } // cierre del else (nómina normal)
                      },
                icon: const Icon(Icons.save),
                label: Text(
                  isComplemento ? 'Crear Complemento' : 'Crear Nómina',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPayrollSummaryRow(
    String label,
    double amount,
    bool isDeduction, {
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            isDeduction
                ? '- ${Helpers.formatCurrency(amount.abs())}'
                : Helpers.formatCurrency(amount),
            style: TextStyle(
              color: isDeduction
                  ? const Color(0xFFC62828)
                  : (isTotal ? const Color(0xFF388E3C) : null),
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceDetailRow(
    IconData icon,
    Color color,
    String label,
    String value,
    String subtitle,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF424242),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: const Color(0xFF9E9E9E)),
          ),
        ],
      ),
    );
  }

  void _showAddConceptDialog(EmployeePayroll payroll) {
    final payrollState = ref.read(payrollProvider);
    String selectedType = 'ingreso';
    PayrollConcept? selectedConcept;
    final amountController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final concepts = selectedType == 'ingreso'
              ? payrollState.incomeConcepts
              : payrollState.deductionConcepts;

          return AlertDialog(
            title: const Text('Agregar Concepto'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tipo
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'ingreso',
                        label: Text('Ingreso'),
                        icon: Icon(Icons.add),
                      ),
                      ButtonSegment(
                        value: 'descuento',
                        label: Text('Descuento'),
                        icon: Icon(Icons.remove),
                      ),
                    ],
                    selected: {selectedType},
                    onSelectionChanged: (value) {
                      setState(() {
                        selectedType = value.first;
                        selectedConcept = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // Concepto
                  DropdownButtonFormField<PayrollConcept>(
                    decoration: const InputDecoration(
                      labelText: 'Concepto',
                      prefixIcon: Icon(Icons.category),
                    ),
                    value: selectedConcept,
                    items: concepts
                        .map(
                          (c) =>
                              DropdownMenuItem(value: c, child: Text(c.name)),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => selectedConcept = value),
                  ),
                  const SizedBox(height: 16),
                  // Monto
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Monto',
                      prefixIcon: Icon(Icons.attach_money),
                      prefixText: '\$ ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  // Notas
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                      prefixIcon: Icon(Icons.note),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  if (selectedConcept == null) return;

                  Navigator.pop(context);
                  final success = await ref
                      .read(payrollProvider.notifier)
                      .addConceptToPayroll(
                        payrollId: payroll.id,
                        conceptId: selectedConcept!.id,
                        amount: double.tryParse(amountController.text) ?? 0,
                        notes: notesController.text.isNotEmpty
                            ? notesController.text
                            : null,
                      );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'Concepto agregado' : 'Error'),
                        backgroundColor: success
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC62828),
                      ),
                    );
                  }
                },
                child: const Text('Agregar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPayPayrollDialog(EmployeePayroll payroll) async {
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

    DateTime paymentDate = DateTime.now();
    String? selectedAccountId = accountsData[0]['id'];
    double selectedAccountBalance = (accountsData[0]['balance'] ?? 0)
        .toDouble();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.payments,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('Procesar Pago de Nómina'),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info del empleado
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        child: Text(
                          (payroll.employeeName ?? 'E')[0].toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              payroll.employeeName ?? 'Empleado',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              payroll.employeePosition ?? '',
                              style: TextStyle(color: const Color(0xFF757575)),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Neto a pagar:',
                            style: TextStyle(fontSize: 12),
                          ),
                          Text(
                            Helpers.formatCurrency(payroll.netPay),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Selección de cuenta
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Cuenta de Pago',
                    prefixIcon: Icon(Icons.account_balance),
                    border: OutlineInputBorder(),
                  ),
                  value: selectedAccountId,
                  items: accountsData.map<DropdownMenuItem<String>>((acc) {
                    final balance = (acc['balance'] ?? 0).toDouble();
                    final hasEnough = balance >= payroll.netPay;
                    return DropdownMenuItem(
                      value: acc['id'] as String,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(acc['name'] ?? 'Cuenta'),
                          Text(
                            Helpers.formatCurrency(balance),
                            style: TextStyle(
                              color: hasEnough
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFC62828),
                              fontWeight: FontWeight.w500,
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

                if (selectedAccountBalance < payroll.netPay) ...[
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
                        Expanded(
                          child: Text(
                            'Saldo insuficiente. Falta: ${Helpers.formatCurrency(payroll.netPay - selectedAccountBalance)}',
                            style: const TextStyle(
                              color: Color(0xFFC62828),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Fecha de pago
                const Text(
                  'Fecha de pago:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: paymentDate,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 30),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (date != null) {
                      setState(() => paymentDate = date);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${paymentDate.day.toString().padLeft(2, '0')}/${paymentDate.month.toString().padLeft(2, '0')}/${paymentDate.year}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.edit_calendar,
                          color: const Color(0xFF9E9E9E),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Color(0xFF2E7D32),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Este pago se registrará automáticamente en contabilidad como egreso',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed:
                  selectedAccountId == null ||
                      selectedAccountBalance < payroll.netPay
                  ? null
                  : () async {
                      // Guardar referencia al messenger ANTES de cerrar
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);

                      final success = await ref
                          .read(payrollProvider.notifier)
                          .processPayment(
                            payrollId: payroll.id,
                            accountId: selectedAccountId!,
                            paymentDate: paymentDate,
                          );

                      if (success) {
                        // Refrescar Caja Diaria y cuentas
                        ref.read(dailyCashProvider.notifier).load();
                      }

                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? '✅ Pago de ${Helpers.formatCurrency(payroll.netPay)} registrado exitosamente'
                                : '❌ Error al procesar el pago',
                          ),
                          backgroundColor: success
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFC62828),
                        ),
                      );
                    },
              icon: const Icon(Icons.check),
              label: const Text('Confirmar Pago'),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // IMPRIMIR COMPROBANTE DE NÓMINA
  // ═══════════════════════════════════════════════════════════════
  void _printPayroll(EmployeePayroll payroll) async {
    try {
      // Cargar detalles de la nómina
      final details = await PayrollDatasource.getPayrollDetails(payroll.id);

      // Buscar empleado para obtener tipo de pago
      final empState = ref.read(employeesProvider);
      final employee = empState.employees
          .where((e) => e.id == payroll.employeeId)
          .firstOrNull;

      // Obtener nombre del periodo
      final allPeriods = await PayrollDatasource.getPeriods();
      final period = allPeriods
          .where((p) => p.id == payroll.periodId)
          .firstOrNull;
      final periodDisplay = period?.displayName ?? payroll.periodName ?? 'N/A';

      // Construir mapa de datos
      final payrollData = <String, dynamic>{
        'employeeName': payroll.employeeName ?? 'Sin nombre',
        'employeePosition': payroll.employeePosition ?? '',
        'baseSalary': payroll.baseSalary,
        'daysWorked': payroll.daysWorked,
        'totalEarnings': payroll.totalEarnings,
        'totalDeductions': payroll.totalDeductions,
        'netPay': payroll.netPay,
        'paymentDate': payroll.paymentDate,
        'notes': payroll.notes ?? '',
        'isDailyPay': employee?.isDailyPay ?? false,
        'dailyRate': employee?.dailyRate ?? 0.0,
      };

      // Convertir detalles a mapas
      final detailMaps = details
          .map(
            (d) => <String, dynamic>{
              'conceptName': d.conceptName,
              'conceptCode': d.conceptCode,
              'type': d.type,
              'quantity': d.quantity,
              'unitValue': d.unitValue,
              'amount': d.amount,
              'notes': d.notes,
            },
          )
          .toList();

      await PrintService.printPayroll(
        payroll: payrollData,
        details: detailMaps,
        periodDisplay: periodDisplay,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al imprimir: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ELIMINAR NÓMINA (con confirmación)
  // ═══════════════════════════════════════════════════════════════
  void _confirmDeletePayroll(EmployeePayroll payroll) {
    final isPagado = payroll.status == 'pagado';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Nómina'),
        content: Text(
          isPagado
              ? '¿Eliminar la nómina PAGADA de ${payroll.employeeName}?\n\n'
                    'Se revertirá el movimiento de caja y se devolverá el saldo a la cuenta.\n'
                    'Esto permite recrearla con los datos correctos.'
              : '¿Eliminar la nómina de ${payroll.employeeName}?\n\n'
                    'Esto permite recrearla con los datos actualizados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _executeDeletePayroll(payroll);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            child: Text(isPagado ? 'Eliminar y Revertir Pago' : 'Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDeletePayroll(EmployeePayroll payroll) async {
    try {
      // Si está pagada, primero revertir el movimiento de caja
      if (payroll.status == 'pagado' && payroll.cashMovementId != null) {
        // Obtener el movimiento de caja para saber el monto y la cuenta
        final movement = await Supabase.instance.client
            .from('cash_movements')
            .select()
            .eq('id', payroll.cashMovementId!)
            .maybeSingle();

        if (movement != null) {
          final accountId = movement['account_id'] as String?;
          final amount = (movement['amount'] as num?)?.toDouble() ?? 0;

          // Devolver el saldo a la cuenta (el pago restó, ahora sumamos)
          if (accountId != null && amount > 0) {
            final account = await Supabase.instance.client
                .from('accounts')
                .select('balance')
                .eq('id', accountId)
                .single();
            final currentBalance =
                (account['balance'] as num?)?.toDouble() ?? 0;
            await AccountsDataSource.updateAccountBalance(
              accountId,
              currentBalance + amount,
            );
            print(
              '✅ Saldo devuelto: $amount a cuenta $accountId (nuevo: ${currentBalance + amount})',
            );
          }

          // Limpiar referencia en la nómina antes de eliminar el movimiento
          await Supabase.instance.client
              .from('payroll')
              .update({
                'cash_movement_id': null,
                'account_id': null,
                'status': 'borrador',
              })
              .eq('id', payroll.id);

          // Eliminar movimiento de caja
          await Supabase.instance.client
              .from('cash_movements')
              .delete()
              .eq('id', payroll.cashMovementId!);
          print('✅ Movimiento de caja eliminado: ${payroll.cashMovementId}');
        } else {
          // Movimiento no encontrado, limpiar referencia
          await Supabase.instance.client
              .from('payroll')
              .update({
                'cash_movement_id': null,
                'account_id': null,
                'status': 'borrador',
              })
              .eq('id', payroll.id);
        }
      }

      // Eliminar la nómina (detalles se eliminan por CASCADE)
      final success = await ref
          .read(payrollProvider.notifier)
          .deletePayroll(payroll.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '✅ Nómina de ${payroll.employeeName} eliminada. Puedes recrearla con los datos correctos.'
                  : '❌ Error al eliminar la nómina',
            ),
            backgroundColor: success
                ? const Color(0xFF2E7D32)
                : const Color(0xFFC62828),
          ),
        );
      }
    } catch (e) {
      print('❌ Error eliminando nómina: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    }
  }

  void _showMonthlyPaymentDialog(EmployeePayroll payroll) async {
    // Determinar mes/año del periodo actual
    // periodNumber: mes*2-1 = Q1, mes*2 = Q2
    final isQ1 = payroll.periodId.isNotEmpty; // placeholder
    int targetMonth = 0;
    int targetYear = 0;

    // Cargar TODOS los periodos (sin filtrar por año) para encontrar el periodo de esta nómina
    final allPeriods = await PayrollDatasource.getPeriods();
    PayrollPeriod? thisPeriod;
    for (final p in allPeriods) {
      if (p.id == payroll.periodId) {
        thisPeriod = p;
        break;
      }
    }

    if (thisPeriod == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontró el periodo de esta nómina'),
            backgroundColor: Color(0xFFC62828),
          ),
        );
      }
      return;
    }

    // Calcular mes a partir del periodNumber
    final pNum = thisPeriod.periodNumber;
    final pYear = thisPeriod.year;
    final pIsQ1 = pNum.isOdd;
    targetMonth = pIsQ1 ? (pNum + 1) ~/ 2 : pNum ~/ 2;
    targetYear = pYear;

    // Buscar el otro periodo del mismo mes (Q1 y Q2)
    final q1Num = targetMonth * 2 - 1;
    final q2Num = targetMonth * 2;
    final otherNum = pIsQ1 ? q2Num : q1Num;

    // Buscar periodos Q1 y Q2 del mes
    var monthPeriods = allPeriods
        .where(
          (p) =>
              p.year == targetYear &&
              p.periodType == 'quincenal' &&
              (p.periodNumber == q1Num || p.periodNumber == q2Num),
        )
        .toList();

    // Si falta uno de los dos periodos, crearlo automáticamente
    final hasQ1Period = monthPeriods.any((p) => p.periodNumber == q1Num);
    final hasQ2Period = monthPeriods.any((p) => p.periodNumber == q2Num);

    if (!hasQ1Period) {
      final q1Start = DateTime(targetYear, targetMonth, 1);
      final q1End = DateTime(targetYear, targetMonth, 15);
      final newPeriod = await PayrollDatasource.createPeriod(
        periodType: 'quincenal',
        periodNumber: q1Num,
        year: targetYear,
        startDate: q1Start,
        endDate: q1End,
      );
      if (newPeriod != null) monthPeriods.add(newPeriod);
    }
    if (!hasQ2Period) {
      final q2Start = DateTime(targetYear, targetMonth, 16);
      final q2End = DateTime(
        targetYear,
        targetMonth + 1,
        0,
      ); // último día del mes
      final newPeriod = await PayrollDatasource.createPeriod(
        periodType: 'quincenal',
        periodNumber: q2Num,
        year: targetYear,
        startDate: q2Start,
        endDate: q2End,
      );
      if (newPeriod != null) monthPeriods.add(newPeriod);
    }

    // Cargar nóminas del empleado en ambos periodos
    List<EmployeePayroll> monthPayrolls = [];
    for (final period in monthPeriods) {
      final payrolls = await PayrollDatasource.getPayrolls(
        periodId: period.id,
        employeeId: payroll.employeeId,
      );
      monthPayrolls.addAll(payrolls);
    }

    // Si falta la nómina de alguna quincena, crearla duplicando valores de la existente
    final hasQ1Payroll = monthPayrolls.any((p) {
      final period = monthPeriods
          .where((pr) => pr.id == p.periodId)
          .firstOrNull;
      return period != null && period.periodNumber == q1Num;
    });
    final hasQ2Payroll = monthPayrolls.any((p) {
      final period = monthPeriods
          .where((pr) => pr.id == p.periodId)
          .firstOrNull;
      return period != null && period.periodNumber == q2Num;
    });

    // Referencia: nómina existente para copiar valores
    final referencePayroll = monthPayrolls.isNotEmpty
        ? monthPayrolls.first
        : payroll;

    print('📋 Pago Mensual: hasQ1=$hasQ1Payroll, hasQ2=$hasQ2Payroll');
    print(
      '📋 Referencia: id=${referencePayroll.id}, netPay=${referencePayroll.netPay}, baseSalary=${referencePayroll.baseSalary}',
    );

    // Cargar detalles de la nómina de referencia para copiarlos
    final referenceDetails = await PayrollDatasource.getPayrollDetails(
      referencePayroll.id,
    );
    print('📋 Detalles de referencia: ${referenceDetails.length} conceptos');

    // Helper para crear nómina copia con detalles
    Future<void> createCopyPayroll(PayrollPeriod targetPeriod) async {
      try {
        print(
          '📋 Creando copia para periodo ${targetPeriod.periodNumber}/${targetPeriod.year}...',
        );
        final newPayroll = await PayrollDatasource.createPayroll(
          employeeId: payroll.employeeId,
          periodId: targetPeriod.id,
          baseSalary: referencePayroll.baseSalary,
          daysWorked: referencePayroll.daysWorked > 0
              ? referencePayroll.daysWorked
              : 15,
        );
        if (newPayroll != null) {
          print(
            '📋 Nómina creada: id=${newPayroll.id}, netPay=${newPayroll.netPay}',
          );
          // Copiar todos los payroll_details de la referencia
          for (final detail in referenceDetails) {
            try {
              await Supabase.instance.client.from('payroll_details').insert({
                'payroll_id': newPayroll.id,
                'concept_id': detail.conceptId,
                'concept_code': detail.conceptCode,
                'concept_name': detail.conceptName,
                'type': detail.type,
                'quantity': detail.quantity,
                'unit_value': detail.unitValue,
                'amount': detail.amount,
                'notes': detail.notes ?? 'Copia para pago mensual',
              });
            } catch (e) {
              print('⚠️ Error copiando detalle ${detail.conceptCode}: $e');
            }
          }
          // Recalcular totales a partir de los detalles copiados
          await Supabase.instance.client.rpc(
            'calculate_payroll_totals',
            params: {'p_payroll_id': newPayroll.id},
          );
          // Si no hay detalles (nómina simple), forzar totales directamente
          if (referenceDetails.isEmpty) {
            await PayrollDatasource.updatePayroll(newPayroll.id, {
              'total_earnings': referencePayroll.totalEarnings,
              'total_deductions': referencePayroll.totalDeductions,
              'net_pay': referencePayroll.netPay,
            });
          }
          await PayrollDatasource.updatePayroll(newPayroll.id, {
            'notes':
                'Auto-creada para pago mensual (copia de ${thisPeriod?.displayName ?? "periodo"})',
          });
          // Recargar para tener datos actualizados
          final reloaded = await PayrollDatasource.getPayrolls(
            periodId: targetPeriod.id,
            employeeId: payroll.employeeId,
          );
          print(
            '📋 Recargadas ${reloaded.length} nóminas, netPay=${reloaded.isNotEmpty ? reloaded.first.netPay : "N/A"}',
          );
          monthPayrolls.addAll(reloaded);
        } else {
          print('❌ createPayroll retornó null para periodo ${targetPeriod.id}');
        }
      } catch (e) {
        print('❌ Error creando copia de nómina: $e');
      }
    }

    if (!hasQ1Payroll) {
      final q1Period = monthPeriods
          .where((p) => p.periodNumber == q1Num)
          .firstOrNull;
      if (q1Period != null) {
        await createCopyPayroll(q1Period);
      } else {
        print('❌ No se encontró periodo Q1 ($q1Num) en monthPeriods');
      }
    }
    if (!hasQ2Payroll) {
      final q2Period = monthPeriods
          .where((p) => p.periodNumber == q2Num)
          .firstOrNull;
      if (q2Period != null) {
        await createCopyPayroll(q2Period);
      } else {
        print('❌ No se encontró periodo Q2 ($q2Num) en monthPeriods');
      }
    }

    // Deduplicar nóminas por ID
    final seenIds = <String>{};
    monthPayrolls = monthPayrolls.where((p) => seenIds.add(p.id)).toList();

    print('📋 Total nóminas del mes: ${monthPayrolls.length}');
    for (final p in monthPayrolls) {
      print('  → ${p.id} status=${p.status} netPay=${p.netPay}');
    }

    // Filtrar solo pendientes/aprobados (no pagados)
    final pendingPayrolls = monthPayrolls
        .where((p) => p.status != 'pagado')
        .toList();
    final paidPayrolls = monthPayrolls
        .where((p) => p.status == 'pagado')
        .toList();

    print(
      '📋 Pendientes: ${pendingPayrolls.length}, Ya pagadas: ${paidPayrolls.length}',
    );

    if (pendingPayrolls.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todas las nóminas del mes ya están pagadas'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
      return;
    }

    final totalToPay = pendingPayrolls.fold(0.0, (sum, p) => sum + p.netPay);
    final totalPaid = paidPayrolls.fold(0.0, (sum, p) => sum + p.netPay);

    const meses = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    final monthLabel = targetMonth >= 1 && targetMonth <= 12
        ? meses[targetMonth]
        : 'Mes $targetMonth';

    // Cargar cuentas
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

    if (!mounted) return;

    DateTime paymentDate = DateTime.now();
    String? selectedAccountId = accountsData[0]['id'];
    double selectedAccountBalance = (accountsData[0]['balance'] ?? 0)
        .toDouble();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.calendar_month, color: Color(0xFF1565C0)),
              const SizedBox(width: 8),
              Text('Pago Mensual — $monthLabel $targetYear'),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(
                            0xFF1565C0,
                          ).withValues(alpha: 0.1),
                          child: Text(
                            (payroll.employeeName ?? 'E')[0].toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF1565C0),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                payroll.employeeName ?? 'Empleado',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                payroll.employeePosition ?? '',
                                style: const TextStyle(
                                  color: Color(0xFF757575),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Total Mensual:',
                              style: TextStyle(fontSize: 12),
                            ),
                            Text(
                              Helpers.formatCurrency(totalToPay),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Desglose por quincena
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Desglose por Quincena',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const Divider(height: 16),
                        // Quincenas pendientes
                        ...pendingPayrolls.map((p) {
                          final period = monthPeriods
                              .where((pr) => pr.id == p.periodId)
                              .firstOrNull;
                          final qLabel = period?.displayName ?? 'Quincena';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.pending,
                                  size: 16,
                                  color: Color(0xFFF9A825),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    qLabel,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Text(
                                  Helpers.formatCurrency(p.netPay),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1565C0),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        // Quincenas ya pagadas
                        ...paidPayrolls.map((p) {
                          final period = monthPeriods
                              .where((pr) => pr.id == p.periodId)
                              .firstOrNull;
                          final qLabel = period?.displayName ?? 'Quincena';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: Color(0xFF2E7D32),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$qLabel (ya pagada)',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF9E9E9E),
                                    ),
                                  ),
                                ),
                                Text(
                                  Helpers.formatCurrency(p.netPay),
                                  style: const TextStyle(
                                    color: Color(0xFF9E9E9E),
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'A pagar (${pendingPayrolls.length} quincena${pendingPayrolls.length > 1 ? "s" : ""}):',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              Helpers.formatCurrency(totalToPay),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cuenta de pago
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Cuenta de Pago',
                      prefixIcon: Icon(Icons.account_balance),
                      border: OutlineInputBorder(),
                    ),
                    value: selectedAccountId,
                    items: accountsData.map<DropdownMenuItem<String>>((acc) {
                      final balance = (acc['balance'] ?? 0).toDouble();
                      final hasEnough = balance >= totalToPay;
                      return DropdownMenuItem(
                        value: acc['id'] as String,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(acc['name'] ?? 'Cuenta'),
                            Text(
                              Helpers.formatCurrency(balance),
                              style: TextStyle(
                                color: hasEnough
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFC62828),
                                fontWeight: FontWeight.w500,
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

                  if (selectedAccountBalance < totalToPay) ...[
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
                          Expanded(
                            child: Text(
                              'Saldo insuficiente. Falta: ${Helpers.formatCurrency(totalToPay - selectedAccountBalance)}',
                              style: const TextStyle(
                                color: Color(0xFFC62828),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Fecha de pago
                  const Text(
                    'Fecha de pago:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: paymentDate,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 30),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (date != null) {
                        setState(() => paymentDate = date);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Color(0xFF1565C0),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${paymentDate.day.toString().padLeft(2, '0')}/${paymentDate.month.toString().padLeft(2, '0')}/${paymentDate.year}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.edit_calendar,
                            color: Color(0xFF9E9E9E),
                            size: 18,
                          ),
                        ],
                      ),
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
              onPressed:
                  selectedAccountId == null ||
                      selectedAccountBalance < totalToPay
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);

                      int successCount = 0;
                      for (final p in pendingPayrolls) {
                        final success = await ref
                            .read(payrollProvider.notifier)
                            .processPayment(
                              payrollId: p.id,
                              accountId: selectedAccountId!,
                              paymentDate: paymentDate,
                            );
                        if (success) successCount++;
                      }

                      // Refrescar Caja Diaria
                      ref.read(dailyCashProvider.notifier).load();

                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            successCount == pendingPayrolls.length
                                ? '✅ Pago mensual de ${Helpers.formatCurrency(totalToPay)} registrado ($successCount quincenas)'
                                : '⚠️ Se pagaron $successCount de ${pendingPayrolls.length} quincenas',
                          ),
                          backgroundColor:
                              successCount == pendingPayrolls.length
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFF9A825),
                        ),
                      );
                    },
              icon: const Icon(Icons.check),
              label: Text('Pagar $monthLabel completo'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Painter para el gráfico de onda en la distribución salarial
class _WaveChartPainter extends CustomPainter {
  final Color color;

  _WaveChartPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    path.moveTo(0, size.height * 0.8);
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, size.height * 0.8);

    // Crear curva suave
    path.cubicTo(
      size.width * 0.15,
      size.height * 0.8,
      size.width * 0.2,
      size.height * 0.25,
      size.width * 0.375,
      size.height * 0.25,
    );
    path.cubicTo(
      size.width * 0.55,
      size.height * 0.25,
      size.width * 0.625,
      size.height * 0.65,
      size.width * 0.75,
      size.height * 0.65,
    );
    path.cubicTo(
      size.width * 0.875,
      size.height * 0.65,
      size.width * 0.95,
      size.height * 0.15,
      size.width,
      size.height * 0.15,
    );

    // Fill path
    fillPath.cubicTo(
      size.width * 0.15,
      size.height * 0.8,
      size.width * 0.2,
      size.height * 0.25,
      size.width * 0.375,
      size.height * 0.25,
    );
    fillPath.cubicTo(
      size.width * 0.55,
      size.height * 0.25,
      size.width * 0.625,
      size.height * 0.65,
      size.width * 0.75,
      size.height * 0.65,
    );
    fillPath.cubicTo(
      size.width * 0.875,
      size.height * 0.65,
      size.width * 0.95,
      size.height * 0.15,
      size.width,
      size.height * 0.15,
    );
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
