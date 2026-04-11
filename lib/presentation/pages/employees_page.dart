import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/responsive/responsive_helper.dart';
import '../../domain/entities/employee.dart';
import '../../data/providers/assets_provider.dart';
import '../../data/providers/employees_provider.dart';
import '../../data/providers/payroll_provider.dart';
import '../../data/providers/activities_provider.dart';
import 'employees/employees_main_tab.dart';
import 'employees/employees_tasks_tab.dart';
import 'employees/employees_payroll_tab.dart';
import 'employees/employees_loans_tab.dart';
import 'employees/employees_assets_tab.dart';
import 'employees/employees_incapacities_tab.dart';
import 'employees/employees_commissions_tab.dart';

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
  bool _dialogOpened = false;

  // Keys to access child tab states for triggering dialogs
  final _mainTabKey = GlobalKey<EmployeesMainTabState>();
  final _tasksTabKey = GlobalKey<EmployeesTasksTabState>();
  final _payrollTabKey = GlobalKey<EmployeesPayrollTabState>();
  final _loansTabKey = GlobalKey<EmployeesLoansTabState>();
  final _incapacitiesTabKey = GlobalKey<EmployeesIncapacitiesTabState>();
  final _assetsTabKey = GlobalKey<EmployeesAssetsTabState>();
  final _commissionsTabKey = GlobalKey<EmployeesCommissionsTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(employeesProvider.notifier).loadEmployees();
      ref.read(employeesProvider.notifier).loadPendingTasks();
      ref.read(payrollProvider.notifier).loadAll();
      ref.read(activitiesProvider.notifier).loadActivities();
      ref.read(assetsProvider.notifier).loadAssets();

      if (widget.openNewDialog && !_dialogOpened) {
        _dialogOpened = true;
        _mainTabKey.currentState?.showEmployeeDialog();
      } else if (widget.openNewTaskDialog && !_dialogOpened) {
        _dialogOpened = true;
        _tabController.animateTo(1);
        Future.delayed(const Duration(milliseconds: 300), () {
          _tasksTabKey.currentState?.showTaskDialog();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeesProvider);
    final payrollState = ref.watch(payrollProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFEEEEEE);
    final isMobile = ResponsiveHelper.isMobile(context);

    return Scaffold(
      floatingActionButton:
          isMobile && _tabController.index != 5 && _tabController.index != 6
          ? FloatingActionButton.small(
              heroTag: 'employees',
              onPressed: () {
                switch (_tabController.index) {
                  case 0:
                    _mainTabKey.currentState?.showEmployeeDialog();
                    break;
                  case 1:
                    _tasksTabKey.currentState?.showTaskDialog();
                    break;
                  case 2:
                    _payrollTabKey.currentState?.showCreatePayrollDialog();
                    break;
                  case 3:
                    _loansTabKey.currentState?.showLoanDialog();
                    break;
                  case 4:
                    _commissionsTabKey.currentState;
                    break;
                  case 5:
                    _incapacitiesTabKey.currentState?.showNewIncapacityDialog();
                    break;
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // Header compacto con tabs inline
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 0 : 4,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: isMobile
                  ? Column(
                      children: [
                        // Mobile: tabs full width
                        TabBar(
                          controller: _tabController,
                          labelColor: theme.colorScheme.primary,
                          unselectedLabelColor:
                              theme.colorScheme.onSurfaceVariant,
                          indicatorColor: theme.colorScheme.primary,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                          labelStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          tabs: const [
                            Tab(text: 'Empleados', height: 36),
                            Tab(text: 'Tareas', height: 36),
                            Tab(text: 'Nómina', height: 36),
                            Tab(text: 'Préstamos', height: 36),
                            Tab(text: 'Comisiones', height: 36),
                            Tab(text: 'Incapacidades', height: 36),
                            Tab(text: 'Activos', height: 36),
                          ],
                        ),
                      ],
                    )
                  : Row(
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
                            unselectedLabelColor:
                                theme.colorScheme.onSurfaceVariant,
                            indicatorColor: theme.colorScheme.primary,
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            labelPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            tabs: const [
                              Tab(text: 'Empleados'),
                              Tab(text: 'Tareas'),
                              Tab(text: 'Nómina'),
                              Tab(text: 'Préstamos'),
                              Tab(text: 'Comisiones'),
                              Tab(text: 'Incapacidades'),
                              Tab(text: 'Activos'),
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
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
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
                  EmployeesMainTab(key: _mainTabKey),
                  EmployeesTasksTab(key: _tasksTabKey),
                  EmployeesPayrollTab(key: _payrollTabKey),
                  EmployeesLoansTab(key: _loansTabKey),
                  EmployeesCommissionsTab(key: _commissionsTabKey),
                  EmployeesIncapacitiesTab(key: _incapacitiesTabKey),
                  EmployeesAssetsTab(key: _assetsTabKey),
                ],
              ),
            ),
          ],
        ),
      ),
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
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF9E9E9E)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton() {
    final labels = ['+Emp', '+Tar', '+Nóm', '+Prés', '+Inc', ''];
    final icons = [
      Icons.person_add,
      Icons.add_task,
      Icons.payments,
      Icons.attach_money,
      Icons.medical_services,
      Icons.precision_manufacturing,
    ];

    // Tab de activos no tiene botón de acción (solo lectura)
    if (_tabController.index == 5) return const SizedBox.shrink();

    return FilledButton.icon(
      onPressed: () {
        switch (_tabController.index) {
          case 0:
            _mainTabKey.currentState?.showEmployeeDialog();
            break;
          case 1:
            _tasksTabKey.currentState?.showTaskDialog();
            break;
          case 2:
            _payrollTabKey.currentState?.showCreatePayrollDialog();
            break;
          case 3:
            _loansTabKey.currentState?.showLoanDialog();
            break;
          case 4:
            _incapacitiesTabKey.currentState?.showNewIncapacityDialog();
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
}
