import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/colombia_time.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/activity.dart';
import 'audit_log_datasource.dart';

class ActivitiesDatasource {
  static final _client = Supabase.instance.client;

  /// Obtener todas las actividades
  static Future<List<Activity>> getActivities() async {
    try {
      AppLogger.debug('?? Cargando actividades desde Supabase...');
      final response = await _client
          .from('activities')
          .select('*, customers(name)')
          .order('start_date', ascending: true);

      final activities = (response as List)
          .map(
            (json) => Activity.fromJson({
              ...json,
              'customer_name': json['customers']?['name'],
            }),
          )
          .toList();

      AppLogger.success('? Actividades cargadas: ${activities.length}');
      return activities;
    } catch (e) {
      AppLogger.error('? Error cargando actividades: $e');
      return [];
    }
  }

  /// Obtener actividades por fecha
  static Future<List<Activity>> getActivitiesByDate(DateTime date) async {
    try {
      final response = await _client
          .from('activities')
          .select('*, customers(name)')
          .gte('start_date', ColombiaTime.startOfDayIso(date))
          .lt('start_date', ColombiaTime.endOfDayIso(date))
          .order('start_date', ascending: true);

      return (response as List)
          .map(
            (json) => Activity.fromJson({
              ...json,
              'customer_name': json['customers']?['name'],
            }),
          )
          .toList();
    } catch (e) {
      AppLogger.error('? Error cargando actividades por fecha: $e');
      return [];
    }
  }

  /// Obtener actividades por mes
  static Future<List<Activity>> getActivitiesByMonth(
    int year,
    int month,
  ) async {
    try {
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 1);

      final response = await _client
          .from('activities')
          .select('*, customers(name)')
          .gte('start_date', ColombiaTime.startOfDayIso(startOfMonth))
          .lt('start_date', ColombiaTime.startOfDayIso(endOfMonth))
          .order('start_date', ascending: true);

      return (response as List)
          .map(
            (json) => Activity.fromJson({
              ...json,
              'customer_name': json['customers']?['name'],
            }),
          )
          .toList();
    } catch (e) {
      AppLogger.error('? Error cargando actividades del mes: $e');
      return [];
    }
  }

  /// Crear nueva actividad
  static Future<Activity?> createActivity(Activity activity) async {
    try {
      AppLogger.debug('?? Creando actividad: ${activity.title}');
      final response = await _client
          .from('activities')
          .insert({
            'title': activity.title,
            'description': activity.description,
            'activity_type': _activityTypeToString(activity.activityType),
            'start_date': ColombiaTime.toIso8601(activity.startDate),
            'end_date': activity.endDate != null
                ? ColombiaTime.toIso8601(activity.endDate!)
                : null,
            'due_date': activity.dueDate != null
                ? ColombiaTime.dateString(activity.dueDate!)
                : null,
            'status': _statusToString(activity.status),
            'priority': _priorityToString(activity.priority),
            'customer_id':
                activity.customerId != null && activity.customerId!.isNotEmpty
                ? activity.customerId
                : null,
            'invoice_id':
                activity.invoiceId != null && activity.invoiceId!.isNotEmpty
                ? activity.invoiceId
                : null,
            'amount': activity.amount,
            'color': activity.color,
            'icon': activity.icon,
            'notes': activity.notes,
            'reminder_enabled': activity.reminderEnabled,
            'reminder_date': activity.reminderDate != null
                ? ColombiaTime.toIso8601(activity.reminderDate!)
                : null,
          })
          .select()
          .single();

      AppLogger.success('? Actividad creada: ${response['id']}');
      final created = Activity.fromJson(response);
      AuditLogDatasource.log(
        action: 'create',
        module: 'activities',
        recordId: created.id,
        description: 'Creó actividad: ${created.title}',
      );
      return created;
    } catch (e) {
      AppLogger.error('? Error creando actividad: $e');
      return null;
    }
  }

  /// Actualizar actividad
  static Future<bool> updateActivity(Activity activity) async {
    try {
      await _client
          .from('activities')
          .update({
            'title': activity.title,
            'description': activity.description,
            'activity_type': _activityTypeToString(activity.activityType),
            'start_date': ColombiaTime.toIso8601(activity.startDate),
            'end_date': activity.endDate != null
                ? ColombiaTime.toIso8601(activity.endDate!)
                : null,
            'due_date': activity.dueDate != null
                ? ColombiaTime.dateString(activity.dueDate!)
                : null,
            'status': _statusToString(activity.status),
            'priority': _priorityToString(activity.priority),
            'customer_id': activity.customerId,
            'amount': activity.amount,
            'color': activity.color,
            'notes': activity.notes,
          })
          .eq('id', activity.id);

      AppLogger.success('? Actividad actualizada: ${activity.id}');
      AuditLogDatasource.log(
        action: 'update',
        module: 'activities',
        recordId: activity.id,
        description: 'Actualizó actividad: ${activity.title}',
      );
      return true;
    } catch (e) {
      AppLogger.error('? Error actualizando actividad: $e');
      return false;
    }
  }

  /// Eliminar actividad
  static Future<bool> deleteActivity(String id) async {
    try {
      await _client.from('activities').delete().eq('id', id);
      AppLogger.success('? Actividad eliminada: $id');
      AuditLogDatasource.log(
        action: 'delete',
        module: 'activities',
        recordId: id,
        description: 'Eliminó actividad',
      );
      return true;
    } catch (e) {
      AppLogger.error('? Error eliminando actividad: $e');
      return false;
    }
  }

  /// Marcar actividad como completada
  static Future<bool> completeActivity(String id) async {
    try {
      await _client
          .from('activities')
          .update({'status': 'completed'})
          .eq('id', id);
      AuditLogDatasource.log(
        action: 'update',
        module: 'activities',
        recordId: id,
        description: 'Completó actividad',
      );
      return true;
    } catch (e) {
      AppLogger.error('? Error completando actividad: $e');
      return false;
    }
  }

  // Helpers para convertir enums a strings
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

  static String _statusToString(ActivityStatus status) {
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

  static String _priorityToString(ActivityPriority priority) {
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
