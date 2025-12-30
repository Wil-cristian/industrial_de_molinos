import 'package:flutter/material.dart';

/// Entidad de Empleado
class Employee {
  final String id;
  final String firstName;
  final String lastName;
  final String? documentType;
  final String? documentNumber;
  final String? email;
  final String? phone;
  final String? address;
  final String position;
  final String? department;
  final DateTime hireDate;
  final DateTime? terminationDate;
  final double? salary;
  final String salaryType;
  final EmployeeStatus status;
  final String workSchedule;
  final String? emergencyContact;
  final String? emergencyPhone;
  final String? bloodType;
  final String? photoUrl;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Employee({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.documentType,
    this.documentNumber,
    this.email,
    this.phone,
    this.address,
    required this.position,
    this.department,
    required this.hireDate,
    this.terminationDate,
    this.salary,
    this.salaryType = 'mensual',
    this.status = EmployeeStatus.activo,
    this.workSchedule = 'tiempo_completo',
    this.emergencyContact,
    this.emergencyPhone,
    this.bloodType,
    this.photoUrl,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullName => '$firstName $lastName';

  String get initials {
    final first = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$first$last';
  }

  String get statusLabel {
    switch (status) {
      case EmployeeStatus.activo:
        return 'Activo';
      case EmployeeStatus.inactivo:
        return 'Inactivo';
      case EmployeeStatus.vacaciones:
        return 'Vacaciones';
      case EmployeeStatus.licencia:
        return 'Licencia';
    }
  }

  Color get statusColor {
    switch (status) {
      case EmployeeStatus.activo:
        return Colors.green;
      case EmployeeStatus.inactivo:
        return Colors.grey;
      case EmployeeStatus.vacaciones:
        return Colors.blue;
      case EmployeeStatus.licencia:
        return Colors.orange;
    }
  }

  factory Employee.fromJson(Map<String, dynamic> json) {
    // Determinar status basado en is_active o status string
    EmployeeStatus employeeStatus;
    if (json.containsKey('is_active')) {
      employeeStatus = (json['is_active'] == true) ? EmployeeStatus.activo : EmployeeStatus.inactivo;
    } else {
      employeeStatus = _parseStatus(json['status'] as String?);
    }
    
    return Employee(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      documentType: json['document_type'] as String?,
      documentNumber: json['document_number'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      position: json['position'] as String? ?? 'Sin cargo',
      department: json['department'] as String?,
      hireDate: json['hire_date'] != null 
          ? DateTime.parse(json['hire_date'] as String)
          : DateTime.now(),
      terminationDate: json['termination_date'] != null
          ? DateTime.parse(json['termination_date'] as String)
          : null,
      salary: json['salary'] != null
          ? (json['salary'] as num).toDouble()
          : null,
      salaryType: json['salary_type'] as String? ?? 'mensual',
      status: employeeStatus,
      workSchedule: json['work_schedule'] as String? ?? 'tiempo_completo',
      emergencyContact: json['emergency_contact'] as String?,
      emergencyPhone: json['emergency_phone'] as String?,
      bloodType: json['blood_type'] as String?,
      photoUrl: json['photo_url'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'document_type': documentType,
      'document_number': documentNumber,
      'email': email,
      'phone': phone,
      'address': address,
      'position': position,
      'department': department,
      'hire_date': hireDate.toIso8601String().split('T')[0],
      'termination_date': terminationDate?.toIso8601String().split('T')[0],
      'salary': salary,
      'is_active': status == EmployeeStatus.activo,
      'notes': notes,
    };
  }

  static EmployeeStatus _parseStatus(String? status) {
    switch (status) {
      case 'inactivo':
        return EmployeeStatus.inactivo;
      case 'vacaciones':
        return EmployeeStatus.vacaciones;
      case 'licencia':
        return EmployeeStatus.licencia;
      default:
        return EmployeeStatus.activo;
    }
  }

  // ignore: unused_element - Reserved for serialization
  static String _statusToString(EmployeeStatus status) {
    switch (status) {
      case EmployeeStatus.activo:
        return 'activo';
      case EmployeeStatus.inactivo:
        return 'inactivo';
      case EmployeeStatus.vacaciones:
        return 'vacaciones';
      case EmployeeStatus.licencia:
        return 'licencia';
    }
  }
}

enum EmployeeStatus { activo, inactivo, vacaciones, licencia }

/// Entidad de Tarea de Empleado
class EmployeeTask {
  final String id;
  final String employeeId;
  final String? employeeName;
  final String title;
  final String? description;
  final DateTime assignedDate;
  final DateTime? dueDate;
  final DateTime? completedDate;
  final TaskStatus status;
  final TaskPriority priority;
  final String category;
  final int? estimatedTime;
  final int? actualTime;
  final String? activityId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? assignedBy;

  EmployeeTask({
    required this.id,
    required this.employeeId,
    this.employeeName,
    required this.title,
    this.description,
    required this.assignedDate,
    this.dueDate,
    this.completedDate,
    this.status = TaskStatus.pendiente,
    this.priority = TaskPriority.media,
    this.category = 'general',
    this.estimatedTime,
    this.actualTime,
    this.activityId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.assignedBy,
  });

  String get statusLabel {
    switch (status) {
      case TaskStatus.pendiente:
        return 'Pendiente';
      case TaskStatus.enProgreso:
        return 'En Progreso';
      case TaskStatus.completada:
        return 'Completada';
      case TaskStatus.cancelada:
        return 'Cancelada';
    }
  }

  Color get statusColor {
    switch (status) {
      case TaskStatus.pendiente:
        return Colors.orange;
      case TaskStatus.enProgreso:
        return Colors.blue;
      case TaskStatus.completada:
        return Colors.green;
      case TaskStatus.cancelada:
        return Colors.grey;
    }
  }

  String get priorityLabel {
    switch (priority) {
      case TaskPriority.baja:
        return 'Baja';
      case TaskPriority.media:
        return 'Media';
      case TaskPriority.alta:
        return 'Alta';
      case TaskPriority.urgente:
        return 'Urgente';
    }
  }

  Color get priorityColor {
    switch (priority) {
      case TaskPriority.baja:
        return Colors.grey;
      case TaskPriority.media:
        return Colors.blue;
      case TaskPriority.alta:
        return Colors.orange;
      case TaskPriority.urgente:
        return Colors.red;
    }
  }

  String get categoryLabel {
    switch (category) {
      case 'produccion':
        return 'Producción';
      case 'limpieza':
        return 'Limpieza';
      case 'mantenimiento':
        return 'Mantenimiento';
      case 'entrega':
        return 'Entrega';
      case 'administrativo':
        return 'Administrativo';
      default:
        return 'General';
    }
  }

  IconData get categoryIcon {
    switch (category) {
      case 'produccion':
        return Icons.precision_manufacturing;
      case 'limpieza':
        return Icons.cleaning_services;
      case 'mantenimiento':
        return Icons.build;
      case 'entrega':
        return Icons.local_shipping;
      case 'administrativo':
        return Icons.description;
      default:
        return Icons.task;
    }
  }

  factory EmployeeTask.fromJson(Map<String, dynamic> json) {
    return EmployeeTask(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      employeeName: json['employees']?['first_name'] != null
          ? '${json['employees']['first_name']} ${json['employees']['last_name']}'
          : null,
      title: json['title'] as String,
      description: json['description'] as String?,
      assignedDate: DateTime.parse(json['assigned_date'] as String),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      completedDate: json['completed_date'] != null
          ? DateTime.parse(json['completed_date'] as String)
          : null,
      status: _parseTaskStatus(json['status'] as String?),
      priority: _parseTaskPriority(json['priority'] as String?),
      category: json['category'] as String? ?? 'general',
      estimatedTime: json['estimated_time'] as int?,
      actualTime: json['actual_time'] as int?,
      activityId: json['activity_id'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      assignedBy: json['assigned_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'employee_id': employeeId,
      'title': title,
      'assigned_date': assignedDate.toIso8601String().split('T')[0],
      'status': _taskStatusToString(status),
      'priority': _taskPriorityToString(priority),
      'category': category,
    };
    
    // Solo incluir campos opcionales si tienen valor
    if (description != null) json['description'] = description;
    if (dueDate != null) json['due_date'] = dueDate!.toIso8601String().split('T')[0];
    if (completedDate != null) json['completed_date'] = completedDate!.toIso8601String();
    if (estimatedTime != null) json['estimated_time'] = estimatedTime;
    if (actualTime != null) json['actual_time'] = actualTime;
    if (notes != null) json['notes'] = notes;
    if (assignedBy != null) json['assigned_by'] = assignedBy;
    if (activityId != null) json['activity_id'] = activityId;
    
    return json;
  }

  static TaskStatus _parseTaskStatus(String? status) {
    switch (status) {
      case 'en_progreso':
        return TaskStatus.enProgreso;
      case 'completada':
        return TaskStatus.completada;
      case 'cancelada':
        return TaskStatus.cancelada;
      default:
        return TaskStatus.pendiente;
    }
  }

  static String _taskStatusToString(TaskStatus status) {
    switch (status) {
      case TaskStatus.pendiente:
        return 'pendiente';
      case TaskStatus.enProgreso:
        return 'en_progreso';
      case TaskStatus.completada:
        return 'completada';
      case TaskStatus.cancelada:
        return 'cancelada';
    }
  }

  static TaskPriority _parseTaskPriority(String? priority) {
    switch (priority) {
      case 'baja':
        return TaskPriority.baja;
      case 'alta':
        return TaskPriority.alta;
      case 'urgente':
        return TaskPriority.urgente;
      default:
        return TaskPriority.media;
    }
  }

  static String _taskPriorityToString(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.baja:
        return 'baja';
      case TaskPriority.media:
        return 'media';
      case TaskPriority.alta:
        return 'alta';
      case TaskPriority.urgente:
        return 'urgente';
    }
  }
}

enum TaskStatus { pendiente, enProgreso, completada, cancelada }

enum TaskPriority { baja, media, alta, urgente }

/// Registro individual de tiempo de un empleado
class EmployeeTimeEntry {
  final String id;
  final String employeeId;
  final DateTime entryDate;
  final String? scheduledStart;
  final String? scheduledEnd;
  final int scheduledMinutes;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int breakMinutes;
  final int workedMinutes;
  final int overtimeMinutes;
  final int deficitMinutes;
  final String status;
  final String source;
  final String? notes;
  final String? approvalNotes;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmployeeTimeEntry({
    required this.id,
    required this.employeeId,
    required this.entryDate,
    this.scheduledStart,
    this.scheduledEnd,
    this.scheduledMinutes = 0,
    this.checkIn,
    this.checkOut,
    this.breakMinutes = 0,
    this.workedMinutes = 0,
    this.overtimeMinutes = 0,
    this.deficitMinutes = 0,
    this.status = 'registrado',
    this.source = 'manual',
    this.notes,
    this.approvalNotes,
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isApproved => approvedAt != null;

  Duration get workedDuration => Duration(minutes: workedMinutes);

  Duration get overtimeDuration => Duration(minutes: overtimeMinutes);

  Duration get deficitDuration => Duration(minutes: deficitMinutes);

  factory EmployeeTimeEntry.fromJson(Map<String, dynamic> json) {
    return EmployeeTimeEntry(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      entryDate: DateTime.parse(json['entry_date'] as String),
      scheduledStart: json['scheduled_start'] as String?,
      scheduledEnd: json['scheduled_end'] as String?,
      scheduledMinutes: (json['scheduled_minutes'] as int?) ?? 0,
      checkIn: json['check_in'] != null
          ? DateTime.parse(json['check_in'] as String)
          : null,
      checkOut: json['check_out'] != null
          ? DateTime.parse(json['check_out'] as String)
          : null,
      breakMinutes: (json['break_minutes'] as int?) ?? 0,
      workedMinutes: (json['worked_minutes'] as int?) ?? 0,
      overtimeMinutes: (json['overtime_minutes'] as int?) ?? 0,
      deficitMinutes: (json['deficit_minutes'] as int?) ?? 0,
      status: json['status'] as String? ?? 'registrado',
      source: json['source'] as String? ?? 'manual',
      notes: json['notes'] as String?,
      approvalNotes: json['approval_notes'] as String?,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'entry_date': entryDate.toIso8601String().split('T')[0],
      'scheduled_start': scheduledStart,
      'scheduled_end': scheduledEnd,
      'scheduled_minutes': scheduledMinutes,
      'check_in': checkIn?.toIso8601String(),
      'check_out': checkOut?.toIso8601String(),
      'break_minutes': breakMinutes,
      'worked_minutes': workedMinutes,
      'overtime_minutes': overtimeMinutes,
      'deficit_minutes': deficitMinutes,
      'status': status,
      'source': source,
      'notes': notes,
      'approval_notes': approvalNotes,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
    };
  }
}

/// Resumen semanal de horas trabajadas
class EmployeeTimeSheet {
  final String id;
  final String employeeId;
  final String? periodId;
  final DateTime weekStart;
  final DateTime weekEnd;
  final int scheduledMinutes;
  final int workedMinutes;
  final int overtimeMinutes;
  final int deficitMinutes;
  final String status;
  final String? notes;
  final String? lockedBy;
  final DateTime? lockedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmployeeTimeSheet({
    required this.id,
    required this.employeeId,
    this.periodId,
    required this.weekStart,
    required this.weekEnd,
    // Horario: L-V 7:30-12 y 1-4:30 (-14min) + Sáb 7:30-1 = 2660 min semanales (44.33h)
    this.scheduledMinutes = 2660,
    this.workedMinutes = 0,
    this.overtimeMinutes = 0,
    this.deficitMinutes = 0,
    this.status = 'abierto',
    this.notes,
    this.lockedBy,
    this.lockedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Duration get scheduledDuration => Duration(minutes: scheduledMinutes);

  Duration get workedDuration => Duration(minutes: workedMinutes);

  Duration get overtimeDuration => Duration(minutes: overtimeMinutes);

  Duration get deficitDuration => Duration(minutes: deficitMinutes);

  factory EmployeeTimeSheet.fromJson(Map<String, dynamic> json) {
    return EmployeeTimeSheet(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      periodId: json['period_id'] as String?,
      weekStart: DateTime.parse(json['week_start'] as String),
      weekEnd: DateTime.parse(json['week_end'] as String),
      scheduledMinutes: (json['scheduled_minutes'] as int?) ?? 2660,
      workedMinutes: (json['worked_minutes'] as int?) ?? 0,
      overtimeMinutes: (json['overtime_minutes'] as int?) ?? 0,
      deficitMinutes: (json['deficit_minutes'] as int?) ?? 0,
      status: json['status'] as String? ?? 'abierto',
      notes: json['notes'] as String?,
      lockedBy: json['locked_by'] as String?,
      lockedAt: json['locked_at'] != null
          ? DateTime.parse(json['locked_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'period_id': periodId,
      'week_start': weekStart.toIso8601String().split('T')[0],
      'week_end': weekEnd.toIso8601String().split('T')[0],
      'scheduled_minutes': scheduledMinutes,
      'worked_minutes': workedMinutes,
      'overtime_minutes': overtimeMinutes,
      'deficit_minutes': deficitMinutes,
      'status': status,
      'notes': notes,
      'locked_by': lockedBy,
      'locked_at': lockedAt?.toIso8601String(),
    };
  }
}

/// Ajuste manual de horas
class EmployeeTimeAdjustment {
  final String id;
  final String employeeId;
  final String? timesheetId;
  final String? entryId;
  final String? periodId;
  final DateTime adjustmentDate;
  final int minutes;
  final String type;
  final String? reason;
  final String status;
  final String? notes;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmployeeTimeAdjustment({
    required this.id,
    required this.employeeId,
    this.timesheetId,
    this.entryId,
    this.periodId,
    required this.adjustmentDate,
    required this.minutes,
    required this.type,
    this.reason,
    this.status = 'pendiente',
    this.notes,
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPositive => minutes > 0;

  Duration get duration => Duration(minutes: minutes.abs());

  factory EmployeeTimeAdjustment.fromJson(Map<String, dynamic> json) {
    return EmployeeTimeAdjustment(
      id: json['id'] as String,
      employeeId: json['employee_id'] as String,
      timesheetId: json['timesheet_id'] as String?,
      entryId: json['entry_id'] as String?,
      periodId: json['period_id'] as String?,
      adjustmentDate: DateTime.parse(json['adjustment_date'] as String),
      minutes: json['minutes'] as int,
      type: json['type'] as String,
      reason: json['reason'] as String?,
      status: json['status'] as String? ?? 'pendiente',
      notes: json['notes'] as String?,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'timesheet_id': timesheetId,
      'entry_id': entryId,
      'period_id': periodId,
      'adjustment_date': adjustmentDate.toIso8601String().split('T')[0],
      'minutes': minutes,
      'type': type,
      'reason': reason,
      'status': status,
      'notes': notes,
      'approved_by': approvedBy,
      'approved_at': approvedAt?.toIso8601String(),
    };
  }
}

/// Tiempo registrado para una tarea específica
class EmployeeTaskTimeLog {
  final String id;
  final String taskId;
  final String employeeId;
  final DateTime startTime;
  final DateTime? endTime;
  final int minutes;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmployeeTaskTimeLog({
    required this.id,
    required this.taskId,
    required this.employeeId,
    required this.startTime,
    this.endTime,
    required this.minutes,
    this.status = 'registrado',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Duration get duration => Duration(minutes: minutes);

  factory EmployeeTaskTimeLog.fromJson(Map<String, dynamic> json) {
    return EmployeeTaskTimeLog(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      employeeId: json['employee_id'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      minutes: json['minutes'] as int,
      status: json['status'] as String? ?? 'registrado',
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'employee_id': employeeId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'minutes': minutes,
      'status': status,
      'notes': notes,
    };
  }
}

/// Vista consolidada de horas por semana destinada a nómina
class EmployeeTimeSummary {
  final String timesheetId;
  final String employeeId;
  final DateTime weekStart;
  final DateTime weekEnd;
  final int scheduledMinutes;
  final int workedMinutes;
  final int overtimeMinutes;
  final int deficitMinutes;
  final int approvedAdjustmentMinutes;
  final int totalEffectiveMinutes;

  const EmployeeTimeSummary({
    required this.timesheetId,
    required this.employeeId,
    required this.weekStart,
    required this.weekEnd,
    required this.scheduledMinutes,
    required this.workedMinutes,
    required this.overtimeMinutes,
    required this.deficitMinutes,
    required this.approvedAdjustmentMinutes,
    required this.totalEffectiveMinutes,
  });

  double get progressRatio =>
      scheduledMinutes == 0 ? 0 : totalEffectiveMinutes / scheduledMinutes;

  Duration get scheduledDuration => Duration(minutes: scheduledMinutes);

  Duration get effectiveDuration => Duration(minutes: totalEffectiveMinutes);

  Duration get overtimeDuration => Duration(minutes: overtimeMinutes);

  Duration get deficitDuration => Duration(minutes: deficitMinutes);

  factory EmployeeTimeSummary.fromJson(Map<String, dynamic> json) {
    return EmployeeTimeSummary(
      timesheetId: json['timesheet_id'] as String,
      employeeId: json['employee_id'] as String,
      weekStart: DateTime.parse(json['week_start'] as String),
      weekEnd: DateTime.parse(json['week_end'] as String),
      scheduledMinutes: (json['scheduled_minutes'] as int?) ?? 0,
      workedMinutes: (json['worked_minutes'] as int?) ?? 0,
      overtimeMinutes: (json['overtime_minutes'] as int?) ?? 0,
      deficitMinutes: (json['deficit_minutes'] as int?) ?? 0,
      approvedAdjustmentMinutes:
          (json['approved_adjustment_minutes'] as int?) ?? 0,
      totalEffectiveMinutes: (json['total_effective_minutes'] as int?) ?? 0,
    );
  }
}
