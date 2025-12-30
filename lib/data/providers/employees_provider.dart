import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/employee.dart';
import '../datasources/employees_datasource.dart';

/// Estado de empleados
class EmployeesState {
  final List<Employee> employees;
  final List<EmployeeTask> tasks;
  final List<EmployeeTimeEntry> timeEntries;
  final List<EmployeeTimeAdjustment> timeAdjustments;
  final List<EmployeeTimeSummary> timeSummaries;
  final List<EmployeeTaskTimeLog> taskTimeLogs;
  final bool isLoading;
  final bool isTimeLoading;
  final String? error;
  final String searchQuery;
  final Employee? selectedEmployee;

  EmployeesState({
    this.employees = const [],
    this.tasks = const [],
    this.timeEntries = const [],
    this.timeAdjustments = const [],
    this.timeSummaries = const [],
    this.taskTimeLogs = const [],
    this.isLoading = false,
    this.isTimeLoading = false,
    this.error,
    this.searchQuery = '',
    this.selectedEmployee,
  });

  EmployeesState copyWith({
    List<Employee>? employees,
    List<EmployeeTask>? tasks,
    List<EmployeeTimeEntry>? timeEntries,
    List<EmployeeTimeAdjustment>? timeAdjustments,
    List<EmployeeTimeSummary>? timeSummaries,
    List<EmployeeTaskTimeLog>? taskTimeLogs,
    bool? isLoading,
    bool? isTimeLoading,
    String? error,
    String? searchQuery,
    Employee? selectedEmployee,
    bool clearSelectedEmployee = false,
  }) {
    return EmployeesState(
      employees: employees ?? this.employees,
      tasks: tasks ?? this.tasks,
      timeEntries: timeEntries ?? this.timeEntries,
      timeAdjustments: timeAdjustments ?? this.timeAdjustments,
      timeSummaries: timeSummaries ?? this.timeSummaries,
      taskTimeLogs: taskTimeLogs ?? this.taskTimeLogs,
      isLoading: isLoading ?? this.isLoading,
      isTimeLoading: isTimeLoading ?? this.isTimeLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedEmployee: clearSelectedEmployee
          ? null
          : selectedEmployee ?? this.selectedEmployee,
    );
  }

  /// Empleados filtrados por búsqueda
  List<Employee> get filteredEmployees {
    if (searchQuery.isEmpty) return employees;
    final query = searchQuery.toLowerCase();
    return employees
        .where(
          (e) =>
              e.fullName.toLowerCase().contains(query) ||
              e.position.toLowerCase().contains(query) ||
              (e.department?.toLowerCase().contains(query) ?? false),
        )
        .toList();
  }

  /// Empleados activos
  List<Employee> get activeEmployees =>
      employees.where((e) => e.status == EmployeeStatus.activo).toList();

  /// Tareas pendientes de hoy
  List<EmployeeTask> get todayTasks {
    final today = DateTime.now();
    return tasks.where((t) {
      return t.assignedDate.year == today.year &&
          t.assignedDate.month == today.month &&
          t.assignedDate.day == today.day &&
          t.status != TaskStatus.completada &&
          t.status != TaskStatus.cancelada;
    }).toList();
  }

  /// Tareas del empleado seleccionado
  List<EmployeeTask> get selectedEmployeeTasks {
    if (selectedEmployee == null) return [];
    return tasks.where((t) => t.employeeId == selectedEmployee!.id).toList();
  }

  /// Resumen semanal más reciente
  EmployeeTimeSummary? get currentTimeSummary =>
      timeSummaries.isNotEmpty ? timeSummaries.first : null;
}

/// Notifier para manejar empleados (Riverpod 3.0)
class EmployeesNotifier extends Notifier<EmployeesState> {
  @override
  EmployeesState build() {
    return EmployeesState();
  }

