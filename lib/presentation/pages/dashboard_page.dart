import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/responsive/responsive_helper.dart';
import '../../data/providers/providers.dart';
import '../../data/providers/activities_provider.dart';
import '../../data/providers/role_provider.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/datasources/employees_datasource.dart';
import '../../data/datasources/payroll_datasource.dart';
import '../../domain/entities/employee.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  // Employee portal data
  Employee? _employee;
  List<EmployeeTimeEntry> _timeEntries = [];
  List<EmployeeTimeSheet> _timesheets = [];
  List<EmployeePayroll> _payrolls = [];
  List<EmployeeIncapacity> _incapacities = [];
  List<EmployeeLoan> _loans = [];
  bool _isLoadingEmployee = true;
  String? _employeeError;

  final _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );
  final _dateFormat = DateFormat('dd/MM/yyyy', 'es_CO');

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(customersProvider.notifier).loadCustomers();
      ref.read(productsProvider.notifier).loadProducts();
      ref.read(quotationsProvider.notifier).loadQuotations();
      ref.read(inventoryProvider.notifier).loadMaterials();
      ref.read(invoicesProvider.notifier).refresh();
      ref.read(activitiesProvider.notifier).loadActivities();

      // Si es empleado, cargar datos del portal
      final roleState = ref.read(roleProvider);
      if (roleState.isEmployee && roleState.employeeId != null) {
        _loadEmployeeData(roleState.employeeId!);
      }
    });
  }

  Future<void> _loadEmployeeData(String employeeId) async {
    setState(() {
      _isLoadingEmployee = true;
      _employeeError = null;
    });

    try {
      final results = await Future.wait([
        EmployeesDatasource.getEmployeeById(employeeId),
        EmployeesDatasource.getTimeEntries(employeeId: employeeId),
        EmployeesDatasource.getTimesheets(employeeId: employeeId),
        PayrollDatasource.getPayrolls(employeeId: employeeId),
        PayrollDatasource.getIncapacities(employeeId: employeeId),
        PayrollDatasource.getLoans(employeeId: employeeId),
      ]);

      if (!mounted) return;
      setState(() {
        _employee = results[0] as Employee?;
        _timeEntries = results[1] as List<EmployeeTimeEntry>;
        _timesheets = results[2] as List<EmployeeTimeSheet>;
        _payrolls = results[3] as List<EmployeePayroll>;
        _incapacities = results[4] as List<EmployeeIncapacity>;
        _loans = results[5] as List<EmployeeLoan>;
        _isLoadingEmployee = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _employeeError = 'Error al cargar datos: $e';
        _isLoadingEmployee = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleState = ref.watch(roleProvider);

    // Si es empleado con permisos, mostrar Mi Portal embebido
    if (roleState.isEmployee && roleState.employeeId != null) {
      return _buildEmployeeDashboard(context);
    }

    // Dashboard normal (logo)
    return Scaffold(
      body: Center(
        child: Image.asset(
          'lib/photo/logo_empresa.png',
          width: 250,
          height: 250,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.precision_manufacturing,
            size: 120,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  // === EMPLOYEE DASHBOARD ===

  Widget _buildEmployeeDashboard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isMobile = ResponsiveHelper.isMobile(context);

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: _isLoadingEmployee
          ? const Center(child: CircularProgressIndicator())
          : _employeeError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: AppColors.danger),
                      const SizedBox(height: AppSpacing.base),
                      Text(_employeeError!, textAlign: TextAlign.center),
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton.icon(
                        onPressed: () {
                          final eid = ref.read(roleProvider).employeeId;
                          if (eid != null) _loadEmployeeData(eid);
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _employee == null
                  ? const Center(child: Text('No se encontró información del empleado.'))
                  : RefreshIndicator(
                      onRefresh: () async {
                        final eid = ref.read(roleProvider).employeeId;
                        if (eid != null) await _loadEmployeeData(eid);
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.all(
                          isMobile ? AppSpacing.base : AppSpacing.xl,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Título Mi Portal + acciones
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.base),
                              child: Row(
                                children: [
                                  Text(
                                    'Mi Portal',
                                    style: tt.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.refresh),
                                    tooltip: 'Actualizar',
                                    onPressed: () {
                                      final eid = ref.read(roleProvider).employeeId;
                                      if (eid != null) _loadEmployeeData(eid);
                                    },
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  FilledButton.tonalIcon(
                                    onPressed: () => ref.read(authProvider.notifier).signOut(),
                                    icon: const Icon(Icons.logout, size: 18),
                                    label: const Text('Cerrar sesión'),
                                  ),
                                ],
                              ),
                            ),
                            if (isMobile)
                              _buildMobileLayout(cs, tt)
                            else
                              _buildDesktopLayout(cs, tt),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildMobileLayout(ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProfileCard(cs, tt),
        const SizedBox(height: AppSpacing.base),
        _buildHoursCard(cs, tt),
        const SizedBox(height: AppSpacing.base),
        _buildPayrollCard(cs, tt),
        const SizedBox(height: AppSpacing.base),
        _buildIncapacitiesCard(cs, tt),
        const SizedBox(height: AppSpacing.base),
        _buildLoansCard(cs, tt),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _buildDesktopLayout(ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProfileCard(cs, tt),
        const SizedBox(height: AppSpacing.base),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildHoursCard(cs, tt)),
            const SizedBox(width: AppSpacing.base),
            Expanded(child: _buildPayrollCard(cs, tt)),
          ],
        ),
        const SizedBox(height: AppSpacing.base),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildIncapacitiesCard(cs, tt)),
            const SizedBox(width: AppSpacing.base),
            Expanded(child: _buildLoansCard(cs, tt)),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  // === CARDS ===

  Widget _buildProfileCard(ColorScheme cs, TextTheme tt) {
    final emp = _employee!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    emp.initials,
                    style: tt.headlineSmall?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.base),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emp.fullName, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(emp.position, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                      if (emp.department != null)
                        Text(emp.department!, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: emp.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    emp.statusLabel,
                    style: tt.labelMedium?.copyWith(color: emp.statusColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.xxl),
            Wrap(
              spacing: AppSpacing.xxl,
              runSpacing: AppSpacing.md,
              children: [
                _infoChip(Icons.badge, 'Doc', '${emp.documentType ?? ''} ${emp.documentNumber ?? 'N/A'}', tt, cs),
                _infoChip(Icons.email, 'Email', emp.email ?? 'N/A', tt, cs),
                _infoChip(Icons.phone, 'Teléfono', emp.phone ?? 'N/A', tt, cs),
                _infoChip(Icons.calendar_today, 'Ingreso', _dateFormat.format(emp.hireDate), tt, cs),
                if (emp.salary != null)
                  _infoChip(Icons.attach_money, 'Salario', _currencyFormat.format(emp.salary), tt, cs),
                _infoChip(Icons.schedule, 'Horario', emp.workSchedule.replaceAll('_', ' '), tt, cs),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, String value, TextTheme tt, ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            Text(value, style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _buildHoursCard(ColorScheme cs, TextTheme tt) {
    final recentEntries = _timeEntries.take(10).toList();
    final totalWorked = _timesheets.fold<int>(0, (sum, ts) => sum + ts.workedMinutes);
    final totalOvertime = _timesheets.fold<int>(0, (sum, ts) => sum + ts.overtimeMinutes);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.access_time, 'Horas Trabajadas', tt, cs),
            const SizedBox(height: AppSpacing.base),
            Row(
              children: [
                _statBadge('Total', _formatMinutes(totalWorked), AppColors.info, tt),
                const SizedBox(width: AppSpacing.md),
                _statBadge('Extras', _formatMinutes(totalOvertime), AppColors.warning, tt),
                const SizedBox(width: AppSpacing.md),
                _statBadge('Semanas', '${_timesheets.length}', AppColors.success, tt),
              ],
            ),
            const SizedBox(height: AppSpacing.base),
            if (recentEntries.isEmpty)
              _emptyMessage('No hay registros de asistencia')
            else ...[
              Text('Últimos registros', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.sm),
              ...recentEntries.map((e) => _timeEntryTile(e, tt, cs)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _timeEntryTile(EmployeeTimeEntry entry, TextTheme tt, ColorScheme cs) {
    final checkIn = entry.checkIn != null ? DateFormat('HH:mm').format(entry.checkIn!) : '--:--';
    final checkOut = entry.checkOut != null ? DateFormat('HH:mm').format(entry.checkOut!) : '--:--';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(_dateFormat.format(entry.entryDate), style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w500))),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.login, size: 14, color: AppColors.success),
          const SizedBox(width: AppSpacing.xxs),
          Text(checkIn, style: tt.bodySmall),
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.logout, size: 14, color: AppColors.danger),
          const SizedBox(width: AppSpacing.xxs),
          Text(checkOut, style: tt.bodySmall),
          const Spacer(),
          Text(_formatMinutes(entry.workedMinutes), style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          if (entry.overtimeMinutes > 0) ...[
            const SizedBox(width: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
              child: Text('+${_formatMinutes(entry.overtimeMinutes)}', style: tt.labelSmall?.copyWith(color: AppColors.warning, fontSize: 10)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPayrollCard(ColorScheme cs, TextTheme tt) {
    final paidPayrolls = _payrolls.where((p) => p.status == 'pagada').toList();
    final totalPaid = paidPayrolls.fold<double>(0, (sum, p) => sum + p.netPay);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.payments, 'Nómina / Pagos', tt, cs),
            const SizedBox(height: AppSpacing.base),
            Row(
              children: [
                _statBadge('Total pagado', _currencyFormat.format(totalPaid), AppColors.success, tt),
                const SizedBox(width: AppSpacing.md),
                _statBadge('Períodos', '${_payrolls.length}', AppColors.info, tt),
              ],
            ),
            const SizedBox(height: AppSpacing.base),
            if (_payrolls.isEmpty)
              _emptyMessage('No hay registros de nómina')
            else ...[
              Text('Historial', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.sm),
              ..._payrolls.take(8).map((p) => _payrollTile(p, tt, cs)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _payrollTile(EmployeePayroll payroll, TextTheme tt, ColorScheme cs) {
    final statusColor = payroll.status == 'pagada' ? AppColors.success : payroll.status == 'aprobada' ? AppColors.info : cs.onSurfaceVariant;
    final statusLabel = payroll.status == 'pagada' ? 'Pagada' : payroll.status == 'aprobada' ? 'Aprobada' : payroll.status == 'borrador' ? 'Borrador' : payroll.status;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(child: Text(payroll.periodName ?? 'Período', style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w500))),
          Text(_currencyFormat.format(payroll.netPay), style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(statusLabel, style: tt.labelSmall?.copyWith(color: statusColor, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildIncapacitiesCard(ColorScheme cs, TextTheme tt) {
    final active = _incapacities.where((i) => i.status == 'activa').toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.local_hospital, 'Ausencias / Incapacidades', tt, cs),
            const SizedBox(height: AppSpacing.base),
            Row(
              children: [
                _statBadge('Total', '${_incapacities.length}', AppColors.info, tt),
                const SizedBox(width: AppSpacing.md),
                _statBadge('Activas', '${active.length}', AppColors.warning, tt),
              ],
            ),
            const SizedBox(height: AppSpacing.base),
            if (_incapacities.isEmpty)
              _emptyMessage('No hay incapacidades registradas')
            else
              ..._incapacities.take(6).map((inc) => _incapacityTile(inc, tt, cs)),
          ],
        ),
      ),
    );
  }

  Widget _incapacityTile(EmployeeIncapacity inc, TextTheme tt, ColorScheme cs) {
    final active = inc.status == 'activa';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Icon(active ? Icons.circle : Icons.check_circle, size: 10, color: active ? AppColors.warning : AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(inc.typeLabel, style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w500))),
          Text('${_dateFormat.format(inc.startDate)} - ${_dateFormat.format(inc.endDate)}', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(width: AppSpacing.sm),
          Text('${inc.daysTotal}d', style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildLoansCard(ColorScheme cs, TextTheme tt) {
    final activeLoans = _loans.where((l) => l.status == 'activo').toList();
    final totalDebt = activeLoans.fold<double>(0, (sum, l) => sum + l.remainingAmount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.account_balance_wallet, 'Préstamos', tt, cs),
            const SizedBox(height: AppSpacing.base),
            Row(
              children: [
                _statBadge('Activos', '${activeLoans.length}', AppColors.info, tt),
                const SizedBox(width: AppSpacing.md),
                _statBadge('Saldo', _currencyFormat.format(totalDebt), AppColors.danger, tt),
              ],
            ),
            const SizedBox(height: AppSpacing.base),
            if (_loans.isEmpty)
              _emptyMessage('No hay préstamos registrados')
            else
              ..._loans.take(6).map((loan) => _loanTile(loan, tt, cs)),
          ],
        ),
      ),
    );
  }

  Widget _loanTile(EmployeeLoan loan, TextTheme tt, ColorScheme cs) {
    final active = loan.status == 'activo';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(loan.reason ?? 'Préstamo', style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w500))),
              Text(_currencyFormat.format(loan.totalAmount), style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (active ? AppColors.warning : AppColors.success).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(active ? 'Activo' : 'Pagado', style: tt.labelSmall?.copyWith(color: active ? AppColors.warning : AppColors.success, fontSize: 10)),
              ),
            ],
          ),
          if (active) ...[
            const SizedBox(height: AppSpacing.xxs),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: loan.progress,
                      backgroundColor: cs.surfaceContainerHighest,
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('${loan.paidInstallments}/${loan.installments} cuotas', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // === HELPERS ===

  Widget _sectionHeader(IconData icon, String title, TextTheme tt, ColorScheme cs) {
    return Row(
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _statBadge(String label, String value, Color color, TextTheme tt) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: tt.labelSmall?.copyWith(color: color)),
            const SizedBox(height: AppSpacing.xxs),
            Text(value, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _emptyMessage(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
      child: Center(
        child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}
