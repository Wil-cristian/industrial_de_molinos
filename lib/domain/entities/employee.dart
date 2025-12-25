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
    return Employee(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      documentType: json['document_type'] as String?,
      documentNumber: json['document_number'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      position: json['position'] as String,
      department: json['department'] as String?,
      hireDate: DateTime.parse(json['hire_date'] as String),
      terminationDate: json['termination_date'] != null
          ? DateTime.parse(json['termination_date'] as String)
          : null,
      salary: json['salary'] != null
          ? (json['salary'] as num).toDouble()
          : null,
      salaryType: json['salary_type'] as String? ?? 'mensual',
      status: _parseStatus(json['status'] as String?),
      workSchedule: json['work_schedule'] as String? ?? 'tiempo_completo',
      emergencyContact: json['emergency_contact'] as String?,
      emergencyPhone: json['emergency_phone'] as String?,
      bloodType: json['blood_type'] as String?,
      photoUrl: json['photo_url'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
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
      'salary_type': salaryType,
      'status': _statusToString(status),
      'work_schedule': workSchedule,
      'emergency_contact': emergencyContact,
      'emergency_phone': emergencyPhone,
      'blood_type': bloodType,
      'photo_url': photoUrl,
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

enum EmployeeStatus {
  activo,
  inactivo,
  vacaciones,
  licencia,
}

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
    return {
      'employee_id': employeeId,
      'title': title,
      'description': description,
      'assigned_date': assignedDate.toIso8601String().split('T')[0],
      'due_date': dueDate?.toIso8601String().split('T')[0],
      'completed_date': completedDate?.toIso8601String(),
      'status': _taskStatusToString(status),
      'priority': _taskPriorityToString(priority),
      'category': category,
      'estimated_time': estimatedTime,
      'actual_time': actualTime,
      'activity_id': activityId,
      'notes': notes,
      'assigned_by': assignedBy,
    };
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

enum TaskStatus {
  pendiente,
  enProgreso,
  completada,
  cancelada,
}

enum TaskPriority {
  baja,
  media,
  alta,
  urgente,
}