  /// Cargar empleados
  Future<void> loadEmployees({bool activeOnly = false}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final employees = await EmployeesDatasource.getEmployees(
        activeOnly: activeOnly,
      );
      state = state.copyWith(employees: employees, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Buscar empleados
  void search(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Seleccionar empleado
  Future<void> selectEmployee(Employee? employee) async {
    if (employee == null) {
      state = state.copyWith(
        clearSelectedEmployee: true,
        timeEntries: [],
        timeAdjustments: [],
        timeSummaries: [],
        taskTimeLogs: [],
        isTimeLoading: false,
      );
      return;
    }

    state = state.copyWith(selectedEmployee: employee);
    await loadTasksByEmployee(employee.id);
    await loadTimeOverview(employee.id);
  }

  /// Crear empleado
  Future<Employee?> createEmployee(Employee employee) async {
    try {
      final created = await EmployeesDatasource.createEmployee(employee);
      if (created != null) {
        state = state.copyWith(employees: [...state.employees, created]);
      }
      return created;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Actualizar empleado
  Future<bool> updateEmployee(Employee employee) async {
    try {
      final success = await EmployeesDatasource.updateEmployee(employee);
      if (success) {
        final updatedList = state.employees.map((e) {
          return e.id == employee.id ? employee : e;
        }).toList();
        state = state.copyWith(employees: updatedList);
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Eliminar empleado
  Future<bool> deleteEmployee(String id) async {
    try {
      final success = await EmployeesDatasource.deleteEmployee(id);
      if (success) {
        state = state.copyWith(
          employees: state.employees.where((e) => e.id != id).toList(),
        );
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // ========== TAREAS ==========

  /// Cargar tareas de un empleado
  Future<void> loadTasksByEmployee(String employeeId) async {
    try {
      final tasks = await EmployeesDatasource.getTasksByEmployee(employeeId);
      state = state.copyWith(tasks: tasks);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Cargar tareas por fecha
  Future<void> loadTasksByDate(DateTime date) async {
    try {
      final tasks = await EmployeesDatasource.getTasksByDate(date);
      state = state.copyWith(tasks: tasks);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Cargar tareas pendientes
  Future<void> loadPendingTasks() async {
    try {
      final tasks = await EmployeesDatasource.getPendingTasks();
      state = state.copyWith(tasks: tasks);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Crear tarea
  Future<EmployeeTask?> createTask(EmployeeTask task) async {
    try {
      print('🔄 Creando tarea: ${task.title}');
      final created = await EmployeesDatasource.createTask(task);
      if (created != null) {
        print('✅ Tarea creada: ${created.id}');
        state = state.copyWith(tasks: [...state.tasks, created]);
      } else {
        print('⚠️ createTask retornó null');
      }
      return created;
    } catch (e) {
      print('❌ Error creando tarea: $e');
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Actualizar tarea
  Future<bool> updateTask(EmployeeTask task) async {
    try {
      final success = await EmployeesDatasource.updateTask(task);
      if (success) {
        final updatedList = state.tasks.map((t) {
          return t.id == task.id ? task : t;
        }).toList();
        state = state.copyWith(tasks: updatedList);
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Completar tarea
  Future<bool> completeTask(String taskId) async {
    try {
      final success = await EmployeesDatasource.completeTask(taskId);
      if (success) {
        final updatedList = state.tasks.map((t) {
          if (t.id == taskId) {
            return EmployeeTask(
              id: t.id,
              employeeId: t.employeeId,
              employeeName: t.employeeName,
              title: t.title,
              description: t.description,
              assignedDate: t.assignedDate,
              dueDate: t.dueDate,
              completedDate: DateTime.now(),
              status: TaskStatus.completada,
              priority: t.priority,
              category: t.category,
              estimatedTime: t.estimatedTime,
              actualTime: t.actualTime,
              activityId: t.activityId,
              notes: t.notes,
              createdAt: t.createdAt,
              updatedAt: DateTime.now(),
              assignedBy: t.assignedBy,
            );
          }
          return t;
        }).toList();
        state = state.copyWith(tasks: updatedList);
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Eliminar tarea
  Future<bool> deleteTask(String taskId) async {
    try {
      final success = await EmployeesDatasource.deleteTask(taskId);
      if (success) {
        state = state.copyWith(
          tasks: state.tasks.where((t) => t.id != taskId).toList(),
        );
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // ========== CONTROL HORARIO ==========

  /// Cargar datos de tiempo para el panel del empleado
  Future<void> loadTimeOverview(String employeeId) async {
    state = state.copyWith(isTimeLoading: true, error: null);
    try {
      final summariesFuture = EmployeesDatasource.getTimeSummaries(
        employeeId: employeeId,
      );
      final entriesFuture = EmployeesDatasource.getTimeEntries(
        employeeId: employeeId,
        startDate: DateTime.now().subtract(const Duration(days: 14)),
      );
      final adjustmentsFuture = EmployeesDatasource.getTimeAdjustments(
        employeeId: employeeId,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
      );
      final logsFuture = EmployeesDatasource.getTaskTimeLogs(
        employeeId: employeeId,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
      );

      final results = await Future.wait([
        summariesFuture,
        entriesFuture,
        adjustmentsFuture,
        logsFuture,
      ]);

      state = state.copyWith(
        timeSummaries: results[0] as List<EmployeeTimeSummary>,
        timeEntries: results[1] as List<EmployeeTimeEntry>,
        timeAdjustments: results[2] as List<EmployeeTimeAdjustment>,
        taskTimeLogs: results[3] as List<EmployeeTaskTimeLog>,
        isTimeLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isTimeLoading: false, error: e.toString());
    }
  }

  /// Crear un ajuste manual de horas para el empleado
  Future<bool> createTimeAdjustment({
    required String employeeId,
    required int minutes,
    required String type,
    DateTime? date,
    String? reason,
    String? notes,
    String? timesheetId,
  }) async {
    try {
      final adjustment = await EmployeesDatasource.createTimeAdjustment(
        employeeId: employeeId,
        minutes: minutes,
        type: type,
        date: date,
        reason: reason,
        notes: notes,
        timesheetId: timesheetId,
      );

      if (adjustment != null) {
        state = state.copyWith(
          timeAdjustments: [adjustment, ...state.timeAdjustments],
        );
        await loadTimeOverview(employeeId);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Registrar entrada de tiempo (check-in)
  Future<EmployeeTimeEntry?> registerTimeEntry({
    required String employeeId,
    required DateTime date,
    required DateTime checkIn,
  }) async {
    try {
      final entry = await EmployeesDatasource.createTimeEntry(
        employeeId: employeeId,
        date: date,
        checkIn: checkIn,
      );

      if (entry != null) {
        state = state.copyWith(
          timeEntries: [entry, ...state.timeEntries],
        );
      }
      return entry;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Actualizar entrada de tiempo (check-out)
  Future<bool> updateTimeEntry({
    required String entryId,
    DateTime? checkOut,
    double? hoursWorked,
  }) async {
    try {
      final success = await EmployeesDatasource.updateTimeEntry(
        entryId: entryId,
        checkOut: checkOut,
        hoursWorked: hoursWorked,
      );

      if (success) {
        final updatedList = state.timeEntries.map((e) {
          if (e.id == entryId) {
            return EmployeeTimeEntry(
              id: e.id,
              employeeId: e.employeeId,
              entryDate: e.entryDate,
              scheduledStart: e.scheduledStart,
              scheduledEnd: e.scheduledEnd,
              scheduledMinutes: e.scheduledMinutes,
              checkIn: e.checkIn,
              checkOut: checkOut ?? e.checkOut,
              breakMinutes: e.breakMinutes,
              workedMinutes: hoursWorked != null ? (hoursWorked * 60).round() : e.workedMinutes,
              overtimeMinutes: e.overtimeMinutes,
              deficitMinutes: e.deficitMinutes,
              status: 'aprobado',
              source: e.source,
              notes: e.notes,
              createdAt: e.createdAt,
              updatedAt: DateTime.now(),
            );
          }
          return e;
        }).toList();
        state = state.copyWith(timeEntries: updatedList);
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

/// Provider de empleados
final employeesProvider = NotifierProvider<EmployeesNotifier, EmployeesState>(
  () {
    return EmployeesNotifier();
  },
);
