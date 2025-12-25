import 'package:flutter/material.dart';

enum ActivityType {
  payment,
  delivery,
  projectStart,
  projectEnd,
  collection,
  meeting,
  reminder,
  general,
  stockAlert,
  maintenance,
}

enum ActivityStatus {
  pending,
  inProgress,
  completed,
  cancelled,
  overdue,
}

enum ActivityPriority {
  low,
  medium,
  high,
  urgent,
}

class Activity {
  final String id;
  final String title;
  final String? description;
  final ActivityType activityType;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? dueDate;
  final ActivityStatus status;
  final ActivityPriority priority;
  final String? customerId;
  final String? customerName;
  final String? invoiceId;
  final String? quotationId;
  final bool reminderEnabled;
  final DateTime? reminderDate;
  final bool reminderSent;
  final double? amount;
  final String color;
  final String? icon;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Activity({
    required this.id,
    required this.title,
    this.description,
    required this.activityType,
    required this.startDate,
    this.endDate,
    this.dueDate,
    required this.status,
    required this.priority,
    this.customerId,
    this.customerName,
    this.invoiceId,
    this.quotationId,
    this.reminderEnabled = false,
    this.reminderDate,
    this.reminderSent = false,
    this.amount,
    this.color = '#2196F3',
    this.icon,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      activityType: _parseActivityType(json['activity_type'] as String),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null 
          ? DateTime.parse(json['end_date'] as String) 
          : null,
      dueDate: json['due_date'] != null 
          ? DateTime.parse(json['due_date'] as String) 
          : null,
      status: _parseActivityStatus(json['status'] as String),
      priority: _parseActivityPriority(json['priority'] as String),
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String?,
      invoiceId: json['invoice_id'] as String?,
      quotationId: json['quotation_id'] as String?,
      reminderEnabled: json['reminder_enabled'] as bool? ?? false,
      reminderDate: json['reminder_date'] != null 
          ? DateTime.parse(json['reminder_date'] as String) 
          : null,
      reminderSent: json['reminder_sent'] as bool? ?? false,
      amount: json['amount'] != null 
          ? (json['amount'] as num).toDouble() 
          : null,
      color: json['color'] as String? ?? '#2196F3',
      icon: json['icon'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'activity_type': _activityTypeToString(activityType),
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'due_date': dueDate?.toIso8601String().split('T')[0],
      'status': _activityStatusToString(status),
      'priority': _activityPriorityToString(priority),
      'customer_id': customerId,
      'invoice_id': invoiceId,
      'quotation_id': quotationId,
      'reminder_enabled': reminderEnabled,
      'reminder_date': reminderDate?.toIso8601String(),
      'amount': amount,
      'color': color,
      'icon': icon,
      'notes': notes,
    };
  }

  Activity copyWith({
    String? id,
    String? title,
    String? description,
    ActivityType? activityType,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? dueDate,
    ActivityStatus? status,
    ActivityPriority? priority,
    String? customerId,
    String? customerName,
    String? invoiceId,
    String? quotationId,
    bool? reminderEnabled,
    DateTime? reminderDate,
    bool? reminderSent,
    double? amount,
    String? color,
    String? icon,
    String? notes,
  }) {
    return Activity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      activityType: activityType ?? this.activityType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      invoiceId: invoiceId ?? this.invoiceId,
      quotationId: quotationId ?? this.quotationId,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderDate: reminderDate ?? this.reminderDate,
      reminderSent: reminderSent ?? this.reminderSent,
      amount: amount ?? this.amount,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Helpers
  Color get colorValue {
    try {
      return Color(int.parse(color.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.blue;
    }
  }

  IconData get iconData {
    switch (activityType) {
      case ActivityType.payment:
        return Icons.payments;
      case ActivityType.delivery:
        return Icons.local_shipping;
      case ActivityType.projectStart:
        return Icons.play_circle;
      case ActivityType.projectEnd:
        return Icons.check_circle;
      case ActivityType.collection:
        return Icons.attach_money;
      case ActivityType.meeting:
        return Icons.groups;
      case ActivityType.reminder:
        return Icons.alarm;
      case ActivityType.stockAlert:
        return Icons.inventory;
      case ActivityType.maintenance:
        return Icons.build;
      case ActivityType.general:
        return Icons.event;
    }
  }

  String get typeLabel {
    switch (activityType) {
      case ActivityType.payment:
        return 'Pago';
      case ActivityType.delivery:
        return 'Entrega';
      case ActivityType.projectStart:
        return 'Inicio Proyecto';
      case ActivityType.projectEnd:
        return 'Fin Proyecto';
      case ActivityType.collection:
        return 'Cobro';
      case ActivityType.meeting:
        return 'Reunión';
      case ActivityType.reminder:
        return 'Recordatorio';
      case ActivityType.stockAlert:
        return 'Alerta Stock';
      case ActivityType.maintenance:
        return 'Mantenimiento';
      case ActivityType.general:
        return 'General';
    }
  }

  String get statusLabel {
    switch (status) {
      case ActivityStatus.pending:
        return 'Pendiente';
      case ActivityStatus.inProgress:
        return 'En Progreso';
      case ActivityStatus.completed:
        return 'Completado';
      case ActivityStatus.cancelled:
        return 'Cancelado';
      case ActivityStatus.overdue:
        return 'Vencido';
    }
  }

  Color get statusColor {
    switch (status) {
      case ActivityStatus.pending:
        return Colors.orange;
      case ActivityStatus.inProgress:
        return Colors.blue;
      case ActivityStatus.completed:
        return Colors.green;
      case ActivityStatus.cancelled:
        return Colors.grey;
      case ActivityStatus.overdue:
        return Colors.red;
    }
  }

  String get priorityLabel {
    switch (priority) {
      case ActivityPriority.low:
        return 'Baja';
      case ActivityPriority.medium:
        return 'Media';
      case ActivityPriority.high:
        return 'Alta';
      case ActivityPriority.urgent:
        return 'Urgente';
    }
  }

  Color get priorityColor {
    switch (priority) {
      case ActivityPriority.low:
        return Colors.grey;
      case ActivityPriority.medium:
        return Colors.blue;
      case ActivityPriority.high:
        return Colors.orange;
      case ActivityPriority.urgent:
        return Colors.red;
    }
  }

  bool get isOverdue {
    if (dueDate == null) return false;
    return status != ActivityStatus.completed && 
           status != ActivityStatus.cancelled &&
           dueDate!.isBefore(DateTime.now());
  }

  static ActivityType _parseActivityType(String value) {
    switch (value) {
      case 'payment':
        return ActivityType.payment;
      case 'delivery':
        return ActivityType.delivery;
      case 'project_start':
        return ActivityType.projectStart;
      case 'project_end':
        return ActivityType.projectEnd;
      case 'collection':
        return ActivityType.collection;
      case 'meeting':
        return ActivityType.meeting;
      case 'reminder':
        return ActivityType.reminder;
      case 'stock_alert':
        return ActivityType.stockAlert;
      case 'maintenance':
        return ActivityType.maintenance;
      case 'general':
      default:
        return ActivityType.general;
    }
  }

  static String _activityTypeToString(ActivityType type) {
    switch (type) {
      case ActivityType.payment:
        return 'payment';
      case ActivityType.delivery:
        return 'delivery';
      case ActivityType.projectStart:
        return 'project_start';
      case ActivityType.projectEnd:
        return 'project_end';
      case ActivityType.collection:
        return 'collection';
      case ActivityType.meeting:
        return 'meeting';
      case ActivityType.reminder:
        return 'reminder';
      case ActivityType.stockAlert:
        return 'stock_alert';
      case ActivityType.maintenance:
        return 'maintenance';
      case ActivityType.general:
        return 'general';
    }
  }

  static ActivityStatus _parseActivityStatus(String value) {
    switch (value) {
      case 'in_progress':
        return ActivityStatus.inProgress;
      case 'completed':
        return ActivityStatus.completed;
      case 'cancelled':
        return ActivityStatus.cancelled;
      case 'overdue':
        return ActivityStatus.overdue;
      case 'pending':
      default:
        return ActivityStatus.pending;
    }
  }

  static String _activityStatusToString(ActivityStatus status) {
    switch (status) {
      case ActivityStatus.inProgress:
        return 'in_progress';
      case ActivityStatus.completed:
        return 'completed';
      case ActivityStatus.cancelled:
        return 'cancelled';
      case ActivityStatus.overdue:
        return 'overdue';
      case ActivityStatus.pending:
        return 'pending';
    }
  }

  static ActivityPriority _parseActivityPriority(String value) {
    switch (value) {
      case 'low':
        return ActivityPriority.low;
      case 'high':
        return ActivityPriority.high;
      case 'urgent':
        return ActivityPriority.urgent;
      case 'medium':
      default:
        return ActivityPriority.medium;
    }
  }

  static String _activityPriorityToString(ActivityPriority priority) {
    switch (priority) {
      case ActivityPriority.low:
        return 'low';
      case ActivityPriority.high:
        return 'high';
      case ActivityPriority.urgent:
        return 'urgent';
      case ActivityPriority.medium:
        return 'medium';
    }
  }
}
