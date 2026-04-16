import '../../core/utils/colombia_time.dart';
import '../../core/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/employee.dart';
import 'audit_log_datasource.dart';

class EmployeesDatasource {
  static final _client = Supabase.instance.client;

  /// Obtener todos los empleados
  static Future<List<Employee>> getEmployees({bool activeOnly = true}) async {
    try {
      AppLogger.debug('?? Cargando empleados desde Supabase...');
      var query = _client.from('employees').select();

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query.order('first_name', ascending: false);

      final employees = (response as List)
          .map((json) => Employee.fromJson(json))
          .toList();

      AppLogger.success('? Empleados cargados: ${employees.length}');
      return employees;
    } catch (e) {
      AppLogger.error('? Error cargando empleados: $e');
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
      AppLogger.error('? Error obteniendo empleado: $e');
      return null;
    }
  }

  /// Crear empleado
  static Future<Employee?> createEmployee(Employee employee) async {
    try {
      AppLogger.debug('?? Creando empleado: ${employee.fullName}');
      final response = await _client
          .from('employees')
          .insert(employee.toJson())
          .select()
          .single();

      AppLogger.success('? Empleado creado exitosamente');
      final created = Employee.fromJson(response);
      AuditLogDatasource.log(
        action: 'create',
        module: 'employees',
        recordId: created.id,
        description: 'Creó empleado: ${created.fullName} (${created.position})',
      );
      return created;
    } catch (e) {
      AppLogger.error('? Error creando empleado: $e');
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

      AppLogger.success('? Empleado actualizado: ${employee.fullName}');
      AuditLogDatasource.log(
        action: 'update',
        module: 'employees',
        recordId: employee.id,
        description: 'Actualizó empleado: ${employee.fullName}',
      );
      return true;
    } catch (e) {
      AppLogger.error('? Error actualizando empleado: $e');
      return false;
    }
  }

  /// Eliminar empleado
  static Future<bool> deleteEmployee(String id) async {
    try {
      await _client.from('employees').delete().eq('id', id);
      AppLogger.success('? Empleado eliminado');
      AuditLogDatasource.log(
        action: 'delete',
        module: 'employees',
        recordId: id,
        description: 'Eliminó empleado',
      );
      return true;
    } catch (e) {
      AppLogger.error('? Error eliminando empleado: $e');
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
      AppLogger.error('? Error cargando tareas: $e');
      return [];
    }
  }

