// ignore_for_file: unused_element, unused_local_variable, unused_field
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/employee.dart';
import '../../data/providers/employees_provider.dart';
import '../../data/providers/payroll_provider.dart';
import '../../data/providers/accounts_provider.dart';
import '../../data/providers/activities_provider.dart';
import '../../data/datasources/payroll_datasource.dart';
import '../../data/datasources/employees_datasource.dart';
import '../../data/datasources/accounts_datasource.dart';
import '../../domain/entities/cash_movement.dart';
import '../../core/utils/helpers.dart';

class EmployeesPage extends ConsumerStatefulWidget {
  final bool openNewDialog;
  final bool openNewTaskDialog;

  const EmployeesPage({
    super.key,
    this.openNewDialog = false,
    this.openNewTaskDialog = false,
  });

  @override
  ConsumerState<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends ConsumerState<EmployeesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _taskSearchController = TextEditingController();
  String _filterStatus = 'todos';
  String _filterDepartment = 'todos';
  bool _dialogOpened = false;

  // Filtros de tareas
  String _taskFilterStatus = 'todos';
  String _taskFilterCategory = 'todos';
  String _taskFilterAssignee = 'todos';
  DateTimeRange? _taskDateRange;

  // Historial de semanas del empleado
  int _weekOffset = 0; // 0 = semana actual, -1 = semana anterior, etc.
  bool _showWeekHistory = false;

  // Key para forzar rebuild del FutureBuilder de quincena al cambiar asistencia
  int _quincenaRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(employeesProvider.notifier).loadEmployees();
      ref.read(employeesProvider.notifier).loadPendingTasks();
      ref.read(payrollProvider.notifier).loadAll();
      ref.read(activitiesProvider.notifier).loadActivities();

      if (widget.openNewDialog && !_dialogOpened) {
        _dialogOpened = true;
        _showEmployeeDialog();
      } else if (widget.openNewTaskDialog && !_dialogOpened) {
        _dialogOpened = true;
        _showTaskDialog();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _taskSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeesProvider);
    final payrollState = ref.watch(payrollProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFEEEEEE);

