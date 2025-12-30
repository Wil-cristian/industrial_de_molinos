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
        query = query.eq('is_active', true);
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
  static Future<List<EmployeeTask>> getTasksByEmployee(
    String employeeId,
  ) async {
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
      await _client
          .from('employee_tasks')
          .update({
            'status': 'completada',
            'completed_date': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId);

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

  // ========== CONTROL HORARIO ==========

  /// Obtener registros de tiempo de un empleado
  static Future<List<EmployeeTimeEntry>> getTimeEntries({
    required String employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _client
          .from('employee_time_entries')
          .select()
          .eq('employee_id', employeeId);

      if (startDate != null) {
        query = query.gte(
          'entry_date',
          startDate.toIso8601String().split('T')[0],
        );
      }

      if (endDate != null) {
        query = query.lte(
          'entry_date',
          endDate.toIso8601String().split('T')[0],
        );
      }

      final response = await query
          .order('entry_date', ascending: false)
          .order('check_in', ascending: false);

      return (response as List)
          .map((json) => EmployeeTimeEntry.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error cargando registros de tiempo: $e');
      return [];
    }
  }

  /// Obtener resúmenes semanales de tiempo del empleado
  static Future<List<EmployeeTimeSummary>> getTimeSummaries({
    required String employeeId,
    int limit = 4,
  }) async {
    try {
      final response = await _client
          .from('employee_time_summary')
          .select()
          .eq('employee_id', employeeId)
          .order('week_start', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => EmployeeTimeSummary.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error cargando resúmenes de tiempo: $e');
      return [];
    }
  }

  /// Obtener ajustes de tiempo del empleado
  static Future<List<EmployeeTimeAdjustment>> getTimeAdjustments({
    required String employeeId,
    DateTime? startDate,
  }) async {
    try {
      var query = _client
          .from('employee_time_adjustments')
          .select()
          .eq('employee_id', employeeId);

      if (startDate != null) {
        query = query.gte(
          'adjustment_date',
          startDate.toIso8601String().split('T')[0],
        );
      }

      final response = await query.order('adjustment_date', ascending: false);

      return (response as List)
          .map((json) => EmployeeTimeAdjustment.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error cargando ajustes de tiempo: $e');
      return [];
    }
  }

  /// Crear ajuste manual (positivo o negativo)
  static Future<EmployeeTimeAdjustment?> createTimeAdjustment({
    required String employeeId,
    required int minutes,
    required String type,
    DateTime? date,
    String? reason,
    String? notes,
    String? timesheetId,
  }) async {
    try {
      final payload = {
        'employee_id': employeeId,
        'minutes': minutes,
        'type': type,
        'adjustment_date': (date ?? DateTime.now()).toIso8601String().split(
          'T',
        )[0],
        'reason': reason,
        'notes': notes,
        'timesheet_id': timesheetId,
      };

      final response = await _client
          .from('employee_time_adjustments')
          .insert(payload)
          .select()
          .single();

      return EmployeeTimeAdjustment.fromJson(response);
    } catch (e) {
      print('❌ Error creando ajuste de tiempo: $e');
      return null;
    }
  }

  /// Registrar entrada/salida manual
  static Future<EmployeeTimeEntry?> createOrUpdateTimeEntry({
    required EmployeeTimeEntry entry,
    bool update = false,
  }) async {
    try {
      final payload = entry.toJson();

      if (!update) {
        final response = await _client
            .from('employee_time_entries')
            .insert(payload)
            .select()
            .single();
        return EmployeeTimeEntry.fromJson(response);
      } else {
        final response = await _client
            .from('employee_time_entries')
            .update(payload)
            .eq('id', entry.id)
            .select()
            .single();
        return EmployeeTimeEntry.fromJson(response);
      }
    } catch (e) {
      print('❌ Error registrando jornada: $e');
      return null;
    }
  }

  /// Obtener tiempos invertidos en tareas
  static Future<List<EmployeeTaskTimeLog>> getTaskTimeLogs({
    required String employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _client
          .from('employee_task_time_logs')
          .select()
          .eq('employee_id', employeeId);

      if (startDate != null) {
        query = query.gte('start_time', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('start_time', endDate.toIso8601String());
      }

      final response = await query.order('start_time', ascending: false);

      return (response as List)
          .map((json) => EmployeeTaskTimeLog.fromJson(json))
          .toList();
    } catch (e) {
      print('❌ Error cargando tiempos de tareas: $e');
      return [];
    }
  }

  /// Crear entrada de tiempo (check-in)
  static Future<EmployeeTimeEntry?> createTimeEntry({
    required String employeeId,
    required DateTime date,
    required DateTime checkIn,
  }) async {
    try {
      print('🔄 Registrando entrada para empleado: $employeeId');
      final response = await _client
          .from('employee_time_entries')
          .insert({
            'employee_id': employeeId,
            'entry_date': date.toIso8601String().split('T')[0],
            'check_in': checkIn.toIso8601String(),
            'status': 'registrado',
            'source': 'manual',
          })
          .select()
          .single();

      print('✅ Entrada registrada exitosamente');
      return EmployeeTimeEntry.fromJson(response);
    } catch (e) {
      print('❌ Error registrando entrada: $e');
      return null;
    }
  }

  /// Actualizar entrada de tiempo (check-out)
  static Future<bool> updateTimeEntry({
    required String entryId,
    DateTime? checkOut,
    double? hoursWorked,
  }) async {
    try {
      print('🔄 Registrando salida para entrada: $entryId');
      final updates = <String, dynamic>{};
      
      if (checkOut != null) {
        updates['check_out'] = checkOut.toIso8601String();
      }
      if (hoursWorked != null) {
        updates['worked_minutes'] = (hoursWorked * 60).round();
      }
      updates['status'] = 'aprobado';

      await _client
          .from('employee_time_entries')
          .update(updates)
          .eq('id', entryId);

      print('✅ Salida registrada exitosamente');
      return true;
    } catch (e) {
      print('❌ Error registrando salida: $e');
      return false;
    }
  }
}