  /// Obtener tareas por fecha
  static Future<List<EmployeeTask>> getTasksByDate(DateTime date) async {
    try {
      final dateStr = ColombiaTime.dateString(date);
      final response = await _client
          .from('employee_tasks')
          .select('*, employees(first_name, last_name)')
          .eq('assigned_date', dateStr)
          .order('priority', ascending: false);

      return (response as List)
          .map((json) => EmployeeTask.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.error('? Error cargando tareas por fecha: $e');
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
      AppLogger.error('? Error cargando tareas pendientes: $e');
      return [];
    }
  }

  /// Crear tarea
  static Future<EmployeeTask?> createTask(EmployeeTask task) async {
    try {
      AppLogger.debug('?? Creando tarea: ${task.title}');
      final response = await _client
          .from('employee_tasks')
          .insert(task.toJson())
          .select('*, employees(first_name, last_name)')
          .single();

      AppLogger.success('? Tarea creada exitosamente');
      final created = EmployeeTask.fromJson(response);
      AuditLogDatasource.log(
        action: 'create',
        module: 'employees',
        recordId: created.id,
        description: 'Creó tarea: ${created.title}',
      );
      return created;
    } catch (e) {
      AppLogger.error('? Error creando tarea: $e');
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

      AppLogger.success('? Tarea actualizada');
      return true;
    } catch (e) {
      AppLogger.error('? Error actualizando tarea: $e');
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
            'completed_date': ColombiaTime.nowIso8601(),
          })
          .eq('id', taskId);

      AppLogger.success('? Tarea completada');
      AuditLogDatasource.log(
        action: 'update',
        module: 'employees',
        recordId: taskId,
        description: 'Completó tarea',
      );
      return true;
    } catch (e) {
      AppLogger.error('? Error completando tarea: $e');
      return false;
    }
  }

  /// Eliminar tarea
  static Future<bool> deleteTask(String taskId) async {
    try {
      await _client.from('employee_tasks').delete().eq('id', taskId);
      AppLogger.success('? Tarea eliminada');
      return true;
    } catch (e) {
      AppLogger.error('? Error eliminando tarea: $e');
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
        query = query.gte('entry_date', ColombiaTime.dateString(startDate));
      }

      if (endDate != null) {
        query = query.lte('entry_date', ColombiaTime.dateString(endDate));
      }

      final response = await query
          .order('entry_date', ascending: false)
          .order('check_in', ascending: false);

      return (response as List)
          .map((json) => EmployeeTimeEntry.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.error('? Error cargando registros de tiempo: $e');
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
      AppLogger.error('? Error cargando resúmenes de tiempo: $e');
      return [];
    }
  }

  /// Obtener ajustes de tiempo del empleado
  static Future<List<EmployeeTimeAdjustment>> getTimeAdjustments({
    required String employeeId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _client
          .from('employee_time_adjustments')
          .select()
          .eq('employee_id', employeeId);

      if (startDate != null) {
        query = query.gte(
          'adjustment_date',
          ColombiaTime.dateString(startDate),
        );
      }

      if (endDate != null) {
        query = query.lte('adjustment_date', ColombiaTime.dateString(endDate));
      }

      final response = await query.order('adjustment_date', ascending: false);

      return (response as List)
          .map((json) => EmployeeTimeAdjustment.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.error('? Error cargando ajustes de tiempo: $e');
      return [];
    }
  }

  /// Obtener ajustes de tiempo de TODOS los empleados en un rango de fechas.
  /// Útil para el calendario de quincena.
  static Future<List<EmployeeTimeAdjustment>> getAllAdjustmentsInRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _client
          .from('employee_time_adjustments')
          .select()
          .gte('adjustment_date', ColombiaTime.dateString(startDate))
          .lte('adjustment_date', ColombiaTime.dateString(endDate))
          .order('adjustment_date', ascending: true);

      return (response as List)
          .map((json) => EmployeeTimeAdjustment.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.error('? Error cargando ajustes de rango: $e');
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
        'adjustment_date': ColombiaTime.dateString(date ?? ColombiaTime.now()),
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
      AppLogger.error('? Error creando ajuste de tiempo: $e');
      return null;
    }
  }

  /// Eliminar todos los ajustes de tiempo de un empleado en una fecha específica.
  /// Retorna la cantidad de registros eliminados (0 si no había).
  static Future<int> deleteTimeAdjustmentsForDate({
    required String employeeId,
    required DateTime date,
  }) async {
    try {
      final dateStr = ColombiaTime.dateString(date);
      // Primero obtener IDs para saber cuántos son
      final existing = await _client
          .from('employee_time_adjustments')
          .select('id')
          .eq('employee_id', employeeId)
          .eq('adjustment_date', dateStr);

      if ((existing as List).isEmpty) return 0;

      await _client
          .from('employee_time_adjustments')
          .delete()
          .eq('employee_id', employeeId)
          .eq('adjustment_date', dateStr);

      return existing.length;
    } catch (e) {
      AppLogger.error('? Error eliminando ajustes de tiempo: $e');
      return 0;
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
      AppLogger.error('? Error registrando jornada: $e');
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
        query = query.gte('start_time', ColombiaTime.toIso8601(startDate));
      }

      if (endDate != null) {
        query = query.lte('start_time', ColombiaTime.toIso8601(endDate));
      }

      final response = await query.order('start_time', ascending: false);

      return (response as List)
          .map((json) => EmployeeTaskTimeLog.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.error('? Error cargando tiempos de tareas: $e');
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
      AppLogger.debug('?? Registrando entrada para empleado: $employeeId');
      final response = await _client
          .from('employee_time_entries')
          .insert({
            'employee_id': employeeId,
            'entry_date': ColombiaTime.dateString(date),
            'check_in': ColombiaTime.toIso8601(checkIn),
            'status': 'registrado',
            'source': 'manual',
          })
          .select()
          .single();

      AppLogger.success('? Entrada registrada exitosamente');
      return EmployeeTimeEntry.fromJson(response);
    } catch (e) {
      AppLogger.error('? Error registrando entrada: $e');
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
      AppLogger.debug('?? Registrando salida para entrada: $entryId');
      final updates = <String, dynamic>{};

      if (checkOut != null) {
        updates['check_out'] = ColombiaTime.toIso8601(checkOut);
      }
      if (hoursWorked != null) {
        updates['worked_minutes'] = (hoursWorked * 60).round();
      }
      updates['status'] = 'aprobado';

      await _client
          .from('employee_time_entries')
          .update(updates)
          .eq('id', entryId);

      AppLogger.success('? Salida registrada exitosamente');
      return true;
    } catch (e) {
      AppLogger.error('? Error registrando salida: $e');
      return false;
    }
  }

  // ========== TIMESHEETS (HOJAS DE TIEMPO) ==========

  /// Obtener timesheets de un empleado
  static Future<List<EmployeeTimeSheet>> getTimesheets({
    required String employeeId,
    int limit = 8,
  }) async {
    try {
      final response = await _client
          .from('employee_time_sheets')
          .select()
          .eq('employee_id', employeeId)
          .order('week_start', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => EmployeeTimeSheet.fromJson(json))
          .toList();
    } catch (e) {
      AppLogger.error('? Error cargando timesheets: $e');
      return [];
    }
  }

  /// Cerrar timesheet (marcar como cerrado)
  static Future<bool> closeTimesheet(String timesheetId) async {
    try {
      await _client
          .from('employee_time_sheets')
          .update({'status': 'cerrado', 'locked_at': ColombiaTime.nowIso8601()})
          .eq('id', timesheetId);
      AppLogger.success('? Timesheet cerrado exitosamente');
      return true;
    } catch (e) {
      AppLogger.error('? Error cerrando timesheet: $e');
      return false;
    }
  }

  /// Aprobar timesheet
  static Future<bool> approveTimesheet(
    String timesheetId,
    String approvedBy,
  ) async {
    try {
      await _client
          .from('employee_time_sheets')
          .update({
            'status': 'aprobado',
            'approved_by': approvedBy,
            'approved_at': ColombiaTime.nowIso8601(),
          })
          .eq('id', timesheetId);
      AppLogger.success('? Timesheet aprobado exitosamente');
      return true;
    } catch (e) {
      AppLogger.error('? Error aprobando timesheet: $e');
      return false;
    }
  }

  /// Reabrir timesheet
  static Future<bool> reopenTimesheet(String timesheetId) async {
    try {
      await _client
          .from('employee_time_sheets')
          .update({
            'status': 'abierto',
            'locked_at': null,
            'approved_by': null,
            'approved_at': null,
          })
          .eq('id', timesheetId);
      AppLogger.success('? Timesheet reabierto exitosamente');
      return true;
    } catch (e) {
      AppLogger.error('? Error reabriendo timesheet: $e');
      return false;
    }
  }

  // ========== NFC ATTENDANCE ==========

  /// Registrar entrada/salida por NFC usando función RPC (por nfc_card_id)
  static Future<Map<String, dynamic>> registerNfcAttendance({
    required String nfcCardId,
    String? deviceName,
  }) async {
    try {
      AppLogger.debug('📱 Registrando asistencia NFC: $nfcCardId');
      final response = await _client.rpc(
        'register_nfc_attendance',
        params: {'p_nfc_card_id': nfcCardId, 'p_device_name': deviceName},
      );

      final result = Map<String, dynamic>.from(response as Map);
      if (result['success'] == true) {
        AppLogger.success(
          '✅ NFC ${result['action']}: ${result['employee_name']}',
        );
      } else {
        AppLogger.warning('⚠️ NFC rechazado: ${result['message']}');
      }
      return result;
    } catch (e) {
      AppLogger.error('❌ Error registrando NFC: $e');
      return {
        'success': false,
        'error': 'SYSTEM_ERROR',
        'message': 'Error del sistema: $e',
      };
    }
  }

  /// Buscar empleado por NFC card ID
  static Future<Employee?> getEmployeeByNfc(String nfcCardId) async {
    try {
      final response = await _client
          .from('employees')
          .select()
          .eq('nfc_card_id', nfcCardId)
          .maybeSingle();

      if (response == null) return null;
      return Employee.fromJson(response);
    } catch (e) {
      AppLogger.error('❌ Error buscando empleado por NFC: $e');
      return null;
    }
  }

  /// Asignar tarjeta NFC a un empleado
  static Future<bool> assignNfcCard({
    required String employeeId,
    required String nfcCardId,
  }) async {
    try {
      await _client
          .from('employees')
          .update({'nfc_card_id': nfcCardId})
          .eq('id', employeeId);
      AppLogger.success('✅ Tarjeta NFC asignada');
      return true;
    } catch (e) {
      AppLogger.error('❌ Error asignando tarjeta NFC: $e');
      return false;
    }
  }

  /// Desasignar tarjeta NFC de un empleado
  static Future<bool> removeNfcCard(String employeeId) async {
    try {
      await _client
          .from('employees')
          .update({'nfc_card_id': null})
          .eq('id', employeeId);
      AppLogger.success('✅ Tarjeta NFC removida');
      return true;
    } catch (e) {
      AppLogger.error('❌ Error removiendo tarjeta NFC: $e');
      return false;
    }
  }

  /// Obtener historial de escaneos NFC
  static Future<List<Map<String, dynamic>>> getNfcAttendanceLog({
    DateTime? startDate,
    DateTime? endDate,
    String? employeeId,
    int limit = 50,
  }) async {
    try {
      var query = _client
          .from('nfc_attendance_log')
          .select('*, employees(first_name, last_name, photo_url)');

      if (employeeId != null) {
        query = query.eq('employee_id', employeeId);
      }
      if (startDate != null) {
        query = query.gte('scanned_at', ColombiaTime.toIso8601(startDate));
      }
      if (endDate != null) {
        query = query.lte('scanned_at', ColombiaTime.toIso8601(endDate));
      }

      final response = await query
          .order('scanned_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      AppLogger.error('❌ Error cargando log NFC: $e');
      return [];
    }
  }

  /// Obtener estado actual de asistencia de todos los empleados (hoy)
  static Future<List<Map<String, dynamic>>> getTodayAttendanceStatus() async {
    try {
      final today = ColombiaTime.todayString();
      final response = await _client
          .from('employees')
          .select(
            'id, first_name, last_name, position, department, photo_url, nfc_card_id, employee_time_entries!inner(id, check_in, check_out, source)',
          )
          .eq('is_active', true)
          .eq('employee_time_entries.entry_date', today);

      // También obtener empleados sin entrada hoy
      final allActive = await _client
          .from('employees')
          .select(
            'id, first_name, last_name, position, department, photo_url, nfc_card_id',
          )
          .eq('is_active', true)
          .order('first_name', ascending: false);

      final withEntries = Map.fromEntries(
        (response as List).map((e) => MapEntry(e['id'] as String, e)),
      );

      return (allActive as List).map((emp) {
        final id = emp['id'] as String;
        if (withEntries.containsKey(id)) {
          return Map<String, dynamic>.from(withEntries[id] as Map);
        }
        return {
          ...Map<String, dynamic>.from(emp as Map),
          'employee_time_entries': <Map<String, dynamic>>[],
        };
      }).toList();
    } catch (e) {
      AppLogger.error('❌ Error cargando estado asistencia: $e');
      return [];
    }
  }
}
