import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/services/nfc_reader_service.dart';
import '../../../data/datasources/employees_datasource.dart';
import '../../../data/datasources/accounts_datasource.dart';
import '../../../data/datasources/payroll_datasource.dart';
import '../../../data/providers/employees_provider.dart';
import '../../../data/providers/payroll_provider.dart';
import '../../../data/providers/accounts_provider.dart';
import '../../../domain/entities/employee.dart';
import '../../../domain/entities/cash_movement.dart';

/// Tab principal de empleados — lista, detalle, dialogs de CRUD/asistencia/NFC.
class EmployeesMainTab extends ConsumerStatefulWidget {
  const EmployeesMainTab({super.key});

  @override
  ConsumerState<EmployeesMainTab> createState() => EmployeesMainTabState();
}

class EmployeesMainTabState extends ConsumerState<EmployeesMainTab> {
  final _searchController = TextEditingController();
  String _filterStatus = 'todos';
  String _filterDepartment = 'todos';

  // Key para forzar rebuild del FutureBuilder de quincena
  int _quincenaRefreshKey = 0;

  /// Public API for shell coordinator to open employee creation dialog.
  void showEmployeeDialog() => _showEmployeeDialog();

  /// Public API for shell coordinator to open loan creation dialog.
  void showLoanDialog() => _showLoanDialog();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeesProvider);
    final payrollState = ref.watch(payrollProvider);
    final theme = Theme.of(context);
    return _buildEmployeesTab(theme, state, payrollState);
  }

  Widget _buildEmployeesTab(
    ThemeData theme,
    EmployeesState state,
    PayrollState payrollState,
  ) {
    final selectedEmployee = state.selectedEmployee;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isMobile) ...[
                    // Mobile: search full width, filters below
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar empleado...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                      ),
                      onChanged: (value) {
                        ref.read(employeesProvider.notifier).search(value);
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildFilterDropdown(
                            value: _filterStatus,
                            items: const [
                              DropdownMenuItem(
                                value: 'todos',
                                child: Text('Todos'),
                              ),
                              DropdownMenuItem(
                                value: 'activo',
                                child: Text('Activos'),
                              ),
                              DropdownMenuItem(
                                value: 'vacaciones',
                                child: Text('Vacaciones'),
                              ),
                              DropdownMenuItem(
                                value: 'licencia',
                                child: Text('Licencia'),
                              ),
                              DropdownMenuItem(
                                value: 'inactivo',
                                child: Text('Inactivos'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _filterStatus = value ?? 'todos');
                            },
                            hint: 'Estado',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildFilterDropdown(
                            value: _filterDepartment,
                            items: const [
                              DropdownMenuItem(
                                value: 'todos',
                                child: Text('Todos'),
                              ),
                              DropdownMenuItem(
                                value: 'produccion',
                                child: Text('Producción'),
                              ),
                              DropdownMenuItem(
                                value: 'ventas',
                                child: Text('Ventas'),
                              ),
                              DropdownMenuItem(
                                value: 'administracion',
                                child: Text('Administración'),
                              ),
                              DropdownMenuItem(
                                value: 'mantenimiento',
                                child: Text('Mantenimiento'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(
                                () => _filterDepartment = value ?? 'todos',
                              );
                            },
                            hint: 'Departamento',
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // Desktop: all in one row
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Buscar empleado...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                            ),
                            onChanged: (value) {
                              ref
                                  .read(employeesProvider.notifier)
                                  .search(value);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        _buildFilterDropdown(
                          value: _filterStatus,
                          items: const [
                            DropdownMenuItem(
                              value: 'todos',
                              child: Text('Todos'),
                            ),
                            DropdownMenuItem(
                              value: 'activo',
                              child: Text('Activos'),
                            ),
                            DropdownMenuItem(
                              value: 'vacaciones',
                              child: Text('Vacaciones'),
                            ),
                            DropdownMenuItem(
                              value: 'licencia',
                              child: Text('Licencia'),
                            ),
                            DropdownMenuItem(
                              value: 'inactivo',
                              child: Text('Inactivos'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _filterStatus = value ?? 'todos');
                          },
                          hint: 'Estado',
                        ),
                        const SizedBox(width: 16),
                        _buildFilterDropdown(
                          value: _filterDepartment,
                          items: const [
                            DropdownMenuItem(
                              value: 'todos',
                              child: Text('Todos'),
                            ),
                            DropdownMenuItem(
                              value: 'produccion',
                              child: Text('Producción'),
                            ),
                            DropdownMenuItem(
                              value: 'ventas',
                              child: Text('Ventas'),
                            ),
                            DropdownMenuItem(
                              value: 'administracion',
                              child: Text('Administración'),
                            ),
                            DropdownMenuItem(
                              value: 'mantenimiento',
                              child: Text('Mantenimiento'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(
                              () => _filterDepartment = value ?? 'todos',
                            );
                          },
                          hint: 'Departamento',
                        ),
                      ],
                    ),
                  ],
                  if (selectedEmployee != null) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.badge, size: 16),
                          label: Text(
                            'Seleccionado: ${selectedEmployee.fullName}',
                          ),
                          onDeleted: () => ref
                              .read(employeesProvider.notifier)
                              .selectEmployee(null),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.refresh, size: 16),
                          label: const Text('Actualizar horas'),
                          onPressed: () => ref
                              .read(employeesProvider.notifier)
                              .loadTimeOverview(selectedEmployee.id),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showSplit = constraints.maxWidth > 1100;
              final listPanel = _buildEmployeeListPanel(
                theme,
                state,
                showSplit,
              );

              if (!showSplit) {
                return listPanel;
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 2, child: listPanel),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: selectedEmployee != null
                        ? _buildEmployeeDashboard(
                            theme,
                            state,
                            payrollState,
                            selectedEmployee,
                          )
                        : _buildDashboardPlaceholder(theme),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeListPanel(
    ThemeData theme,
    EmployeesState state,
    bool showSplit,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final employees = _getFilteredEmployees(state);

    if (employees.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: _buildEmptyState(
          icon: Icons.people_outline,
          title: 'Sin empleados',
          subtitle:
              'Agrega empleados para comenzar a gestionar\nsu tiempo, tareas y nómina',
          onAction: () => _showEmployeeDialog(),
          actionLabel: 'Agregar Empleado',
        ),
      );
    }

    final selectedId = state.selectedEmployee?.id;

    return Card(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Icon(Icons.groups, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Equipo',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Botón Pasar Lista (Asistencia Inversa)
                FilledButton.icon(
                  onPressed: () => _showAttendanceDialog(),
                  icon: const Icon(Icons.fact_check, size: 16),
                  label: const Text(
                    'Pasar Lista',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${employees.length}'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: employees.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final employee = employees[index];
                final isSelected = selectedId == employee.id;

                return Material(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.08)
                      : Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.12,
                      ),
                      backgroundImage: employee.photoUrl != null
                          ? NetworkImage(employee.photoUrl!)
                          : null,
                      child: employee.photoUrl == null
                          ? Text(
                              employee.initials,
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      employee.fullName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.position,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            // Chips de info
                            Flexible(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  _buildStatusChip(employee),
                                  if (employee.department != null)
                                    _buildInfoChip(
                                      icon: Icons.business,
                                      label: employee.department!,
                                    ),
                                  if (employee.phone != null)
                                    _buildInfoChip(
                                      icon: Icons.phone,
                                      label: employee.phone!,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Barra de progreso de horas semanales
                            SizedBox(
                              width: 120,
                              child: _buildEmployeeHoursProgressBar(
                                employee,
                                state,
                                theme,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'detail':
                            _showEmployeeDetail(employee);
                            break;
                          case 'task':
                            _showAssignTaskDialog(employee);
                            break;
                          case 'nfc':
                            _showNfcAssignDialog(employee);
                            break;
                          case 'edit':
                            _showEmployeeDialog(employee: employee);
                            break;
                          case 'delete':
                            _confirmDelete(employee);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'detail',
                          child: Text('Ver detalle'),
                        ),
                        const PopupMenuItem(
                          value: 'task',
                          child: Text('Asignar tarea'),
                        ),
                        PopupMenuItem(
                          value: 'nfc',
                          child: Row(
                            children: [
                              Icon(
                                Icons.nfc,
                                size: 18,
                                color: employee.nfcCardId != null
                                    ? Colors.green
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                employee.nfcCardId != null
                                    ? 'Cambiar tarjeta NFC'
                                    : 'Asignar tarjeta NFC',
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Editar'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Eliminar'),
                        ),
                      ],
                    ),
                    onTap: () {
                      if (showSplit) {
                        ref
                            .read(employeesProvider.notifier)
                            .selectEmployee(employee);
                      } else {
                        _showEmployeeDetail(employee);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(Employee employee) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: employee.statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        employee.statusLabel,
        style: TextStyle(
          color: employee.statusColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF9E9E9E).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF616161)),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 80),
            child: Text(
              label,
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeHoursProgressBar(
    Employee employee,
    EmployeesState state,
    ThemeData theme,
  ) {
    // Si es pago diario, mostrar días de asistencia en vez de horas
    if (employee.isDailyPay) {
      final info = _calculateEmployeeWeekAttendanceInfo(employee, state);
      final days = info.daysPresent;
      final absent = info.daysAbsent;
      final target = employee.attendanceBonusDays;
      final meetsBonus = days >= target;
      final bonusLost = absent > 0;
      final color = meetsBonus
          ? const Color(0xFF2E7D32)
          : bonusLost
          ? const Color(0xFFC62828)
          : const Color(0xFFF9A825);
      return Row(
        children: [
          Icon(
            bonusLost ? Icons.cancel : Icons.calendar_today,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            '$days/$target días',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (meetsBonus) ...[
            const SizedBox(width: 4),
            Icon(Icons.emoji_events, size: 14, color: const Color(0xFFFFA000)),
          ],
        ],
      );
    }

    // Horario: L-V 7:30-12:00 y 1:00-4:30, Sáb 7:30-1:00 = 44h semanales
    const double weeklyBase = 44.0; // 44h semanales
    double weekHours = weeklyBase;

    // Calcular ajustes de esta semana
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    final weekAdjustments = state.timeAdjustments
        .where((a) => a.employeeId == employee.id)
        .where(
          (a) => a.adjustmentDate.isAfter(
            startOfWeek.subtract(const Duration(days: 1)),
          ),
        )
        .toList();

    // Aplicar ajustes a las 48 horas base
    for (var adj in weekAdjustments) {
      if (adj.type == 'overtime') {
        weekHours += adj.minutes / 60.0;
      } else {
        weekHours -= adj.minutes / 60.0;
      }
    }

    if (weekHours < 0) weekHours = 0;

    final isOvertime = weekHours > weeklyBase;
    final isUndertime = weekHours < weeklyBase;

    final progressColor = isOvertime
        ? const Color(0xFF2E7D32)
        : isUndertime
        ? const Color(0xFFF9A825)
        : theme.colorScheme.primary;

    return Row(
      children: [
        // Botón restar 0.5 hora
        InkWell(
          onTap: () => _addHours(employee, -0.5),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFC62828).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.remove, size: 16, color: Color(0xFFC62828)),
          ),
        ),
        const SizedBox(width: 12),
        // Horas
        Text(
          '${weekHours.toStringAsFixed(1)}h',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: progressColor,
          ),
        ),
        const SizedBox(width: 12),
        // Botón sumar 0.5 hora
        InkWell(
          onTap: () => _addHours(employee, 0.5),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.add, size: 16, color: Color(0xFF2E7D32)),
          ),
        ),
      ],
    );
  }

  List<Employee> _getFilteredEmployees(EmployeesState state) {
    var employees = state.filteredEmployees;

    if (_filterStatus != 'todos') {
      employees = employees
          .where((e) => e.status.name == _filterStatus)
          .toList();
    }

    if (_filterDepartment != 'todos') {
      employees = employees
          .where(
            (e) =>
                e.department?.toLowerCase() == _filterDepartment.toLowerCase(),
          )
          .toList();
    }

    return employees;
  }

  Widget _buildEmployeeDashboard(
    ThemeData theme,
    EmployeesState state,
    PayrollState payrollState,
    Employee employee,
  ) {
    final tasks = state.selectedEmployeeTasks;
    final adjustments = state.timeAdjustments.take(5).toList();
    final activeLoans = payrollState.loans
        .where((loan) => loan.employeeId == employee.id)
        .where((loan) => loan.status == 'activo')
        .toList();
    final pendingLoanAmount = activeLoans.fold<double>(
      0,
      (sum, loan) => sum + loan.remainingAmount,
    );

    // Calcular horas de la semana
    final weekHours = _calculateEmployeeWeekHours(employee, state);
    const double weeklyBase = 44.0;
    final extraHours = weekHours > weeklyBase ? weekHours - weeklyBase : 0.0;
    final deficitHours = weekHours < weeklyBase ? weeklyBase - weekHours : 0.0;

    // Para pago diario: días de asistencia esta semana
    final bool isDailyPayEmployee = employee.isDailyPay;
    final attendanceInfo = isDailyPayEmployee
        ? _calculateEmployeeWeekAttendanceInfo(employee, state)
        : (daysPresent: 0, daysAbsent: 0);
    final int weekAttendanceDays = attendanceInfo.daysPresent;
    final int weekAbsenceDays = attendanceInfo.daysAbsent;
    final bool bonusLostThisWeek = weekAbsenceDays > 0;
    final int bonusDaysTarget = employee.attendanceBonusDays;

    final pendingTasks = tasks
        .where(
          (t) =>
              t.status != TaskStatus.completada &&
              t.status != TaskStatus.cancelada,
        )
        .toList();
    final inProgressTasks = tasks
        .where((t) => t.status == TaskStatus.enProgreso)
        .length;

    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = const Color(0xFF137FEC);
    final borderColor = isDark
        ? const Color(0xFF2D3748)
        : const Color(0xFFDBE0E6);
    final cardBg = isDark ? const Color(0xFF1A2632) : Colors.white;
    final bgColor = isDark ? const Color(0xFF101922) : const Color(0xFFF6F7F8);
    final textMain = isDark ? Colors.white : const Color(0xFF111418);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF617589);

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === HEADER DEL EMPLEADO (compacto) ===
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                // Avatar compacto
                CircleAvatar(
                  radius: 18,
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  backgroundImage: employee.photoUrl != null
                      ? NetworkImage(employee.photoUrl!)
                      : null,
                  child: employee.photoUrl == null
                      ? Text(
                          employee.initials,
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        employee.fullName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textMain,
                        ),
                      ),
                      Text(
                        '${employee.position} • ${employee.department ?? "Sin depto"}',
                        style: TextStyle(fontSize: 11, color: textSub),
                      ),
                    ],
                  ),
                ),
                // Info compacta
                if (employee.phone != null) ...[
                  Icon(Icons.phone, size: 14, color: textSub),
                  const SizedBox(width: 4),
                  Text(
                    employee.phone!,
                    style: TextStyle(fontSize: 11, color: textSub),
                  ),
                  const SizedBox(width: 12),
                ],
                _buildStatusChip(employee),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // === CONTROL DE HORAS ===
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDailyPayEmployee
                            ? Icons.calendar_today
                            : Icons.schedule,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDailyPayEmployee
                                ? 'Control de Asistencia Semanal'
                                : 'Control de Horas Semanales',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textMain,
                            ),
                          ),
                          Text(
                            isDailyPayEmployee
                                ? 'Pago diario: ${Helpers.formatCurrency(employee.dailyRate)}/día'
                                : 'Base: 44h/semana (L-V 7:30-4:30, S 7:30-1:00)',
                            style: TextStyle(fontSize: 12, color: textSub),
                          ),
                        ],
                      ),
                    ),
                    if (isDailyPayEmployee)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9A825).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'DIARIO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFFF8F00),
                          ),
                        ),
                      ),
                    if (!isDailyPayEmployee)
                      IconButton(
                        onPressed: () => _showTimeHistoryDialog(employee),
                        icon: Icon(
                          Icons.history,
                          color: primaryColor,
                          size: 20,
                        ),
                        tooltip: 'Ver historial completo',
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                if (isDailyPayEmployee)
                  // === CONTROL DE ASISTENCIA PARA PAGO DIARIO ===
                  Column(
                    children: [
                      // Número grande de días
                      Text(
                        '$weekAttendanceDays',
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.bold,
                          color: weekAttendanceDays >= bonusDaysTarget
                              ? const Color(0xFF43A047)
                              : textMain,
                        ),
                      ),
                      Text(
                        'días esta semana',
                        style: TextStyle(fontSize: 14, color: textSub),
                      ),
                      const SizedBox(height: 12),
                      // Barra de progreso de asistencia
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: weekAttendanceDays / bonusDaysTarget,
                                minHeight: 10,
                                backgroundColor: primaryColor.withValues(
                                  alpha: 0.1,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  weekAttendanceDays >= bonusDaysTarget
                                      ? const Color(0xFF2E7D32)
                                      : bonusLostThisWeek
                                      ? const Color(0xFFC62828)
                                      : primaryColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$weekAttendanceDays/$bonusDaysTarget',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: bonusLostThisWeek
                                  ? const Color(0xFFE53935)
                                  : textSub,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Info del bono - 3 estados: ganado, perdido, en progreso
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: weekAttendanceDays >= bonusDaysTarget
                              ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                              : bonusLostThisWeek
                              ? const Color(0xFFC62828).withValues(alpha: 0.1)
                              : const Color(0xFFF9A825).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              weekAttendanceDays >= bonusDaysTarget
                                  ? Icons.emoji_events
                                  : bonusLostThisWeek
                                  ? Icons.cancel
                                  : Icons.info_outline,
                              size: 16,
                              color: weekAttendanceDays >= bonusDaysTarget
                                  ? const Color(0xFF388E3C)
                                  : bonusLostThisWeek
                                  ? const Color(0xFFD32F2F)
                                  : const Color(0xFFF57C00),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                weekAttendanceDays >= bonusDaysTarget
                                    ? '¡Bono semanal ganado! +${Helpers.formatCurrency(employee.attendanceBonus)}'
                                    : bonusLostThisWeek
                                    ? 'PERDIÓ bono esta semana ($weekAbsenceDays falta${weekAbsenceDays > 1 ? 's' : ''})'
                                    : 'Va bien — $weekAttendanceDays/$bonusDaysTarget días, sin faltas',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: weekAttendanceDays >= bonusDaysTarget
                                      ? const Color(0xFF388E3C)
                                      : bonusLostThisWeek
                                      ? const Color(0xFFD32F2F)
                                      : const Color(0xFFF57C00),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  // === CONTROL DE HORAS PARA PAGO POR HORA ===
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Botón restar
                      Material(
                        color: const Color(0xFFC62828).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => _addHours(employee, -0.5),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 56,
                            height: 56,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.remove,
                              size: 28,
                              color: const Color(0xFFE53935),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Total de horas
                      Column(
                        children: [
                          Text(
                            '${weekHours.toStringAsFixed(1)}h',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: extraHours > 0
                                  ? const Color(0xFF43A047)
                                  : (deficitHours > 0
                                        ? const Color(0xFFFB8C00)
                                        : textMain),
                            ),
                          ),
                          if (extraHours > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF2E7D32,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '+${extraHours.toStringAsFixed(1)}h extras',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF43A047),
                                ),
                              ),
                            )
                          else if (deficitHours > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFF9A825,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '-${deficitHours.toStringAsFixed(1)}h faltantes',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFFB8C00),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      // Botón sumar
                      Material(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () => _addHours(employee, 0.5),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 56,
                            height: 56,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.add,
                              size: 28,
                              color: const Color(0xFF43A047),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // === TARJETAS DE RESUMEN ===
          Row(
            children: [
              Expanded(
                child: _buildModernStatCard(
                  icon: Icons.account_balance_wallet,
                  label: 'Préstamos activos',
                  value: Helpers.formatCurrency(pendingLoanAmount),
                  subtitle: activeLoans.isEmpty
                      ? 'Sin préstamos'
                      : '${activeLoans.length} en curso',
                  color: const Color(0xFFF9A825),
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () => _showLoanDialog(employee: employee),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModernStatCard(
                  icon: Icons.task_alt,
                  label: 'Tareas pendientes',
                  value: '${pendingTasks.length}',
                  subtitle: '$inProgressTasks en progreso',
                  color: const Color(0xFF3F51B5),
                  isDark: isDark,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textMain: textMain,
                  textSub: textSub,
                  onTap: () => _showAssignTaskDialog(employee),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // === CALENDARIO DE QUINCENA DEL EMPLEADO ===
          _buildEmployeeQuincenaSection(
            employee: employee,
            isDark: isDark,
            primaryColor: primaryColor,
            cardBg: cardBg,
            borderColor: borderColor,
            textMain: textMain,
            textSub: textSub,
          ),
          const SizedBox(height: 20),

          const SizedBox(height: 20),

          // === AJUSTES RECIENTES ===
          if (adjustments.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.history, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Ajustes recientes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textMain,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...adjustments.map(
              (adj) => _buildAdjustmentCard(
                adj,
                isDark,
                cardBg,
                borderColor,
                textMain,
                textSub,
              ),
            ),
          ],
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          content,
          if (state.isTimeLoading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModernStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textMain,
    required Color textSub,
    VoidCallback? onTap,
  }) {
    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(Icons.add_circle_outline, color: color, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Text(label, style: TextStyle(fontSize: 12, color: textSub)),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textMain,
                ),
              ),
              Text(subtitle, style: TextStyle(fontSize: 11, color: textSub)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeQuincenaSection({
    required Employee employee,
    required bool isDark,
    required Color primaryColor,
    required Color cardBg,
    required Color borderColor,
    required Color textMain,
    required Color textSub,
  }) {
    final now = DateTime.now();
    final quinStart = _getQuincenaStart(now);
    final quinEnd = _getQuincenaEnd(now);

    // Quincena label
    final isFirstQ = now.day <= 15;
    final monthNames = [
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
    final quinLabel = isFirstQ ? 'Q1' : 'Q2';
    final quinTitle =
        '$quinLabel ${monthNames[quinStart.month]} ${quinStart.year}';

    // Días de la quincena
    final quinDays = <DateTime>[];
    DateTime d = quinStart;
    while (!d.isAfter(quinEnd)) {
      quinDays.add(d);
      d = d.add(const Duration(days: 1));
    }

    // Cargar datos de asistencia del empleado
    return FutureBuilder<Map<String, Map<String, int>>>(
      key: ValueKey('quincena_${employee.id}_$_quincenaRefreshKey'),
      future: _loadEmployeeQuincenaData(employee.id, quinStart, quinEnd),
      builder: (context, snapshot) {
        final dayData = snapshot.data ?? {};
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        // Contar novedades del empleado
        int totalAusencias = 0;
        int totalPermisos = 0;
        int totalIncapacidades = 0;
        for (final entry in dayData.entries) {
          totalAusencias += entry.value['ausente'] ?? 0;
          totalPermisos += entry.value['permiso'] ?? 0;
          totalIncapacidades += entry.value['incapacidad'] ?? 0;
        }
        final totalFaltas = totalAusencias + totalPermisos + totalIncapacidades;

        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, color: primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      quinTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textMain,
                      ),
                    ),
                    const Spacer(),
                    if (isLoading)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryColor,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: totalFaltas == 0
                              ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                              : const Color(0xFFF9A825).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          totalFaltas == 0
                              ? 'Asistencia completa'
                              : '$totalFaltas falta${totalFaltas > 1 ? "s" : ""}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: totalFaltas == 0
                                ? const Color(0xFF388E3C)
                                : const Color(0xFFF57C00),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Calendario — mismos headers L M X J V S D
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: ['L', 'M', 'X', 'J', 'V', 'S', 'D'].map((day) {
                    return Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: day == 'D'
                                ? const Color(0xFFE57373)
                                : const Color(0xFF9E9E9E),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 4),

              // Grid de días
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildQuincenaCalendarGrid(
                  quinDays: quinDays,
                  dayData: dayData,
                  today: now,
                  selectedDate: DateTime(1900),
                  onDayTap: (tappedDay) {
                    _showDayStatusDialog(
                      employee: employee,
                      date: tappedDay,
                      dayData: dayData,
                    );
                  },
                ),
              ),

              // Leyenda
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCalendarLegendDot(const Color(0xFF2E7D32), 'OK'),
                    const SizedBox(width: 10),
                    _buildCalendarLegendDot(const Color(0xFFC62828), 'Falta'),
                    const SizedBox(width: 10),
                    _buildCalendarLegendDot(const Color(0xFFF9A825), 'Permiso'),
                    const SizedBox(width: 10),
                    _buildCalendarLegendDot(const Color(0xFF7B1FA2), 'Incap.'),
                    const SizedBox(width: 10),
                    _buildCalendarLegendDot(const Color(0xFF9E9E9E), 'Pend.'),
                  ],
                ),
              ),

              // Resumen de novedades (solo si hay)
              if (totalFaltas > 0) ...[
                Divider(height: 1, color: borderColor),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      if (totalAusencias > 0)
                        _buildAttendanceSummaryChip(
                          Icons.cancel,
                          '$totalAusencias',
                          const Color(0xFFC62828),
                        ),
                      if (totalAusencias > 0 &&
                          (totalPermisos > 0 || totalIncapacidades > 0))
                        const SizedBox(width: 6),
                      if (totalPermisos > 0)
                        _buildAttendanceSummaryChip(
                          Icons.back_hand,
                          '$totalPermisos',
                          const Color(0xFFF9A825),
                        ),
                      if (totalPermisos > 0 && totalIncapacidades > 0)
                        const SizedBox(width: 6),
                      if (totalIncapacidades > 0)
                        _buildAttendanceSummaryChip(
                          Icons.local_hospital,
                          '$totalIncapacidades',
                          const Color(0xFF7B1FA2),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Cargar datos de asistencia de UN empleado para la quincena
  Future<Map<String, Map<String, int>>> _loadEmployeeQuincenaData(
    String employeeId,
    DateTime quinStart,
    DateTime quinEnd,
  ) async {
    final adjustments = await EmployeesDatasource.getTimeAdjustments(
      employeeId: employeeId,
      startDate: quinStart,
      endDate: quinEnd,
    );

    final Map<String, Map<String, int>> dayData = {};

    for (final adj in adjustments) {
      final dateKey = adj.adjustmentDate.toIso8601String().split('T')[0];
      dayData.putIfAbsent(
        dateKey,
        () => {'ausente': 0, 'permiso': 0, 'incapacidad': 0},
      );

      final reason = (adj.reason ?? '').toLowerCase();
      if (reason.contains('descuento dominical')) continue;

      if (reason.contains('ausencia')) {
        dayData[dateKey]!['ausente'] = (dayData[dateKey]!['ausente'] ?? 0) + 1;
      } else if (reason.contains('permiso')) {
        dayData[dateKey]!['permiso'] = (dayData[dateKey]!['permiso'] ?? 0) + 1;
      } else if (reason.contains('incapacidad')) {
        dayData[dateKey]!['incapacidad'] =
            (dayData[dateKey]!['incapacidad'] ?? 0) + 1;
      }
    }

    return dayData;
  }

  /// Diálogo para cambiar el estado de asistencia de UN empleado en UN día.
  /// Permite: Presente (OK), Ausente, Permiso, Incapacidad.
  void _showDayStatusDialog({
    required Employee employee,
    required DateTime date,
    required Map<String, Map<String, int>> dayData,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    // No permitir editar días futuros
    if (dateOnly.isAfter(today)) return;
    // No permitir editar domingos
    if (date.weekday == DateTime.sunday) return;

    final dateKey = date.toIso8601String().split('T')[0];
    final data = dayData[dateKey];
    final ausentes = data?['ausente'] ?? 0;
    final permisos = data?['permiso'] ?? 0;
    final incapacidades = data?['incapacidad'] ?? 0;

    // Determinar estado actual
    String currentStatus;
    if (ausentes > 0) {
      currentStatus = 'ausente';
    } else if (permisos > 0) {
      currentStatus = 'permiso';
    } else if (incapacidades > 0) {
      currentStatus = 'incapacidad';
    } else {
      currentStatus = 'presente';
    }

    String selectedStatus = currentStatus;

    final dayNames = ['', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final monthNames = [
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
    final dateLabel =
        '${dayNames[date.weekday]} ${date.day} ${monthNames[date.month]}';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Widget statusOption({
            required String value,
            required String label,
            required IconData icon,
            required Color color,
            String? subtitle,
          }) {
            final isSelected = selectedStatus == value;
            return InkWell(
              onTap: () => setDialogState(() => selectedStatus = value),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? color
                        : const Color(0xFF9E9E9E).withValues(alpha: 0.2),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isSelected ? color : null,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 11,
                                color: const Color(0xFF9E9E9E),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: color, size: 22),
                  ],
                ),
              ),
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.edit_calendar,
                    color: Color(0xFF1565C0),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        employee.fullName,
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF757575),
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            content: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 360, minWidth: 200),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Estado de asistencia',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9E9E9E),
                    ),
                  ),
                  const SizedBox(height: 10),
                  statusOption(
                    value: 'presente',
                    label: 'Presente',
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF2E7D32),
                    subtitle: 'Asistió normalmente',
                  ),
                  const SizedBox(height: 8),
                  statusOption(
                    value: 'ausente',
                    label: 'Ausente (Falta)',
                    icon: Icons.cancel_outlined,
                    color: const Color(0xFFC62828),
                    subtitle: 'No asistió — se descuenta día + dominical',
                  ),
                  const SizedBox(height: 8),
                  statusOption(
                    value: 'permiso',
                    label: 'Permiso',
                    icon: Icons.back_hand_outlined,
                    color: const Color(0xFFF9A825),
                    subtitle: 'Permiso autorizado — se descuenta día',
                  ),
                  const SizedBox(height: 8),
                  statusOption(
                    value: 'incapacidad',
                    label: 'Incapacidad',
                    icon: Icons.local_hospital_outlined,
                    color: const Color(0xFF7B1FA2),
                    subtitle: 'Incapacidad médica',
                  ),
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: selectedStatus == currentStatus
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await _applyDayStatusChange(
                          employee: employee,
                          date: date,
                          oldStatus: currentStatus,
                          newStatus: selectedStatus,
                        );
                      },
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Guardar'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Aplica el cambio de estado de asistencia de un empleado en un día.
  /// Primero limpia los ajustes existentes, luego crea los nuevos si aplica.
  Future<void> _applyDayStatusChange({
    required Employee employee,
    required DateTime date,
    required String oldStatus,
    required String newStatus,
  }) async {
    final dateStr = '${date.day}/${date.month}/${date.year}';
    final isSaturday = date.weekday == DateTime.saturday;
    final hoursToDeduct = isSaturday ? 5.5 : 7.7;
    final minutesToDeduct = (hoursToDeduct * 60).round();
    const domingoMinutes = 462; // 7.7h × 60

    final quinStart = _getQuincenaStart(date);
    final quinEnd = _getQuincenaEnd(date);
    final domingosTotalEnQuincena = _countSundaysInRange(quinStart, quinEnd);

    try {
      // 1) Eliminar ajustes previos de este día
      if (oldStatus != 'presente') {
        await ref
            .read(employeesProvider.notifier)
            .deleteTimeAdjustmentsForDate(employeeId: employee.id, date: date);
      }

      // 2) Si el nuevo estado no es presente, crear los ajustes correspondientes
      if (newStatus == 'ausente') {
        // Descuento del día laboral
        await ref
            .read(employeesProvider.notifier)
            .createTimeAdjustment(
              employeeId: employee.id,
              minutes: minutesToDeduct,
              type: 'deduction',
              date: date,
              reason: 'Ausencia — $dateStr | PIERDE_BONO',
            );

        // Descuento dominical si quedan domingos
        final domingosYaDescontados = await _countDomingoDeductionsInQuincena(
          employee.id,
          quinStart,
          quinEnd,
        );
        if (domingosYaDescontados < domingosTotalEnQuincena) {
          await ref
              .read(employeesProvider.notifier)
              .createTimeAdjustment(
                employeeId: employee.id,
                minutes: domingoMinutes,
                type: 'deduction',
                date: date,
                reason:
                    'Descuento dominical por ausencia — $dateStr (${domingosYaDescontados + 1}/$domingosTotalEnQuincena)',
              );
        }
      } else if (newStatus == 'permiso') {
        await ref
            .read(employeesProvider.notifier)
            .createTimeAdjustment(
              employeeId: employee.id,
              minutes: minutesToDeduct,
              type: 'deduction',
              date: date,
              reason: 'Permiso — $dateStr | PIERDE_BONO',
            );
      } else if (newStatus == 'incapacidad') {
        // Incapacidad: descuento del día (parcial según días consecutivos)
        final consecutiveDays = await _countConsecutiveIncapacityDays(
          employee.id,
          date,
        );
        final isFirstTwoDays = consecutiveDays < 2;

        if (isFirstTwoDays) {
          // Primeros 2 días: empleador paga 100%, descontar completo
          await ref
              .read(employeesProvider.notifier)
              .createTimeAdjustment(
                employeeId: employee.id,
                minutes: minutesToDeduct,
                type: 'deduction',
                date: date,
                reason:
                    'Incapacidad día ${consecutiveDays + 1} — $dateStr (empresa 100%)',
              );
        } else {
          // Día 3+: EPS paga 66.67%, descontar 33.33%
          final reducedMinutes = (minutesToDeduct * 0.3333).round();
          await ref
              .read(employeesProvider.notifier)
              .createTimeAdjustment(
                employeeId: employee.id,
                minutes: reducedMinutes,
                type: 'deduction',
                date: date,
                reason:
                    'Incapacidad día ${consecutiveDays + 1} — $dateStr (EPS 66.67%)',
              );
        }
      }

      // 3) Refrescar datos desde la BD para que dashboard y lista se actualicen
      await ref.read(employeesProvider.notifier).loadTimeOverview(employee.id);

      // 4) Refrescar calendario y UI
      if (mounted) {
        setState(() => _quincenaRefreshKey++);

        final statusLabels = {
          'presente': 'Presente ✅',
          'ausente': 'Ausente ❌',
          'permiso': 'Permiso 🟡',
          'incapacidad': 'Incapacidad 🟣',
        };

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${employee.fullName} — $dateStr → ${statusLabels[newStatus]}',
            ),
            backgroundColor: newStatus == 'presente'
                ? const Color(0xFF2E7D32)
                : newStatus == 'ausente'
                ? const Color(0xFFC62828)
                : newStatus == 'permiso'
                ? const Color(0xFFF9A825)
                : const Color(0xFF7B1FA2),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar asistencia: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    }
  }

  Widget _buildAdjustmentCard(
    EmployeeTimeAdjustment adj,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textMain,
    Color textSub,
  ) {
    final isPositive = adj.type == 'overtime';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  (isPositive
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828))
                      .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPositive ? Icons.add : Icons.remove,
              color: isPositive
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFC62828),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  adj.reason ?? (isPositive ? 'Horas extra' : 'Descuento'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: textMain,
                  ),
                ),
                Text(
                  Helpers.formatDate(adj.adjustmentDate),
                  style: TextStyle(fontSize: 11, color: textSub),
                ),
              ],
            ),
          ),
          Text(
            '${isPositive ? '+' : '-'}${(adj.minutes / 60).toStringAsFixed(1)}h',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isPositive
                  ? const Color(0xFF43A047)
                  : const Color(0xFFE53935),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateEmployeeWeekHours(Employee employee, EmployeesState state) {
    const double weeklyBase = 44.0;
    double weekHours = weeklyBase;

    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    final weekAdjustments = state.timeAdjustments
        .where((a) => a.employeeId == employee.id)
        .where(
          (a) => a.adjustmentDate.isAfter(
            startOfWeek.subtract(const Duration(days: 1)),
          ),
        )
        .toList();

    for (var adj in weekAdjustments) {
      if (adj.type == 'overtime') {
        weekHours += adj.minutes / 60.0;
      } else {
        weekHours -= adj.minutes / 60.0;
      }
    }

    if (weekHours < 0) weekHours = 0;
    return weekHours;
  }

  /// Para empleados de pago diario: cuenta los días presentes y ausentes
  /// en la semana actual (L-S).
  /// Retorna ({int daysPresent, int daysAbsent}) para saber si el bono
  /// ya se perdió (daysAbsent > 0) o aún es posible.
  ({int daysPresent, int daysAbsent}) _calculateEmployeeWeekAttendanceInfo(
    Employee employee,
    EmployeesState state,
  ) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    int daysPresent = 0;
    int daysAbsent = 0;

    // Contar L-S (weekday 1 a 6)
    for (int i = 0; i < 6; i++) {
      final day = startOfWeek.add(Duration(days: i));
      if (day.isAfter(now)) continue; // Día futuro, no contar

      // Buscar si tiene deducción de jornada completa ese día
      final dayAdjustments = state.timeAdjustments
          .where((a) => a.employeeId == employee.id)
          .where(
            (a) =>
                a.adjustmentDate.year == day.year &&
                a.adjustmentDate.month == day.month &&
                a.adjustmentDate.day == day.day,
          )
          .toList();

      // Si tiene deducción >= jornada completa (7.7h = 462 min aprox), no vino
      final totalDeduction = dayAdjustments
          .where((a) => a.type == 'deduction')
          .fold(0.0, (sum, a) => sum + a.minutes);

      if (totalDeduction < 400) {
        // Menos de ~6.7h deducidas → vino a trabajar
        daysPresent++;
      } else {
        daysAbsent++;
      }
    }
    return (daysPresent: daysPresent, daysAbsent: daysAbsent);
  }

  Widget _buildDashboardPlaceholder(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = const Color(0xFF137FEC);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF617589);

    return Container(
      margin: const EdgeInsets.only(right: 16, bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101922) : const Color(0xFFF6F7F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_search, size: 64, color: primaryColor),
            ),
            const SizedBox(height: 20),
            Text(
              'Selecciona un empleado',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF111418),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Haz clic en un empleado de la lista para\nver su información y gestionar sus horas',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: textSub),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          hint: Text(hint),
        ),
      ),
    );
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '--:--';
    final local = dateTime.toLocal();
    final hours = local.hour.toString().padLeft(2, '0');
    final minutes = local.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF757575),
            ),
            textAlign: TextAlign.center,
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // ========== DIÁLOGOS ==========

  void _showEmployeeDialog({Employee? employee}) {
    final isEditing = employee != null;
    final firstNameController = TextEditingController(
      text: employee?.firstName ?? '',
    );
    final lastNameController = TextEditingController(
      text: employee?.lastName ?? '',
    );
    final positionController = TextEditingController(
      text: employee?.position ?? '',
    );
    final phoneController = TextEditingController(text: employee?.phone ?? '');
    final emailController = TextEditingController(text: employee?.email ?? '');
    final salaryController = TextEditingController(
      text: employee?.salary != null
          ? employee!.salary!.toStringAsFixed(0)
          : '',
    );
    final dailyRateController = TextEditingController(
      text: (employee?.dailyRate ?? 0) > 0
          ? employee!.dailyRate.toStringAsFixed(0)
          : '',
    );
    String selectedDepartment = employee?.department ?? 'Producción';
    EmployeeStatus selectedStatus = employee?.status ?? EmployeeStatus.activo;
    // 'daily' = pago por día · 'hourly' = pago por horas/mensual
    String selectedPayType = employee?.payType ?? 'hourly';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                isEditing ? Icons.edit : Icons.person_add,
                size: 22,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Text(isEditing ? 'Editar Empleado' : 'Nuevo Empleado'),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 520, minWidth: 200),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Nombres ──────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: firstNameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: lastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Apellido *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: positionController,
                    decoration: const InputDecoration(
                      labelText: 'Cargo *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── Departamento + Estado ─────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedDepartment,
                          decoration: const InputDecoration(
                            labelText: 'Departamento',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Producción',
                              child: Text('Producción'),
                            ),
                            DropdownMenuItem(
                              value: 'Ventas',
                              child: Text('Ventas'),
                            ),
                            DropdownMenuItem(
                              value: 'Administración',
                              child: Text('Administración'),
                            ),
                            DropdownMenuItem(
                              value: 'Mantenimiento',
                              child: Text('Mantenimiento'),
                            ),
                            DropdownMenuItem(
                              value: 'Logística',
                              child: Text('Logística'),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() => selectedDepartment = value!);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<EmployeeStatus>(
                          value: selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Estado',
                            border: OutlineInputBorder(),
                          ),
                          items: EmployeeStatus.values.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Text(
                                status.name[0].toUpperCase() +
                                    status.name.substring(1),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() => selectedStatus = value!);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ── Contacto ──────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // ── Tipo de pago ──────────────────────────────
                  const Text(
                    'Tipo de pago',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF757575),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _payTypeOption(
                          setDialogState,
                          label: 'Mensual / Por horas',
                          icon: Icons.calendar_month,
                          value: 'hourly',
                          selected: selectedPayType,
                          onTap: () =>
                              setDialogState(() => selectedPayType = 'hourly'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _payTypeOption(
                          setDialogState,
                          label: 'Por día (Jornal)',
                          icon: Icons.today,
                          value: 'daily',
                          selected: selectedPayType,
                          onTap: () =>
                              setDialogState(() => selectedPayType = 'daily'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ── Salario según tipo ────────────────────────
                  if (selectedPayType == 'daily') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFE082)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.today,
                                size: 16,
                                color: Color(0xFFF9A825),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'PAGO DIARIO (JORNAL)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF9A825),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: dailyRateController,
                            decoration: const InputDecoration(
                              labelText: 'Valor por día *',
                              helperText:
                                  'Cuánto gana este empleado por cada día trabajado',
                              border: OutlineInputBorder(),
                              prefixText: '\$ ',
                              suffixText: '/ día',
                            ),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: salaryController,
                      decoration: const InputDecoration(
                        labelText: 'Salario mensual',
                        border: OutlineInputBorder(),
                        prefixText: '\$ ',
                        suffixText: '/ mes',
                      ),
                      keyboardType: TextInputType.number,
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
            FilledButton(
              onPressed: () async {
                if (firstNameController.text.isEmpty ||
                    lastNameController.text.isEmpty ||
                    positionController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Completa los campos obligatorios'),
                    ),
                  );
                  return;
                }

                if (selectedPayType == 'daily' &&
                    (dailyRateController.text.isEmpty ||
                        (double.tryParse(dailyRateController.text) ?? 0) <=
                            0)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ingresa el valor por día'),
                      backgroundColor: Color(0xFFF9A825),
                    ),
                  );
                  return;
                }

                final newDailyRate =
                    double.tryParse(dailyRateController.text) ?? 0;
                final newSalary = double.tryParse(salaryController.text);

                final newEmployee = Employee(
                  id: employee?.id ?? '',
                  firstName: firstNameController.text.trim(),
                  lastName: lastNameController.text.trim(),
                  position: positionController.text.trim(),
                  department: selectedDepartment,
                  phone: phoneController.text.isEmpty
                      ? null
                      : phoneController.text,
                  email: emailController.text.isEmpty
                      ? null
                      : emailController.text,
                  salary: selectedPayType == 'daily'
                      ? (newDailyRate * 30) // estimado mensual
                      : newSalary,
                  payType: selectedPayType,
                  dailyRate: selectedPayType == 'daily' ? newDailyRate : 0,
                  // preservar campos que no se editan aquí
                  salaryType: employee?.salaryType ?? 'mensual',
                  attendanceBonus: employee?.attendanceBonus ?? 0,
                  attendanceBonusDays: employee?.attendanceBonusDays ?? 6,
                  workSchedule: employee?.workSchedule ?? 'tiempo_completo',
                  status: selectedStatus,
                  hireDate: employee?.hireDate ?? DateTime.now(),
                  documentType: employee?.documentType,
                  documentNumber: employee?.documentNumber,
                  address: employee?.address,
                  bloodType: employee?.bloodType,
                  photoUrl: employee?.photoUrl,
                  notes: employee?.notes,
                  emergencyContact: employee?.emergencyContact,
                  emergencyPhone: employee?.emergencyPhone,
                  createdAt: employee?.createdAt ?? DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                Navigator.pop(context);

                if (isEditing) {
                  await ref
                      .read(employeesProvider.notifier)
                      .updateEmployee(newEmployee);
                } else {
                  await ref
                      .read(employeesProvider.notifier)
                      .createEmployee(newEmployee);
                }
              },
              child: Text(isEditing ? 'Guardar' : 'Crear'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _payTypeOption(
    StateSetter setDialogState, {
    required String label,
    required IconData icon,
    required String value,
    required String selected,
    required VoidCallback onTap,
  }) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : const Color(0xFFE0E0E0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : const Color(0xFF9E9E9E),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : const Color(0xFF424242),
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  IconData _getTaskCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'produccion':
        return Icons.precision_manufacturing;
      case 'mantenimiento':
        return Icons.build;
      case 'limpieza':
        return Icons.cleaning_services;
      case 'logistica':
        return Icons.local_shipping;
      case 'administrativo':
        return Icons.description;
      default:
        return Icons.task;
    }
  }

  void _showAssignTaskDialog(Employee employee) {
    final state = ref.read(employeesProvider);
    // Filtrar tareas sin asignar o que pueden ser reasignadas
    final availableTasks = state.tasks
        .where((t) => t.status != TaskStatus.completada)
        .toList();

    if (availableTasks.isEmpty) {
      // Cerrar cualquier SnackBar anterior
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No hay tareas disponibles. Crea una primero en la pestaña de Tareas.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.assignment_ind,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Asignar Tarea'),
                      Text(
                        'a ${employee.fullName}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: const Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 500, minWidth: 200),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selecciona una tarea para asignar:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF616161),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: availableTasks.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final task = availableTasks[index];
                        final isAssignedToOther =
                            task.employeeId != employee.id;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: task.priorityColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getTaskCategoryIcon(task.category),
                              color: task.priorityColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            task.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (task.description != null)
                                Text(
                                  task.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xFF9E9E9E),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: task.statusColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      task.statusLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: task.statusColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isAssignedToOther)
                                    Text(
                                      'Asignada a: ${task.employeeName}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: const Color(0xFFF9A825),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          trailing: FilledButton(
                            onPressed: () async {
                              Navigator.pop(context);

                              final updatedTask = EmployeeTask(
                                id: task.id,
                                employeeId: employee.id,
                                employeeName: employee.fullName,
                                title: task.title,
                                description: task.description,
                                assignedDate: DateTime.now(),
                                dueDate: task.dueDate,
                                status: task.status,
                                priority: task.priority,
                                category: task.category,
                                createdAt: task.createdAt,
                                updatedAt: DateTime.now(),
                              );

                              await ref
                                  .read(employeesProvider.notifier)
                                  .updateTask(updatedTask);

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Tarea "${task.title}" asignada a ${employee.fullName}',
                                    ),
                                    backgroundColor: const Color(0xFF2E7D32),
                                  ),
                                );
                              }
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: const Text('Asignar'),
                          ),
                        );
                      },
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
            ],
          );
        },
      ),
    );
  }

  void _showEmployeeDetail(Employee employee) {
    ref.read(employeesProvider.notifier).selectEmployee(employee);
    int selectedDayIndex = (DateTime.now().weekday - 1).clamp(
      0,
      5,
    ); // 0=Lunes, 5=Sábado

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final state = ref.read(employeesProvider);
          final payrollState = ref.read(payrollProvider);
          final allTasks = state.selectedEmployeeTasks;
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          final borderColor = isDark
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0);

          // Préstamos activos del empleado
          final employeeLoans = payrollState.loans
              .where((l) => l.employeeId == employee.id && l.status == 'activo')
              .toList();

          final now = DateTime.now();
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

          // Días de la semana (sin domingo)
          final dayNames = ['L', 'M', 'X', 'J', 'V', 'S'];
          final dayFullNames = [
            'Lunes',
            'Martes',
            'Miércoles',
            'Jueves',
            'Viernes',
            'Sábado',
          ];

          // Horario: L-V 7:30-12:00 y 1:00-4:30, Sáb 7:30-1:00 = 44h semanales
          const double weekdayBase = 7.7; // (44 - 5.5) / 5
          const double saturdayBase = 5.5; // Sábado
          Map<int, double> hoursByDay = {};
          Map<int, DateTime> datesByDay = {};

          for (int i = 0; i < 6; i++) {
            final dayDate = startOfWeek.add(Duration(days: i));
            datesByDay[i] = dayDate;

            final dayAdjustments = state.timeAdjustments
                .where((a) => a.employeeId == employee.id)
                .where(
                  (a) =>
                      a.adjustmentDate.year == dayDate.year &&
                      a.adjustmentDate.month == dayDate.month &&
                      a.adjustmentDate.day == dayDate.day,
                )
                .toList();

            // i=5 es sábado, usar saturdayBase, sino weekdayBase
            double dayHours = (i == 5) ? saturdayBase : weekdayBase;
            for (var adj in dayAdjustments) {
              if (adj.type == 'overtime') {
                dayHours += adj.minutes / 60.0;
              } else {
                dayHours -= adj.minutes / 60.0;
              }
            }
            hoursByDay[i] = dayHours.clamp(0.0, 24.0);
          }

          // Total semanal
          final totalWeekHours = hoursByDay.values.fold(0.0, (a, b) => a + b);
          const weeklyBase = 44.0; // 44h semanales
          final progress = (totalWeekHours / weeklyBase).clamp(0.0, 1.0);
          final isOvertime = totalWeekHours > weeklyBase;
          final isUndertime = totalWeekHours < weeklyBase;

          // Día seleccionado
          final selectedDate = datesByDay[selectedDayIndex] ?? now;
          final isSelectedToday =
              selectedDayIndex == (now.weekday - 1) && now.weekday <= 6;
          final isSelectedFuture = selectedDate.isAfter(
            DateTime(now.year, now.month, now.day),
          );

          // Filtrar tareas del día seleccionado
          final dayTasks = allTasks.where((t) {
            if (t.dueDate == null) return false;
            return t.dueDate!.year == selectedDate.year &&
                t.dueDate!.month == selectedDate.month &&
                t.dueDate!.day == selectedDate.day;
          }).toList();

          return AlertDialog(
            title: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.1,
                  ),
                  child: Text(
                    employee.initials,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(employee.fullName),
                      Text(employee.position, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 600, minWidth: 200),
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Columna izquierda - Info personal y tareas del día
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Información Personal',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF757575),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              children: [
                                _buildInfoRow(
                                  Icons.business,
                                  'Depto',
                                  employee.department ?? 'N/A',
                                ),
                                _buildInfoRow(
                                  Icons.phone,
                                  'Tel',
                                  employee.phone ?? 'N/A',
                                ),
                                _buildInfoRow(
                                  Icons.email,
                                  'Email',
                                  employee.email ?? 'N/A',
                                ),
                                _buildInfoRow(
                                  Icons.calendar_today,
                                  'Ingreso',
                                  _formatDate(employee.hireDate),
                                ),
                                _buildInfoRow(
                                  Icons.nfc,
                                  'NFC',
                                  employee.nfcCardId ?? 'Sin asignar',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Tareas del día seleccionado
                          Text(
                            '${dayFullNames[selectedDayIndex]} ${selectedDate.day}/${selectedDate.month} - Tareas (${dayTasks.length})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF757575),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 140,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: dayTasks.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isSelectedFuture
                                              ? Icons.event_note
                                              : Icons.check_circle_outline,
                                          size: 24,
                                          color: const Color(0xFFBDBDBD),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isSelectedFuture
                                              ? 'Sin tareas programadas'
                                              : isSelectedToday
                                              ? 'Sin tareas hoy'
                                              : 'Sin tareas registradas',
                                          style: TextStyle(
                                            color: const Color(0xFF9E9E9E),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(8),
                                    itemCount: dayTasks.length,
                                    itemBuilder: (context, index) {
                                      final task = dayTasks[index];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 2,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              task.status ==
                                                      TaskStatus.completada
                                                  ? Icons.check_circle
                                                  : task.status ==
                                                        TaskStatus.enProgreso
                                                  ? Icons.play_circle
                                                  : Icons.pending,
                                              color: task.statusColor,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                task.title,
                                                style: TextStyle(fontSize: 12),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          // Sección de préstamos activos
                          if (employeeLoans.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Préstamos Activos (${employeeLoans.length})',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFF57C00),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFF9A825,
                                ).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(
                                    0xFFF9A825,
                                  ).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                children: employeeLoans
                                    .map(
                                      (loan) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  Helpers.formatCurrency(
                                                    loan.totalAmount,
                                                  ),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                Text(
                                                  'Cuota ${loan.paidInstallments + 1}/${loan.installments} • ${Helpers.formatCurrency(loan.installmentAmount)}/mes',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: const Color(
                                                      0xFF757575,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'Pendiente',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: const Color(
                                                      0xFF9E9E9E,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  Helpers.formatCurrency(
                                                    loan.remainingAmount,
                                                  ),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(
                                                      0xFFF57C00,
                                                    ),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Columna derecha - Horas trabajadas
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Horas Semana',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF757575),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              children: [
                                // Total y progreso
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${totalWeekHours.toStringAsFixed(1)}h',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            color: isOvertime
                                                ? const Color(0xFF2E7D32)
                                                : isUndertime
                                                ? const Color(0xFFF9A825)
                                                : theme.colorScheme.primary,
                                          ),
                                        ),
                                        Text(
                                          'de 44h',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: const Color(0xFF9E9E9E),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox(
                                          width: 50,
                                          height: 50,
                                          child: CircularProgressIndicator(
                                            value: progress,
                                            strokeWidth: 5,
                                            backgroundColor: const Color(
                                              0xFFE0E0E0,
                                            ),
                                            color: isOvertime
                                                ? const Color(0xFF2E7D32)
                                                : isUndertime
                                                ? const Color(0xFFF9A825)
                                                : theme.colorScheme.primary,
                                          ),
                                        ),
                                        Text(
                                          '${(progress * 100).toInt()}%',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 12),
                                // Botones +/- 0.5 hora para el día seleccionado
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _addHoursForDay(
                                          employee,
                                          -0.5,
                                          selectedDate,
                                        ),
                                        icon: const Icon(
                                          Icons.remove,
                                          size: 18,
                                        ),
                                        label: const Text('0.5h'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFFC62828,
                                          ),
                                          side: const BorderSide(
                                            color: Color(0xFFC62828),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () => _addHoursForDay(
                                          employee,
                                          0.5,
                                          selectedDate,
                                        ),
                                        icon: const Icon(Icons.add, size: 18),
                                        label: const Text('0.5h'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF2E7D32,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Días clickeables (sin domingo)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: dayNames.asMap().entries.map((e) {
                                final dayIndex = e.key;
                                final baseForDay = (dayIndex == 5)
                                    ? saturdayBase
                                    : weekdayBase;
                                final hours =
                                    hoursByDay[dayIndex] ?? baseForDay;
                                final isToday =
                                    dayIndex == (now.weekday - 1) &&
                                    now.weekday <= 6;
                                final isSelected = dayIndex == selectedDayIndex;
                                final hasExtra = hours > baseForDay;
                                final hasDeduction = hours < baseForDay;

                                return GestureDetector(
                                  onTap: () => setDialogState(
                                    () => selectedDayIndex = dayIndex,
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        e.value,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                              : const Color(0xFF9E9E9E),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 150,
                                        ),
                                        width: isSelected ? 36 : 28,
                                        height: isSelected ? 36 : 28,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                                    .withValues(alpha: 0.15)
                                              : hasExtra
                                              ? const Color(
                                                  0xFF2E7D32,
                                                ).withValues(alpha: 0.1)
                                              : hasDeduction
                                              ? const Color(
                                                  0xFFF9A825,
                                                ).withValues(alpha: 0.1)
                                              : const Color(0xFFEEEEEE),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                : isToday
                                                ? theme.colorScheme.primary
                                                      .withValues(alpha: 0.5)
                                                : Colors.transparent,
                                            width: isSelected ? 2 : 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            hours.toStringAsFixed(0),
                                            style: TextStyle(
                                              fontSize: isSelected ? 12 : 11,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected
                                                  ? theme.colorScheme.primary
                                                  : hasExtra
                                                  ? const Color(0xFF388E3C)
                                                  : hasDeduction
                                                  ? const Color(0xFFF57C00)
                                                  : const Color(0xFF757575),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
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
                child: const Text('Cerrar'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showAdelantoDialog(employee);
                },
                icon: const Icon(Icons.money, size: 18),
                label: const Text('Adelanto'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7B1FA2),
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showAssignTaskDialog(employee);
                },
                icon: const Icon(Icons.add_task, size: 18),
                label: const Text('Asignar tarea'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Método para agregar horas a un día específico
  void _addHoursForDay(Employee employee, double hours, DateTime date) async {
    final minutes = (hours * 60).round();
    final type = hours > 0 ? 'overtime' : 'deduction';

    try {
      await ref
          .read(employeesProvider.notifier)
          .createTimeAdjustment(
            employeeId: employee.id,
            minutes: minutes.abs(),
            type: type,
            date: date,
            reason: hours > 0
                ? 'Hora extra - ${date.day}/${date.month}'
                : 'Descuento - ${date.day}/${date.month}',
          );

      await ref.read(employeesProvider.notifier).loadTimeOverview(employee.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hours > 0
                  ? '✅ +${hours}h añadida al ${date.day}/${date.month}'
                  : '✅ ${hours}h descontada del ${date.day}/${date.month}',
            ),
            backgroundColor: hours > 0
                ? const Color(0xFF2E7D32)
                : const Color(0xFFF9A825),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    }
  }

  void _addHours(Employee employee, double hours) async {
    // Mostrar diálogo para elegir fecha (hoy o pasada)
    final now = DateTime.now();
    DateTime selectedDate = now;
    final hoursCtrl = TextEditingController(text: hours.abs().toString());
    final isPositive = hours > 0;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isPositive ? Icons.more_time : Icons.timer_off,
                  color: isPositive
                      ? const Color(0xFF388E3C)
                      : const Color(0xFFC62828),
                ),
                const SizedBox(width: 8),
                Text(isPositive ? 'Agregar Horas Extra' : 'Descontar Horas'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: hoursCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: isPositive ? 'Horas extra' : 'Horas a descontar',
                    prefixIcon: const Icon(Icons.timer),
                    helperText: 'Ej: 1.5 = 1h 30min',
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: now.subtract(const Duration(days: 60)),
                      lastDate: now,
                      locale: const Locale('es', 'CO'),
                    );
                    if (picked != null) {
                      setDlgState(() => selectedDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Fecha',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${selectedDate.day}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                        ),
                        if (selectedDate.day == now.day &&
                            selectedDate.month == now.month &&
                            selectedDate.year == now.year)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF1B4F72,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Hoy',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1B4F72),
                              ),
                            ),
                          ),
                      ],
                    ),
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
                onPressed: () {
                  final h = double.tryParse(hoursCtrl.text.trim());
                  if (h != null && h > 0) {
                    Navigator.pop(ctx, {'hours': h, 'date': selectedDate});
                  }
                },
                icon: Icon(isPositive ? Icons.add : Icons.remove, size: 18),
                label: Text(isPositive ? 'Agregar' : 'Descontar'),
                style: FilledButton.styleFrom(
                  backgroundColor: isPositive
                      ? const Color(0xFF388E3C)
                      : const Color(0xFFC62828),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return;

    final finalHours = result['hours'] as double;
    final finalDate = result['date'] as DateTime;
    final minutes = (finalHours * 60).round();
    final type = isPositive ? 'overtime' : 'deduction';

    try {
      await ref
          .read(employeesProvider.notifier)
          .createTimeAdjustment(
            employeeId: employee.id,
            minutes: minutes,
            type: type,
            date: finalDate,
            reason: isPositive
                ? 'Hora extra manual - ${finalDate.day}/${finalDate.month.toString().padLeft(2, '0')}'
                : 'Descuento manual - ${finalDate.day}/${finalDate.month.toString().padLeft(2, '0')}',
          );

      // Recargar datos del empleado
      await ref.read(employeesProvider.notifier).loadTimeOverview(employee.id);

      if (mounted) {
        final dateLabel =
            (finalDate.day == now.day &&
                finalDate.month == now.month &&
                finalDate.year == now.year)
            ? 'hoy'
            : '${finalDate.day}/${finalDate.month.toString().padLeft(2, '0')}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPositive
                  ? '✅ +${finalHours}h añadida a ${employee.firstName} ($dateLabel)'
                  : '✅ -${finalHours}h descontada de ${employee.firstName} ($dateLabel)',
            ),
            backgroundColor: isPositive
                ? const Color(0xFF2E7D32)
                : const Color(0xFFF9A825),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    }
  }

  // ========== ASISTENCIA INVERSA ==========
  /// Diálogo de asistencia con calendario de quincena integrado.
  /// Muestra el historial de la quincena actual y permite pasar lista.
  /// Estados: 'presente', 'ausente', 'permiso', 'incapacidad'
  void _showAttendanceDialog({DateTime? initialDate}) async {
    final empState = ref.read(employeesProvider);
    final activeEmployees = empState.activeEmployees;

    if (activeEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay empleados activos'),
          backgroundColor: Color(0xFFF9A825),
        ),
      );
      return;
    }

    // Todos presentes por defecto
    final attendance = <String, String>{};
    for (final emp in activeEmployees) {
      attendance[emp.id] = 'presente';
    }

    // Mapa de incapacidades/permisos nuevos registrados en esta sesión
    // key=employeeId, value={type, startDate, endDate, days, diagnosis}
    final incapacityRecords = <String, Map<String, dynamic>>{};

    DateTime selectedDate = initialDate ?? DateTime.now();
    final now = DateTime.now();
    final quinStart = _getQuincenaStart(now);
    final quinEnd = _getQuincenaEnd(now);

    // Cargar incapacidades activas para auto-marcar
    final payrollSt = ref.read(payrollProvider);
    final activeIncapacities = payrollSt.activeIncapacities;

    // Auto-marcar empleados con incapacidad activa que cubra selectedDate
    void autoMarkIncapacities(DateTime forDate) {
      for (final inc in activeIncapacities) {
        final dateOnly = DateTime(forDate.year, forDate.month, forDate.day);
        final startOnly = DateTime(
          inc.startDate.year,
          inc.startDate.month,
          inc.startDate.day,
        );
        final endOnly = DateTime(
          inc.endDate.year,
          inc.endDate.month,
          inc.endDate.day,
        );
        if (!dateOnly.isBefore(startOnly) && !dateOnly.isAfter(endOnly)) {
          // Esta incapacidad cubre la fecha seleccionada
          if (inc.type == 'permiso') {
            attendance[inc.employeeId] = 'permiso';
          } else {
            attendance[inc.employeeId] = 'incapacidad';
          }
        }
      }
    }

    autoMarkIncapacities(selectedDate);

    // Cargar historial de la quincena
    Map<String, Map<String, int>> dayData = {};
    try {
      final adjustments = await EmployeesDatasource.getAllAdjustmentsInRange(
        startDate: quinStart,
        endDate: quinEnd,
      );
      for (final adj in adjustments) {
        final dateKey = adj.adjustmentDate.toIso8601String().split('T')[0];
        dayData.putIfAbsent(
          dateKey,
          () => {'ausente': 0, 'permiso': 0, 'incapacidad': 0},
        );
        final reason = (adj.reason ?? '').toLowerCase();
        if (reason.contains('descuento dominical')) continue;
        if (reason.contains('ausencia')) {
          dayData[dateKey]!['ausente'] =
              (dayData[dateKey]!['ausente'] ?? 0) + 1;
        } else if (reason.contains('permiso')) {
          dayData[dateKey]!['permiso'] =
              (dayData[dateKey]!['permiso'] ?? 0) + 1;
        } else if (reason.contains('incapacidad')) {
          dayData[dateKey]!['incapacidad'] =
              (dayData[dateKey]!['incapacidad'] ?? 0) + 1;
        }
      }
    } catch (_) {}

    // Días de la quincena
    final quinDays = <DateTime>[];
    DateTime d = quinStart;
    while (!d.isAfter(quinEnd)) {
      quinDays.add(d);
      d = d.add(const Duration(days: 1));
    }

    final monthNames = [
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
    final quinLabel = quinStart.day <= 15 ? '1ra Quincena' : '2da Quincena';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final presentCount = attendance.values
              .where((v) => v == 'presente')
              .length;
          final absentCount = attendance.values
              .where((v) => v == 'ausente')
              .length;
          final permisoCount = attendance.values
              .where((v) => v == 'permiso')
              .length;
          final incapacidadCount = attendance.values
              .where((v) => v == 'incapacidad')
              .length;
          final isSaturday = selectedDate.weekday == DateTime.saturday;
          final isSunday = selectedDate.weekday == DateTime.sunday;
          final dayNames = [
            '',
            'Lunes',
            'Martes',
            'Miércoles',
            'Jueves',
            'Viernes',
            'Sábado',
            'Domingo',
          ];
          final dayLabel = dayNames[selectedDate.weekday];
          final hoursToDeduct = isSaturday ? 5.5 : 7.7;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540, maxHeight: 750),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // === HEADER ===
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2E7D32,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.fact_check,
                            color: Color(0xFF2E7D32),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pasar Lista',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$dayLabel ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFF757575),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Quincena label
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF1565C0,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$quinLabel ${monthNames[quinStart.month]}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, size: 20),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),

                  // === CALENDARIO DE QUINCENA ===
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9E9E9E).withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF9E9E9E).withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Días de la semana header
                        Row(
                          children: ['L', 'M', 'X', 'J', 'V', 'S', 'D'].map((
                            day,
                          ) {
                            return Expanded(
                              child: Center(
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    color: day == 'D'
                                        ? const Color(0xFFE57373)
                                        : const Color(0xFF9E9E9E),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 2),
                        // Grilla de días
                        _buildQuincenaCalendarGrid(
                          quinDays: quinDays,
                          dayData: dayData,
                          today: now,
                          selectedDate: selectedDate,
                          onDayTap: (tappedDate) {
                            setDialogState(() {
                              selectedDate = tappedDate;
                              // Reset attendance al cambiar de día
                              for (final emp in activeEmployees) {
                                attendance[emp.id] = 'presente';
                              }
                              // Re-aplicar incapacidades activas para este día
                              autoMarkIncapacities(tappedDate);
                            });
                          },
                        ),
                        // Leyenda compacta
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildCalendarLegendDot(
                              const Color(0xFF2E7D32),
                              'OK',
                            ),
                            const SizedBox(width: 6),
                            _buildCalendarLegendDot(
                              const Color(0xFFC62828),
                              'Falta',
                            ),
                            const SizedBox(width: 6),
                            _buildCalendarLegendDot(
                              const Color(0xFFF9A825),
                              'Permiso',
                            ),
                            const SizedBox(width: 6),
                            _buildCalendarLegendDot(
                              const Color(0xFF7B1FA2),
                              'Incap.',
                            ),
                            const SizedBox(width: 6),
                            _buildCalendarLegendDot(
                              const Color(0xFFE0E0E0),
                              'Pend.',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  const Divider(height: 1),
                  // === CONTENIDO SCROLLABLE ===
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Resumen compacto
                          Row(
                            children: [
                              _buildAttendanceSummaryChip(
                                Icons.check_circle,
                                '$presentCount',
                                const Color(0xFF2E7D32),
                              ),
                              const SizedBox(width: 4),
                              _buildAttendanceSummaryChip(
                                Icons.cancel,
                                '$absentCount',
                                absentCount > 0
                                    ? const Color(0xFFC62828)
                                    : const Color(0xFF9E9E9E),
                              ),
                              const SizedBox(width: 4),
                              _buildAttendanceSummaryChip(
                                Icons.event_busy,
                                '$permisoCount',
                                permisoCount > 0
                                    ? const Color(0xFFF9A825)
                                    : const Color(0xFF9E9E9E),
                              ),
                              const SizedBox(width: 4),
                              _buildAttendanceSummaryChip(
                                Icons.local_hospital,
                                '$incapacidadCount',
                                incapacidadCount > 0
                                    ? const Color(0xFF7B1FA2)
                                    : const Color(0xFF9E9E9E),
                              ),
                            ],
                          ),
                          if (isSunday) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFF9A825,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber,
                                    color: Color(0xFFF9A825),
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Domingo — día de descanso',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFF9A825),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          const Divider(height: 1),
                          // Lista de empleados
                          ...activeEmployees.map((emp) {
                            final status = attendance[emp.id] ?? 'presente';
                            final isPresent = status == 'presente';
                            final statusColor = _attendanceStatusColor(status);

                            // Buscar si tiene incapacidad/permiso activo
                            final activeInc = activeIncapacities.where((inc) {
                              final dateOnly = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                              );
                              final startOnly = DateTime(
                                inc.startDate.year,
                                inc.startDate.month,
                                inc.startDate.day,
                              );
                              final endOnly = DateTime(
                                inc.endDate.year,
                                inc.endDate.month,
                                inc.endDate.day,
                              );
                              return inc.employeeId == emp.id &&
                                  !dateOnly.isBefore(startOnly) &&
                                  !dateOnly.isAfter(endOnly);
                            }).toList();
                            final hasActiveInc = activeInc.isNotEmpty;
                            // Info del record nuevo registrado en esta sesión
                            final newRecord = incapacityRecords[emp.id];

                            return Container(
                              decoration: BoxDecoration(
                                color: isPresent
                                    ? Colors.transparent
                                    : statusColor.withValues(alpha: 0.03),
                                border: Border(
                                  bottom: BorderSide(
                                    color: const Color(
                                      0xFF9E9E9E,
                                    ).withValues(alpha: 0.1),
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                  horizontal: 2,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: statusColor.withValues(
                                        alpha: 0.1,
                                      ),
                                      backgroundImage: emp.photoUrl != null
                                          ? NetworkImage(emp.photoUrl!)
                                          : null,
                                      child: emp.photoUrl == null
                                          ? Text(
                                              emp.initials,
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: statusColor,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            emp.fullName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                              decoration: status == 'ausente'
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                              color: isPresent
                                                  ? null
                                                  : statusColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (hasActiveInc) ...[
                                            Text(
                                              '${activeInc.first.type == 'permiso' ? '🟠 Permiso' : '🟣 Incapacidad'} hasta ${activeInc.first.endDate.day}/${activeInc.first.endDate.month}',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color:
                                                    activeInc.first.type ==
                                                        'permiso'
                                                    ? const Color(0xFFF57C00)
                                                    : const Color(0xFF7B1FA2),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ] else if (newRecord != null) ...[
                                            Text(
                                              '${status == 'permiso' ? '🟠 Permiso' : '🟣 Incap.'} ${(newRecord['days'] as int)} día${(newRecord['days'] as int) > 1 ? "s" : ""} → hasta ${(newRecord['endDate'] as DateTime).day}/${(newRecord['endDate'] as DateTime).month}',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: status == 'permiso'
                                                    ? const Color(0xFFF57C00)
                                                    : const Color(0xFF7B1FA2),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    _buildAttendanceStatusButton(
                                      icon: Icons.check_circle,
                                      color: const Color(0xFF2E7D32),
                                      isActive: status == 'presente',
                                      tooltip: 'Presente',
                                      onTap: () => setDialogState(
                                        () => attendance[emp.id] = 'presente',
                                      ),
                                    ),
                                    _buildAttendanceStatusButton(
                                      icon: Icons.cancel,
                                      color: const Color(0xFFC62828),
                                      isActive: status == 'ausente',
                                      tooltip: 'Ausente',
                                      onTap: () => setDialogState(
                                        () => attendance[emp.id] = 'ausente',
                                      ),
                                    ),
                                    _buildAttendanceStatusButton(
                                      icon: Icons.event_busy,
                                      color: const Color(0xFFF9A825),
                                      isActive: status == 'permiso',
                                      tooltip: 'Permiso',
                                      onTap: () async {
                                        // Preguntar duración del permiso
                                        final result =
                                            await _showAbsenceDurationDialog(
                                              context: context,
                                              employeeName: emp.fullName,
                                              isPermiso: true,
                                              initialDate: selectedDate,
                                            );
                                        if (result != null) {
                                          setDialogState(() {
                                            attendance[emp.id] = 'permiso';
                                            incapacityRecords[emp.id] = {
                                              'type': 'permiso',
                                              'startDate': result['startDate'],
                                              'endDate': result['endDate'],
                                              'days': result['days'],
                                              'diagnosis': result['reason'],
                                            };
                                          });
                                        }
                                      },
                                    ),
                                    _buildAttendanceStatusButton(
                                      icon: Icons.local_hospital,
                                      color: const Color(0xFF7B1FA2),
                                      isActive: status == 'incapacidad',
                                      tooltip: 'Incapacidad',
                                      onTap: () async {
                                        // Preguntar duración de la incapacidad
                                        final result =
                                            await _showAbsenceDurationDialog(
                                              context: context,
                                              employeeName: emp.fullName,
                                              isPermiso: false,
                                              initialDate: selectedDate,
                                            );
                                        if (result != null) {
                                          setDialogState(() {
                                            attendance[emp.id] = 'incapacidad';
                                            incapacityRecords[emp.id] = {
                                              'type': result['type'],
                                              'startDate': result['startDate'],
                                              'endDate': result['endDate'],
                                              'days': result['days'],
                                              'diagnosis': result['reason'],
                                            };
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          if ((absentCount + permisoCount + incapacidadCount) >
                                  0 &&
                              !isSunday) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFF9A825,
                                ).withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (absentCount > 0)
                                    Text(
                                      '• Ausencia: ${hoursToDeduct}h + domingo 15na + pierde bono',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFFC62828),
                                      ),
                                    ),
                                  if (permisoCount > 0)
                                    Text(
                                      '• Permiso: ${hoursToDeduct}h + pierde bono',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFFF9A825),
                                      ),
                                    ),
                                  if (incapacidadCount > 0)
                                    Text(
                                      '• Incapacidad: días 1-3=100%, 4+=66.33%',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF7B1FA2),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ),
                  // === FOOTER ===
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            // 1) Registrar incapacidades/permisos nuevos en la tabla
                            for (final entry in incapacityRecords.entries) {
                              final empId = entry.key;
                              final data = entry.value;
                              try {
                                final incapacity = EmployeeIncapacity(
                                  id: '',
                                  employeeId: empId,
                                  type: data['type'] as String,
                                  startDate: data['startDate'] as DateTime,
                                  endDate: data['endDate'] as DateTime,
                                  daysTotal: data['days'] as int,
                                  diagnosis: data['diagnosis'] as String?,
                                  paymentPercentage: data['type'] == 'permiso'
                                      ? 0
                                      : (data['type'] == 'accidente_laboral'
                                            ? 100
                                            : 66.67),
                                  status: 'activa',
                                );
                                await ref
                                    .read(payrollProvider.notifier)
                                    .createIncapacity(incapacity);
                              } catch (_) {}
                            }
                            // 2) Procesar asistencia normal (excluir empleados con incapacidad/permiso
                            //    ya que createIncapacity auto-genera sus time_adjustments)
                            final filteredAttendance = Map<String, String>.from(
                              attendance,
                            );
                            for (final empId in incapacityRecords.keys) {
                              filteredAttendance.remove(empId);
                            }
                            await _processAttendance(
                              filteredAttendance,
                              selectedDate,
                            );
                          },
                          icon: const Icon(Icons.save, size: 16),
                          label: const Text('Guardar Asistencia'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Diálogo para preguntar la duración de una incapacidad o permiso.
  /// Retorna un Map con {startDate, endDate, days, type, reason} o null si canceló.
  Future<Map<String, dynamic>?> _showAbsenceDurationDialog({
    required BuildContext context,
    required String employeeName,
    required bool isPermiso,
    required DateTime initialDate,
  }) async {
    DateTime startDate = initialDate;
    DateTime endDate = initialDate; // Por defecto 1 solo día
    String selectedType = isPermiso ? 'permiso' : 'enfermedad';
    final reasonController = TextEditingController();

    return showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          final days = endDate.difference(startDate).inDays + 1;

          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isPermiso ? Icons.event_busy : Icons.local_hospital,
                  color: isPermiso
                      ? const Color(0xFFF9A825)
                      : const Color(0xFF7B1FA2),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isPermiso ? 'Registrar Permiso' : 'Registrar Incapacidad',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 400, minWidth: 200),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Empleado
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          (isPermiso
                                  ? const Color(0xFFF9A825)
                                  : const Color(0xFF7B1FA2))
                              .withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 18,
                          color: const Color(0xFF757575),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          employeeName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tipo (solo para incapacidad)
                  if (!isPermiso) ...[
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        prefixIcon: Icon(Icons.medical_services),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'enfermedad',
                          child: Text('Enfermedad General'),
                        ),
                        DropdownMenuItem(
                          value: 'accidente_laboral',
                          child: Text('Accidente Laboral'),
                        ),
                        DropdownMenuItem(
                          value: 'accidente_comun',
                          child: Text('Accidente Común'),
                        ),
                      ],
                      onChanged: (v) => setDState(() => selectedType = v!),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ¿Solo hoy o rango?
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: ctx,
                              initialDate: startDate,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 30),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null) {
                              setDState(() {
                                startDate = date;
                                if (endDate.isBefore(startDate)) {
                                  endDate = startDate;
                                }
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Desde',
                              prefixIcon: Icon(Icons.calendar_today),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: Text(
                              '${startDate.day}/${startDate.month}/${startDate.year}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: ctx,
                              initialDate: endDate,
                              firstDate: startDate,
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null) {
                              setDState(() => endDate = date);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Hasta',
                              prefixIcon: Icon(Icons.calendar_today),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: Text(
                              '${endDate.day}/${endDate.month}/${endDate.year}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Días calculados
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isPermiso
                                  ? const Color(0xFFF9A825)
                                  : const Color(0xFF7B1FA2))
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timer,
                          size: 16,
                          color: isPermiso
                              ? const Color(0xFFF9A825)
                              : const Color(0xFF7B1FA2),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$days día${days > 1 ? "s" : ""} de ${isPermiso ? "permiso" : "incapacidad"}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isPermiso
                                ? const Color(0xFFEF6C00)
                                : const Color(0xFF6A1B9A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Motivo
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      labelText: isPermiso
                          ? 'Motivo del permiso (opcional)'
                          : 'Diagnóstico (opcional)',
                      prefixIcon: Icon(
                        isPermiso ? Icons.note : Icons.local_hospital,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx, {
                    'startDate': startDate,
                    'endDate': endDate,
                    'days': days,
                    'type': selectedType,
                    'reason': reasonController.text.isNotEmpty
                        ? reasonController.text
                        : null,
                  });
                },
                icon: const Icon(Icons.check, size: 16),
                label: Text(isPermiso ? 'Registrar Permiso' : 'Registrar'),
                style: FilledButton.styleFrom(
                  backgroundColor: isPermiso
                      ? const Color(0xFFF9A825)
                      : const Color(0xFF7B1FA2),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Grilla de calendario de quincena integrada en el diálogo de asistencia.
  /// Muestra colores por estado del historial y permite seleccionar un día.
  Widget _buildQuincenaCalendarGrid({
    required List<DateTime> quinDays,
    required Map<String, Map<String, int>> dayData,
    required DateTime today,
    required DateTime selectedDate,
    required void Function(DateTime) onDayTap,
  }) {
    final firstDay = quinDays.first;
    final startWeekday = firstDay.weekday;

    final cells = <Widget>[];
    for (int i = 1; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }

    for (final day in quinDays) {
      final dateKey = day.toIso8601String().split('T')[0];
      final data = dayData[dateKey];
      final isSunday = day.weekday == DateTime.sunday;
      final isToday =
          day.year == today.year &&
          day.month == today.month &&
          day.day == today.day;
      final isSelected =
          day.year == selectedDate.year &&
          day.month == selectedDate.month &&
          day.day == selectedDate.day;
      final isPast = day.isBefore(DateTime(today.year, today.month, today.day));
      final isFuture = day.isAfter(
        DateTime(today.year, today.month, today.day),
      );

      final ausentes = data?['ausente'] ?? 0;
      final permisos = data?['permiso'] ?? 0;
      final incapacidades = data?['incapacidad'] ?? 0;
      final hasNovedades = ausentes + permisos + incapacidades > 0;

      Color bgColor;
      Color textColor;
      List<Color> dotColors = [];

      if (isSunday) {
        bgColor = const Color(0xFF9E9E9E).withValues(alpha: 0.05);
        textColor = const Color(0xFFE57373);
      } else if (isFuture) {
        bgColor = const Color(0xFF9E9E9E).withValues(alpha: 0.03);
        textColor = const Color(0xFFBDBDBD);
      } else if (!hasNovedades && isPast) {
        bgColor = const Color(0xFF2E7D32).withValues(alpha: 0.15);
        textColor = const Color(0xFF388E3C);
      } else if (!hasNovedades && isToday) {
        bgColor = const Color(0xFF2E7D32).withValues(alpha: 0.1);
        textColor = const Color(0xFF388E3C);
      } else if (hasNovedades) {
        if (ausentes > 0) {
          bgColor = const Color(0xFFC62828).withValues(alpha: 0.15);
          textColor = const Color(0xFFD32F2F);
          dotColors.add(const Color(0xFFC62828));
        } else {
          bgColor = const Color(0xFF2E7D32).withValues(alpha: 0.1);
          textColor = const Color(0xFF388E3C);
        }
        if (permisos > 0) {
          dotColors.add(const Color(0xFFF9A825));
          if (ausentes == 0) {
            bgColor = const Color(0xFFF9A825).withValues(alpha: 0.15);
            textColor = const Color(0xFFF57C00);
          }
        }
        if (incapacidades > 0) {
          dotColors.add(const Color(0xFF7B1FA2));
          if (ausentes == 0 && permisos == 0) {
            bgColor = const Color(0xFF7B1FA2).withValues(alpha: 0.15);
            textColor = const Color(0xFF7B1FA2);
          }
        }
      } else {
        bgColor = const Color(0xFF9E9E9E).withValues(alpha: 0.05);
        textColor = const Color(0xFF9E9E9E);
      }

      cells.add(
        GestureDetector(
          onTap: isSunday || isFuture ? null : () => onDayTap(day),
          child: Container(
            margin: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF1565C0).withValues(alpha: 0.2)
                  : bgColor,
              borderRadius: BorderRadius.circular(6),
              border: isSelected
                  ? Border.all(color: const Color(0xFF1565C0), width: 2)
                  : isToday
                  ? Border.all(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.5),
                      width: 1,
                    )
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontWeight: isSelected || isToday
                        ? FontWeight.bold
                        : FontWeight.w600,
                    fontSize: 12,
                    color: isSelected ? const Color(0xFF1565C0) : textColor,
                  ),
                ),
                if (dotColors.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: dotColors.take(3).map((c) {
                      return Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final remainder = cells.length % 7;
    if (remainder > 0) {
      for (int i = 0; i < 7 - remainder; i++) {
        cells.add(const SizedBox());
      }
    }

    final rows = <Widget>[];
    for (int i = 0; i < cells.length; i += 7) {
      rows.add(
        SizedBox(
          height: 40,
          child: Row(
            children: cells.sublist(i, i + 7).map((cell) {
              return Expanded(child: cell);
            }).toList(),
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildCalendarLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: const Color(0xFF757575)),
        ),
      ],
    );
  }

  Widget _buildAttendanceSummaryChip(IconData icon, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              count,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceStatusButton({
    required IconData icon,
    required Color color,
    required bool isActive,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive
                ? color.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive
                  ? color
                  : const Color(0xFF9E9E9E).withValues(alpha: 0.2),
              width: isActive ? 1.5 : 0.5,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive
                ? color
                : const Color(0xFF9E9E9E).withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  Color _attendanceStatusColor(String status) {
    switch (status) {
      case 'presente':
        return const Color(0xFF2E7D32);
      case 'ausente':
        return const Color(0xFFC62828);
      case 'permiso':
        return const Color(0xFFF9A825);
      case 'incapacidad':
        return const Color(0xFF7B1FA2);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  /// Procesar asistencia con lógica laboral colombiana:
  /// - AUSENCIA: descuento del día + 1 domingo (si quedan en la quincena) + pierde BONO
  /// - PERMISO: descuento del día + pierde BONO_ASISTENCIA
  /// - INCAPACIDAD: días 1-3 consecutivos = 100% pago (sin descuento),
  ///   día 4+ = pago al 66.33% (descuento del 33.67%)
  /// Quincenas: 1-15 y 16-fin de mes. Solo se descuentan domingos
  /// de la quincena actual (no pagada).
  Future<void> _processAttendance(
    Map<String, String> attendance,
    DateTime date,
  ) async {
    final isSunday = date.weekday == DateTime.sunday;
    if (isSunday) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Domingo es día de descanso, no se registran ausencias',
            ),
            backgroundColor: Color(0xFFF9A825),
          ),
        );
      }
      return;
    }

    final isSaturday = date.weekday == DateTime.saturday;
    // Horas laborales: L-V = 7.7h, Sáb = 5.5h (jornada 44h/semana)
    final hoursToDeduct = isSaturday ? 5.5 : 7.7;
    final minutesToDeduct = (hoursToDeduct * 60).round(); // 462 o 330 min

    // Valor de un domingo = equivalente a un día laboral
    const domingoMinutes = 462; // 7.7h × 60

    // Determinar quincena actual (no pagada)
    final quinStart = _getQuincenaStart(date);
    final quinEnd = _getQuincenaEnd(date);
    final domingosTotalEnQuincena = _countSundaysInRange(quinStart, quinEnd);

    // Empleados ausentes
    final absentEntries = attendance.entries
        .where((e) => e.value == 'ausente')
        .toList();

    // Empleados con permiso
    final permisoEntries = attendance.entries
        .where((e) => e.value == 'permiso')
        .toList();

    // Empleados con incapacidad
    final incapacityEntries = attendance.entries
        .where((e) => e.value == 'incapacidad')
        .toList();

    if (absentEntries.isEmpty &&
        permisoEntries.isEmpty &&
        incapacityEntries.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Todos presentes — asistencia completa'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
      return;
    }

    int successCount = 0;
    int failCount = 0;
    int domingoSkipped = 0;
    final dateStr = '${date.day}/${date.month}/${date.year}';

    // =============================================
    // AUSENCIA: descuento día + domingo (si quedan) + PIERDE_BONO
    // =============================================
    for (final entry in absentEntries) {
      try {
        // 1) Descuento del día laboral
        final s1 = await ref
            .read(employeesProvider.notifier)
            .createTimeAdjustment(
              employeeId: entry.key,
              minutes: minutesToDeduct,
              type: 'deduction',
              date: date,
              reason: 'Ausencia — $dateStr | PIERDE_BONO',
            );

        // 2) Descuento dominical — solo si quedan domingos por descontar
        //    en esta quincena para este empleado
        bool s2 = true;
        final domingosYaDescontados = await _countDomingoDeductionsInQuincena(
          entry.key,
          quinStart,
          quinEnd,
        );

        if (domingosYaDescontados < domingosTotalEnQuincena) {
          s2 = await ref
              .read(employeesProvider.notifier)
              .createTimeAdjustment(
                employeeId: entry.key,
                minutes: domingoMinutes,
                type: 'deduction',
                date: date,
                reason:
                    'Descuento dominical por ausencia — $dateStr (${domingosYaDescontados + 1}/$domingosTotalEnQuincena)',
              );
        } else {
          // Ya no quedan domingos en esta quincena para descontar
          domingoSkipped++;
        }

        if (s1 && s2) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
      }
    }

    // =============================================
    // PERMISO: descuento del día + PIERDE_BONO
    // =============================================
    for (final entry in permisoEntries) {
      try {
        final success = await ref
            .read(employeesProvider.notifier)
            .createTimeAdjustment(
              employeeId: entry.key,
              minutes: minutesToDeduct,
              type: 'deduction',
              date: date,
              reason: 'Permiso — $dateStr | PIERDE_BONO',
            );
        if (success) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
      }
    }

    // =============================================
    // INCAPACIDAD: ley colombiana Art. 227 CST
    //   - Días 1-3 consecutivos: empresa paga 100% (sin descuento, NO crear adjustment)
    //   - Día 4+: solo se paga 66.33% (descuento del 33.67%)
    //   - NO pierde BONO_ASISTENCIA
    // =============================================
    for (final entry in incapacityEntries) {
      try {
        // Contar días consecutivos de incapacidad ANTES de hoy
        final consecutiveDays = await _countConsecutiveIncapacityDays(
          entry.key,
          date,
        );
        // El día de hoy sería el consecutiveDays + 1
        final currentDay = consecutiveDays + 1;

        if (currentDay <= 3) {
          // Días 1-3: pago completo, sin descuento
          // NO creamos adjustment (la ausencia de descuento = pago 100%)
          successCount++;
        } else {
          // Día 4+: descuento del 33.67% (pago solo 66.33%)
          final discountMinutes = (minutesToDeduct * 0.3367).round();
          final success = await ref
              .read(employeesProvider.notifier)
              .createTimeAdjustment(
                employeeId: entry.key,
                minutes: discountMinutes,
                type: 'deduction',
                date: date,
                reason: 'Incapacidad día $currentDay — pago 66.33% — $dateStr',
              );
          if (success) {
            successCount++;
          } else {
            failCount++;
          }
        }
      } catch (e) {
        failCount++;
      }
    }

    if (mounted) {
      final messages = <String>[];
      if (absentEntries.isNotEmpty) {
        messages.add(
          '${absentEntries.length} ausencia${absentEntries.length > 1 ? "s" : ""}',
        );
      }
      if (permisoEntries.isNotEmpty) {
        messages.add(
          '${permisoEntries.length} permiso${permisoEntries.length > 1 ? "s" : ""}',
        );
      }
      if (incapacityEntries.isNotEmpty) {
        messages.add(
          '${incapacityEntries.length} incapacidad${incapacityEntries.length > 1 ? "es" : ""}',
        );
      }
      if (domingoSkipped > 0) {
        messages.add(
          '$domingoSkipped sin domingo (ya descontados todos en quincena)',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failCount == 0
                ? '✅ Asistencia guardada — ${messages.join(", ")}'
                : '⚠️ $successCount de ${successCount + failCount} registrados',
          ),
          backgroundColor: failCount == 0
              ? const Color(0xFF2E7D32)
              : const Color(0xFFF9A825),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Inicio de la quincena: día 1 o día 16 del mes
  DateTime _getQuincenaStart(DateTime date) {
    return date.day <= 15
        ? DateTime(date.year, date.month, 1)
        : DateTime(date.year, date.month, 16);
  }

  /// Fin de la quincena: día 15 o último día del mes
  DateTime _getQuincenaEnd(DateTime date) {
    if (date.day <= 15) {
      return DateTime(date.year, date.month, 15);
    } else {
      // Último día del mes
      return DateTime(date.year, date.month + 1, 0);
    }
  }

  /// Contar domingos en un rango de fechas [start, end] (inclusive)
  int _countSundaysInRange(DateTime start, DateTime end) {
    int count = 0;
    DateTime d = start;
    while (!d.isAfter(end)) {
      if (d.weekday == DateTime.sunday) count++;
      d = d.add(const Duration(days: 1));
    }
    return count;
  }

  /// Contar cuántos descuentos dominicales ya tiene este empleado
  /// en la quincena delimitada por [quinStart] y [quinEnd].
  Future<int> _countDomingoDeductionsInQuincena(
    String employeeId,
    DateTime quinStart,
    DateTime quinEnd,
  ) async {
    try {
      final adjustments = await EmployeesDatasource.getTimeAdjustments(
        employeeId: employeeId,
        startDate: quinStart,
        endDate: quinEnd,
      );

      // Filtrar solo los que son "Descuento dominical"
      return adjustments.where((a) {
        if (a.reason == null) return false;
        return a.reason!.toLowerCase().contains('descuento dominical');
      }).length;
    } catch (e) {
      return 0;
    }
  }

  /// Contar días consecutivos de incapacidad ANTES de [date] para [employeeId].
  /// Busca hacia atrás desde date-1 contando registros con reason que contenga
  /// "Incapacidad" en fechas consecutivas (saltando domingos).
  Future<int> _countConsecutiveIncapacityDays(
    String employeeId,
    DateTime date,
  ) async {
    try {
      // Buscar ajustes de los últimos 180 días para este empleado
      final startDate = date.subtract(const Duration(days: 180));
      final adjustments = await EmployeesDatasource.getTimeAdjustments(
        employeeId: employeeId,
        startDate: startDate,
      );

      // Filtrar solo incapacidades (reason contiene "Incapacidad")
      final incapacityAdjustments = adjustments
          .where(
            (a) =>
                a.reason != null &&
                a.reason!.toLowerCase().contains('incapacidad'),
          )
          .toList();

      // Crear set de fechas con incapacidad
      final incapacityDates = <String>{};
      for (final adj in incapacityAdjustments) {
        incapacityDates.add(adj.adjustmentDate.toIso8601String().split('T')[0]);
      }

      // Contar días consecutivos hacia atrás desde date-1
      int consecutiveDays = 0;
      DateTime checkDate = date.subtract(const Duration(days: 1));

      while (true) {
        // Saltar domingos (no son laborales)
        if (checkDate.weekday == DateTime.sunday) {
          checkDate = checkDate.subtract(const Duration(days: 1));
          continue;
        }

        final dateKey = checkDate.toIso8601String().split('T')[0];
        if (incapacityDates.contains(dateKey)) {
          consecutiveDays++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break; // Si no hay incapacidad en ese día, se corta la cadena
        }

        // Máximo 180 días de búsqueda
        if (consecutiveDays >= 180) break;
      }

      return consecutiveDays;
    } catch (e) {
      return 0; // Si hay error, asumir que es el primer día
    }
  }

  void _showTimeHistoryDialog(Employee employee) {
    final now = DateTime.now();
    DateTime startDate = DateTime(now.year, now.month, 1); // Inicio del mes
    DateTime endDate = now;
    List<EmployeeTimeEntry> historyEntries = [];
    bool isLoading = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // Cargar datos al abrir o al cambiar rango
            void loadEntries() async {
              setDialogState(() => isLoading = true);
              try {
                final entries = await EmployeesDatasource.getTimeEntries(
                  employeeId: employee.id,
                  startDate: startDate,
                  endDate: endDate,
                );
                setDialogState(() {
                  historyEntries = entries;
                  isLoading = false;
                });
              } catch (e) {
                setDialogState(() {
                  historyEntries = [];
                  isLoading = false;
                });
              }
            }

            // Primera carga
            if (isLoading && historyEntries.isEmpty) {
              Future.microtask(loadEntries);
            }

            // Agrupar por fecha
            final Map<String, List<EmployeeTimeEntry>> grouped = {};
            for (final entry in historyEntries) {
              final key =
                  '${entry.entryDate.year}-${entry.entryDate.month.toString().padLeft(2, '0')}-${entry.entryDate.day.toString().padLeft(2, '0')}';
              grouped.putIfAbsent(key, () => []).add(entry);
            }
            final sortedDays = grouped.keys.toList()
              ..sort((a, b) => b.compareTo(a));

            // Totales
            final totalMinutes = historyEntries.fold<int>(
              0,
              (sum, e) => sum + e.workedMinutes,
            );
            final totalOvertime = historyEntries.fold<int>(
              0,
              (sum, e) => sum + e.overtimeMinutes,
            );
            final totalDays = sortedDays.length;

            final theme = Theme.of(ctx);
            final primaryColor = theme.colorScheme.primary;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 600,
                  maxHeight: 700,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.history,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Historial de Horas — ${employee.fullName}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(ctx),
                                icon: const Icon(
                                  Icons.close,
                                  color: Color(0xB3FFFFFF),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Date range selector
                          Row(
                            children: [
                              _buildDateChip(ctx, 'Desde', startDate, (picked) {
                                setDialogState(() {
                                  startDate = picked;
                                  isLoading = true;
                                  historyEntries = [];
                                });
                              }),
                              const SizedBox(width: 8),
                              _buildDateChip(ctx, 'Hasta', endDate, (picked) {
                                setDialogState(() {
                                  endDate = picked;
                                  isLoading = true;
                                  historyEntries = [];
                                });
                              }),
                              const SizedBox(width: 8),
                              // Quick presets
                              PopupMenuButton<int>(
                                icon: const Icon(
                                  Icons.date_range,
                                  color: Color(0xB3FFFFFF),
                                  size: 20,
                                ),
                                tooltip: 'Rangos rápidos',
                                onSelected: (days) {
                                  setDialogState(() {
                                    endDate = now;
                                    startDate = now.subtract(
                                      Duration(days: days),
                                    );
                                    isLoading = true;
                                    historyEntries = [];
                                  });
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 7,
                                    child: Text('Última semana'),
                                  ),
                                  const PopupMenuItem(
                                    value: 14,
                                    child: Text('Últimas 2 semanas'),
                                  ),
                                  const PopupMenuItem(
                                    value: 30,
                                    child: Text('Último mes'),
                                  ),
                                  const PopupMenuItem(
                                    value: 90,
                                    child: Text('Últimos 3 meses'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Summary bar
                    if (!isLoading)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        color: const Color(0xFFFAFAFA),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSummaryItem(
                              'Días',
                              '$totalDays',
                              Icons.calendar_today,
                            ),
                            _buildSummaryItem(
                              'Horas',
                              '${(totalMinutes / 60).toStringAsFixed(1)}h',
                              Icons.access_time,
                            ),
                            _buildSummaryItem(
                              'Extra',
                              '${(totalOvertime / 60).toStringAsFixed(1)}h',
                              Icons.trending_up,
                            ),
                            _buildSummaryItem(
                              'Prom/día',
                              totalDays > 0
                                  ? '${(totalMinutes / 60 / totalDays).toStringAsFixed(1)}h'
                                  : '0h',
                              Icons.show_chart,
                            ),
                          ],
                        ),
                      ),
                    // Content
                    Flexible(
                      child: isLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : historyEntries.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.event_busy,
                                      size: 48,
                                      color: const Color(0xFFBDBDBD),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Sin registros en este período',
                                      style: TextStyle(
                                        color: const Color(0xFFBDBDBD),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: sortedDays.length,
                              itemBuilder: (_, dayIndex) {
                                final dayKey = sortedDays[dayIndex];
                                final dayEntries = grouped[dayKey]!;
                                final dayDate = DateTime.parse(dayKey);
                                final dayTotal = dayEntries.fold<int>(
                                  0,
                                  (s, e) => s + e.workedMinutes,
                                );
                                final dayNames = [
                                  'Lun',
                                  'Mar',
                                  'Mié',
                                  'Jue',
                                  'Vie',
                                  'Sáb',
                                  'Dom',
                                ];
                                final monthNames = [
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

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFFEEEEEE),
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: [
                                      // Day header
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFAFAFA),
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(10),
                                              ),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              '${dayNames[dayDate.weekday - 1]} ${dayDate.day} ${monthNames[dayDate.month - 1]}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: dayTotal >= 468
                                                    ? const Color(
                                                        0xFF2E7D32,
                                                      ).withValues(alpha: 0.1)
                                                    : const Color(
                                                        0xFFF9A825,
                                                      ).withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${(dayTotal / 60).toStringAsFixed(1)}h',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: dayTotal >= 468
                                                      ? const Color(0xFF388E3C)
                                                      : const Color(0xFFF57C00),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Entries
                                      ...dayEntries.map(
                                        (entry) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                entry.checkOut != null
                                                    ? Icons.check_circle_outline
                                                    : Icons
                                                          .radio_button_unchecked,
                                                size: 16,
                                                color: entry.checkOut != null
                                                    ? const Color(0xFF2E7D32)
                                                    : const Color(0xFFF9A825),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                _formatTime(entry.checkIn),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const Text(
                                                ' → ',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF9E9E9E),
                                                ),
                                              ),
                                              Text(
                                                entry.checkOut != null
                                                    ? _formatTime(
                                                        entry.checkOut,
                                                      )
                                                    : 'En turno',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: entry.checkOut != null
                                                      ? null
                                                      : const Color(0xFF2E7D32),
                                                ),
                                              ),
                                              const Spacer(),
                                              if (entry.workedMinutes > 0)
                                                Text(
                                                  '${(entry.workedMinutes / 60).toStringAsFixed(1)}h',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: primaryColor,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              if (entry.overtimeMinutes >
                                                  0) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 1,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFF9A825,
                                                    ).withValues(alpha: 0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          3,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '+${(entry.overtimeMinutes / 60).toStringAsFixed(1)}h',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: const Color(
                                                        0xFFFF8F00,
                                                      ),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      entry.status == 'aprobado'
                                                      ? const Color(
                                                          0xFF2E7D32,
                                                        ).withValues(alpha: 0.1)
                                                      : const Color(
                                                          0xFF9E9E9E,
                                                        ).withValues(
                                                          alpha: 0.1,
                                                        ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  entry.status,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        entry.status ==
                                                            'aprobado'
                                                        ? const Color(
                                                            0xFF388E3C,
                                                          )
                                                        : const Color(
                                                            0xFF757575,
                                                          ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDateChip(
    BuildContext ctx,
    String label,
    DateTime date,
    Function(DateTime) onPicked,
  ) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: ctx,
          initialDate: date,
          firstDate: DateTime(2024),
          lastDate: DateTime.now(),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ${date.day}/${date.month}/${date.year}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.edit_calendar, size: 14, color: Color(0xB3FFFFFF)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF9E9E9E)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: const Color(0xFF757575)),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF9E9E9E)),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showNfcAssignDialog(Employee employee) {
    final cardController = TextEditingController(
      text: employee.nfcCardId ?? '',
    );
    bool isListening = false;
    String? statusMessage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.nfc, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('Tarjeta NFC - ${employee.fullName}')),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420, minWidth: 200),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (employee.nfcCardId != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.credit_card,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tarjeta actual: ${employee.nfcCardId}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  employee.nfcCardId != null
                      ? 'Ingresa el nuevo ID o escanea la tarjeta para reemplazar:'
                      : 'Escanea la tarjeta en el lector USB o ingresa el ID manualmente:',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cardController,
                  decoration: InputDecoration(
                    labelText: 'ID de tarjeta NFC',
                    hintText: 'Ej: 0A0042F3B2',
                    prefixIcon: const Icon(Icons.contactless),
                    border: const OutlineInputBorder(),
                    suffixIcon: isListening
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                if (!isListening)
                  OutlinedButton.icon(
                    onPressed: () {
                      setDialogState(() {
                        isListening = true;
                        statusMessage = 'Esperando escaneo de tarjeta...';
                      });
                      // Escuchar el próximo escaneo HID
                      late StreamSubscription<NfcScanResult> sub;
                      sub = NfcReaderService.instance.onCardScanned.listen((
                        scan,
                      ) {
                        cardController.text = scan.cardId;
                        sub.cancel();
                        setDialogState(() {
                          isListening = false;
                          statusMessage = '✅ Tarjeta detectada: ${scan.cardId}';
                        });
                      });
                      // Iniciar lectura si no está activa
                      NfcReaderService.instance.startNfcReading();
                      // Timeout de 30 segundos
                      Future.delayed(const Duration(seconds: 30), () {
                        if (isListening) {
                          sub.cancel();
                          if (context.mounted) {
                            setDialogState(() {
                              isListening = false;
                              statusMessage =
                                  '⏱ Tiempo agotado. Intenta de nuevo.';
                            });
                          }
                        }
                      });
                    },
                    icon: const Icon(Icons.sensors),
                    label: const Text('Escanear tarjeta del lector USB'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () {
                      setDialogState(() {
                        isListening = false;
                        statusMessage = null;
                      });
                    },
                    icon: const Icon(Icons.stop),
                    label: const Text('Cancelar escaneo'),
                  ),
                if (statusMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    statusMessage!,
                    style: TextStyle(
                      color: statusMessage!.startsWith('✅')
                          ? Colors.green
                          : statusMessage!.startsWith('⏱')
                          ? Colors.orange
                          : Theme.of(context).colorScheme.primary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (employee.nfcCardId != null)
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  final success = await EmployeesDatasource.removeNfcCard(
                    employee.id,
                  );
                  if (success && mounted) {
                    ref.read(employeesProvider.notifier).loadEmployees();
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Tarjeta NFC removida'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.link_off, color: Colors.red),
                label: const Text(
                  'Quitar tarjeta',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final cardId = cardController.text.trim();
                if (cardId.isEmpty) return;
                Navigator.pop(context);
                final success = await EmployeesDatasource.assignNfcCard(
                  employeeId: employee.id,
                  nfcCardId: cardId,
                );
                if (mounted) {
                  ref.read(employeesProvider.notifier).loadEmployees();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Tarjeta $cardId asignada a ${employee.fullName}'
                            : 'Error al asignar tarjeta (puede estar en uso)',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('Asignar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Employee employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar empleado'),
        content: Text('¿Estás seguro de eliminar a ${employee.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(employeesProvider.notifier)
                  .deleteEmployee(employee.id);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            child: const Text('Eliminar'),
          ),
        ],
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
            content: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 420, minWidth: 200),
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
