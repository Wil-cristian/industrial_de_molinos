// ignore_for_file: unused_element, unused_local_variable, unused_field
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/activity.dart';
import '../../data/providers/employees_provider.dart';
import '../../data/providers/payroll_provider.dart';
import '../../data/providers/activities_provider.dart';
import '../../data/datasources/payroll_datasource.dart';
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
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;

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
                _buildCompactStat(Icons.people, '${state.employees.length}', 'Emp', Colors.blue, isDark),
                const SizedBox(width: 4),
                _buildCompactStat(Icons.check_circle, '${state.activeEmployees.length}', 'Act', Colors.green, isDark),
                const SizedBox(width: 4),
                _buildCompactStat(Icons.pending_actions, '${state.tasks.where((t) => t.status == TaskStatus.pendiente || t.status == TaskStatus.enProgreso).length}', 'Tar', Colors.orange, isDark),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

  Widget _buildCompactStat(IconData icon, String value, String label, Color color, bool isDark) {
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
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton() {
    final labels = ['+Emp', '+Tar', '+Nóm', '+Prés', '+Inc'];
    final icons = [Icons.person_add, Icons.add_task, Icons.payments, Icons.attach_money, Icons.medical_services];

    return FilledButton.icon(
      onPressed: () {
        switch (_tabController.index) {
          case 0: _showEmployeeDialog(); break;
          case 1: _showTaskDialog(); break;
          case 2: _showCreatePayrollDialog(); break;
          case 3: _showLoanDialog(); break;
          case 4: _showIncapacityDialog(); break;
        }
      },
      icon: Icon(icons[_tabController.index], size: 14),
      label: Text(labels[_tabController.index], style: const TextStyle(fontSize: 12)),
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
          color: Colors.white.withValues(alpha: 0.15),
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
                      color: Colors.white.withValues(alpha: 0.8),
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
          subtitle: 'Agrega empleados para comenzar a gestionar\nsu tiempo, tareas y nómina',
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
                              child: _buildEmployeeHoursProgressBar(employee, state, theme),
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
        color: Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[700]),
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

  Widget _buildEmployeeHoursIndicator(Employee employee, EmployeesState state, ThemeData theme) {
    // Calcular horas de hoy para este empleado
    final now = DateTime.now();
    final todayEntries = state.timeEntries
        .where((e) => e.employeeId == employee.id)
        .where((e) => e.entryDate.day == now.day && e.entryDate.month == now.month && e.entryDate.year == now.year)
        .toList();
    
    final todayHours = todayEntries.fold(0.0, (sum, e) => sum + (e.workedMinutes / 60.0));
    
    // También sumar ajustes de hoy
    final todayAdjustments = state.timeAdjustments
        .where((a) => a.employeeId == employee.id)
        .where((a) => a.adjustmentDate.day == now.day && a.adjustmentDate.month == now.month && a.adjustmentDate.year == now.year)
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

  Widget _buildEmployeeHoursProgressBar(Employee employee, EmployeesState state, ThemeData theme) {
    // Horario: L-V 7:30-12:00 y 1:00-4:30 (-14min descanso) = 7.77h, Sáb 7:30-1:00 = 5.5h
    const double weekdayBase = 7.77; // (4.5h + 3.5h) - 14min = 7h 46min
    const double saturdayBase = 5.5;  // 7:30 a 1:00
    const double weeklyBase = 44.33;  // (5 x 7.77) + 5.5 = 44.33h
    double weekHours = weeklyBase;
    
    // Calcular ajustes de esta semana
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    
    final weekAdjustments = state.timeAdjustments
        .where((a) => a.employeeId == employee.id)
        .where((a) => a.adjustmentDate.isAfter(startOfWeek.subtract(const Duration(days: 1))))
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
        ? Colors.green
        : isUndertime 
            ? Colors.orange
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
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.remove, size: 16, color: Colors.red),
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
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.add, size: 16, color: Colors.green),
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
    final weekDays = List.generate(7, (index) => weekStart.add(Duration(days: index)));
    
    // Calcular horas de la semana
    final weekHours = _calculateEmployeeWeekHours(employee, state);
    const double weeklyBase = 44.0;
    final extraHours = weekHours > weeklyBase ? weekHours - weeklyBase : 0.0;
    final deficitHours = weekHours < weeklyBase ? weeklyBase - weekHours : 0.0;

    final pendingTasks = tasks
        .where((t) => t.status != TaskStatus.completada && t.status != TaskStatus.cancelada)
        .toList();
    final inProgressTasks = tasks.where((t) => t.status == TaskStatus.enProgreso).length;

    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = const Color(0xFF137FEC);
    final borderColor = isDark ? const Color(0xFF2D3748) : const Color(0xFFDBE0E6);
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
                  Text(employee.phone!, style: TextStyle(fontSize: 11, color: textSub)),
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
                      child: Icon(Icons.schedule, color: primaryColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Control de Horas Semanales',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textMain,
                            ),
                          ),
                          Text(
                            'Base: 44h/semana (L-V 7:30-4:30, S 7:30-1:00)',
                            style: TextStyle(fontSize: 12, color: textSub),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Control de +/- horas grande
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Botón restar
                    Material(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => _addHours(employee, -0.5),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          child: Icon(Icons.remove, size: 28, color: Colors.red[600]),
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
                            color: extraHours > 0 ? Colors.green[600] : (deficitHours > 0 ? Colors.orange[600] : textMain),
                          ),
                        ),
                        if (extraHours > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '+${extraHours.toStringAsFixed(1)}h extras',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[600],
                              ),
                            ),
                          )
                        else if (deficitHours > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '-${deficitHours.toStringAsFixed(1)}h faltantes',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[600],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 24),
                    // Botón sumar
                    Material(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => _addHours(employee, 0.5),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          child: Icon(Icons.add, size: 28, color: Colors.green[600]),
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
                  subtitle: activeLoans.isEmpty ? 'Sin préstamos' : '${activeLoans.length} en curso',
                  color: Colors.orange,
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
                  color: Colors.indigo,
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

          // === HISTORIAL DE SEMANAS (EXPANDIBLE) ===
          _buildWeekHistorySection(
            employee: employee,
            state: state,
            isDark: isDark,
            primaryColor: primaryColor,
            cardBg: cardBg,
            borderColor: borderColor,
            textMain: textMain,
            textSub: textSub,
          ),
          const SizedBox(height: 20),

          // === BOTONES DE ACCIÓN ===
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showAssignTaskDialog(employee),
                  icon: const Icon(Icons.add_task, size: 18),
                  label: const Text('Asignar Tarea'),
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showLoanDialog(employee: employee),
                  icon: const Icon(Icons.attach_money, size: 18),
                  label: const Text('Nuevo Préstamo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textMain,
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // === CALENDARIO DE ACTIVIDADES ===
          _buildActivitiesCalendar(
            isDark: isDark,
            primaryColor: primaryColor,
            cardBg: cardBg,
            borderColor: borderColor,
            textMain: textMain,
            textSub: textSub,
          ),
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
            ...adjustments.map((adj) => _buildAdjustmentCard(adj, isDark, cardBg, borderColor, textMain, textSub)),
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

  Widget _buildInfoItem(IconData icon, String label, String value, Color textMain, Color textSub) {
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
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
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
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textMain),
              ),
              Text(subtitle, style: TextStyle(fontSize: 11, color: textSub)),
            ],
          ),
        ),
      ),
    );
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
    final displayWeekStart = currentWeekStart.add(Duration(days: _weekOffset * 7));
    final displayWeekDays = List.generate(7, (index) => displayWeekStart.add(Duration(days: index)));
    
    // Formatear el rango de fechas
    final weekEnd = displayWeekStart.add(const Duration(days: 6));
    final monthNames = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
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
                      onPressed: _weekOffset > -12 ? () => setState(() => _weekOffset--) : null,
                      icon: Icon(Icons.chevron_left, color: _weekOffset > -12 ? primaryColor : textSub),
                      tooltip: 'Semana anterior',
                      visualDensity: VisualDensity.compact,
                    ),
                    // Ir a semana actual
                    if (_weekOffset != 0)
                      TextButton(
                        onPressed: () => setState(() => _weekOffset = 0),
                        child: Text('Hoy', style: TextStyle(color: primaryColor, fontSize: 12)),
                      ),
                    // Ir a semana siguiente (solo si no es la actual)
                    IconButton(
                      onPressed: _weekOffset < 0 ? () => setState(() => _weekOffset++) : null,
                      icon: Icon(Icons.chevron_right, color: _weekOffset < 0 ? primaryColor : textSub),
                      tooltip: 'Semana siguiente',
                      visualDensity: VisualDensity.compact,
                    ),
                    // Botón expandir/colapsar historial
                    IconButton(
                      onPressed: () => setState(() => _showWeekHistory = !_showWeekHistory),
                      icon: Icon(
                        _showWeekHistory ? Icons.expand_less : Icons.expand_more,
                        color: primaryColor,
                      ),
                      tooltip: _showWeekHistory ? 'Ocultar historial' : 'Ver historial',
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
                final isToday = now.year == date.year &&
                    now.month == date.month &&
                    now.day == date.day;
                final dayHours = _getDayHours(employee, state, date);
                final isSaturday = date.weekday == DateTime.saturday;
                final isSunday = date.weekday == DateTime.sunday;
                final double targetHours = isSunday ? 0.0 : (isSaturday ? 5.5 : 7.77);
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
                    final weekStart = currentWeekStart.subtract(Duration(days: (index + 1) * 7));
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
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                weekTotal >= 44 ? Icons.check_circle : Icons.schedule,
                                color: weekTotal >= 44 ? Colors.green : Colors.orange,
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
                                    index == 0 ? 'Semana pasada' : 'Hace ${index + 1} semanas',
                                    style: TextStyle(fontSize: 11, color: textSub),
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
                                    color: weekTotal >= 44 ? Colors.green[600] : Colors.orange[600],
                                  ),
                                ),
                                Text(
                                  weekTotal >= 44 
                                      ? '+${(weekTotal - 44).toStringAsFixed(1)}h extra'
                                      : '-${(44 - weekTotal).toStringAsFixed(1)}h',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: weekTotal >= 44 ? Colors.green : Colors.orange,
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
      bgColor = isDark ? const Color(0xFF1A2632) : Colors.grey.shade100;
      textColor = textSub;
    } else if (isComplete) {
      bgColor = Colors.green.withValues(alpha: 0.1);
      textColor = Colors.green[700]!;
    } else if (hours > 0) {
      bgColor = Colors.orange.withValues(alpha: 0.1);
      textColor = Colors.orange[700]!;
    } else {
      bgColor = Colors.red.withValues(alpha: 0.1);
      textColor = Colors.red[700]!;
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
              color: (isPositive ? Colors.green : Colors.red).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPositive ? Icons.add : Icons.remove,
              color: isPositive ? Colors.green : Colors.red,
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
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textMain),
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
              color: isPositive ? Colors.green[600] : Colors.red[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitiesCalendar({
    required bool isDark,
    required Color primaryColor,
    required Color cardBg,
    required Color borderColor,
    required Color textMain,
    required Color textSub,
  }) {
    final activitiesState = ref.watch(activitiesProvider);
    final activities = activitiesState.activities;
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    
    // Día de la semana en que empieza el mes (0 = Lunes en nuestra vista)
    final startWeekday = (firstDayOfMonth.weekday - 1) % 7;
    
    // Agrupar actividades por fecha
    final activitiesByDate = <String, List<Activity>>{};
    for (final activity in activities) {
      final key = activity.startDate.toIso8601String().split('T')[0];
      activitiesByDate.putIfAbsent(key, () => []).add(activity);
    }

    final dayNames = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    final monthNames = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];

    return InkWell(
      onTap: () => context.go('/calendar'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.calendar_month, color: primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${monthNames[now.month - 1]} ${now.year}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textMain,
                    ),
                  ),
                ),
                Icon(Icons.open_in_new, color: textSub, size: 18),
              ],
            ),
            const SizedBox(height: 16),
            // Días de la semana
            Row(
              children: dayNames.map((day) {
                return Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textSub,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            // Grilla del calendario
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.0,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: startWeekday + daysInMonth,
              itemBuilder: (context, index) {
                if (index < startWeekday) {
                  return const SizedBox.shrink();
                }
                
                final day = index - startWeekday + 1;
                final date = DateTime(now.year, now.month, day);
                final dateKey = date.toIso8601String().split('T')[0];
                final dayActivities = activitiesByDate[dateKey] ?? [];
                final isToday = now.day == day && now.month == date.month && now.year == date.year;
                final isFuture = date.isAfter(now);
                final isPast = date.isBefore(DateTime(now.year, now.month, now.day));
                
                // Colores según actividades
                Color? dotColor;
                if (dayActivities.isNotEmpty) {
                  final hasCompleted = dayActivities.any((a) => a.status == ActivityStatus.completed);
                  final hasPending = dayActivities.any((a) => a.status == ActivityStatus.pending);
                  final hasInProgress = dayActivities.any((a) => a.status == ActivityStatus.inProgress);
                  
                  if (hasCompleted && !hasPending && !hasInProgress) {
                    dotColor = Colors.green;
                  } else if (hasPending || hasInProgress) {
                    dotColor = isPast ? Colors.orange : primaryColor;
                  }
                }

                return Container(
                  decoration: BoxDecoration(
                    color: isToday 
                        ? primaryColor
                        : isFuture 
                            ? (isDark ? const Color(0xFF1A2632) : Colors.grey.shade100)
                            : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday 
                              ? Colors.white 
                              : isFuture 
                                  ? textSub
                                  : textMain,
                        ),
                      ),
                      if (dotColor != null)
                        Positioned(
                          bottom: 4,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            // Leyenda
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCalendarLegend(primaryColor, 'Pendiente', textSub),
                const SizedBox(width: 16),
                _buildCalendarLegend(Colors.green, 'Completada', textSub),
                const SizedBox(width: 16),
                _buildCalendarLegend(Colors.orange, 'Atrasada', textSub),
              ],
            ),
            // Próximas actividades
            if (activities.where((a) => 
              a.startDate.isAfter(now) && 
              a.startDate.isBefore(now.add(const Duration(days: 7)))
            ).isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: borderColor),
              const SizedBox(height: 12),
              Text(
                'Próximos 7 días',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textSub,
                ),
              ),
              const SizedBox(height: 8),
              ...activities
                  .where((a) => 
                    a.startDate.isAfter(now) && 
                    a.startDate.isBefore(now.add(const Duration(days: 7))))
                  .take(3)
                  .map((activity) => _buildActivityPreview(activity, textMain, textSub)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarLegend(Color color, String label, Color textSub) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: textSub)),
      ],
    );
  }

  Widget _buildActivityPreview(Activity activity, Color textMain, Color textSub) {
    final color = Color(int.parse(activity.color.replaceFirst('#', '0xFF')));
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textMain,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${activity.startDate.day}/${activity.startDate.month} • ${activity.activityType.name}',
                  style: TextStyle(fontSize: 10, color: textSub),
                ),
              ],
            ),
          ),
          Icon(
            activity.status == ActivityStatus.completed 
                ? Icons.check_circle 
                : Icons.schedule,
            size: 16,
            color: activity.status == ActivityStatus.completed 
                ? Colors.green 
                : color,
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
        .where((a) => a.adjustmentDate.isAfter(startOfWeek.subtract(const Duration(days: 1))))
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
        .where((a) => 
            a.adjustmentDate.year == date.year &&
            a.adjustmentDate.month == date.month &&
            a.adjustmentDate.day == date.day)
        .toList();
    
    double baseHours = isSaturday ? 5.5 : 7.77;
    
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
        border: Border.all(color: Colors.grey.shade300),
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
          else ...[          Icon(icon, color: color),
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
        : Colors.grey.withValues(alpha: 0.2);

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
                  ? Colors.orange
                  : deficit > 0
                  ? Colors.red
                  : Colors.grey,
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
        color: Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.grey, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
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
        border: Border.all(color: Colors.grey.withValues(alpha: 0.16)),
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
        color: Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.grey[700]),
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
        color = Colors.green;
        label = 'Aprobado';
        break;
      case 'rechazado':
        color = Colors.red;
        label = 'Rechazado';
        break;
      case 'pendiente':
        color = Colors.orange;
        label = 'Pendiente';
        break;
      default:
        color = Colors.blueGrey;
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

  Widget _buildMonthlyAttendanceCalendar(
    ThemeData theme,
    List<EmployeeTimeEntry> timeEntries,
  ) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    
    // Get the day of week the month starts on (1 = Monday in Dart)
    final startWeekday = (firstDayOfMonth.weekday % 7);
    
    // Group entries by date
    final entriesByDate = <String, List<EmployeeTimeEntry>>{};
    for (final entry in timeEntries) {
      final key = entry.entryDate.toIso8601String().split('T')[0];
      entriesByDate.putIfAbsent(key, () => []).add(entry);
    }

    final dayNames = ['D', 'L', 'M', 'M', 'J', 'V', 'S'];
    final monthNames = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${monthNames[now.month - 1]} ${now.year}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  _buildAttendanceLegend(Colors.green, 'Presente'),
                  const SizedBox(width: 12),
                  _buildAttendanceLegend(Colors.orange, 'Tardanza'),
                  const SizedBox(width: 12),
                  _buildAttendanceLegend(Colors.red, 'Ausente'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Day headers
          Row(
            children: dayNames.map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.2,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startWeekday) {
                return const SizedBox.shrink();
              }
              
              final day = index - startWeekday + 1;
              final date = DateTime(now.year, now.month, day);
              final dateKey = date.toIso8601String().split('T')[0];
              final entries = entriesByDate[dateKey] ?? [];
              final isToday = now.day == day;
              final isFuture = date.isAfter(now);
              final isWeekend = date.weekday == DateTime.saturday || 
                               date.weekday == DateTime.sunday;
              
              // Determine attendance status
              Color? statusColor;
              if (!isFuture && !isWeekend) {
                if (entries.isNotEmpty) {
                  final hasLate = entries.any((e) => e.status == 'tardanza');
                  statusColor = hasLate ? Colors.orange : Colors.green;
                } else if (date.isBefore(DateTime(now.year, now.month, now.day))) {
                  statusColor = Colors.red;
                }
              }

              return Container(
                decoration: BoxDecoration(
                  color: isToday 
                      ? theme.colorScheme.primary.withValues(alpha: 0.15)
                      : statusColor?.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: isToday 
                      ? Border.all(color: theme.colorScheme.primary, width: 2)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isFuture 
                          ? Colors.grey 
                          : isWeekend 
                              ? Colors.grey.shade400 
                              : null,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
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
        border: Border.all(color: Colors.grey.withValues(alpha: 0.16)),
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
    final color = isPositive ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.16)),
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
                    color: Colors.grey[600],
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
        color = Colors.green;
        label = 'Aprobado';
        break;
      case 'rechazado':
        color = Colors.red;
        label = 'Rechazado';
        break;
      default:
        color = Colors.orange;
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
        if (task.category.toLowerCase() != _taskFilterCategory.toLowerCase()) return false;
      }
      
      // Filtro por asignado
      if (_taskFilterAssignee != 'todos') {
        if (task.employeeId != _taskFilterAssignee) return false;
      }
      
      // Filtro por rango de fechas
      if (_taskDateRange != null) {
        final taskDate = task.assignedDate;
        if (taskDate.isBefore(_taskDateRange!.start) || taskDate.isAfter(_taskDateRange!.end)) {
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
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.grey.shade400 : const Color(0xFF64748B);
    final textMuted = isDark ? Colors.grey.shade600 : const Color(0xFF94A3B8);

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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              hintStyle: TextStyle(color: textMuted, fontSize: 13),
                              prefixIcon: Icon(Icons.search, color: textMuted, size: 20),
                              suffixIcon: _taskSearchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear, size: 16, color: textMuted),
                                      onPressed: () { _taskSearchController.clear(); setState(() {}); },
                                    )
                                  : null,
                              filled: true,
                              fillColor: bgColor,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: theme.colorScheme.primary)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Filtros dropdown compactos
                        _buildCompactFilter('Estado', _taskFilterStatus, {
                          'todos': 'Todos', 'pendiente': 'Pendiente', 'en_progreso': 'En Progreso', 
                          'completada': 'Completada', 'cancelada': 'Cancelada'
                        }, (v) => setState(() => _taskFilterStatus = v!), theme, borderColor),
                        const SizedBox(width: 8),
                        _buildCompactFilter('Categoría', _taskFilterCategory, {
                          'todos': 'Todas', 'General': 'General', 'Produccion': 'Producción', 
                          'Mantenimiento': 'Mantenimiento', 'Limpieza': 'Limpieza', 'Reportes': 'Reportes'
                        }, (v) => setState(() => _taskFilterCategory = v!), theme, borderColor),
                        const SizedBox(width: 8),
                        _buildCompactFilter('Asignado', _taskFilterAssignee, {
                          'todos': 'Todos', for (var e in state.activeEmployees) e.id: e.fullName
                        }, (v) => setState(() => _taskFilterAssignee = v!), theme, borderColor),
                        const SizedBox(width: 8),
                        // Limpiar filtros
                        if (_hasActiveFilters())
                          IconButton(
                            icon: Icon(Icons.filter_alt_off, color: theme.colorScheme.primary, size: 20),
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
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Header tabla
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                border: Border(bottom: BorderSide(color: borderColor)),
                              ),
                              child: Row(
                                children: [
                                  _buildTableHeader('TAREA', textSecondary, flex: 3),
                                  _buildTableHeader('UBICACIÓN', textSecondary, flex: 2),
                                  _buildTableHeader('EQUIPO', textSecondary, flex: 2),
                                  _buildTableHeader('ESTADO', textSecondary, flex: 2),
                                  _buildTableHeader('TIEMPO', textSecondary, flex: 2),
                                  _buildTableHeader('ACCIONES', textSecondary, flex: 2, align: TextAlign.right),
                                ],
                              ),
                            ),
                            // Filas
                            if (filteredTasks.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(48),
                                child: _buildEmptyState(
                                  icon: Icons.task_alt,
                                  title: state.tasks.isEmpty ? 'Sin tareas' : 'Sin resultados',
                                  subtitle: state.tasks.isEmpty 
                                      ? 'Crea tareas para asignar a tu equipo'
                                      : 'No hay tareas que coincidan con los filtros',
                                  onAction: () => _showTaskDialog(),
                                  actionLabel: 'Crear Tarea',
                                ),
                              )
                            else
                              ...filteredTasks.map((task) => _buildTaskRow(theme, task, textMain, textSecondary, textMuted, borderColor, bgColor)),
                            // Footer
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                                border: Border(top: BorderSide(color: borderColor)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      text: 'Mostrando ',
                                      style: TextStyle(fontSize: 12, color: textSecondary),
                                      children: [
                                        TextSpan(
                                          text: '${filteredTasks.length}',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: textMain),
                                        ),
                                        TextSpan(text: ' de '),
                                        TextSpan(
                                          text: '${state.tasks.length}',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: textMain),
                                        ),
                                        TextSpan(text: ' tareas'),
                                      ],
                                    ),
                                  ),
                                  if (filteredTasks.length != state.tasks.length)
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
                                      icon: const Icon(Icons.filter_alt_off, size: 16),
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
          color: isActive ? theme.colorScheme.primary.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? theme.colorScheme.primary : borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isActive ? (options[value] ?? value) : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
      itemBuilder: (ctx) => options.entries.map((e) => PopupMenuItem(
        value: e.key,
        child: Row(
          children: [
            if (e.key == value) Icon(Icons.check, size: 16, color: theme.colorScheme.primary) else const SizedBox(width: 16),
            const SizedBox(width: 8),
            Text(e.value, style: TextStyle(fontSize: 13)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildFilterButton(String label, Color textColor, Color borderColor, Color bgColor) {
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
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor)),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 18, color: textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text, Color color, {int flex = 1, TextAlign align = TextAlign.left}) {
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
        child: Icon(icon, size: 18, color: Colors.grey),
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
    final employee = ref.read(employeesProvider).employees.where(
      (e) => e.id == task.employeeId,
    ).firstOrNull;

    return InkWell(
      onTap: () => _showTaskDialog(task: task),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor.withValues(alpha: 0.5))),
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
                    style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.w500),
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
                    child: Icon(Icons.location_on, size: 16, color: textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.category,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textSecondary),
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
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    backgroundImage: employee?.photoUrl != null ? NetworkImage(employee!.photoUrl!) : null,
                    child: employee?.photoUrl == null
                        ? Text(
                            employee?.initials ?? '?',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            // Estado
            Expanded(
              flex: 2,
              child: _buildStatusBadge(task.status, task.statusLabel, task.statusColor),
            ),
            // Tiempo
            Expanded(
              flex: 2,
              child: _buildTimeCell(task, textSecondary),
            ),
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
                        await ref.read(employeesProvider.notifier).completeTask(task.id);
                      } else {
                        final updatedTask = EmployeeTask(
                          id: task.id,
                          employeeId: task.employeeId,
                          employeeName: task.employeeName,
                          title: task.title,
                          description: task.description,
                          assignedDate: task.assignedDate,
                          dueDate: task.dueDate,
                          completedDate: newStatus == TaskStatus.completada ? DateTime.now() : null,
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
                        await ref.read(employeesProvider.notifier).updateTask(updatedTask);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: TaskStatus.pendiente,
                        child: Row(
                          children: [
                            Icon(Icons.pending, color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            const Text('Pendiente'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: TaskStatus.enProgreso,
                        child: Row(
                          children: [
                            Icon(Icons.play_circle, color: Colors.blue, size: 18),
                            const SizedBox(width: 8),
                            const Text('En Progreso'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: TaskStatus.completada,
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 18),
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
                            Icon(Icons.cancel, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            const Text('Cancelar'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Eliminar
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red.shade300, size: 20),
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(employeesProvider.notifier).deleteTask(task.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Tarea eliminada' : 'Error al eliminar'),
                    backgroundColor: success ? Colors.green : Colors.red,
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
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
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
          Text('A tiempo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green)),
        ],
      );
    }

    final dueDate = task.dueDate;
    if (dueDate == null) {
      return Row(
        children: [
          Icon(Icons.schedule, size: 16, color: textColor),
          const SizedBox(width: 6),
          Expanded(child: Text('Sin fecha', style: TextStyle(fontSize: 13, color: textColor))),
        ],
      );
    }

    final now = DateTime.now();
    final diff = dueDate.difference(now);
    
    if (diff.isNegative) {
      return Row(
        children: [
          Icon(Icons.warning, size: 16, color: Colors.red),
          const SizedBox(width: 6),
          Text('-${diff.inHours.abs()}h (Venció)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red)),
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
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor))),
      ],
    );
  }

  Widget _buildComplexityBars(TaskPriority priority, Color textColor, Color primaryColor) {
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
        barColor = Colors.red;
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textColor)),
        const SizedBox(width: 8),
        Row(
          children: List.generate(5, (i) {
            return Container(
              width: 5,
              height: 16,
              margin: const EdgeInsets.only(left: 2),
              decoration: BoxDecoration(
                color: i < filled ? barColor : Colors.grey.withValues(alpha: 0.2),
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
                Icon(Icons.person, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(task.employeeName ?? 'Sin asignar'),
                const SizedBox(width: 16),
                Icon(Icons.schedule, size: 14, color: Colors.grey),
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
                icon: const Icon(Icons.check_circle, color: Colors.green),
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
              color: Colors.grey.shade600,
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
                        color: Colors.grey.withValues(alpha: 0.4),
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
                                  backgroundColor: Colors.red,
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
                                    ? Colors.green
                                    : Colors.red,
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                              final emp = employees.firstWhere((e) => e.id == id, orElse: () => employees.first);
                              return Chip(
                                avatar: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                  child: Text(emp.initials, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary)),
                                ),
                                label: Text(emp.fullName, style: const TextStyle(fontSize: 12)),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () => setDialogState(() => selectedEmployeeIds.remove(id)),
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
                                        final isSelected = selectedEmployeeIds.contains(emp.id);
                                        return CheckboxListTile(
                                          value: isSelected,
                                          title: Text(emp.fullName),
                                          subtitle: Text(emp.position, style: const TextStyle(fontSize: 12)),
                                          secondary: CircleAvatar(
                                            radius: 16,
                                            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                            child: Text(emp.initials, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary)),
                                          ),
                                          onChanged: (val) {
                                            setInnerState(() {
                                              if (val == true) {
                                                selectedEmployeeIds.add(emp.id);
                                              } else {
                                                selectedEmployeeIds.remove(emp.id);
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
                              Icon(Icons.add_circle_outline, size: 18, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                selectedEmployeeIds.isEmpty ? 'Seleccionar empleados' : 'Agregar más',
                                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13),
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
                            side: BorderSide(color: Colors.grey.shade400),
                          ),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
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
                          subtitle: Text(dueDate != null ? Helpers.formatDate(dueDate!) : 'Sin fecha límite'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (dueDate != null)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => setDialogState(() => dueDate = null),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              const SizedBox(width: 4),
                              const Icon(Icons.event),
                            ],
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: dueDate != null ? Colors.orange : Colors.grey.shade400),
                          ),
                          tileColor: dueDate != null ? Colors.orange.withValues(alpha: 0.05) : null,
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: dueDate ?? DateTime.now().add(const Duration(days: 7)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
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
                if (titleController.text.isEmpty || selectedEmployeeIds.isEmpty) {
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
                    description: descriptionController.text.isEmpty ? null : descriptionController.text,
                    assignedDate: selectedDate,
                    dueDate: dueDate,
                    status: task.status,
                    priority: selectedPriority,
                    category: selectedCategory,
                    createdAt: task.createdAt,
                    updatedAt: DateTime.now(),
                  );
                  await ref.read(employeesProvider.notifier).updateTask(updatedTask);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Tarea actualizada'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } else {
                  // Si es nueva, crear una tarea por cada empleado seleccionado
                  bool anySuccess = false;
                  for (final empId in selectedEmployeeIds) {
                    final emp = employees.firstWhere((e) => e.id == empId, orElse: () => employees.first);
                    final newTask = EmployeeTask(
                      id: '',
                      employeeId: empId,
                      employeeName: emp.fullName,
                      title: titleController.text,
                      description: descriptionController.text.isEmpty ? null : descriptionController.text,
                      assignedDate: selectedDate,
                      dueDate: dueDate,
                      status: TaskStatus.pendiente,
                      priority: selectedPriority,
                      category: selectedCategory,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    final created = await ref.read(employeesProvider.notifier).createTask(newTask);
                    if (created != null) anySuccess = true;
                  }
                  
                  if (mounted) {
                    if (anySuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(selectedEmployeeIds.length > 1 
                            ? '✅ Tarea asignada a ${selectedEmployeeIds.length} empleados'
                            : '✅ Tarea creada exitosamente'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('❌ Error al crear la tarea'),
                          backgroundColor: Colors.red,
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
    final availableTasks = state.tasks.where((t) => 
      t.status != TaskStatus.completada
    ).toList();

    if (availableTasks.isEmpty) {
      // Cerrar cualquier SnackBar anterior
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No hay tareas disponibles. Crea una primero en la pestaña de Tareas.'),
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
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
                          color: Colors.grey,
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
                      color: Colors.grey.shade700,
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
                        final isAssignedToOther = task.employeeId != employee.id;
                        
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: task.statusColor.withValues(alpha: 0.1),
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
                                      style: TextStyle(fontSize: 11, color: Colors.orange),
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
                              
                              await ref.read(employeesProvider.notifier).updateTask(updatedTask);
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Tarea "${task.title}" asignada a ${employee.fullName}'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    int selectedDayIndex = (DateTime.now().weekday - 1).clamp(0, 5); // 0=Lunes, 5=Sábado

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Consumer(
          builder: (context, ref, child) {
            final state = ref.watch(employeesProvider);
            final allTasks = state.selectedEmployeeTasks;
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
            
            final now = DateTime.now();
            final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
            
            // Días de la semana (sin domingo)
            final dayNames = ['L', 'M', 'X', 'J', 'V', 'S'];
            final dayFullNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
            
            // Horario: L-V 7:30-12:00 y 1:00-4:30 (-14min) = 7.77h, Sáb 7:30-1:00 = 5.5h
            const double weekdayBase = 7.77; // Entre semana
            const double saturdayBase = 5.5;  // Sábado
            Map<int, double> hoursByDay = {};
            Map<int, DateTime> datesByDay = {};
            
            for (int i = 0; i < 6; i++) {
              final dayDate = startOfWeek.add(Duration(days: i));
              datesByDay[i] = dayDate;
              
              final dayAdjustments = state.timeAdjustments
                  .where((a) => a.employeeId == employee.id)
                  .where((a) => a.adjustmentDate.year == dayDate.year && 
                               a.adjustmentDate.month == dayDate.month && 
                               a.adjustmentDate.day == dayDate.day)
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
            const weeklyBase = 44.33; // (5 x 7.77) + 5.5
            final progress = (totalWeekHours / weeklyBase).clamp(0.0, 1.0);
            final isOvertime = totalWeekHours > weeklyBase;
            final isUndertime = totalWeekHours < weeklyBase;
            
            // Día seleccionado
            final selectedDate = datesByDay[selectedDayIndex] ?? now;
            final selectedDayHours = hoursByDay[selectedDayIndex] ?? ((selectedDayIndex == 5) ? saturdayBase : weekdayBase);
            final isSelectedToday = selectedDayIndex == (now.weekday - 1) && now.weekday <= 6;
            final isSelectedFuture = selectedDate.isAfter(DateTime(now.year, now.month, now.day));
            
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
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
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
                            Text('Información Personal', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600, fontSize: 12)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                children: [
                                  _buildInfoRow(Icons.business, 'Depto', employee.department ?? 'N/A'),
                                  _buildInfoRow(Icons.phone, 'Tel', employee.phone ?? 'N/A'),
                                  _buildInfoRow(Icons.email, 'Email', employee.email ?? 'N/A'),
                                  _buildInfoRow(Icons.calendar_today, 'Ingreso', _formatDate(employee.hireDate)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Tareas del día seleccionado
                            Text(
                              '${dayFullNames[selectedDayIndex]} ${selectedDate.day}/${selectedDate.month} - Tareas (${dayTasks.length})',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 140,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor),
                              ),
                              child: dayTasks.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            isSelectedFuture ? Icons.event_note : Icons.check_circle_outline,
                                            size: 24,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            isSelectedFuture 
                                                ? 'Sin tareas programadas'
                                                : isSelectedToday 
                                                    ? 'Sin tareas hoy'
                                                    : 'Sin tareas registradas',
                                            style: TextStyle(color: Colors.grey, fontSize: 11),
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
                                          padding: const EdgeInsets.symmetric(vertical: 2),
                                          child: Row(
                                            children: [
                                              Icon(
                                                task.status == TaskStatus.completada 
                                                    ? Icons.check_circle 
                                                    : task.status == TaskStatus.enProgreso
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
                            Text('Horas Semana', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600, fontSize: 12)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                children: [
                                  // Total y progreso
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${totalWeekHours.toStringAsFixed(1)}h',
                                            style: TextStyle(
                                              fontSize: 24, 
                                              fontWeight: FontWeight.w800, 
                                              color: isOvertime 
                                                  ? Colors.green 
                                                  : isUndertime 
                                                      ? Colors.orange 
                                                      : theme.colorScheme.primary,
                                            ),
                                          ),
                                          Text('de 48h', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                                              backgroundColor: Colors.grey.shade300,
                                              color: isOvertime ? Colors.green : isUndertime ? Colors.orange : theme.colorScheme.primary,
                                            ),
                                          ),
                                          Text('${(progress * 100).toInt()}%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
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
                                          onPressed: () => _addHoursForDay(employee, -0.5, selectedDate),
                                          icon: const Icon(Icons.remove, size: 18),
                                          label: const Text('0.5h'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            side: const BorderSide(color: Colors.red),
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: () => _addHoursForDay(employee, 0.5, selectedDate),
                                          icon: const Icon(Icons.add, size: 18),
                                          label: const Text('0.5h'),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            padding: const EdgeInsets.symmetric(vertical: 8),
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
                                color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: dayNames.asMap().entries.map((e) {
                                  final dayIndex = e.key;
                                  final baseForDay = (dayIndex == 5) ? saturdayBase : weekdayBase;
                                  final hours = hoursByDay[dayIndex] ?? baseForDay;
                                  final isToday = dayIndex == (now.weekday - 1) && now.weekday <= 6;
                                  final isSelected = dayIndex == selectedDayIndex;
                                  final hasExtra = hours > baseForDay;
                                  final hasDeduction = hours < baseForDay;
                                  
                                  return GestureDetector(
                                    onTap: () => setDialogState(() => selectedDayIndex = dayIndex),
                                    child: Column(
                                      children: [
                                        Text(
                                          e.value,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            color: isSelected ? theme.colorScheme.primary : Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          width: isSelected ? 36 : 28,
                                          height: isSelected ? 36 : 28,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                                : hasExtra 
                                                    ? Colors.green.withValues(alpha: 0.1)
                                                    : hasDeduction 
                                                        ? Colors.orange.withValues(alpha: 0.1)
                                                        : Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isSelected 
                                                  ? theme.colorScheme.primary 
                                                  : isToday 
                                                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
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
                                                        ? Colors.green.shade700 
                                                        : hasDeduction 
                                                            ? Colors.orange.shade700 
                                                            : Colors.grey.shade600,
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
      await ref.read(employeesProvider.notifier).createTimeAdjustment(
        employeeId: employee.id,
        minutes: minutes.abs(),
        type: type,
        date: date,
        reason: hours > 0 ? 'Hora extra - ${date.day}/${date.month}' : 'Descuento - ${date.day}/${date.month}',
      );
      
      await ref.read(employeesProvider.notifier).loadTimeOverview(employee.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(hours > 0 
                ? '✅ +${hours}h añadida al ${date.day}/${date.month}'
                : '✅ ${hours}h descontada del ${date.day}/${date.month}'),
            backgroundColor: hours > 0 ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _addHours(Employee employee, double hours) async {
    final minutes = (hours * 60).round();
    final type = hours > 0 ? 'overtime' : 'deduction';
    
    try {
      await ref.read(employeesProvider.notifier).createTimeAdjustment(
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
            content: Text(hours > 0 
                ? '✅ +${hours}h añadida a ${employee.firstName}'
                : '✅ ${hours}h descontada de ${employee.firstName}'),
            backgroundColor: hours > 0 ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Widget> _buildWeekDayRows(Map<int, double> hoursByDay, int currentDay, ThemeData theme) {
    final days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final targetPerDay = 44 / 6; // ~7.33 horas por día laboral (Lun-Sáb)
    
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
                      : isPast ? Colors.grey.shade700 : Colors.grey.shade400,
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
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: hours >= target && target > 0
                            ? Colors.green
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

  Widget _buildTodayTimeLog(Employee employee, List<EmployeeTimeEntry> entries, DateTime now, ThemeData theme) {
    final todayEntries = entries.where((e) => 
      e.entryDate.day == now.day && 
      e.entryDate.month == now.month && 
      e.entryDate.year == now.year
    ).toList();

    if (todayEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time, size: 32, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'Sin registros hoy',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 4),
            Text(
              'Registra la entrada para comenzar',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
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
            color: isActive ? Colors.green.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? Colors.green.withValues(alpha: 0.3) : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isActive ? Icons.play_circle : Icons.check_circle,
                color: isActive ? Colors.green : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.login, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'Entrada: ${_formatTime(checkIn)}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        if (checkOut != null) ...[
                          const SizedBox(width: 16),
                          Icon(Icons.logout, size: 14, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            'Salida: ${_formatTime(checkOut)}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                    if (isActive)
                      Text(
                        'En turno activo',
                        style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
              ),
              if (hoursWorked > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
      await ref.read(employeesProvider.notifier).registerTimeEntry(
        employeeId: employee.id,
        date: now,
        checkIn: now,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Entrada registrada para ${employee.fullName} a las ${_formatTime(now)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _registerCheckOut(Employee employee, dynamic entry) async {
    final now = DateTime.now();
    final checkIn = entry.checkIn as DateTime;
    final hoursWorked = now.difference(checkIn).inMinutes / 60.0;
    
    try {
      await ref.read(employeesProvider.notifier).updateTimeEntry(
        entryId: entry.id,
        checkOut: now,
        hoursWorked: hoursWorked,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Salida registrada para ${employee.fullName}. Trabajó ${hoursWorked.toStringAsFixed(1)} horas'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showTimeHistoryDialog(Employee employee) {
    // TODO: Implementar historial completo de horas
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Historial de horas - Próximamente')),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
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
          backgroundColor: Colors.green,
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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

    // Calcular estadísticas
    final totalCostoNomina = payrollState.payrolls.fold(
      0.0,
      (sum, p) => sum + p.totalEarnings,
    );
    final totalDescuentos = payrollState.payrolls.fold(
      0.0,
      (sum, p) => sum + p.totalDeductions,
    );
    final totalNetoNomina = payrollState.totalNetPayroll;
    final empleadosActivos = empState.employees.where((e) => e.status == EmployeeStatus.activo).length;

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
                    Text(
                      'Mes ${payrollState.currentPeriod?.displayName ?? '12/2025'}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Exportando...')),
                ),
                icon: const Icon(Icons.download, size: 14),
                label: const Text('Exportar'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: _showCreatePayrollDialog,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Nuevo Pago'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Tarjetas de estadísticas en fila compacta
          SizedBox(
            height: 72,
            child: Row(
              children: [
                Expanded(child: _buildCompactStatCard(Icons.attach_money, 'Costo Nómina', Helpers.formatCurrency(totalCostoNomina), '+12%', theme)),
                const SizedBox(width: 6),
                Expanded(child: _buildCompactStatCard(Icons.groups, 'Empleados', '$empleadosActivos', '+2%', theme)),
                const SizedBox(width: 6),
                Expanded(child: _buildCompactStatCard(Icons.receipt_long, 'Descuentos', Helpers.formatCurrency(totalDescuentos), '+5%', theme)),
                const SizedBox(width: 6),
                Expanded(child: _buildCompactStatCard(Icons.account_balance, 'Neto', Helpers.formatCurrency(totalNetoNomina), '+8%', theme)),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Gráficos lado a lado (altura fija)
          SizedBox(
            height: 140,
            child: Row(
              children: [
                Expanded(child: _buildCompactTrendCard(theme, payrollState)),
                const SizedBox(width: 8),
                Expanded(child: _buildCompactDistributionCard(theme, empState)),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Tabla de pagos (ocupa el espacio restante)
          Expanded(
            child: _buildCompactPaymentsTable(theme, payrollState, empState),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatCard(IconData icon, String label, String value, String change, ThemeData theme) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
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
                  Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                  Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(change, style: TextStyle(color: Colors.green[600], fontSize: 10, fontWeight: FontWeight.w600)),
                    Icon(Icons.arrow_upward, size: 8, color: Colors.green[600]),
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
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tendencia de Costos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text(Helpers.formatCurrency(payrollState.totalNetPayroll * 6), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Últimos 6 meses', style: TextStyle(color: Colors.grey[600], fontSize: 9)),
                Text('+5.2% vs anterior', style: TextStyle(color: Colors.green[600], fontSize: 9, fontWeight: FontWeight.w500)),
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
                                    color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.primary.withValues(alpha: 0.2),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(months[i], style: TextStyle(fontSize: 8, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, color: isCurrent ? theme.colorScheme.primary : Colors.grey[600])),
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

  Widget _buildCompactDistributionCard(ThemeData theme, EmployeesState empState) {
    final departments = <String, int>{};
    for (final emp in empState.employees.where((e) => e.status == EmployeeStatus.activo)) {
      final dept = emp.department ?? 'Otros';
      departments[dept] = (departments[dept] ?? 0) + 1;
    }

    final colors = [theme.colorScheme.primary, Colors.blue[300]!, Colors.blue[200]!, Colors.grey[400]!];
    final total = empState.employees.where((e) => e.status == EmployeeStatus.activo).length;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Distribución Salarial', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text('$total', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Por departamento', style: TextStyle(color: Colors.grey[600], fontSize: 9)),
                Text('Empleados activos', style: TextStyle(color: Colors.green[600], fontSize: 9, fontWeight: FontWeight.w500)),
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
                        color: theme.colorScheme.primary.withValues(alpha: 0.05),
                      ),
                      child: CustomPaint(painter: _WaveChartPainter(theme.colorScheme.primary)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: departments.entries.take(4).toList().asMap().entries.map((entry) {
                        final i = entry.key;
                        final dept = entry.value;
                        return Row(
                          children: [
                            Container(width: 6, height: 6, decoration: BoxDecoration(color: colors[i % colors.length], borderRadius: BorderRadius.circular(3))),
                            const SizedBox(width: 4),
                            Expanded(child: Text(dept.key, style: TextStyle(fontSize: 9, color: Colors.grey[700]), overflow: TextOverflow.ellipsis)),
                            Text('${dept.value}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                          ],
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
    );
  }

  Widget _buildCompactPaymentsTable(ThemeData theme, PayrollState payrollState, EmployeesState empState) {
    final pendingPayrolls = payrollState.payrolls.where((p) => p.status != 'pagado').take(5).toList();

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Próximos Pagos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                  child: Text('Ver todos', style: TextStyle(color: theme.colorScheme.primary, fontSize: 11)),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.grey[50],
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('EMPLEADO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey))),
                Expanded(flex: 2, child: Text('DEPARTAMENTO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey))),
                Expanded(flex: 2, child: Text('FECHA PAGO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey))),
                Expanded(flex: 2, child: Text('MONTO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey))),
                Expanded(flex: 1, child: Text('ESTADO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey))),
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
                        Icon(Icons.payments_outlined, size: 20, color: Colors.grey[400]),
                        const SizedBox(height: 4),
                        Text('No hay pagos pendientes', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: _showCreatePayrollDialog,
                          icon: const Icon(Icons.add, size: 10),
                          label: const Text('Crear Nómina'),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), textStyle: const TextStyle(fontSize: 10)),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: pendingPayrolls.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final payroll = pendingPayrolls[index];
                      final employee = empState.employees.where((e) => e.id == payroll.employeeId).firstOrNull;
                      final statusColor = payroll.status == 'pagado' ? Colors.green : payroll.status == 'aprobado' ? Colors.blue : Colors.orange;
                      
                      return InkWell(
                        onTap: () => _showPayrollDetailDialog(payroll),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                      child: Text((payroll.employeeName ?? 'E')[0].toUpperCase(), style: TextStyle(color: theme.colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(payroll.employeeName ?? 'Empleado', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                          Text(payroll.employeePosition ?? '', style: TextStyle(fontSize: 10, color: Colors.grey[600]), overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(flex: 2, child: Text(employee?.department ?? '-', style: TextStyle(fontSize: 11, color: Colors.grey[700]))),
                              Expanded(flex: 2, child: Text(payroll.paymentDate != null ? Helpers.formatDate(payroll.paymentDate!) : 'Por definir', style: TextStyle(fontSize: 11, color: Colors.grey[700]))),
                              Expanded(flex: 2, child: Text(Helpers.formatCurrency(payroll.netPay), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                  child: Text(payroll.status == 'pagado' ? 'Pagado' : payroll.status == 'aprobado' ? 'Aprobado' : 'Pendiente', textAlign: TextAlign.center, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
                                padding: EdgeInsets.zero,
                                onSelected: (v) {
                                  if (v == 'ver') _showPayrollDetailDialog(payroll);
                                  if (v == 'editar') _showAddConceptDialog(payroll);
                                  if (v == 'pagar') _showPayPayrollDialog(payroll);
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'ver', child: Text('Ver detalles', style: TextStyle(fontSize: 12))),
                                  const PopupMenuItem(value: 'editar', child: Text('Editar', style: TextStyle(fontSize: 12))),
                                  if (payroll.status != 'pagado') const PopupMenuItem(value: 'pagar', child: Text('Pagar', style: TextStyle(fontSize: 12))),
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

  void _showPayrollDetailDialog(EmployeePayroll payroll) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      (payroll.employeeName ?? 'E').substring(0, 1).toUpperCase(),
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
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              // Detalles de la nómina
              _buildDetailRowDialog('Salario Base', Helpers.formatCurrency(payroll.baseSalary)),
              _buildDetailRowDialog('Días Trabajados', '${payroll.daysWorked} días'),
              _buildDetailRowDialog('Horas Extra', '${payroll.overtimeHours25 + payroll.overtimeHours35 + payroll.overtimeHours100} horas'),
              const Divider(height: 32),
              _buildDetailRowDialog('Total Ingresos', Helpers.formatCurrency(payroll.totalEarnings), Colors.green),
              _buildDetailRowDialog('Total Descuentos', Helpers.formatCurrency(payroll.totalDeductions), Colors.red),
              const Divider(height: 32),
              _buildDetailRowDialog('Neto a Pagar', Helpers.formatCurrency(payroll.netPay), Theme.of(context).colorScheme.primary, true),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
  }

  Widget _buildDetailRowDialog(String label, String value, [Color? color, bool isBold = false]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
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
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
        ? Colors.green
        : payroll.status == 'aprobado'
        ? Colors.blue
        : Colors.orange;

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
                        Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _buildPayrollDetailRow(
                        'Total Descuentos',
                        Helpers.formatCurrency(payroll.totalDeductions),
                        Colors.red,
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
                        style: TextStyle(color: Colors.grey[600]),
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
          Text(label, style: TextStyle(color: Colors.grey[600])),
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
                  Colors.orange,
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
                  Colors.red,
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
                        color: Colors.green[300],
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
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  child: Icon(
                    isPaid ? Icons.check : Icons.account_balance_wallet,
                    color: isPaid ? Colors.green : Colors.orange,
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
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                        backgroundColor: Colors.grey[200],
                        color: isPaid
                            ? Colors.green
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
                    color: Colors.red[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (loan.reason != null && loan.reason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Motivo: ${loan.reason}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ],
        ),
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

    final activeIncapacities = payrollState.activeIncapacities;
    final pastIncapacities = payrollState.incapacities
        .where((i) => i.status != 'activa')
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
                  'Incapacidades Activas',
                  '${activeIncapacities.length}',
                  Icons.medical_services,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPayrollSummaryCard(
                  'Días de Incapacidad',
                  '${activeIncapacities.fold(0, (sum, i) => sum + i.daysTotal)}',
                  Icons.calendar_today,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPayrollSummaryCard(
                  'Este Mes',
                  '${payrollState.incapacities.where((i) => i.startDate.month == DateTime.now().month).length}',
                  Icons.date_range,
                  theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Lista de incapacidades activas
          const Text(
            'Incapacidades Activas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (activeIncapacities.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 64,
                        color: Colors.green[300],
                      ),
                      const SizedBox(height: 16),
                      const Text('No hay incapacidades activas'),
                    ],
                  ),
                ),
              ),
            )
          else
            ...activeIncapacities.map(
              (inc) => _buildIncapacityCard(inc, theme),
            ),

          if (pastIncapacities.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Historial',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...pastIncapacities.map(
              (inc) => _buildIncapacityCard(inc, theme, isPast: true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIncapacityCard(
    EmployeeIncapacity incapacity,
    ThemeData theme, {
    bool isPast = false,
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
                  backgroundColor: isPast
                      ? Colors.grey.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.medical_services,
                    color: isPast ? Colors.grey : Colors.red,
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
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isPast
                        ? Colors.grey.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${incapacity.daysTotal} días',
                    style: TextStyle(
                      color: isPast ? Colors.grey : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Desde',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
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
  void _showCreatePayrollDialog() async {
    final employees = ref.read(employeesProvider).activeEmployees;
    final payrollState = ref.read(payrollProvider);

    print('🔍 DEBUG: Verificando estado de nómina...');
    print('🔍 currentPeriod: ${payrollState.currentPeriod}');
    print('🔍 Empleados activos: ${employees.length}');
    print('🔍 Nóminas existentes: ${payrollState.payrolls.length}');

    // Si no hay periodo, intentar cargarlo
    if (payrollState.currentPeriod == null) {
      print('⚠️ No hay periodo, intentando cargar...');
      await ref.read(payrollProvider.notifier).loadAll();
      
      final newState = ref.read(payrollProvider);
      if (newState.currentPeriod == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo cargar el periodo activo. Verifica la conexión.'), backgroundColor: Colors.red),
          );
        }
        return;
      }
    }

    final currentPayrollState = ref.read(payrollProvider);

    // Empleados que ya tienen nómina en este periodo
    final employeesWithPayroll = currentPayrollState.payrolls.map((p) => p.employeeId).toSet();
    final availableEmployees = employees.where((e) => !employeesWithPayroll.contains(e.id)).toList();

    print('🔍 Empleados con nómina: ${employeesWithPayroll.length}');
    print('🔍 Empleados disponibles: ${availableEmployees.length}');

    if (availableEmployees.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todos los empleados ya tienen nómina este periodo'), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    String? selectedEmployeeId;
    Employee? selectedEmployee;
    double baseSalary = 0;
    double hoursWorked = 0;
    double overtimeHours = 0;
    int daysWorked = 26; // 6 días x ~4.33 semanas
    int daysAbsent = 0;
    bool includeActiveLoans = true;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Calcular valores
          final hourlyRate = baseSalary > 0 ? baseSalary / 191 : 0.0; // 191 horas = 44h x 4.33 semanas
          final dailyRate = baseSalary > 0 ? baseSalary / 26 : 0.0;
          final overtimePay = overtimeHours * hourlyRate; // Pago normal sin recargo
          final absenceDiscount = daysAbsent * dailyRate;
          
          // Buscar préstamos activos del empleado
          final activeLoans = selectedEmployeeId != null
              ? currentPayrollState.loans.where((l) => l.employeeId == selectedEmployeeId && l.status == 'activo').toList()
              : <EmployeeLoan>[];
          final loanDeduction = includeActiveLoans 
              ? activeLoans.fold(0.0, (sum, l) => sum + l.installmentAmount)
              : 0.0;
          
          final totalEarnings = baseSalary + overtimePay;
          final totalDeductions = absenceDiscount + loanDeduction;
          final netPay = totalEarnings - totalDeductions;

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.receipt_long, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Crear Nómina'),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Periodo
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Text('Periodo: ${currentPayrollState.currentPeriod!.displayName}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),


                    // Selección de empleado
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Empleado',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      items: availableEmployees.map((e) => DropdownMenuItem(
                        value: e.id,
                        child: Text('${e.fullName} - ${e.position}'),
                      )).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          final emp = availableEmployees.firstWhere((e) => e.id == value);
                          setState(() {
                            selectedEmployeeId = value;
                            selectedEmployee = emp;
                            baseSalary = emp.salary ?? 0;
                            // 44 horas semanales estándar * 4.33 semanas = 191 horas/mes
                            hoursWorked = 191;
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
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Cargo: ${selectedEmployee!.position}'),
                                Text('Depto: ${selectedEmployee!.department ?? "N/A"}'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Salario Base: ${Helpers.formatCurrency(baseSalary)}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Días trabajados y ausentes
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: daysWorked.toString(),
                            decoration: const InputDecoration(
                              labelText: 'Días Trabajados',
                              prefixIcon: Icon(Icons.check_circle_outline),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => setState(() => daysWorked = int.tryParse(v) ?? 26),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            initialValue: daysAbsent.toString(),
                            decoration: const InputDecoration(
                              labelText: 'Días Ausente',
                              prefixIcon: Icon(Icons.cancel_outlined),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => setState(() => daysAbsent = int.tryParse(v) ?? 0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Horas extras
                    TextFormField(
                      initialValue: overtimeHours.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Horas Extra',
                        prefixIcon: Icon(Icons.more_time),
                        border: OutlineInputBorder(),
                        helperText: 'Horas adicionales a la jornada normal',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => setState(() => overtimeHours = double.tryParse(v) ?? 0),
                    ),
                    const SizedBox(height: 16),

                    // Préstamos activos
                    if (activeLoans.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.account_balance_wallet, color: Colors.orange[700], size: 20),
                                const SizedBox(width: 8),
                                Text('Préstamos Activos (${activeLoans.length})', 
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange[800])),
                                const Spacer(),
                                Switch(
                                  value: includeActiveLoans,
                                  onChanged: (v) => setState(() => includeActiveLoans = v),
                                  activeColor: Colors.orange[700],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...activeLoans.map((loan) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Cuota ${loan.paidInstallments + 1}/${loan.installments}',
                                    style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                                  Text('- ${Helpers.formatCurrency(loan.installmentAmount)}',
                                    style: TextStyle(color: Colors.red[600], fontWeight: FontWeight.w500, fontSize: 13)),
                                ],
                              ),
                            )),
                            if (activeLoans.length > 1) ...[
                              const Divider(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total Descuento', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800])),
                                  Text('- ${Helpers.formatCurrency(loanDeduction)}',
                                    style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    const Divider(height: 24),

                    // Resumen de cálculos
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          _buildPayrollSummaryRow('Salario Base', baseSalary, false),
                          if (overtimePay > 0) _buildPayrollSummaryRow('Horas Extra (${overtimeHours.toStringAsFixed(1)}h)', overtimePay, false),
                          const Divider(height: 16),
                          _buildPayrollSummaryRow('Total Ingresos', totalEarnings, false),
                          if (absenceDiscount > 0) _buildPayrollSummaryRow('Descuento Faltas ($daysAbsent días)', -absenceDiscount, true),
                          if (loanDeduction > 0) _buildPayrollSummaryRow('Cuotas Préstamos', -loanDeduction, true),
                          const Divider(height: 16),
                          _buildPayrollSummaryRow('NETO A PAGAR', netPay, false, isTotal: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              FilledButton.icon(
                onPressed: selectedEmployeeId == null ? null : () async {
                  Navigator.pop(context);
                  
                  print('🔄 Creando nómina para empleado: $selectedEmployeeId');
                  
                  // Crear la nómina
                  final payroll = await ref.read(payrollProvider.notifier).createPayroll(
                    employeeId: selectedEmployeeId!,
                    periodId: currentPayrollState.currentPeriod!.id,
                    baseSalary: baseSalary,
                    daysWorked: daysWorked,
                  );

                  print('📋 Resultado: $payroll');

                  if (payroll != null) {
                    // Agregar horas extras si hay
                    if (overtimeHours > 0) {
                      await ref.read(payrollProvider.notifier).addOvertimeHours(
                        payrollId: payroll.id,
                        hours: overtimeHours,
                        type: 'normal',
                        hourlyRate: baseSalary / 191,
                      );
                    }

                    // Agregar descuento por faltas si hay
                    if (daysAbsent > 0) {
                      await ref.read(payrollProvider.notifier).addAbsenceDiscount(
                        payrollId: payroll.id,
                        days: daysAbsent,
                        dailyRate: baseSalary / 26,
                      );
                    }

                    // Agregar cuotas de préstamos
                    if (includeActiveLoans && activeLoans.isNotEmpty) {
                      for (final loan in activeLoans) {
                        await ref.read(payrollProvider.notifier).addLoanInstallmentDiscount(
                          payrollId: payroll.id,
                          loan: loan,
                        );
                      }
                    }

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ Nómina creada exitosamente'), backgroundColor: Colors.green),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('Crear Nómina'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPayrollSummaryRow(String label, double amount, bool isDeduction, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
          )),
          Text(
            isDeduction ? '- ${Helpers.formatCurrency(amount.abs())}' : Helpers.formatCurrency(amount),
            style: TextStyle(
              color: isDeduction ? Colors.red : (isTotal ? Colors.green[700] : null),
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              fontSize: isTotal ? 18 : 14,
            ),
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
                      prefixText: 'S/ ',
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
                        backgroundColor: success ? Colors.green : Colors.red,
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
          const SnackBar(content: Text('No hay cuentas disponibles'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    DateTime paymentDate = DateTime.now();
    String? selectedAccountId = accountsData[0]['id'];
    double selectedAccountBalance = (accountsData[0]['balance'] ?? 0).toDouble();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.payments, color: Theme.of(context).colorScheme.primary),
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
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
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
                            Text(payroll.employeeName ?? 'Empleado',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(payroll.employeePosition ?? '', style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Neto a pagar:', style: TextStyle(fontSize: 12)),
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
                              color: hasEnough ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      final acc = accountsData.firstWhere((a) => a['id'] == value);
                      setState(() {
                        selectedAccountId = value;
                        selectedAccountBalance = (acc['balance'] ?? 0).toDouble();
                      });
                    }
                  },
                ),
                
                if (selectedAccountBalance < payroll.netPay) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Saldo insuficiente. Falta: ${Helpers.formatCurrency(payroll.netPay - selectedAccountBalance)}',
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Fecha de pago
                const Text('Fecha de pago:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: paymentDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (date != null) {
                      setState(() => paymentDate = date);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          '${paymentDate.day.toString().padLeft(2, '0')}/${paymentDate.month.toString().padLeft(2, '0')}/${paymentDate.year}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        Icon(Icons.edit_calendar, color: Colors.grey[500], size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton.icon(
              onPressed: selectedAccountId == null || selectedAccountBalance < payroll.netPay
                  ? null
                  : () async {
                      Navigator.pop(context);
                      
                      final success = await ref.read(payrollProvider.notifier).processPayment(
                        payrollId: payroll.id,
                        accountId: selectedAccountId!,
                        paymentDate: paymentDate,
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success 
                              ? '✅ Pago de ${Helpers.formatCurrency(payroll.netPay)} registrado exitosamente' 
                              : '❌ Error al procesar el pago'),
                            backgroundColor: success ? Colors.green : Colors.red,
                          ),
                        );
                      }
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
          const SnackBar(content: Text('No hay cuentas disponibles'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    final employees = ref.read(employeesProvider).activeEmployees;
    String? selectedEmployeeId = employee?.id;
    String? selectedAccountId = accountsData[0]['id'];
    double selectedAccountBalance = (accountsData[0]['balance'] ?? 0).toDouble();
    double amount = 0;
    int installments = 1;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final installmentAmount = installments > 0 ? amount / installments : 0.0;
          final hasEnoughBalance = selectedAccountBalance >= amount;

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Theme.of(context).colorScheme.primary),
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
                      items: employees.map((e) => DropdownMenuItem(
                        value: e.id,
                        child: Text('${e.fullName} - ${e.position}'),
                      )).toList(),
                      onChanged: employee == null ? (value) => setState(() => selectedEmployeeId = value) : null,
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
                              prefixText: 'S/ ',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => setState(() => amount = double.tryParse(v) ?? 0),
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
                            onChanged: (v) => setState(() => installments = int.tryParse(v) ?? 1),
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
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Cuota mensual a descontar:', style: TextStyle(fontWeight: FontWeight.w500)),
                            Text(
                              Helpers.formatCurrency(installmentAmount),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange),
                            ),
                          ],
                        ),
                      ),
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
                              Text(Helpers.formatCurrency(balance),
                                style: TextStyle(color: balance >= amount ? Colors.green : Colors.red)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          final acc = accountsData.firstWhere((a) => a['id'] == value);
                          setState(() {
                            selectedAccountId = value;
                            selectedAccountBalance = (acc['balance'] ?? 0).toDouble();
                          });
                        }
                      },
                    ),

                    if (!hasEnoughBalance && amount > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.red, size: 16),
                            const SizedBox(width: 8),
                            Text('Saldo insuficiente', style: TextStyle(color: Colors.red[700], fontSize: 12)),
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
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue, size: 20),
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
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              FilledButton.icon(
                onPressed: (selectedEmployeeId == null || amount <= 0 || !hasEnoughBalance)
                    ? null
                    : () async {
                        Navigator.pop(context);

                        final success = await ref.read(payrollProvider.notifier).createLoan(
                          employeeId: selectedEmployeeId!,
                          amount: amount,
                          installments: installments,
                          accountId: selectedAccountId!,
                          reason: reasonController.text.isNotEmpty ? reasonController.text : null,
                        );

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? '✅ Préstamo de ${Helpers.formatCurrency(amount)} otorgado'
                                  : '❌ Error al crear préstamo'),
                              backgroundColor: success ? Colors.green : Colors.red,
                            ),
                          );
                        }
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

          return AlertDialog(
            title: const Text('Nueva Incapacidad'),
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
                        labelText: 'Tipo de Incapacidad',
                        prefixIcon: Icon(Icons.medical_services),
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
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer, color: Colors.orange),
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
                        backgroundColor: success ? Colors.green : Colors.red,
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
      size.width * 0.15, size.height * 0.8,
      size.width * 0.2, size.height * 0.25,
      size.width * 0.375, size.height * 0.25,
    );
    path.cubicTo(
      size.width * 0.55, size.height * 0.25,
      size.width * 0.625, size.height * 0.65,
      size.width * 0.75, size.height * 0.65,
    );
    path.cubicTo(
      size.width * 0.875, size.height * 0.65,
      size.width * 0.95, size.height * 0.15,
      size.width, size.height * 0.15,
    );

    // Fill path
    fillPath.cubicTo(
      size.width * 0.15, size.height * 0.8,
      size.width * 0.2, size.height * 0.25,
      size.width * 0.375, size.height * 0.25,
    );
    fillPath.cubicTo(
      size.width * 0.55, size.height * 0.25,
      size.width * 0.625, size.height * 0.65,
      size.width * 0.75, size.height * 0.65,
    );
    fillPath.cubicTo(
      size.width * 0.875, size.height * 0.65,
      size.width * 0.95, size.height * 0.15,
      size.width, size.height * 0.15,
    );
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
