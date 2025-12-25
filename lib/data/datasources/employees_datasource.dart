import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/employee.dart';

class EmployeesDatasource {
  static final _client = Supabase.instance.client;

  /// Obtener todos los empleados
  static Future<List<Employee>> getEmployees({bool activeOnly = true}) async {
    try {
      print('🔄 Cargando empleados desde Supabase...');
      var query = _client.from('employees').select();
      
      if (activeOnly) {
        query = query.eq('status', 'activo');
      }
      
      final response = await query.order('first_name', ascending: true);

      final employees = (response as List)
          .map((json) => Employee.fromJson(json))
          .toList();

      print('✅ Empleados cargados: ${employees.length}');
      return employees;
    } catch (e) {
      print('❌ Error cargando empleados: $e');
      return [];
    }
  }

  /// Obtener empleado por ID
  static Future<Employee?> getEmployeeById(String id) async {
    try {
      final response = await _client
          .from('employees')
          .select()
          .eq('id', id)
          .single();

      return Employee.fromJson(response);
    } catch (e) {
      print('❌ Error obteniendo empleado: $e');
      return null;
    }
  }

  /// Crear empleado
  static Future<Employee?> createEmployee(Employee employee) async {
    try {
      print('🔄 Creando empleado: ${employee.fullName}');
      final response = await _client
          .from('employees')
          .insert(employee.toJson())
          .select()
          .single();

      print('✅ Empleado creado exitosamente');
      return Employee.fromJson(response);
    } catch (e) {
      print('❌ Error creando empleado: $e');
      return null;
    }
  }

  /// Actualizar empleado
  static Future<bool> updateEmployee(Employee employee) async {
    try {
      await _client
          .from('employees')
          .update(employee.toJson())
          .eq('id', employee.id);

      print('✅ Empleado actualizado: ${employee.fullName}');
      return true;
    } catch (e) {
      print('❌ Error actualizando empleado: $e');
      return false;
    }
  }

  /// Eliminar empleado
  static Future<bool> deleteEmployee(String id) async {
    try {
      await _client.from('employees').delete().eq('id', id);
      print('✅ Empleado eliminado');
      return true;
    } catch (e) {
      print('❌ Error eliminando empleado: $e');
      return false;
    }
  }

  // ========== TAREAS ==========

  /// Obtener tareas de un empleado
  static Future<List<EmployeeTask>> getTasksByEmployee(String employeeId) async {
    try {
      final response = await _client
          .from('employee_tasks')
          .select('*, employees(first_name, last_name)')
          .eq('employee_id', employeeId)
          .order('assigned_date', ascending: false);

      return (response as List)
          .map((json) => EmployeeTask.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error cargando tareas: $e');
      return [];
    }
  }

  /// Obtener tareas por fecha
  static Future<List<EmployeeTask>> getTasksByDate(DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final response = await _client
          .from('employee_tasks')
          .select('*, employees(first_name, last_name)')
          .eq('assigned_date', dateStr)
          .order('priority', ascending: false);

      return (response as List)
          .map((json) => EmployeeTask.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error cargando tareas por fecha: $e');
      return [];
    }
  }

  /// Obtener todas las tareas pendientes
  static Future<List<EmployeeTask>> getPendingTasks() async {
    try {
      final response = await _client
          .from('employee_tasks')
          .select('*, employees(first_name, last_name)')
          .inFilter('status', ['pendiente', 'en_progreso'])
          .order('due_date', ascending: true);

      return (response as List)
          .map((json) => EmployeeTask.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error cargando tareas pendientes: $e');
      return [];
    }
  }

  /// Crear tarea
  static Future<EmployeeTask?> createTask(EmployeeTask task) async {
    try {
      print('🔄 Creando tarea: ${task.title}');
      final response = await _client
          .from('employee_tasks')
          .insert(task.toJson())
          .select('*, employees(first_name, last_name)')
          .single();

      print('✅ Tarea creada exitosamente');
      return EmployeeTask.fromJson(response);
    } catch (e) {
      print('❌ Error creando tarea: $e');
      return null;
    }
  }

  /// Actualizar tarea
  static Future<bool> updateTask(EmployeeTask task) async {
    try {
      await _client
          .from('employee_tasks')
          .update(task.toJson())
          .eq('id', task.id);

      print('✅ Tarea actualizada');
      return true;
    } catch (e) {
      print('❌ Error actualizando tarea: $e');
      return false;
    }
  }

  /// Completar tarea
  static Future<bool> completeTask(String taskId) async {
    try {
      await _client.from('employee_tasks').update({
        'status': 'completada',
        'completed_date': DateTime.now().toIso8601String(),
      }).eq('id', taskId);

      print('✅ Tarea completada');
      return true;
    } catch (e) {
      print('❌ Error completando tarea: $e');
      return false;
    }
  }

  /// Eliminar tarea
  static Future<bool> deleteTask(String taskId) async {
    try {
      await _client.from('employee_tasks').delete().eq('id', taskId);
      print('✅ Tarea eliminada');
      return true;
    } catch (e) {
      print('❌ Error eliminando tarea: $e');
      return false;
    }
  }
}
