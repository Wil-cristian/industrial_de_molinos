import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/employee.dart';
import '../datasources/employees_datasource.dart';

/// Estado de empleados
class EmployeesState {
  final List<Employee> employees;
  final List<EmployeeTask> tasks;
  final bool isLoading;
  final String? error;
  final String searchQuery;
  final Employee? selectedEmployee;

  EmployeesState({
    this.employees = const [],
    this.tasks = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
    this.selectedEmployee,
  });

  EmployeesState copyWith({
    List<Employee>? employees,
    List<EmployeeTask>? tasks,
    bool? isLoading,
    String? error,
    String? searchQuery,
    Employee? selectedEmployee,
  }) {
    return EmployeesState(
      employees: employees ?? this.employees,
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedEmployee: selectedEmployee ?? this.selectedEmployee,
    );
  }

  /// Empleados filtrados por búsqueda
  List<Employee> get filteredEmployees {
    if (searchQuery.isEmpty) return employees;
    final query = searchQuery.toLowerCase();
    return employees.where((e) =>
      e.fullName.toLowerCase().contains(query) ||
      e.position.toLowerCase().contains(query) ||
      (e.department?.toLowerCase().contains(query) ?? false)
    ).toList();
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
      final employees = await EmployeesDatasource.getEmployees(activeOnly: activeOnly);
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
    state = state.copyWith(selectedEmployee: employee);
    if (employee != null) {
      await loadTasksByEmployee(employee.id);
    }
  }

  /// Crear empleado
  Future<Employee?> createEmployee(Employee employee) async {
    try {
      final created = await EmployeesDatasource.createEmployee(employee);
      if (created != null) {
        state = state.copyWith(
          employees: [...state.employees, created],
        );
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
      final created = await EmployeesDatasource.createTask(task);
      if (created != null) {
        state = state.copyWith(
          tasks: [...state.tasks, created],
        );
      }
      return created;
    } catch (e) {
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
}

/// Provider de empleados
final employeesProvider =
    NotifierProvider<EmployeesNotifier, EmployeesState>(() {
  return EmployeesNotifier();
});