    return Scaffold(
      body: Column(
        children: [
          // Header compacto con tabs inline
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                // Stats compactos
                _buildCompactStat(
                  Icons.people,
                  '${state.employees.length}',
                  'Emp',
                  const Color(0xFF1565C0),
                  isDark,
                ),
                const SizedBox(width: 4),
                _buildCompactStat(
                  Icons.check_circle,
                  '${state.activeEmployees.length}',
                  'Act',
                  const Color(0xFF2E7D32),
                  isDark,
                ),
                const SizedBox(width: 4),
                _buildCompactStat(
                  Icons.pending_actions,
                  '${state.tasks.where((t) => t.status == TaskStatus.pendiente || t.status == TaskStatus.enProgreso).length}',
                  'Tar',
                  const Color(0xFFF9A825),
                  isDark,
                ),
                const SizedBox(width: 8),
                // Tabs
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    labelColor: theme.colorScheme.primary,
                    unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                    indicatorColor: theme.colorScheme.primary,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    tabs: const [
                      Tab(text: 'Empleados'),
                      Tab(text: 'Tareas'),
                      Tab(text: 'Nómina'),
                      Tab(text: 'Préstamos'),
                      Tab(text: 'Incapacidades'),
                    ],
                  ),
                ),
                // Periodo
                if (payrollState.currentPeriod != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      payrollState.currentPeriod!.displayName,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ),
                // Botón de acción
                _buildHeaderActionButton(),
              ],
            ),
          ),

          // Contenido
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEmployeesTab(theme, state, payrollState),
                _buildTasksTab(theme, state),
                _buildPayrollTab(theme, state, payrollState),
                _buildLoansTab(theme, state, payrollState),
                _buildIncapacitiesTab(theme, state, payrollState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildFAB() {
    final labels = ['Empleado', 'Tarea', 'Nómina', 'Préstamo', 'Incapacidad'];
    final icons = [
      Icons.person_add,
      Icons.add_task,
      Icons.payments,
      Icons.attach_money,
      Icons.medical_services,
    ];

    return FloatingActionButton.extended(
      onPressed: () {
        switch (_tabController.index) {
          case 0:
            _showEmployeeDialog();
            break;
          case 1:
            _showTaskDialog();
            break;
          case 2:
            _showCreatePayrollDialog();
            break;
          case 3:
            _showLoanDialog();
            break;
          case 4:
            _showIncapacityDialog();
            break;
        }
      },
      icon: Icon(icons[_tabController.index]),
      label: Text(labels[_tabController.index]),
    );
  }

  Widget _buildCompactStat(
    IconData icon,
    String value,
    String label,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDark ? Colors.white : const Color(0xDD000000),
            ),
          ),
          const SizedBox(width: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: const Color(0xFF9E9E9E))),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton() {
    final labels = ['+Emp', '+Tar', '+Nóm', '+Prés', '+Inc'];
    final icons = [
      Icons.person_add,
      Icons.add_task,
      Icons.payments,
      Icons.attach_money,
      Icons.medical_services,
    ];

    return FilledButton.icon(
      onPressed: () {
        switch (_tabController.index) {
          case 0:
            _showEmployeeDialog();
            break;
          case 1:
            _showTaskDialog();
            break;
          case 2:
            _showCreatePayrollDialog();
            break;
          case 3:
            _showLoanDialog();
            break;
          case 4:
            _showIncapacityDialog();
            break;
        }
      },
      icon: Icon(icons[_tabController.index], size: 14),
      label: Text(
        labels[_tabController.index],
        style: const TextStyle(fontSize: 12),
      ),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: const Color(0xFFFFFFFF).withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        ref.read(employeesProvider.notifier).search(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  _buildFilterDropdown(
                    value: _filterStatus,
                    items: const [
                      DropdownMenuItem(value: 'todos', child: Text('Todos')),
                      DropdownMenuItem(value: 'activo', child: Text('Activos')),
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
                      DropdownMenuItem(value: 'todos', child: Text('Todos')),
                      DropdownMenuItem(
                        value: 'produccion',
                        child: Text('Producción'),
                      ),
                      DropdownMenuItem(value: 'ventas', child: Text('Ventas')),
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
                      setState(() => _filterDepartment = value ?? 'todos');
                    },
                    hint: 'Departamento',
                  ),
                ],
              ),
              if (selectedEmployee != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.badge, size: 16),
                      label: Text('Seleccionado: ${selectedEmployee.fullName}'),
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
                          case 'edit':
                            _showEmployeeDialog(employee: employee);
                            break;
                          case 'delete':
                            _confirmDelete(employee);
                            break;
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'detail',
                          child: Text('Ver detalle'),
                        ),
                        PopupMenuItem(
                          value: 'task',
                          child: Text('Asignar tarea'),
                        ),
                        PopupMenuItem(value: 'edit', child: Text('Editar')),
                        PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                      ],
                    ),
                    onTap: () {
                      if (showSplit) {
                        // Resetear navegación de semanas al cambiar de empleado
                        setState(() {
                          _weekOffset = 0;
                          _showWeekHistory = false;
                        });
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

  Widget _buildEmployeeHoursIndicator(
    Employee employee,
    EmployeesState state,
    ThemeData theme,
  ) {
    // Calcular horas de hoy para este empleado
    final now = DateTime.now();
    final todayEntries = state.timeEntries
        .where((e) => e.employeeId == employee.id)
        .where(
          (e) =>
              e.entryDate.day == now.day &&
              e.entryDate.month == now.month &&
              e.entryDate.year == now.year,
        )
        .toList();

    final todayHours = todayEntries.fold(
      0.0,
      (sum, e) => sum + (e.workedMinutes / 60.0),
    );

    // También sumar ajustes de hoy
    final todayAdjustments = state.timeAdjustments
        .where((a) => a.employeeId == employee.id)
        .where(
          (a) =>
              a.adjustmentDate.day == now.day &&
              a.adjustmentDate.month == now.month &&
              a.adjustmentDate.year == now.year,
        )
        .toList();

    double adjustedHours = todayHours;
    for (var adj in todayAdjustments) {
      if (adj.type == 'overtime') {
        adjustedHours += adj.minutes / 60.0;
      } else {
        adjustedHours -= adj.minutes / 60.0;
      }
    }

    if (adjustedHours <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            '${adjustedHours.toStringAsFixed(1)}h',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
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
    const double weekdayBase = 7.7; // (44 - 5.5) / 5 = 7.7h
    const double saturdayBase = 5.5; // 7:30 a 1:00
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
            child: const Icon(Icons.remove, size: 16, color: const Color(0xFFC62828)),
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
            child: const Icon(Icons.add, size: 16, color: const Color(0xFF2E7D32)),
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
    final summary = state.currentTimeSummary;
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

    final weekStart = summary?.weekStart ?? _startOfWeek(DateTime.now());
    final weekDays = List.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
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
                                color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
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
                                color: const Color(0xFFF9A825).withValues(alpha: 0.1),
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

  Widget _buildInfoItem(
    IconData icon,
    String label,
    String value,
    Color textMain,
    Color textSub,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Icon(icon, size: 18, color: textSub),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: textSub)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textMain,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
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
    );

    final Map<String, Map<String, int>> dayData = {};

    for (final adj in adjustments) {
      // Filtrar solo los de la quincena
      if (adj.adjustmentDate.isBefore(quinStart) ||
          adj.adjustmentDate.isAfter(quinEnd)) {
        continue;
      }

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
                    color: const Color(0xFF1565C0),
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
            content: SizedBox(
              width: 360,
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
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
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

  Widget _buildWeekHistorySection({
    required Employee employee,
    required EmployeesState state,
    required bool isDark,
    required Color primaryColor,
    required Color cardBg,
    required Color borderColor,
    required Color textMain,
    required Color textSub,
  }) {
    // Calcular la semana basada en el offset
    final now = DateTime.now();
    final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final displayWeekStart = currentWeekStart.add(
      Duration(days: _weekOffset * 7),
    );
    final displayWeekDays = List.generate(
      7,
      (index) => displayWeekStart.add(Duration(days: index)),
    );

    // Formatear el rango de fechas
    final weekEnd = displayWeekStart.add(const Duration(days: 6));
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
    final weekLabel = _weekOffset == 0
        ? 'Semana actual'
        : _weekOffset == -1
        ? 'Semana anterior'
        : '${displayWeekStart.day} ${monthNames[displayWeekStart.month - 1]} - ${weekEnd.day} ${monthNames[weekEnd.month - 1]}';

    // Calcular total de horas de la semana mostrada
    double totalWeekHours = 0;
    for (var date in displayWeekDays) {
      if (!date.isAfter(now)) {
        totalWeekHours += _getDayHours(employee, state, date);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          // Header con navegación
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.calendar_view_week, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weekLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textMain,
                        ),
                      ),
                      Text(
                        'Total: ${totalWeekHours.toStringAsFixed(1)}h de 44h',
                        style: TextStyle(fontSize: 12, color: textSub),
                      ),
                    ],
                  ),
                ),
                // Botones de navegación
                Row(
                  children: [
                    // Ir a semana anterior
                    IconButton(
                      onPressed: _weekOffset > -12
                          ? () => setState(() => _weekOffset--)
                          : null,
                      icon: Icon(
                        Icons.chevron_left,
                        color: _weekOffset > -12 ? primaryColor : textSub,
                      ),
                      tooltip: 'Semana anterior',
                      visualDensity: VisualDensity.compact,
                    ),
                    // Ir a semana actual
                    if (_weekOffset != 0)
                      TextButton(
                        onPressed: () => setState(() => _weekOffset = 0),
                        child: Text(
                          'Hoy',
                          style: TextStyle(color: primaryColor, fontSize: 12),
                        ),
                      ),
                    // Ir a semana siguiente (solo si no es la actual)
                    IconButton(
                      onPressed: _weekOffset < 0
                          ? () => setState(() => _weekOffset++)
                          : null,
                      icon: Icon(
                        Icons.chevron_right,
                        color: _weekOffset < 0 ? primaryColor : textSub,
                      ),
                      tooltip: 'Semana siguiente',
                      visualDensity: VisualDensity.compact,
                    ),
                    // Botón expandir/colapsar historial
                    IconButton(
                      onPressed: () =>
                          setState(() => _showWeekHistory = !_showWeekHistory),
                      icon: Icon(
                        _showWeekHistory
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: primaryColor,
                      ),
                      tooltip: _showWeekHistory
                          ? 'Ocultar historial'
                          : 'Ver historial',
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Vista de la semana actual/seleccionada
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: displayWeekDays.map((date) {
                final isToday =
                    now.year == date.year &&
                    now.month == date.month &&
                    now.day == date.day;
                final dayHours = _getDayHours(employee, state, date);
                final isSaturday = date.weekday == DateTime.saturday;
                final isSunday = date.weekday == DateTime.sunday;
                final double targetHours = isSunday
                    ? 0.0
                    : (isSaturday ? 5.5 : 7.7);
                final isComplete = isSunday ? true : dayHours >= targetHours;
                final isFuture = date.isAfter(now);

                return Expanded(
                  child: _buildWeekDayCard(
                    date: date,
                    hours: dayHours,
                    targetHours: targetHours,
                    isToday: isToday,
                    isComplete: isComplete,
                    isFuture: isFuture,
                    isDark: isDark,
                    primaryColor: primaryColor,
                    textMain: textMain,
                    textSub: textSub,
                  ),
                );
              }).toList(),
            ),
          ),
          // Historial expandido de semanas anteriores
          if (_showWeekHistory) ...[
            Divider(height: 1, color: borderColor),
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historial de semanas',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Mostrar las últimas 4 semanas
                  ...List.generate(4, (index) {
                    final weekStart = currentWeekStart.subtract(
                      Duration(days: (index + 1) * 7),
                    );
                    final weekEndDate = weekStart.add(const Duration(days: 6));

                    // Calcular horas de esa semana
                    double weekTotal = 0;
                    for (int i = 0; i < 7; i++) {
                      final day = weekStart.add(Duration(days: i));
                      weekTotal += _getDayHours(employee, state, day);
                    }

                    final isSelected = _weekOffset == -(index + 1);

                    return InkWell(
                      onTap: () => setState(() => _weekOffset = -(index + 1)),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? primaryColor : borderColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: weekTotal >= 44
                                    ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                                    : const Color(0xFFF9A825).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                weekTotal >= 44
                                    ? Icons.check_circle
                                    : Icons.schedule,
                                color: weekTotal >= 44
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFF9A825),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${weekStart.day} ${monthNames[weekStart.month - 1]} - ${weekEndDate.day} ${monthNames[weekEndDate.month - 1]}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: textMain,
                                    ),
                                  ),
                                  Text(
                                    index == 0
                                        ? 'Semana pasada'
                                        : 'Hace ${index + 1} semanas',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textSub,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${weekTotal.toStringAsFixed(1)}h',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: weekTotal >= 44
                                        ? const Color(0xFF43A047)
                                        : const Color(0xFFFB8C00),
                                  ),
                                ),
                                Text(
                                  weekTotal >= 44
                                      ? '+${(weekTotal - 44).toStringAsFixed(1)}h extra'
                                      : '-${(44 - weekTotal).toStringAsFixed(1)}h',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: weekTotal >= 44
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFFF9A825),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right, color: textSub, size: 20),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeekDayCard({
    required DateTime date,
    required double hours,
    required double targetHours,
    required bool isToday,
    required bool isComplete,
    required bool isFuture,
    required bool isDark,
    required Color primaryColor,
    required Color textMain,
    required Color textSub,
  }) {
    final dayNames = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    final dayName = dayNames[date.weekday - 1];

    Color bgColor;
    Color textColor;
    if (isToday) {
      bgColor = primaryColor;
      textColor = Colors.white;
    } else if (isFuture) {
      bgColor = isDark ? const Color(0xFF1A2632) : const Color(0xFFF5F5F5);
      textColor = textSub;
    } else if (isComplete) {
      bgColor = const Color(0xFF2E7D32).withValues(alpha: 0.1);
      textColor = const Color(0xFF388E3C);
    } else if (hours > 0) {
      bgColor = const Color(0xFFF9A825).withValues(alpha: 0.1);
      textColor = const Color(0xFFF57C00);
    } else {
      bgColor = const Color(0xFFC62828).withValues(alpha: 0.1);
      textColor = const Color(0xFFD32F2F);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            dayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
              color: isToday ? Colors.white : textSub,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isToday ? Colors.white : textMain,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isFuture ? '-' : '${hours.toStringAsFixed(1)}h',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
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
              color: (isPositive ? const Color(0xFF2E7D32) : const Color(0xFFC62828)).withValues(
                alpha: 0.1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPositive ? Icons.add : Icons.remove,
              color: isPositive ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
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
              color: isPositive ? const Color(0xFF43A047) : const Color(0xFFE53935),
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

  double _getDayHours(Employee employee, EmployeesState state, DateTime date) {
    // Por ahora retornamos las horas base según el día
    // En una implementación completa, se buscarían los time entries
    final isSaturday = date.weekday == DateTime.saturday;
    final isSunday = date.weekday == DateTime.sunday;
    final isFuture = date.isAfter(DateTime.now());

    if (isSunday || isFuture) return 0;

    // Buscar ajustes para este día específico
    final dayAdjustments = state.timeAdjustments
        .where((a) => a.employeeId == employee.id)
        .where(
          (a) =>
              a.adjustmentDate.year == date.year &&
              a.adjustmentDate.month == date.month &&
              a.adjustmentDate.day == date.day,
        )
        .toList();

    double baseHours = isSaturday ? 5.5 : 7.7;

    for (var adj in dayAdjustments) {
      if (adj.type == 'overtime') {
        baseHours += adj.minutes / 60.0;
      } else {
        baseHours -= adj.minutes / 60.0;
      }
    }

    return baseHours > 0 ? baseHours : 0;
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

  Widget _buildHighlightCard({
    required ThemeData theme,
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    String? subtitle,
    double? progress,
    bool useCircularProgress = false,
  }) {
    final showProgress = progress != null;
    final clampedProgress = showProgress ? progress.clamp(0.0, 1.0) : 0.0;

    return Container(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (useCircularProgress && showProgress)
            Row(
              children: [
                SizedBox(
                  width: 70,
                  height: 70,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: clampedProgress,
                        strokeWidth: 8,
                        backgroundColor: color.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                      Text(
                        '${(clampedProgress * 100).round()}%',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle != null)
                        Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ],
          if (showProgress && !useCircularProgress) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: clampedProgress > 1.2 ? 1.2 : clampedProgress,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeekDayIndicator(
    ThemeData theme,
    DateTime date,
    List<EmployeeTimeEntry> entries,
    int dailyTargetMinutes,
    bool isToday,
  ) {
    final worked = entries.fold<int>(0, (sum, e) => sum + e.workedMinutes);
    final overtime = entries.fold<int>(0, (sum, e) => sum + e.overtimeMinutes);
    final deficit = entries.fold<int>(0, (sum, e) => sum + e.deficitMinutes);
    final progress = dailyTargetMinutes > 0 ? worked / dailyTargetMinutes : 0.0;
    final label = _weekdayLabel(date);
    final highlightColor = isToday
        ? theme.colorScheme.primary.withValues(alpha: 0.12)
        : Colors.white;
    final borderColor = isToday
        ? theme.colorScheme.primary.withValues(alpha: 0.3)
        : const Color(0xFF9E9E9E).withValues(alpha: 0.2);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlightColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text('${date.day}/${date.month}', style: theme.textTheme.labelSmall),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.5),
            minHeight: 6,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatMinutesLabel(worked),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            overtime > 0
                ? '+${_formatMinutesLabel(overtime)}'
                : deficit > 0
                ? '-${_formatMinutesLabel(deficit)}'
                : 'Completado',
            style: TextStyle(
              fontSize: 11,
              color: overtime > 0
                  ? const Color(0xFFF9A825)
                  : deficit > 0
                  ? const Color(0xFFC62828)
                  : const Color(0xFF9E9E9E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineEmpty(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF9E9E9E).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: const Color(0xFF9E9E9E), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: const Color(0xFF9E9E9E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeEntryTile(EmployeeTimeEntry entry, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF9E9E9E).withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                Helpers.formatDate(entry.entryDate),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _buildTimeStatusChip(entry.status),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildEntryInfoTag('Entrada', _formatTime(entry.checkIn)),
              _buildEntryInfoTag('Salida', _formatTime(entry.checkOut)),
              _buildEntryInfoTag(
                'Trabajadas',
                _formatMinutesLabel(entry.workedMinutes),
              ),
              if (entry.overtimeMinutes > 0)
                _buildEntryInfoTag(
                  'Extra',
                  _formatMinutesLabel(entry.overtimeMinutes),
                  icon: Icons.bolt,
                ),
              if (entry.deficitMinutes > 0)
                _buildEntryInfoTag(
                  'Déficit',
                  _formatMinutesLabel(entry.deficitMinutes),
                  icon: Icons.warning_amber_outlined,
                ),
            ],
          ),
          if (entry.notes != null && entry.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(entry.notes!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _buildEntryInfoTag(String label, String value, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF9E9E9E).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: const Color(0xFF616161)),
            const SizedBox(width: 4),
          ],
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          Text(value, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildTimeStatusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'aprobado':
        color = const Color(0xFF2E7D32);
        label = 'Aprobado';
        break;
      case 'rechazado':
        color = const Color(0xFFC62828);
        label = 'Rechazado';
        break;
      case 'pendiente':
        color = const Color(0xFFF9A825);
        label = 'Pendiente';
        break;
      default:
        color = const Color(0xFF607D8B);
        label = status.isNotEmpty
            ? '${status[0].toUpperCase()}${status.substring(1)}'
            : 'Registrado';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildEmployeeTaskTile(EmployeeTask task, ThemeData theme) {
    final estimated = task.estimatedTime ?? 0;
    final actual = task.actualTime ?? 0;
    final progress = estimated > 0 ? actual / estimated : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF9E9E9E).withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(task.categoryIcon, color: task.priorityColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildTaskStatusChip(task),
            ],
          ),
          if (task.description != null && task.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              task.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildEntryInfoTag('Prioridad', task.priorityLabel),
              if (task.dueDate != null)
                _buildEntryInfoTag(
                  'Entrega',
                  Helpers.formatDate(task.dueDate!),
                ),
              if (estimated > 0)
                _buildEntryInfoTag('Estimado', _formatMinutesLabel(estimated)),
              if (actual > 0)
                _buildEntryInfoTag(
                  'Real',
                  _formatMinutesLabel(actual),
                  icon: Icons.schedule,
                ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.5),
              minHeight: 6,
              backgroundColor: task.priorityColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(task.priorityColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskStatusChip(EmployeeTask task) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: task.statusColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        task.statusLabel,
        style: TextStyle(
          color: task.statusColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildAdjustmentTile(
    EmployeeTimeAdjustment adjustment,
    ThemeData theme,
  ) {
    final isPositive = adjustment.minutes > 0;
    final color = isPositive ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF9E9E9E).withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(isPositive ? Icons.add : Icons.remove, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Helpers.formatDate(adjustment.adjustmentDate),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${isPositive ? 'Suma' : 'Descuento'} ${_formatMinutesLabel(adjustment.minutes.abs())}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  adjustment.type.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.6,
                    color: const Color(0xFF757575),
                  ),
                ),
                if (adjustment.reason != null &&
                    adjustment.reason!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(adjustment.reason!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildAdjustmentStatusChip(adjustment.status),
        ],
      ),
    );
  }

  Widget _buildAdjustmentStatusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case 'aprobado':
        color = const Color(0xFF2E7D32);
        label = 'Aprobado';
        break;
      case 'rechazado':
        color = const Color(0xFFC62828);
        label = 'Rechazado';
        break;
      default:
        color = const Color(0xFFF9A825);
        label = 'Pendiente';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  String _weekdayLabel(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'Lun';
      case DateTime.tuesday:
        return 'Mar';
      case DateTime.wednesday:
        return 'Mié';
      case DateTime.thursday:
        return 'Jue';
      case DateTime.friday:
        return 'Vie';
      case DateTime.saturday:
        return 'Sáb';
      case DateTime.sunday:
        return 'Dom';
      default:
        return '';
    }
  }

  String _formatMinutesLabel(int minutes) {
    final absMinutes = minutes.abs();
    final hours = absMinutes ~/ 60;
    final mins = absMinutes % 60;

    if (hours > 0 && mins > 0) {
      return '${hours}h ${mins}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${mins}m';
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '--:--';
    final local = dateTime.toLocal();
    final hours = local.hour.toString().padLeft(2, '0');
    final minutes = local.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  Widget _buildEmployeeCard(ThemeData theme, Employee employee) {
    return const SizedBox.shrink();
  }

  /// Filtrar tareas según criterios seleccionados
  List<EmployeeTask> _getFilteredTasks(List<EmployeeTask> tasks) {
    return tasks.where((task) {
      // Filtro por búsqueda
      if (_taskSearchController.text.isNotEmpty) {
        final query = _taskSearchController.text.toLowerCase();
        final matchesTitle = task.title.toLowerCase().contains(query);
        final matchesId = task.id.toLowerCase().contains(query);
        final matchesCategory = task.category.toLowerCase().contains(query);
        if (!matchesTitle && !matchesId && !matchesCategory) return false;
      }

      // Filtro por estado
      if (_taskFilterStatus != 'todos') {
        final statusMap = {
          'pendiente': TaskStatus.pendiente,
          'en_progreso': TaskStatus.enProgreso,
          'completada': TaskStatus.completada,
          'cancelada': TaskStatus.cancelada,
        };
        if (task.status != statusMap[_taskFilterStatus]) return false;
      }

      // Filtro por categoría/ubicación
      if (_taskFilterCategory != 'todos') {
        if (task.category.toLowerCase() != _taskFilterCategory.toLowerCase()) {
          return false;
        }
      }

      // Filtro por asignado
      if (_taskFilterAssignee != 'todos') {
        if (task.employeeId != _taskFilterAssignee) return false;
      }

      // Filtro por rango de fechas
      if (_taskDateRange != null) {
        final taskDate = task.assignedDate;
        if (taskDate.isBefore(_taskDateRange!.start) ||
            taskDate.isAfter(_taskDateRange!.end)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Widget _buildTasksTab(ThemeData theme, EmployeesState state) {
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFFBDBDBD)
        : const Color(0xFF64748B);
    final textMuted = isDark ? const Color(0xFF757575) : const Color(0xFF94A3B8);

    return Container(
      color: bgColor,
      child: Column(
        children: [
          // Contenido con scroll
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  // Filtros compactos
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        // Búsqueda
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _taskSearchController,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Buscar tarea...',
                              hintStyle: TextStyle(
                                color: textMuted,
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: textMuted,
                                size: 20,
                              ),
                              suffixIcon: _taskSearchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        size: 16,
                                        color: textMuted,
                                      ),
                                      onPressed: () {
                                        _taskSearchController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: bgColor,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Filtros dropdown compactos
                        _buildCompactFilter(
                          'Estado',
                          _taskFilterStatus,
                          {
                            'todos': 'Todos',
                            'pendiente': 'Pendiente',
                            'en_progreso': 'En Progreso',
                            'completada': 'Completada',
                            'cancelada': 'Cancelada',
                          },
                          (v) => setState(() => _taskFilterStatus = v!),
                          theme,
                          borderColor,
                        ),
                        const SizedBox(width: 8),
                        _buildCompactFilter(
                          'Categoría',
                          _taskFilterCategory,
                          {
                            'todos': 'Todas',
                            'General': 'General',
                            'Produccion': 'Producción',
                            'Mantenimiento': 'Mantenimiento',
                            'Limpieza': 'Limpieza',
                            'Reportes': 'Reportes',
                          },
                          (v) => setState(() => _taskFilterCategory = v!),
                          theme,
                          borderColor,
                        ),
                        const SizedBox(width: 8),
                        _buildCompactFilter(
                          'Asignado',
                          _taskFilterAssignee,
                          {
                            'todos': 'Todos',
                            for (var e in state.activeEmployees)
                              e.id: e.fullName,
                          },
                          (v) => setState(() => _taskFilterAssignee = v!),
                          theme,
                          borderColor,
                        ),
                        const SizedBox(width: 8),
                        // Limpiar filtros
                        if (_hasActiveFilters())
                          IconButton(
                            icon: Icon(
                              Icons.filter_alt_off,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            tooltip: 'Limpiar filtros',
                            onPressed: _clearTaskFilters,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tabla de tareas
                  Builder(
                    builder: (context) {
                      final filteredTasks = _getFilteredTasks(state.tasks);

                      return Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF000000).withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Header tabla
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(15),
                                ),
                                border: Border(
                                  bottom: BorderSide(color: borderColor),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildTableHeader(
                                    'TAREA',
                                    textSecondary,
                                    flex: 3,
                                  ),
                                  _buildTableHeader(
                                    'UBICACIÓN',
                                    textSecondary,
                                    flex: 2,
                                  ),
                                  _buildTableHeader(
                                    'EQUIPO',
                                    textSecondary,
                                    flex: 2,
                                  ),
                                  _buildTableHeader(
                                    'ESTADO',
                                    textSecondary,
                                    flex: 2,
                                  ),
                                  _buildTableHeader(
                                    'TIEMPO',
                                    textSecondary,
                                    flex: 2,
                                  ),
                                  _buildTableHeader(
                                    'ACCIONES',
                                    textSecondary,
                                    flex: 2,
                                    align: TextAlign.right,
                                  ),
                                ],
                              ),
                            ),
                            // Filas
                            if (filteredTasks.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(48),
                                child: _buildEmptyState(
                                  icon: Icons.task_alt,
                                  title: state.tasks.isEmpty
                                      ? 'Sin tareas'
                                      : 'Sin resultados',
                                  subtitle: state.tasks.isEmpty
                                      ? 'Crea tareas para asignar a tu equipo'
                                      : 'No hay tareas que coincidan con los filtros',
                                  onAction: () => _showTaskDialog(),
                                  actionLabel: 'Crear Tarea',
                                ),
                              )
                            else
                              ...filteredTasks.map(
                                (task) => _buildTaskRow(
                                  theme,
                                  task,
                                  textMain,
                                  textSecondary,
                                  textMuted,
                                  borderColor,
                                  bgColor,
                                ),
                              ),
                            // Footer
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(15),
                                ),
                                border: Border(
                                  top: BorderSide(color: borderColor),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      text: 'Mostrando ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textSecondary,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: '${filteredTasks.length}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: textMain,
                                          ),
                                        ),
                                        TextSpan(text: ' de '),
                                        TextSpan(
                                          text: '${state.tasks.length}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: textMain,
                                          ),
                                        ),
                                        TextSpan(text: ' tareas'),
                                      ],
                                    ),
                                  ),
                                  if (filteredTasks.length !=
                                      state.tasks.length)
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _taskSearchController.clear();
                                          _taskFilterStatus = 'todos';
                                          _taskFilterCategory = 'todos';
                                          _taskFilterAssignee = 'todos';
                                          _taskDateRange = null;
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.filter_alt_off,
                                        size: 16,
                                      ),
                                      label: const Text('Quitar filtros'),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helpers para filtros compactos
  bool _hasActiveFilters() =>
      _taskSearchController.text.isNotEmpty ||
      _taskFilterStatus != 'todos' ||
      _taskFilterCategory != 'todos' ||
      _taskFilterAssignee != 'todos' ||
      _taskDateRange != null;

  void _clearTaskFilters() {
    setState(() {
      _taskSearchController.clear();
      _taskFilterStatus = 'todos';
      _taskFilterCategory = 'todos';
      _taskFilterAssignee = 'todos';
      _taskDateRange = null;
    });
  }

  Widget _buildCompactFilter(
    String label,
    String value,
    Map<String, String> options,
    void Function(String?) onChanged,
    ThemeData theme,
    Color borderColor,
  ) {
    final isActive = value != 'todos';
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      tooltip: label,
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? theme.colorScheme.primary : borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isActive ? (options[value] ?? value) : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
      itemBuilder: (ctx) => options.entries
          .map(
            (e) => PopupMenuItem(
              value: e.key,
              child: Row(
                children: [
                  if (e.key == value)
                    Icon(
                      Icons.check,
                      size: 16,
                      color: theme.colorScheme.primary,
                    )
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(e.value, style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildFilterButton(
    String label,
    Color textColor,
    Color borderColor,
    Color bgColor,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 18, color: textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(
    String text,
    Color color, {
    int flex = 1,
    TextAlign align = TextAlign.left,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPaginationButton(IconData icon, Color borderColor) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF9E9E9E)),
      ),
    );
  }

  Widget _buildTaskRow(
    ThemeData theme,
    EmployeeTask task,
    Color textMain,
    Color textSecondary,
    Color textMuted,
    Color borderColor,
    Color bgColor,
  ) {
    final employee = ref
        .read(employeesProvider)
        .employees
        .where((e) => e.id == task.employeeId)
        .firstOrNull;

    return InkWell(
      onTap: () => _showTaskDialog(task: task),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: borderColor.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          children: [
            // Tarea
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID: #TK-${task.id.substring(0, 4).toUpperCase()}',
                    style: TextStyle(
                      fontSize: 11,
                      color: textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Ubicación
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.location_on,
                      size: 16,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.category,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Equipo
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.1,
                    ),
                    backgroundImage: employee?.photoUrl != null
                        ? NetworkImage(employee!.photoUrl!)
                        : null,
                    child: employee?.photoUrl == null
                        ? Text(
                            employee?.initials ?? '?',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            // Estado
            Expanded(
              flex: 2,
              child: _buildStatusBadge(
                task.status,
                task.statusLabel,
                task.statusColor,
              ),
            ),
            // Tiempo
            Expanded(flex: 2, child: _buildTimeCell(task, textSecondary)),
            // Acciones
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Cambiar estado
                  PopupMenuButton<TaskStatus>(
                    tooltip: 'Cambiar estado',
                    icon: Icon(Icons.more_vert, color: textSecondary, size: 20),
                    onSelected: (newStatus) async {
                      if (newStatus == TaskStatus.completada) {
                        await ref
                            .read(employeesProvider.notifier)
                            .completeTask(task.id);
                      } else {
                        final updatedTask = EmployeeTask(
                          id: task.id,
                          employeeId: task.employeeId,
                          employeeName: task.employeeName,
                          title: task.title,
                          description: task.description,
                          assignedDate: task.assignedDate,
                          dueDate: task.dueDate,
                          completedDate: newStatus == TaskStatus.completada
                              ? DateTime.now()
                              : null,
                          status: newStatus,
                          priority: task.priority,
                          category: task.category,
                          estimatedTime: task.estimatedTime,
                          actualTime: task.actualTime,
                          activityId: task.activityId,
                          notes: task.notes,
                          createdAt: task.createdAt,
                          updatedAt: DateTime.now(),
                          assignedBy: task.assignedBy,
                        );
                        await ref
                            .read(employeesProvider.notifier)
                            .updateTask(updatedTask);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: TaskStatus.pendiente,
                        child: Row(
                          children: [
                            Icon(Icons.pending, color: const Color(0xFFF9A825), size: 18),
                            const SizedBox(width: 8),
                            const Text('Pendiente'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: TaskStatus.enProgreso,
                        child: Row(
                          children: [
                            Icon(
                              Icons.play_circle,
                              color: const Color(0xFF1565C0),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Text('En Progreso'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: TaskStatus.completada,
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: const Color(0xFF2E7D32),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Text('Completada'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: TaskStatus.cancelada,
                        child: Row(
                          children: [
                            Icon(Icons.cancel, color: const Color(0xFFC62828), size: 18),
                            const SizedBox(width: 8),
                            const Text('Cancelar'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Eliminar
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: const Color(0xFFE57373),
                      size: 20,
                    ),
                    tooltip: 'Eliminar tarea',
                    onPressed: () => _confirmDeleteTask(task),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTask(EmployeeTask task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Tarea'),
        content: Text('¿Estás seguro de eliminar la tarea "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref
                  .read(employeesProvider.notifier)
                  .deleteTask(task.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Tarea eliminada' : 'Error al eliminar',
                    ),
                    backgroundColor: success ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                  ),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(TaskStatus status, String label, Color color) {
    final bgColor = color.withValues(alpha: 0.1);
    final borderColor = color.withValues(alpha: 0.2);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == TaskStatus.completada)
                Icon(Icons.check_circle, size: 14, color: color)
              else
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeCell(EmployeeTask task, Color textColor) {
    if (task.status == TaskStatus.completada) {
      return Row(
        children: [
          Text(
            'A tiempo',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2E7D32),
            ),
          ),
        ],
      );
    }

    final dueDate = task.dueDate;
    if (dueDate == null) {
      return Row(
        children: [
          Icon(Icons.schedule, size: 16, color: textColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Sin fecha',
              style: TextStyle(fontSize: 13, color: textColor),
            ),
          ),
        ],
      );
    }

    final now = DateTime.now();
    final diff = dueDate.difference(now);

    if (diff.isNegative) {
      return Row(
        children: [
          Icon(Icons.warning, size: 16, color: const Color(0xFFC62828)),
          const SizedBox(width: 6),
          Text(
            '-${diff.inHours.abs()}h (Venció)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFC62828),
            ),
          ),
        ],
      );
    }

    final days = diff.inDays;
    final hours = diff.inHours;
    final text = days > 0 ? '$days días restantes' : '${hours}h restantes';

    return Row(
      children: [
        Icon(Icons.schedule, size: 16, color: textColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComplexityBars(
    TaskPriority priority,
    Color textColor,
    Color primaryColor,
  ) {
    int filled;
    String label;
    Color barColor;

    switch (priority) {
      case TaskPriority.baja:
        filled = 1;
        label = 'Baja';
        barColor = primaryColor.withValues(alpha: 0.4);
        break;
      case TaskPriority.media:
        filled = 3;
        label = 'Media';
        barColor = primaryColor.withValues(alpha: 0.6);
        break;
      case TaskPriority.alta:
        filled = 4;
        label = 'Alta';
        barColor = primaryColor;
        break;
      case TaskPriority.urgente:
        filled = 5;
        label = 'Urgente';
        barColor = const Color(0xFFC62828);
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        const SizedBox(width: 8),
        Row(
          children: List.generate(5, (i) {
            return Container(
              width: 5,
              height: 16,
              margin: const EdgeInsets.only(left: 2),
              decoration: BoxDecoration(
                color: i < filled
                    ? barColor
                    : const Color(0xFF9E9E9E).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTaskCard(ThemeData theme, EmployeeTask task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: task.priorityColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getTaskCategoryIcon(task.category),
            color: task.priorityColor,
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: task.status == TaskStatus.completada
                ? TextDecoration.lineThrough
                : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person, size: 14, color: const Color(0xFF9E9E9E)),
                const SizedBox(width: 4),
                Text(task.employeeName ?? 'Sin asignar'),
                const SizedBox(width: 16),
                Icon(Icons.schedule, size: 14, color: const Color(0xFF9E9E9E)),
                const SizedBox(width: 4),
                Text(_formatDate(task.assignedDate)),
              ],
            ),
            if (task.description != null) ...[
              const SizedBox(height: 4),
              Text(
                task.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: task.statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                task.statusLabel,
                style: TextStyle(
                  color: task.statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (task.status != TaskStatus.completada &&
                task.status != TaskStatus.cancelada) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.check_circle, color: const Color(0xFF2E7D32)),
                onPressed: () => _completeTask(task),
                tooltip: 'Completar',
              ),
            ],
            PopupMenuButton<String>(
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Editar')),
                const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _showTaskDialog(task: task);
                } else if (value == 'delete') {
                  _confirmDeleteTask(task);
                }
              },
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

  void _showTimeAdjustmentDialog({
    required Employee employee,
    required bool isPositive,
  }) {
    final hoursController = TextEditingController(text: '1.0');
    final reasonController = TextEditingController();
    String selectedType = isPositive ? 'overtime' : 'descuento';
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9E9E9E).withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  Text(
                    '${isPositive ? 'Sumar' : 'Descontar'} horas - ${employee.fullName}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: hoursController,
                    decoration: InputDecoration(
                      labelText:
                          'Horas ${isPositive ? 'extra' : 'a descontar'}',
                      prefixIcon: const Icon(Icons.timer),
                      helperText:
                          'Usa decimales para minutos (ej. 1.5 = 1h 30m)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de ajuste',
                      prefixIcon: Icon(Icons.category),
                    ),
                    items:
                        (isPositive
                                ? const [
                                    DropdownMenuItem(
                                      value: 'overtime',
                                      child: Text('Horas extra'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'compensacion',
                                      child: Text('Compensación'),
                                    ),
                                  ]
                                : const [
                                    DropdownMenuItem(
                                      value: 'descuento',
                                      child: Text('Descuento'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'licencia',
                                      child: Text('Licencia / Permiso'),
                                    ),
                                  ])
                            .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => selectedType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 30),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha del ajuste',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(Helpers.formatDate(selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Motivo (opcional)',
                      prefixIcon: Icon(Icons.subject),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final hours = double.tryParse(
                              hoursController.text.trim(),
                            );
                            if (hours == null || hours <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Ingresa un número de horas válido',
                                  ),
                                  backgroundColor: const Color(0xFFC62828),
                                ),
                              );
                              return;
                            }

                            final minutes =
                                (hours * 60).round() * (isPositive ? 1 : -1);
                            Navigator.pop(context);

                            final currentSummary = ref
                                .read(employeesProvider)
                                .currentTimeSummary;

                            final success = await ref
                                .read(employeesProvider.notifier)
                                .createTimeAdjustment(
                                  employeeId: employee.id,
                                  minutes: minutes,
                                  type: selectedType,
                                  date: selectedDate,
                                  reason: reasonController.text.isNotEmpty
                                      ? reasonController.text
                                      : null,
                                  notes: null,
                                  timesheetId: currentSummary?.timesheetId,
                                );

                            if (!mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? 'Ajuste registrado'
                                      : 'No se pudo registrar el ajuste',
                                ),
                                backgroundColor: success
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFC62828),
                              ),
                            );
                          },
                          child: Text(
                            isPositive ? 'Sumar horas' : 'Descontar horas',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

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
      text: employee?.salary?.toString() ?? '',
    );
    String selectedDepartment = employee?.department ?? 'Producción';
    EmployeeStatus selectedStatus = employee?.status ?? EmployeeStatus.activo;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Editar Empleado' : 'Nuevo Empleado'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  const SizedBox(height: 16),
                  TextField(
                    controller: salaryController,
                    decoration: const InputDecoration(
                      labelText: 'Salario',
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                    keyboardType: TextInputType.number,
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

                final newEmployee = Employee(
                  id: employee?.id ?? '',
                  firstName: firstNameController.text,
                  lastName: lastNameController.text,
                  position: positionController.text,
                  department: selectedDepartment,
                  phone: phoneController.text.isEmpty
                      ? null
                      : phoneController.text,
                  email: emailController.text.isEmpty
                      ? null
                      : emailController.text,
                  salary: double.tryParse(salaryController.text),
                  status: selectedStatus,
                  hireDate: employee?.hireDate ?? DateTime.now(),
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

  void _showTaskDialog({Employee? employee, EmployeeTask? task}) {
    final isEditing = task != null;
    final titleController = TextEditingController(text: task?.title ?? '');
    final descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    // Soporte para múltiples empleados
    List<String> selectedEmployeeIds = [];
    if (task?.employeeId != null) {
      selectedEmployeeIds = [task!.employeeId];
    } else if (employee != null) {
      selectedEmployeeIds = [employee.id];
    }
    TaskPriority selectedPriority = task?.priority ?? TaskPriority.media;
    String selectedCategory = task?.category ?? 'General';
    DateTime selectedDate = task?.assignedDate ?? DateTime.now();
    DateTime? dueDate = task?.dueDate;

    final employees = ref.read(employeesProvider).activeEmployees;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Editar Tarea' : 'Nueva Tarea'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Título de la tarea *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  // Selector múltiple de empleados
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Asignar a *',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Chips de empleados seleccionados
                        if (selectedEmployeeIds.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: selectedEmployeeIds.map((id) {
                              final emp = employees.firstWhere(
                                (e) => e.id == id,
                                orElse: () => employees.first,
                              );
                              return Chip(
                                avatar: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.2),
                                  child: Text(
                                    emp.initials,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                label: Text(
                                  emp.fullName,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () => setDialogState(
                                  () => selectedEmployeeIds.remove(id),
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 8),
                        // Botón para agregar más
                        InkWell(
                          onTap: () async {
                            await showDialog(
                              context: context,
                              builder: (ctx) => StatefulBuilder(
                                builder: (ctx, setInnerState) => AlertDialog(
                                  title: const Text('Seleccionar Empleados'),
                                  content: SizedBox(
                                    width: 300,
                                    height: 300,
                                    child: ListView.builder(
                                      itemCount: employees.length,
                                      itemBuilder: (ctx, i) {
                                        final emp = employees[i];
                                        final isSelected = selectedEmployeeIds
                                            .contains(emp.id);
                                        return CheckboxListTile(
                                          value: isSelected,
                                          title: Text(emp.fullName),
                                          subtitle: Text(
                                            emp.position,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                          secondary: CircleAvatar(
                                            radius: 16,
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.1),
                                            child: Text(
                                              emp.initials,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          onChanged: (val) {
                                            setInnerState(() {
                                              if (val == true) {
                                                selectedEmployeeIds.add(emp.id);
                                              } else {
                                                selectedEmployeeIds.remove(
                                                  emp.id,
                                                );
                                              }
                                            });
                                          },
                                          dense: true,
                                        );
                                      },
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Listo'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            // Actualizar el diálogo padre después de cerrar
                            setDialogState(() {});
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                selectedEmployeeIds.isEmpty
                                    ? 'Seleccionar empleados'
                                    : 'Agregar más',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<TaskPriority>(
                          value: selectedPriority,
                          decoration: const InputDecoration(
                            labelText: 'Prioridad',
                            border: OutlineInputBorder(),
                          ),
                          items: TaskPriority.values.map((priority) {
                            return DropdownMenuItem(
                              value: priority,
                              child: Text(
                                priority.name[0].toUpperCase() +
                                    priority.name.substring(1),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() => selectedPriority = value!);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'General',
                              child: Text('General'),
                            ),
                            DropdownMenuItem(
                              value: 'Produccion',
                              child: Text('Producción'),
                            ),
                            DropdownMenuItem(
                              value: 'Mantenimiento',
                              child: Text('Mantenimiento'),
                            ),
                            DropdownMenuItem(
                              value: 'Limpieza',
                              child: Text('Limpieza'),
                            ),
                            DropdownMenuItem(
                              value: 'Logistica',
                              child: Text('Logística'),
                            ),
                            DropdownMenuItem(
                              value: 'Administrativo',
                              child: Text('Administrativo'),
                            ),
                            DropdownMenuItem(
                              value: 'Reportes',
                              child: Text('Reportes'),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() => selectedCategory = value!);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: const Text('Fecha Asignación'),
                          subtitle: Text(Helpers.formatDate(selectedDate)),
                          trailing: const Icon(Icons.calendar_today),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: const Color(0xFFBDBDBD)),
                          ),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null) {
                              setDialogState(() => selectedDate = date);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ListTile(
                          title: const Text('Fecha Límite'),
                          subtitle: Text(
                            dueDate != null
                                ? Helpers.formatDate(dueDate!)
                                : 'Sin fecha límite',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (dueDate != null)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () =>
                                      setDialogState(() => dueDate = null),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              const SizedBox(width: 4),
                              const Icon(Icons.event),
                            ],
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: dueDate != null
                                  ? const Color(0xFFF9A825)
                                  : const Color(0xFFBDBDBD),
                            ),
                          ),
                          tileColor: dueDate != null
                              ? const Color(0xFFF9A825).withValues(alpha: 0.05)
                              : null,
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate:
                                  dueDate ??
                                  DateTime.now().add(const Duration(days: 7)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null) {
                              setDialogState(() => dueDate = date);
                            }
                          },
                        ),
                      ),
                    ],
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
            FilledButton(
              onPressed: () async {
                if (titleController.text.isEmpty ||
                    selectedEmployeeIds.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Completa los campos obligatorios'),
                    ),
                  );
                  return;
                }

                Navigator.pop(context);

                if (isEditing) {
                  // Si es edición, solo actualizar la tarea existente con el primer empleado
                  final selectedEmp = employees.firstWhere(
                    (e) => e.id == selectedEmployeeIds.first,
                    orElse: () => employees.first,
                  );
                  final updatedTask = EmployeeTask(
                    id: task.id,
                    employeeId: selectedEmployeeIds.first,
                    employeeName: selectedEmp.fullName,
                    title: titleController.text,
                    description: descriptionController.text.isEmpty
                        ? null
                        : descriptionController.text,
                    assignedDate: selectedDate,
                    dueDate: dueDate,
                    status: task.status,
                    priority: selectedPriority,
                    category: selectedCategory,
                    createdAt: task.createdAt,
                    updatedAt: DateTime.now(),
                  );
                  await ref
                      .read(employeesProvider.notifier)
                      .updateTask(updatedTask);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Tarea actualizada'),
                        backgroundColor: const Color(0xFF2E7D32),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } else {
                  // Si es nueva, crear una tarea por cada empleado seleccionado
                  bool anySuccess = false;
                  for (final empId in selectedEmployeeIds) {
                    final emp = employees.firstWhere(
                      (e) => e.id == empId,
                      orElse: () => employees.first,
                    );
                    final newTask = EmployeeTask(
                      id: '',
                      employeeId: empId,
                      employeeName: emp.fullName,
                      title: titleController.text,
                      description: descriptionController.text.isEmpty
                          ? null
                          : descriptionController.text,
                      assignedDate: selectedDate,
                      dueDate: dueDate,
                      status: TaskStatus.pendiente,
                      priority: selectedPriority,
                      category: selectedCategory,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    final created = await ref
                        .read(employeesProvider.notifier)
                        .createTask(newTask);
                    if (created != null) anySuccess = true;
                  }

                  if (mounted) {
                    if (anySuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            selectedEmployeeIds.length > 1
                                ? '✅ Tarea asignada a ${selectedEmployeeIds.length} empleados'
                                : '✅ Tarea creada exitosamente',
                          ),
                          backgroundColor: const Color(0xFF2E7D32),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('❌ Error al crear la tarea'),
                          backgroundColor: const Color(0xFFC62828),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                }
              },
              child: Text(isEditing ? 'Guardar' : 'Crear'),
            ),
          ],
        ),
      ),
    );
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
          action: SnackBarAction(
            label: 'Crear Tarea',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              _tabController.animateTo(1); // Ir a pestaña de Tareas
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) _showTaskDialog();
              });
            },
          ),
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
            content: SizedBox(
              width: 500,
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
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showTaskDialog(employee: employee);
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Crear Nueva Tarea'),
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
        builder: (context, setDialogState) => Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(employeesProvider);
            final payrollState = ref.watch(payrollProvider);
            final allTasks = state.selectedEmployeeTasks;
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            final borderColor = isDark
                ? const Color(0xFF334155)
                : const Color(0xFFE2E8F0);

            // Préstamos activos del empleado
            final employeeLoans = payrollState.loans
                .where(
                  (l) => l.employeeId == employee.id && l.status == 'activo',
                )
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
            final selectedDayHours =
                hoursByDay[selectedDayIndex] ??
                ((selectedDayIndex == 5) ? saturdayBase : weekdayBase);
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
                        Text(
                          employee.position,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
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
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                  color: const Color(0xFFF9A825).withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFF9A825).withValues(alpha: 0.3),
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
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Cuota ${loan.paidInstallments + 1}/${loan.installments} • ${Helpers.formatCurrency(loan.installmentAmount)}/mes',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: const Color(0xFF757575),
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
                                                      color: const Color(0xFF9E9E9E),
                                                    ),
                                                  ),
                                                  Text(
                                                    Helpers.formatCurrency(
                                                      loan.remainingAmount,
                                                    ),
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: const Color(0xFFF57C00),
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
                                              backgroundColor:
                                                  const Color(0xFFE0E0E0),
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
                                            foregroundColor: const Color(0xFFC62828),
                                            side: const BorderSide(
                                              color: const Color(0xFFC62828),
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
                                            backgroundColor: const Color(0xFF2E7D32),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
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
                                  final isSelected =
                                      dayIndex == selectedDayIndex;
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
                                                ? const Color(0xFF2E7D32).withValues(
                                                    alpha: 0.1,
                                                  )
                                                : hasDeduction
                                                ? const Color(0xFFF9A825).withValues(
                                                    alpha: 0.1,
                                                  )
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
            backgroundColor: hours > 0 ? const Color(0xFF2E7D32) : const Color(0xFFF9A825),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFC62828)),
        );
      }
    }
  }

  void _addHours(Employee employee, double hours) async {
    final minutes = (hours * 60).round();
    final type = hours > 0 ? 'overtime' : 'deduction';

    try {
      await ref
          .read(employeesProvider.notifier)
          .createTimeAdjustment(
            employeeId: employee.id,
            minutes: minutes.abs(),
            type: type,
            date: DateTime.now(),
            reason: hours > 0 ? 'Hora extra manual' : 'Descuento manual',
          );

      // Recargar datos del empleado
      await ref.read(employeesProvider.notifier).loadTimeOverview(employee.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hours > 0
                  ? '✅ +${hours}h añadida a ${employee.firstName}'
                  : '✅ ${hours}h descontada de ${employee.firstName}',
            ),
            backgroundColor: hours > 0 ? const Color(0xFF2E7D32) : const Color(0xFFF9A825),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFC62828)),
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
          backgroundColor: const Color(0xFFF9A825),
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
                            color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.fact_check,
                            color: const Color(0xFF2E7D32),
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
                            color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$quinLabel ${monthNames[quinStart.month]}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1565C0),
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
                            _buildCalendarLegendDot(const Color(0xFF2E7D32), 'OK'),
                            const SizedBox(width: 6),
                            _buildCalendarLegendDot(const Color(0xFFC62828), 'Falta'),
                            const SizedBox(width: 6),
                            _buildCalendarLegendDot(const Color(0xFFF9A825), 'Permiso'),
                            const SizedBox(width: 6),
                            _buildCalendarLegendDot(const Color(0xFF7B1FA2), 'Incap.'),
                            const SizedBox(width: 6),
                            _buildCalendarLegendDot(const Color(0xFFE0E0E0), 'Pend.'),
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
                                absentCount > 0 ? const Color(0xFFC62828) : const Color(0xFF9E9E9E),
                              ),
                              const SizedBox(width: 4),
                              _buildAttendanceSummaryChip(
                                Icons.event_busy,
                                '$permisoCount',
                                permisoCount > 0 ? const Color(0xFFF9A825) : const Color(0xFF9E9E9E),
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
                                color: const Color(0xFFF9A825).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber,
                                    color: const Color(0xFFF9A825),
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Domingo — día de descanso',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: const Color(0xFFF9A825),
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
                                    color: const Color(0xFF9E9E9E).withValues(alpha: 0.1),
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
                                color: const Color(0xFFF9A825).withValues(alpha: 0.06),
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
                                        color: const Color(0xFFC62828),
                                      ),
                                    ),
                                  if (permisoCount > 0)
                                    Text(
                                      '• Permiso: ${hoursToDeduct}h + pierde bono',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFFF9A825),
                                      ),
                                    ),
                                  if (incapacidadCount > 0)
                                    Text(
                                      '• Incapacidad: días 1-3=100%, 4+=66.33%',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF7B1FA2),
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
                  color: isPermiso ? const Color(0xFFF9A825) : const Color(0xFF7B1FA2),
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
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Empleado
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isPermiso ? const Color(0xFFF9A825) : const Color(0xFF7B1FA2))
                          .withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 18, color: const Color(0xFF757575)),
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
                      color: (isPermiso ? const Color(0xFFF9A825) : const Color(0xFF7B1FA2))
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.timer,
                          size: 16,
                          color: isPermiso ? const Color(0xFFF9A825) : const Color(0xFF7B1FA2),
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
                  backgroundColor: isPermiso ? const Color(0xFFF9A825) : const Color(0xFF7B1FA2),
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
              color: isSelected ? const Color(0xFF1565C0).withValues(alpha: 0.2) : bgColor,
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
        Text(label, style: TextStyle(fontSize: 9, color: const Color(0xFF757575))),
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

  Widget _buildLegendItem(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 10, color: color)),
      ],
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
              color: isActive ? color : const Color(0xFF9E9E9E).withValues(alpha: 0.2),
              width: isActive ? 1.5 : 0.5,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive ? color : const Color(0xFF9E9E9E).withValues(alpha: 0.3),
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

  IconData _attendanceStatusIcon(String status) {
    switch (status) {
      case 'presente':
        return Icons.check_circle;
      case 'ausente':
        return Icons.cancel;
      case 'permiso':
        return Icons.event_busy;
      case 'incapacidad':
        return Icons.local_hospital;
      default:
        return Icons.help;
    }
  }

  String _attendanceStatusLabel(String status) {
    switch (status) {
      case 'presente':
        return 'Presente';
      case 'ausente':
        return 'Ausente';
      case 'permiso':
        return 'Permiso';
      case 'incapacidad':
        return 'Incapacidad';
      default:
        return status;
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
            backgroundColor: const Color(0xFFF9A825),
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
            backgroundColor: const Color(0xFF2E7D32),
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
          backgroundColor: failCount == 0 ? const Color(0xFF2E7D32) : const Color(0xFFF9A825),
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
      );

      // Filtrar solo los que son "Descuento dominical" dentro del rango
      return adjustments.where((a) {
        if (a.reason == null) return false;
        final inRange =
            !a.adjustmentDate.isBefore(quinStart) &&
            !a.adjustmentDate.isAfter(quinEnd);
        return inRange &&
            a.reason!.toLowerCase().contains('descuento dominical');
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

  List<Widget> _buildWeekDayRows(
    Map<int, double> hoursByDay,
    int currentDay,
    ThemeData theme,
  ) {
    final days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final targetPerDay = 44.0 / 6; // ~7.33 horas por día laboral (Lun-Sáb)

    return List.generate(7, (index) {
      final dayNum = index + 1;
      final hours = hoursByDay[dayNum] ?? 0;
      final isToday = dayNum == currentDay;
      final isPast = dayNum < currentDay;
      final isSunday = dayNum == 7;
      final target = isSunday ? 0.0 : targetPerDay;
      final progress = target > 0 ? (hours / target).clamp(0.0, 1.0) : 0.0;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: isToday
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                days[index],
                style: TextStyle(
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                  color: isToday
                      ? theme.colorScheme.primary
                      : isPast
                      ? const Color(0xFF616161)
                      : const Color(0xFFBDBDBD),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEEEE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: hours >= target && target > 0
                            ? const Color(0xFF2E7D32)
                            : theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 45,
              child: Text(
                '${hours.toStringAsFixed(1)}h',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: isToday ? theme.colorScheme.primary : null,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTodayTimeLog(
    Employee employee,
    List<EmployeeTimeEntry> entries,
    DateTime now,
    ThemeData theme,
  ) {
    final todayEntries = entries
        .where(
          (e) =>
              e.entryDate.day == now.day &&
              e.entryDate.month == now.month &&
              e.entryDate.year == now.year,
        )
        .toList();

    if (todayEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time, size: 32, color: const Color(0xFFBDBDBD)),
            const SizedBox(height: 8),
            Text(
              'Sin registros hoy',
              style: TextStyle(color: const Color(0xFFBDBDBD)),
            ),
            const SizedBox(height: 4),
            Text(
              'Registra la entrada para comenzar',
              style: TextStyle(fontSize: 11, color: const Color(0xFFBDBDBD)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: todayEntries.length,
      itemBuilder: (context, index) {
        final entry = todayEntries[index];
        final checkIn = entry.checkIn;
        final checkOut = entry.checkOut;
        final isActive = checkIn != null && checkOut == null;
        final hoursWorked = entry.workedMinutes / 60.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF2E7D32).withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF2E7D32).withValues(alpha: 0.3)
                  : const Color(0xFFEEEEEE),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isActive ? Icons.play_circle : Icons.check_circle,
                color: isActive ? const Color(0xFF2E7D32) : const Color(0xFF9E9E9E),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.login, size: 14, color: const Color(0xFF2E7D32)),
                        const SizedBox(width: 4),
                        Text(
                          'Entrada: ${_formatTime(checkIn)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (checkOut != null) ...[
                          const SizedBox(width: 16),
                          Icon(Icons.logout, size: 14, color: const Color(0xFFC62828)),
                          const SizedBox(width: 4),
                          Text(
                            'Salida: ${_formatTime(checkOut)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isActive)
                      Text(
                        'En turno activo',
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFF2E7D32),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (hoursWorked > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${hoursWorked.toStringAsFixed(1)}h',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _registerCheckIn(Employee employee) async {
    final now = DateTime.now();

    try {
      await ref
          .read(employeesProvider.notifier)
          .registerTimeEntry(employeeId: employee.id, date: now, checkIn: now);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Entrada registrada para ${employee.fullName} a las ${_formatTime(now)}',
            ),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFC62828)),
        );
      }
    }
  }

  void _registerCheckOut(Employee employee, dynamic entry) async {
    final now = DateTime.now();
    final checkIn = entry.checkIn as DateTime;
    final hoursWorked = now.difference(checkIn).inMinutes / 60.0;

    try {
      await ref
          .read(employeesProvider.notifier)
          .updateTimeEntry(
            entryId: entry.id,
            checkOut: now,
            hoursWorked: hoursWorked,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Salida registrada para ${employee.fullName}. Trabajó ${hoursWorked.toStringAsFixed(1)} horas',
            ),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFC62828)),
        );
      }
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
                                  color: const Color(0xB3FFFFFF),
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
                                  color: const Color(0xB3FFFFFF),
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
                                                    ? const Color(0xFF2E7D32).withValues(
                                                        alpha: 0.1,
                                                      )
                                                    : const Color(0xFFF9A825).withValues(
                                                        alpha: 0.1,
                                                      ),
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
                                                  color: const Color(0xFF9E9E9E),
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
                                                    color: const Color(0xFFF9A825)
                                                        .withValues(
                                                          alpha: 0.15,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          3,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '+${(entry.overtimeMinutes / 60).toStringAsFixed(1)}h',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: const Color(0xFFFF8F00),
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
                                                      ? const Color(0xFF2E7D32).withValues(
                                                          alpha: 0.1,
                                                        )
                                                      : const Color(0xFF9E9E9E).withValues(
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
                                                        ? const Color(0xFF388E3C)
                                                        : const Color(0xFF757575),
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
            const Icon(Icons.edit_calendar, size: 14, color: const Color(0xB3FFFFFF)),
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

  void _completeTask(EmployeeTask task) async {
    await ref.read(employeesProvider.notifier).completeTask(task.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tarea completada'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    }
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
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 3: NÓMINA - Panel de Control Moderno (Sin Scroll)
  // ============================================================
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
        totalBonoCreadas += diferencia; // Usar la diferencia real (puede ser bono + HE)
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
                    style: TextStyle(color: const Color(0xFF757575), fontSize: 10),
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
                    Icon(Icons.arrow_upward, size: 8, color: const Color(0xFF43A047)),
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
                      color: const Color(0xFF9E9E9E),
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
                      color: const Color(0xFF9E9E9E),
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
                      color: const Color(0xFF9E9E9E),
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
                      color: const Color(0xFF9E9E9E),
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
                      color: const Color(0xFF9E9E9E),
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
                      color: const Color(0xFF9E9E9E),
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
                      color: const Color(0xFF9E9E9E),
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
                      color: const Color(0xFF9E9E9E),
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
                      color: const Color(0xFF9E9E9E),
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
                    showActions: false,
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
                            color: status == 'Pagado' ? const Color(0xFF757575) : null,
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
                                style: TextStyle(color: const Color(0xFF757575)),
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
                                : const Color(0xFFF9A825).withValues(alpha: 0.1),
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
                                        backgroundColor: const Color(0xFFC62828),
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
                    style: TextStyle(color: const Color(0xFF757575), fontSize: 12),
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
  Widget _buildLoansTab(
    ThemeData theme,
    EmployeesState empState,
    PayrollState payrollState,
  ) {
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
                    color: isPaid ? const Color(0xFF2E7D32) : const Color(0xFFF9A825),
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
                        style: TextStyle(color: const Color(0xFF757575), fontSize: 12),
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
                      style: TextStyle(color: const Color(0xFF757575), fontSize: 12),
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
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFC62828)),
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
            backgroundColor: const Color(0xFFC62828),
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
                            backgroundColor: const Color(0xFF7B1FA2).withValues(
                              alpha: 0.1,
                            ),
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
                      style: TextStyle(fontSize: 12, color: const Color(0xFF757575)),
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
                            color: const Color(0xFF7B1FA2).withValues(alpha: 0.3),
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
            backgroundColor: const Color(0xFFC62828),
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
                                color: const Color(0xFF2E7D32).withValues(alpha: 0.2),
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
                                backgroundColor: const Color(0xFFC62828),
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
            Icon(Icons.warning_amber_rounded, color: const Color(0xFFC62828)),
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
                  backgroundColor: success ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                ),
              );
            },
            icon: const Icon(Icons.delete_forever),
            label: const Text('Anular'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 5: INCAPACIDADES
  // ============================================================
  Widget _buildIncapacitiesTab(
    ThemeData theme,
    EmployeesState empState,
    PayrollState payrollState,
  ) {
    if (payrollState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Separar incapacidades de permisos
    final allActive = payrollState.activeIncapacities;
    final activeIncapacidades = allActive
        .where((i) => i.type != 'permiso')
        .toList();
    final activePermisos = allActive.where((i) => i.type == 'permiso').toList();

    final pastItems = payrollState.incapacities
        .where((i) => i.status != 'activa')
        .toList();
    final pastIncapacidades = pastItems
        .where((i) => i.type != 'permiso')
        .toList();
    final pastPermisos = pastItems.where((i) => i.type == 'permiso').toList();

    final now = DateTime.now();

    // Calcular días restantes de incapacidad
    int diasRestantesIncap = 0;
    for (final inc in activeIncapacidades) {
      final remaining = inc.endDate.difference(now).inDays + 1;
      if (remaining > 0) diasRestantesIncap += remaining;
    }
    int diasRestantesPerm = 0;
    for (final p in activePermisos) {
      final remaining = p.endDate.difference(now).inDays + 1;
      if (remaining > 0) diasRestantesPerm += remaining;
    }

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
                  'Incapacidades',
                  '${activeIncapacidades.length}',
                  Icons.local_hospital,
                  const Color(0xFF7B1FA2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPayrollSummaryCard(
                  'Días Restantes',
                  '$diasRestantesIncap',
                  Icons.calendar_today,
                  const Color(0xFFC62828),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPayrollSummaryCard(
                  'Permisos',
                  '${activePermisos.length}',
                  Icons.event_busy,
                  const Color(0xFFF9A825),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPayrollSummaryCard(
                  'Días Permiso',
                  '$diasRestantesPerm',
                  Icons.timer,
                  const Color(0xFFF9A825),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── INCAPACIDADES ACTIVAS ──
          Row(
            children: [
              Icon(Icons.local_hospital, size: 20, color: const Color(0xFF7B1FA2)),
              const SizedBox(width: 8),
              const Text(
                'Incapacidades Activas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (activeIncapacidades.isEmpty)
            _buildEmptyStateCard(
              'Sin incapacidades activas',
              Icons.check_circle,
              const Color(0xFF2E7D32),
            )
          else
            ...activeIncapacidades.map(
              (inc) => _buildIncapacityCard(inc, theme),
            ),

          const SizedBox(height: 20),

          // ── PERMISOS ACTIVOS ──
          Row(
            children: [
              Icon(Icons.event_busy, size: 20, color: const Color(0xFFF57C00)),
              const SizedBox(width: 8),
              const Text(
                'Permisos Activos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (activePermisos.isEmpty)
            _buildEmptyStateCard(
              'Sin permisos activos',
              Icons.check_circle,
              const Color(0xFF2E7D32),
            )
          else
            ...activePermisos.map((inc) => _buildIncapacityCard(inc, theme)),

          // ── HISTORIAL ──
          if (pastItems.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.history, size: 20, color: const Color(0xFF757575)),
                const SizedBox(width: 8),
                const Text(
                  'Historial',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...pastItems.map(
              (inc) => _buildIncapacityCard(inc, theme, isPast: true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard(String message, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: color.withValues(alpha: 0.5)),
              const SizedBox(width: 10),
              Text(
                message,
                style: TextStyle(color: const Color(0xFF9E9E9E), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncapacityCard(
    EmployeeIncapacity incapacity,
    ThemeData theme, {
    bool isPast = false,
  }) {
    final isPermiso = incapacity.type == 'permiso';
    final activeColor = isPermiso ? const Color(0xFFF9A825) : const Color(0xFF7B1FA2);
    final activeIcon = isPermiso ? Icons.event_busy : Icons.local_hospital;

    // Calcular días restantes
    final now = DateTime.now();
    final daysRemaining = incapacity.endDate.difference(now).inDays + 1;
    final daysElapsed = now.difference(incapacity.startDate).inDays;

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
                  backgroundColor: isPast
                      ? const Color(0xFF9E9E9E).withValues(alpha: 0.1)
                      : activeColor.withValues(alpha: 0.1),
                  child: Icon(
                    activeIcon,
                    color: isPast ? const Color(0xFF9E9E9E) : activeColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        incapacity.employeeName ?? 'Empleado',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        incapacity.typeLabel,
                        style: TextStyle(color: const Color(0xFF757575)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isPast
                            ? const Color(0xFF9E9E9E).withValues(alpha: 0.1)
                            : activeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${incapacity.daysTotal} días',
                        style: TextStyle(
                          color: isPast ? const Color(0xFF9E9E9E) : activeColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (!isPast && daysRemaining > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Quedan $daysRemaining día${daysRemaining > 1 ? "s" : ""}',
                          style: TextStyle(
                            fontSize: 10,
                            color: activeColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Barra de progreso
            if (!isPast) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (daysElapsed / incapacity.daysTotal).clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: const Color(0xFFEEEEEE),
                  valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const Divider(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Desde',
                        style: TextStyle(color: const Color(0xFF757575), fontSize: 12),
                      ),
                      Text(Helpers.formatDate(incapacity.startDate)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hasta',
                        style: TextStyle(color: const Color(0xFF757575), fontSize: 12),
                      ),
                      Text(Helpers.formatDate(incapacity.endDate)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pago',
                        style: TextStyle(color: const Color(0xFF757575), fontSize: 12),
                      ),
                      Text(
                        '${incapacity.paymentPercentage.toStringAsFixed(0)}%',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (incapacity.diagnosis != null &&
                incapacity.diagnosis!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Diagnóstico: ${incapacity.diagnosis}',
                style: TextStyle(color: const Color(0xFF616161), fontSize: 13),
              ),
            ],
            if (!isPast) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _endIncapacity(incapacity),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Terminar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIÁLOGOS DE NÓMINA - SISTEMA COMPLETO
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
              backgroundColor: const Color(0xFFC62828),
            ),
          );
        }
        return;
      }
    } else {
      // SIEMPRE recargar préstamos y conceptos para tener datos frescos
      await ref.read(payrollProvider.notifier).loadLoans();
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
    final defaultPeriod = defaultPeriods
        .where(
          (p) => p.periodType == 'quincenal' && p.periodNumber == defaultPNum,
        )
        .firstOrNull;

    Set<String> employeesWithPayroll = {};
    List<EmployeePayroll> existingPayrollsList = [];
    if (defaultPeriod != null) {
      final defaultPayrolls = await PayrollDatasource.getPayrolls(
        periodId: defaultPeriod.id,
      );
      employeesWithPayroll = defaultPayrolls.map((p) => p.employeeId).toSet();
      existingPayrollsList = defaultPayrolls;
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
            overtimePay = overtimeHours * hourlyRate * overtimeMultiplier;
            underHoursDiscount = underHours * hourlyRate;
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

          final totalEarnings = fortnightSalary + overtimePay + bonoAsistencia;
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
                                          color: const Color(0xFFF9A825),
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
                          final matchingPeriod = periods
                              .where(
                                (p) =>
                                    p.periodType == 'quincenal' &&
                                    p.periodNumber == pNum,
                              )
                              .firstOrNull;

                          Set<String> withPayroll = {};
                          List<EmployeePayroll> fetchedPayrolls = [];
                          if (matchingPeriod != null) {
                            final payrolls =
                                await PayrollDatasource.getPayrolls(
                                  periodId: matchingPeriod.id,
                                );
                            withPayroll = payrolls
                                .map((p) => p.employeeId)
                                .toSet();
                            fetchedPayrolls = payrolls;
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
                                Icon(Icons.info_outline, color: const Color(0xFFF9A825)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Todos los empleados ya tienen nómina en esta quincena.',
                                    style: TextStyle(color: const Color(0xFFF9A825)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              '¿Pagaste la nómina adelantada y quedaron días sin cubrir?',
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xDD000000),
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
                                  side: BorderSide(color: const Color(0xFF64B5F6)),
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
                                            color: const Color(0xFF7B1FA2),
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
                                    style: TextStyle(color: const Color(0xFF757575)),
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
                                    style: TextStyle(color: const Color(0xFF757575)),
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
                          color: const Color(0xFF1565C0).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.date_range,
                                  color: const Color(0xFF1565C0),
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
                                : const Color(0xFFF9A825).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: daysAbsent == 0
                                  ? const Color(0xFF2E7D32).withValues(alpha: 0.3)
                                  : const Color(0xFFF9A825).withValues(alpha: 0.3),
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
                                      ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
                                      : const Color(0xFFC62828).withValues(alpha: 0.1),
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

                    // Horas extras con selector de tipo (solo si hay horas extra)
                    if (selectedEmployee != null &&
                        overtimeHours > 0 &&
                        !isDailyPay)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF2E7D32).withValues(alpha: 0.2),
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
                                Text(
                                  'Horas Extra Detectadas',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF2E7D32),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '+${overtimeHours.toStringAsFixed(1)}h',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF388E3C),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
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
                              onChanged: (v) =>
                                  setState(() => overtimeType = v ?? 'normal'),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${overtimeHours.toStringAsFixed(1)}h × ${Helpers.formatCurrency(hourlyRate)} × ${getOvertimeMultiplier(overtimeType)}x',
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
                        ),
                      ),

                    // Descuento por horas faltantes (solo si faltan horas)
                    if (selectedEmployee != null &&
                        underHours > 0 &&
                        !isDailyPay)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9A825).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFF9A825).withValues(alpha: 0.2),
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
                                color: const Color(0xFFF9A825).withValues(alpha: 0.1),
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
                            color: const Color(0xFFF9A825).withValues(alpha: 0.3),
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
                            if (overtimePay > 0)
                              _buildPayrollSummaryRow(
                                'Horas Extra (${overtimeHours.toStringAsFixed(1)}h ${getOvertimeLabel(overtimeType)})',
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
                              backgroundColor: const Color(0xFFC62828),
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
                              backgroundColor: const Color(0xFFC62828),
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

                            // Intentar agregar BONO DE ASISTENCIA como detalle
                            if (bonoAsistencia > 0) {
                              final bonoConcept = currentPayrollState.concepts
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
                              } else {
                                print(
                                  '⚠️ Concepto BONO_ASISTENCIA no encontrado en BD',
                                );
                              }
                            }

                            // Agregar horas extras si hay
                            if (overtimeHours > 0 && !isDailyPay) {
                              await ref
                                  .read(payrollProvider.notifier)
                                  .addOvertimeHours(
                                    payrollId: payroll.id,
                                    hours: overtimeHours,
                                    type: overtimeType,
                                    hourlyRate: baseSalary / hoursPerMonth,
                                    skipReload: true,
                                  );
                            }

                            // Agregar descuento por horas faltantes si hay
                            if (underHours > 0 && !isDailyPay) {
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
                                backgroundColor: const Color(0xFFC62828),
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
                        backgroundColor: success ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
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
            backgroundColor: const Color(0xFFC62828),
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
                              color: hasEnough ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
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
                        const Icon(Icons.warning, color: const Color(0xFFC62828), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Saldo insuficiente. Falta: ${Helpers.formatCurrency(payroll.netPay - selectedAccountBalance)}',
                            style: const TextStyle(
                              color: const Color(0xFFC62828),
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
                      Icon(Icons.check_circle, color: const Color(0xFF2E7D32), size: 20),
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
                          backgroundColor: success ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
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
            backgroundColor: const Color(0xFFC62828),
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
      // Empezar desde la quincena actual o siguiente
      DateTime refDate = DateTime(now.year, now.month, now.day);
      for (int i = 0; i < 24; i++) {
        // 24 quincenas futuras (1 año)
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
    }

    int selectedStartQuincenaIndex = 0; // Por defecto la quincena actual

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
            content: SizedBox(
              width: 480,
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
                            color: const Color(0xFFF9A825).withValues(alpha: 0.3),
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
                                color: const Color(0xFFF9A825),
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
                      items: futureQuincenas
                          .take(12) // Mostrar 6 meses adelante
                          .toList()
                          .asMap()
                          .entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value['label'] as String),
                            ),
                          )
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
                          color: const Color(0xFF1565C0).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.2),
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
                            ...List.generate(
                              installments > 12 ? 12 : installments,
                              (i) {
                                final qIdx = selectedStartQuincenaIndex + i;
                                final qLabel = qIdx < futureQuincenas.length
                                    ? futureQuincenas[qIdx]['label'] as String
                                    : '...';
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
                                              ? const Color(0xFF2E7D32).withValues(
                                                  alpha: 0.2,
                                                )
                                              : const Color(0xFF1565C0).withValues(
                                                  alpha: 0.1,
                                                ),
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
                                        Helpers.formatCurrency(
                                          installmentAmount,
                                        ),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFFF57C00),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
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
                              color: const Color(0xFFC62828),
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
                            color: const Color(0xFF1565C0),
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
                onPressed:
                    (selectedEmployeeId == null ||
                        amount <= 0 ||
                        !hasEnoughBalance)
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

  void _showIncapacityDialog() {
    final employees = ref.read(employeesProvider).activeEmployees;
    String? selectedEmployeeId;
    String selectedType = 'enfermedad';
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 3));
    final diagnosisController = TextEditingController();
    final certificateController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final days = endDate.difference(startDate).inDays + 1;
          final isPermiso = selectedType == 'permiso';

          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isPermiso ? Icons.event_busy : Icons.local_hospital,
                  color: isPermiso ? const Color(0xFFF9A825) : const Color(0xFF7B1FA2),
                ),
                const SizedBox(width: 8),
                Text(isPermiso ? 'Nuevo Permiso' : 'Nueva Incapacidad'),
              ],
            ),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Empleado',
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: employees
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.id,
                              child: Text(e.fullName),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => selectedEmployeeId = value,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        prefixIcon: Icon(Icons.category),
                      ),
                      value: selectedType,
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
                        DropdownMenuItem(
                          value: 'maternidad',
                          child: Text('Licencia Maternidad'),
                        ),
                        DropdownMenuItem(
                          value: 'permiso',
                          child: Text('Permiso'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => selectedType = value!),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 30),
                                ),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (date != null) {
                                setState(() => startDate = date);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Fecha Inicio',
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(Helpers.formatDate(startDate)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: endDate,
                                firstDate: startDate,
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (date != null) setState(() => endDate = date);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Fecha Fin',
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(Helpers.formatDate(endDate)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9A825).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer, color: const Color(0xFFF9A825)),
                          const SizedBox(width: 8),
                          Text(
                            '$days días de incapacidad',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: certificateController,
                      decoration: const InputDecoration(
                        labelText: 'N° Certificado (opcional)',
                        prefixIcon: Icon(Icons.description),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: diagnosisController,
                      decoration: const InputDecoration(
                        labelText: 'Diagnóstico (opcional)',
                        prefixIcon: Icon(Icons.local_hospital),
                      ),
                      maxLines: 2,
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
              FilledButton(
                onPressed: () async {
                  if (selectedEmployeeId == null) return;

                  Navigator.pop(context);

                  final incapacity = EmployeeIncapacity(
                    id: '',
                    employeeId: selectedEmployeeId!,
                    type: selectedType,
                    startDate: startDate,
                    endDate: endDate,
                    daysTotal: days,
                    certificateNumber: certificateController.text.isNotEmpty
                        ? certificateController.text
                        : null,
                    diagnosis: diagnosisController.text.isNotEmpty
                        ? diagnosisController.text
                        : null,
                    paymentPercentage: selectedType == 'accidente_laboral'
                        ? 100
                        : 66.67,
                  );

                  final success = await ref
                      .read(payrollProvider.notifier)
                      .createIncapacity(incapacity);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success ? 'Incapacidad registrada' : 'Error',
                        ),
                        backgroundColor: success ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                      ),
                    );
                  }
                },
                child: const Text('Registrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _endIncapacity(EmployeeIncapacity incapacity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminar Incapacidad'),
        content: Text(
          '¿Terminar la incapacidad de ${incapacity.employeeName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(payrollProvider.notifier)
                  .endIncapacity(incapacity.id);
            },
            child: const Text('Terminar'),
          ),
        ],
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
