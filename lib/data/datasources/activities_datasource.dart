import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/activity.dart';

class ActivitiesDatasource {
  static final _client = Supabase.instance.client;

  /// Obtener todas las actividades
  static Future<List<Activity>> getActivities() async {
    try {
      print('🔄 Cargando actividades desde Supabase...');
      final response = await _client
          .from('activities')
          .select('*, customers(name)')
          .order('start_date', ascending: true);

      final activities = (response as List)
          .map((json) => Activity.fromJson({
                ...json,
                'customer_name': json['customers']?['name'],
              }))
          .toList();

      print('✅ Actividades cargadas: ${activities.length}');
      return activities;
    } catch (e) {
      print('❌ Error cargando actividades: $e');
      return [];
    }
  }

  /// Obtener actividades por fecha
  static Future<List<Activity>> getActivitiesByDate(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final response = await _client
          .from('activities')
          .select('*, customers(name)')
          .gte('start_date', startOfDay.toIso8601String())
          .lt('start_date', endOfDay.toIso8601String())
          .order('start_date', ascending: true);

      return (response as List)
          .map((json) => Activity.fromJson({
                ...json,
                'customer_name': json['customers']?['name'],
              }))
          .toList();
    } catch (e) {
      print('❌ Error cargando actividades por fecha: $e');
      return [];
    }
  }

  /// Obtener actividades por mes
  static Future<List<Activity>> getActivitiesByMonth(int year, int month) async {
    try {
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 1);

      final response = await _client
          .from('activities')
          .select('*, customers(name)')
          .gte('start_date', startOfMonth.toIso8601String())
          .lt('start_date', endOfMonth.toIso8601String())
          .order('start_date', ascending: true);

      return (response as List)
          .map((json) => Activity.fromJson({
                ...json,
                'customer_name': json['customers']?['name'],
              }))
          .toList();
    } catch (e) {
      print('❌ Error cargando actividades del mes: $e');
      return [];
    }
  }

  /// Crear nueva actividad
  static Future<Activity?> createActivity(Activity activity) async {
    try {
      print('🔄 Creando actividad: ${activity.title}');
      final response = await _client
          .from('activities')
          .insert({
            'title': activity.title,
            'description': activity.description,
            'activity_type': _activityTypeToString(activity.activityType),
            'start_date': activity.startDate.toIso8601String(),
            'end_date': activity.endDate?.toIso8601String(),
            'due_date': activity.dueDate?.toIso8601String().split('T')[0],
            'status': _statusToString(activity.status),
            'priority': _priorityToString(activity.priority),
            'customer_id': activity.customerId,
            'invoice_id': activity.invoiceId,
            'amount': activity.amount,
            'color': activity.color,
            'icon': activity.icon,
            'notes': activity.notes,
            'reminder_enabled': activity.reminderEnabled,
            'reminder_date': activity.reminderDate?.toIso8601String(),
          })
          .select()
          .single();

      print('✅ Actividad creada: ${response['id']}');
      return Activity.fromJson(response);
    } catch (e) {
      print('❌ Error creando actividad: $e');
      return null;
    }
  }

  /// Actualizar actividad
  static Future<bool> updateActivity(Activity activity) async {
    try {
      await _client.from('activities').update({
        'title': activity.title,
        'description': activity.description,
        'activity_type': _activityTypeToString(activity.activityType),
        'start_date': activity.startDate.toIso8601String(),
        'end_date': activity.endDate?.toIso8601String(),
        'due_date': activity.dueDate?.toIso8601String().split('T')[0],
        'status': _statusToString(activity.status),
        'priority': _priorityToString(activity.priority),
        'customer_id': activity.customerId,
        'amount': activity.amount,
        'color': activity.color,
        'notes': activity.notes,
      }).eq('id', activity.id);

      print('✅ Actividad actualizada: ${activity.id}');
      return true;
    } catch (e) {
      print('❌ Error actualizando actividad: $e');
      return false;
    }
  }

  /// Eliminar actividad
  static Future<bool> deleteActivity(String id) async {
    try {
      await _client.from('activities').delete().eq('id', id);
      print('✅ Actividad eliminada: $id');
      return true;
    } catch (e) {
      print('❌ Error eliminando actividad: $e');
      return false;
    }
  }

  /// Marcar actividad como completada
  static Future<bool> completeActivity(String id) async {
    try {
      await _client.from('activities').update({
        'status': 'completed',
      }).eq('id', id);
      return true;
    } catch (e) {
      print('❌ Error completando actividad: $e');
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
