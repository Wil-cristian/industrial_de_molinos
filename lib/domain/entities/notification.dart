import 'package:flutter/material.dart';

enum NotificationType {
  lowStock,
  overdueInvoice,
  upcomingDelivery,
  activityReminder,
  paymentDue,
  collectionDue,
  projectUpdate,
  general,
}

enum NotificationSeverity {
  info,
  warning,
  error,
  success,
}

class AppNotification {
  final String id;
  final NotificationType notificationType;
  final String title;
  final String message;
  final bool isRead;
  final bool isDismissed;
  final NotificationSeverity severity;
  final String? activityId;
  final String? customerId;
  final String? customerName;
  final String? invoiceId;
  final String? materialId;
  final String? materialName;
  final String? actionUrl;
  final String? icon;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? expiresAt;

  AppNotification({
    required this.id,
    required this.notificationType,
    required this.title,
    required this.message,
    this.isRead = false,
    this.isDismissed = false,
    required this.severity,
    this.activityId,
    this.customerId,
    this.customerName,
    this.invoiceId,
    this.materialId,
    this.materialName,
    this.actionUrl,
    this.icon,
    this.data,
    required this.createdAt,
    this.readAt,
    this.expiresAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      notificationType: _parseNotificationType(json['notification_type'] as String),
      title: json['title'] as String,
      message: json['message'] as String,
      isRead: json['is_read'] as bool? ?? false,
      isDismissed: json['is_dismissed'] as bool? ?? false,
      severity: _parseSeverity(json['severity'] as String),
      activityId: json['activity_id'] as String?,
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String?,
      invoiceId: json['invoice_id'] as String?,
      materialId: json['material_id'] as String?,
      materialName: json['material_name'] as String?,
      actionUrl: json['action_url'] as String?,
      icon: json['icon'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null 
          ? DateTime.parse(json['read_at'] as String) 
          : null,
      expiresAt: json['expires_at'] != null 
          ? DateTime.parse(json['expires_at'] as String) 
          : null,
    );
  }

  AppNotification copyWith({
    bool? isRead,
    bool? isDismissed,
    DateTime? readAt,
  }) {
    return AppNotification(
      id: id,
      notificationType: notificationType,
      title: title,
      message: message,
      isRead: isRead ?? this.isRead,
      isDismissed: isDismissed ?? this.isDismissed,
      severity: severity,
      activityId: activityId,
      customerId: customerId,
      customerName: customerName,
      invoiceId: invoiceId,
      materialId: materialId,
      materialName: materialName,
      actionUrl: actionUrl,
      icon: icon,
      data: data,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      expiresAt: expiresAt,
    );
  }

  // Helpers
  IconData get iconData {
    switch (notificationType) {
      case NotificationType.lowStock:
        return Icons.inventory_2;
      case NotificationType.overdueInvoice:
        return Icons.receipt_long;
      case NotificationType.upcomingDelivery:
        return Icons.local_shipping;
      case NotificationType.activityReminder:
        return Icons.alarm;
      case NotificationType.paymentDue:
        return Icons.payments;
      case NotificationType.collectionDue:
        return Icons.attach_money;
      case NotificationType.projectUpdate:
        return Icons.work;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  Color get severityColor {
    switch (severity) {
      case NotificationSeverity.error:
        return Colors.red;
      case NotificationSeverity.warning:
        return Colors.orange;
      case NotificationSeverity.success:
        return Colors.green;
      case NotificationSeverity.info:
        return Colors.blue;
    }
  }

  String get typeLabel {
    switch (notificationType) {
      case NotificationType.lowStock:
        return 'Stock Bajo';
      case NotificationType.overdueInvoice:
        return 'Factura Vencida';
      case NotificationType.upcomingDelivery:
        return 'Entrega Próxima';
      case NotificationType.activityReminder:
        return 'Recordatorio';
      case NotificationType.paymentDue:
        return 'Pago Pendiente';
      case NotificationType.collectionDue:
        return 'Cobro Pendiente';
      case NotificationType.projectUpdate:
        return 'Proyecto';
      case NotificationType.general:
        return 'General';
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 1) {
      return 'Ahora mismo';
    } else if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Hace ${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return 'Hace ${diff.inDays}d';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }

  static NotificationType _parseNotificationType(String value) {
    switch (value) {
      case 'low_stock':
        return NotificationType.lowStock;
      case 'overdue_invoice':
        return NotificationType.overdueInvoice;
      case 'upcoming_delivery':
        return NotificationType.upcomingDelivery;
      case 'activity_reminder':
        return NotificationType.activityReminder;
      case 'payment_due':
        return NotificationType.paymentDue;
      case 'collection_due':
        return NotificationType.collectionDue;
      case 'project_update':
        return NotificationType.projectUpdate;
      case 'general':
      default:
        return NotificationType.general;
    }
  }

  static NotificationSeverity _parseSeverity(String value) {
    switch (value) {
      case 'error':
        return NotificationSeverity.error;
      case 'warning':
        return NotificationSeverity.warning;
      case 'success':
        return NotificationSeverity.success;
      case 'info':
      default:
        return NotificationSeverity.info;
    }
  }
}
