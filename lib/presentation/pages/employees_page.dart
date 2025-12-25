import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/employee.dart';
import '../../data/providers/employees_provider.dart';
import '../../data/providers/payroll_provider.dart';
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
  String _filterStatus = 'todos';
  String _filterDepartment = 'todos';
  bool _dialogOpened = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(employeesProvider.notifier).loadEmployees();
      ref.read(employeesProvider.notifier).loadPendingTasks();
      ref.read(payrollProvider.notifier).loadAll();

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeesProvider);
    final payrollState = ref.watch(payrollProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // Header con estadísticas
          _buildHeader(theme, state, payrollState),

          // Tab Bar
          Container(
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              indicatorColor: theme.colorScheme.primary,
              isScrollable: true,
              tabs: const [
                Tab(icon: Icon(Icons.people), text: 'Empleados'),
                Tab(icon: Icon(Icons.task_alt), text: 'Tareas'),
                Tab(icon: Icon(Icons.payments), text: 'Nómina'),
                Tab(
                  icon: Icon(Icons.account_balance_wallet),
                  text: 'Préstamos',
                ),
                Tab(icon: Icon(Icons.medical_services), text: 'Incapacidades'),
              ],
            ),
          ),

          // Contenido
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEmployeesTab(theme, state),
                _buildTasksTab(theme, state),
                _buildPayrollTab(theme, state, payrollState),
                _buildLoansTab(theme, state, payrollState),
                _buildIncapacitiesTab(theme, state, payrollState),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
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

  Widget _buildHeader(
    ThemeData theme,
    EmployeesState state,
    PayrollState payrollState,
  ) {
    final activeCount = state.activeEmployees.length;
    final totalCount = state.employees.length;
    final pendingTasks = state.tasks
        .where(
          (t) =>
              t.status == TaskStatus.pendiente ||
              t.status == TaskStatus.enProgreso,
        )
        .length;
    final activeLoans = payrollState.activeLoans.length;
    final pendingPayrolls = payrollState.pendingPayrolls.length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.badge_outlined, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Gestión de Empleados y Nómina',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (payrollState.currentPeriod != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Periodo: ${payrollState.currentPeriod!.displayName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatCard(
                icon: Icons.people,
                label: 'Empleados',
                value: '$totalCount',
                color: Colors.blue,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                icon: Icons.check_circle,
                label: 'Activos',
                value: '$activeCount',
                color: Colors.green,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                icon: Icons.pending_actions,
                label: 'Tareas Pend.',
                value: '$pendingTasks',
                color: Colors.orange,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                icon: Icons.payments,
                label: 'Nóminas Pend.',
                value: '$pendingPayrolls',
                color: Colors.purple,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                icon: Icons.account_balance_wallet,
                label: 'Préstamos Act.',
                value: '$activeLoans',
                color: Colors.teal,
              ),
            ],
          ),
        ],
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

  Widget _buildEmployeesTab(ThemeData theme, EmployeesState state) {
    return Column(
      children: [
        // Barra de búsqueda y filtros
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
                  DropdownMenuItem(value: 'licencia', child: Text('Licencia')),
                  DropdownMenuItem(value: 'inactivo', child: Text('Inactivos')),
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
        ),

        // Lista de empleados
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.filteredEmployees.isEmpty
              ? _buildEmptyState(
                  icon: Icons.people_outline,
                  title: 'Sin empleados',
                  subtitle: 'Agrega empleados para comenzar',
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 350,
                    childAspectRatio: 1.3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _getFilteredEmployees(state).length,
                  itemBuilder: (context, index) {
                    final employee = _getFilteredEmployees(state)[index];
                    return _buildEmployeeCard(theme, employee);
                  },
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

  Widget _buildEmployeeCard(ThemeData theme, Employee employee) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showEmployeeDetail(employee),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.1,
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
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.fullName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          employee.position,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: employee.statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      employee.statusLabel,
                      style: TextStyle(
                        color: employee.statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (employee.department != null) ...[
                Row(
                  children: [
                    Icon(Icons.business, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      employee.department!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              Row(
                children: [
                  Icon(Icons.phone, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    employee.phone ?? 'Sin teléfono',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.assignment,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: () => _showTaskDialog(employee: employee),
                    tooltip: 'Asignar tarea',
                    iconSize: 20,
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.orange),
                    onPressed: () => _showEmployeeDialog(employee: employee),
                    tooltip: 'Editar',
                    iconSize: 20,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(employee),
                    tooltip: 'Eliminar',
                    iconSize: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTasksTab(ThemeData theme, EmployeesState state) {
    return Column(
      children: [
        // Filtros de tareas
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar tarea...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ActionChip(
                avatar: const Icon(Icons.today, size: 18),
                label: const Text('Hoy'),
                onPressed: () {
                  ref
                      .read(employeesProvider.notifier)
                      .loadTasksByDate(DateTime.now());
                },
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.pending, size: 18),
                label: const Text('Pendientes'),
                onPressed: () {
                  ref.read(employeesProvider.notifier).loadPendingTasks();
                },
              ),
            ],
          ),
        ),

        // Lista de tareas
        Expanded(
          child: state.tasks.isEmpty
              ? _buildEmptyState(
                  icon: Icons.task_alt,
                  title: 'Sin tareas',
                  subtitle: 'Asigna tareas a tus empleados',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.tasks.length,
                  itemBuilder: (context, index) {
                    final task = state.tasks[index];
                    return _buildTaskCard(theme, task);
                  },
                ),
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
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade500)),
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
    String? selectedEmployeeId = task?.employeeId ?? employee?.id;
    TaskPriority selectedPriority = task?.priority ?? TaskPriority.media;
    String selectedCategory = task?.category ?? 'General';
    DateTime selectedDate = task?.assignedDate ?? DateTime.now();

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
                  DropdownButtonFormField<String>(
                    value: selectedEmployeeId,
                    decoration: const InputDecoration(
                      labelText: 'Asignar a *',
                      border: OutlineInputBorder(),
                    ),
                    items: employees.map((emp) {
                      return DropdownMenuItem(
                        value: emp.id,
                        child: Text(emp.fullName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedEmployeeId = value);
                    },
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
                          ],
                          onChanged: (value) {
                            setDialogState(() => selectedCategory = value!);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Fecha'),
                    subtitle: Text(_formatDate(selectedDate)),
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
                    selectedEmployeeId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Completa los campos obligatorios'),
                    ),
                  );
                  return;
                }

                final selectedEmp = employees.firstWhere(
                  (e) => e.id == selectedEmployeeId,
                  orElse: () => employees.first,
                );

                final newTask = EmployeeTask(
                  id: task?.id ?? '',
                  employeeId: selectedEmployeeId!,
                  employeeName: selectedEmp.fullName,
                  title: titleController.text,
                  description: descriptionController.text.isEmpty
                      ? null
                      : descriptionController.text,
                  assignedDate: selectedDate,
                  status: task?.status ?? TaskStatus.pendiente,
                  priority: selectedPriority,
                  category: selectedCategory,
                  createdAt: task?.createdAt ?? DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                Navigator.pop(context);

                if (isEditing) {
                  await ref
                      .read(employeesProvider.notifier)
                      .updateTask(newTask);
                } else {
                  await ref
                      .read(employeesProvider.notifier)
                      .createTask(newTask);
                }
              },
              child: Text(isEditing ? 'Guardar' : 'Crear'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmployeeDetail(Employee employee) {
    ref.read(employeesProvider.notifier).selectEmployee(employee);

    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final state = ref.watch(employeesProvider);
          final tasks = state.selectedEmployeeTasks;

          return AlertDialog(
            title: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    employee.initials,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
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
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info del empleado
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            Icons.business,
                            'Departamento',
                            employee.department ?? 'N/A',
                          ),
                          _buildInfoRow(
                            Icons.phone,
                            'Teléfono',
                            employee.phone ?? 'N/A',
                          ),
                          _buildInfoRow(
                            Icons.email,
                            'Email',
                            employee.email ?? 'N/A',
                          ),
                          _buildInfoRow(
                            Icons.calendar_today,
                            'Fecha ingreso',
                            _formatDate(employee.hireDate),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tareas asignadas (${tasks.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: tasks.isEmpty
                        ? Center(
                            child: Text(
                              'Sin tareas asignadas',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: tasks.length,
                            itemBuilder: (context, index) {
                              final task = tasks[index];
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  task.status == TaskStatus.completada
                                      ? Icons.check_circle
                                      : Icons.pending,
                                  color: task.statusColor,
                                  size: 20,
                                ),
                                title: Text(
                                  task.title,
                                  style: TextStyle(
                                    decoration:
                                        task.status == TaskStatus.completada
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                subtitle: Text(_formatDate(task.assignedDate)),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: task.priorityColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    task.priority.name,
                                    style: TextStyle(
                                      color: task.priorityColor,
                                      fontSize: 10,
                                    ),
                                  ),
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
                child: const Text('Cerrar'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showTaskDialog(employee: employee);
                },
                icon: const Icon(Icons.add_task),
                label: const Text('Asignar tarea'),
              ),
            ],
          );
        },
      ),
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

  void _confirmDeleteTask(EmployeeTask task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text('¿Estás seguro de eliminar "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(employeesProvider.notifier).deleteTask(task.id);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TAB 3: NÓMINA
  // ============================================================
  Widget _buildPayrollTab(
    ThemeData theme,
    EmployeesState empState,
    PayrollState payrollState,
  ) {
    if (payrollState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con periodo y acciones
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.calendar_month, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Periodo Actual',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          payrollState.currentPeriod?.displayName ??
                              'Sin periodo',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(payrollProvider.notifier).loadAll(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Resumen de nómina
          Row(
            children: [
              Expanded(
                child: _buildPayrollSummaryCard(
                  'Total Ingresos',
                  Helpers.formatCurrency(
                    payrollState.payrolls.fold(
                      0.0,
                      (sum, p) => sum + p.totalEarnings,
                    ),
                  ),
                  Icons.trending_up,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPayrollSummaryCard(
                  'Total Descuentos',
                  Helpers.formatCurrency(
                    payrollState.payrolls.fold(
                      0.0,
                      (sum, p) => sum + p.totalDeductions,
                    ),
                  ),
                  Icons.trending_down,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPayrollSummaryCard(
                  'Neto a Pagar',
                  Helpers.formatCurrency(payrollState.totalNetPayroll),
                  Icons.payments,
                  theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Lista de nóminas
          const Text(
            'Nóminas del Periodo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (payrollState.payrolls.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text('No hay nóminas para este periodo'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _showCreatePayrollDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Crear Nómina'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...payrollState.payrolls.map(
              (payroll) => _buildPayrollCard(payroll, theme),
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
  // DIÁLOGOS
  // ============================================================
  void _showCreatePayrollDialog() {
    final employees = ref.read(employeesProvider).activeEmployees;
    final payrollState = ref.read(payrollProvider);

    if (payrollState.currentPeriod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay periodo activo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String? selectedEmployeeId;
    final salaryController = TextEditingController();
    final daysController = TextEditingController(text: '30');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crear Nómina'),
        content: SizedBox(
          width: 400,
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
                onChanged: (value) {
                  selectedEmployeeId = value;
                  // Auto-llenar salario del empleado
                  final emp = employees.firstWhere((e) => e.id == value);
                  salaryController.text = emp.salary?.toString() ?? '0';
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: salaryController,
                decoration: const InputDecoration(
                  labelText: 'Salario Base',
                  prefixIcon: Icon(Icons.attach_money),
                  prefixText: 'S/ ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: daysController,
                decoration: const InputDecoration(
                  labelText: 'Días Trabajados',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                keyboardType: TextInputType.number,
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
              if (selectedEmployeeId == null) return;

              Navigator.pop(context);
              final success = await ref
                  .read(payrollProvider.notifier)
                  .createPayroll(
                    employeeId: selectedEmployeeId!,
                    periodId: payrollState.currentPeriod!.id,
                    baseSalary: double.tryParse(salaryController.text) ?? 0,
                    daysWorked: int.tryParse(daysController.text) ?? 30,
                  );

              if (mounted && success != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nómina creada'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Crear'),
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

  void _showPayPayrollDialog(EmployeePayroll payroll) {
    String paymentMethod = 'efectivo';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Pagar Nómina'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Empleado: ${payroll.employeeName}'),
              Text(
                'Neto a pagar: ${Helpers.formatCurrency(payroll.netPay)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Método de pago:'),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'efectivo', label: Text('Efectivo')),
                  ButtonSegment(
                    value: 'transferencia',
                    label: Text('Transfer.'),
                  ),
                ],
                selected: {paymentMethod},
                onSelectionChanged: (value) =>
                    setState(() => paymentMethod = value.first),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Este pago se registrará en contabilidad',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                // TODO: Seleccionar cuenta de pago
                final accounts = await Supabase.instance.client
                    .from('accounts')
                    .select()
                    .eq('is_active', true);

                if (accounts.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No hay cuentas disponibles'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  return;
                }

                final success = await ref
                    .read(payrollProvider.notifier)
                    .processPayment(
                      payrollId: payroll.id,
                      accountId: accounts[0]['id'],
                      paymentMethod: paymentMethod,
                    );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success ? '✅ Pago registrado en contabilidad' : 'Error',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Pagar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoanDialog() {
    final employees = ref.read(employeesProvider).activeEmployees;
    String? selectedEmployeeId;
    final amountController = TextEditingController();
    final installmentsController = TextEditingController(text: '1');
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Préstamo'),
        content: SizedBox(
          width: 400,
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
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Monto del Préstamo',
                  prefixIcon: Icon(Icons.attach_money),
                  prefixText: 'S/ ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: installmentsController,
                decoration: const InputDecoration(
                  labelText: 'Número de Cuotas',
                  prefixIcon: Icon(Icons.calendar_view_month),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Motivo (opcional)',
                  prefixIcon: Icon(Icons.note),
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
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'El préstamo se registrará como egreso en contabilidad',
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
          FilledButton(
            onPressed: () async {
              if (selectedEmployeeId == null) return;

              Navigator.pop(context);

              // Obtener cuenta para el préstamo
              final accounts = await Supabase.instance.client
                  .from('accounts')
                  .select()
                  .eq('is_active', true);

              if (accounts.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No hay cuentas disponibles'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              final success = await ref
                  .read(payrollProvider.notifier)
                  .createLoan(
                    employeeId: selectedEmployeeId!,
                    amount: double.tryParse(amountController.text) ?? 0,
                    installments:
                        int.tryParse(installmentsController.text) ?? 1,
                    accountId: accounts[0]['id'],
                    reason: reasonController.text.isNotEmpty
                        ? reasonController.text
                        : null,
                  );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? '✅ Préstamo registrado en contabilidad'
                          : 'Error',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Crear Préstamo'),
          ),
        ],
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
