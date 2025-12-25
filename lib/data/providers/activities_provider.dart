import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/activity.dart';
import '../datasources/activities_datasource.dart';

/// Estado de las actividades
class ActivitiesState {
  final List<Activity> activities;
  final bool isLoading;
  final String? error;
  final DateTime selectedMonth;

  ActivitiesState({
    this.activities = const [],
    this.isLoading = false,
    this.error,
    DateTime? selectedMonth,
  }) : selectedMonth = selectedMonth ?? DateTime.now();

  ActivitiesState copyWith({
    List<Activity>? activities,
    bool? isLoading,
    String? error,
    DateTime? selectedMonth,
  }) {
    return ActivitiesState(
      activities: activities ?? this.activities,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedMonth: selectedMonth ?? this.selectedMonth,
    );
  }

  /// Obtener actividades para un día específico
  List<Activity> getActivitiesForDay(DateTime day) {
    return activities.where((a) {
      final activityDate = a.dueDate ?? a.startDate;
      return activityDate.year == day.year &&
          activityDate.month == day.month &&
          activityDate.day == day.day;
    }).toList();
  }

  /// Verificar si un día tiene actividades
  bool hasActivitiesOnDay(DateTime day) {
    return getActivitiesForDay(day).isNotEmpty;
  }

  /// Obtener color de indicador para un día
  List<String> getIndicatorColorsForDay(DateTime day) {
    return getActivitiesForDay(day).map((a) => a.color).take(3).toList();
  }
}

/// Notifier para manejar las actividades (Riverpod 3.0)
class ActivitiesNotifier extends Notifier<ActivitiesState> {
  @override
  ActivitiesState build() {
    return ActivitiesState();
  }

  /// Cargar actividades del mes actual
  Future<void> loadActivities() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final activities = await ActivitiesDatasource.getActivities();
      state = state.copyWith(activities: activities, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Cargar actividades de un mes específico
  Future<void> loadActivitiesForMonth(int year, int month) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      selectedMonth: DateTime(year, month),
    );
    try {
      final activities = await ActivitiesDatasource.getActivitiesByMonth(year, month);
      state = state.copyWith(activities: activities, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Crear nueva actividad
  Future<bool> createActivity(Activity activity) async {
    try {
      final created = await ActivitiesDatasource.createActivity(activity);
      if (created != null) {
        state = state.copyWith(
          activities: [...state.activities, created],
        );
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Actualizar actividad
  Future<bool> updateActivity(Activity activity) async {
    try {
      final success = await ActivitiesDatasource.updateActivity(activity);
      if (success) {
        final updatedList = state.activities.map((a) {
          return a.id == activity.id ? activity : a;
        }).toList();
        state = state.copyWith(activities: updatedList);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Eliminar actividad
  Future<bool> deleteActivity(String id) async {
    try {
      final success = await ActivitiesDatasource.deleteActivity(id);
      if (success) {
        state = state.copyWith(
          activities: state.activities.where((a) => a.id != id).toList(),
        );
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Marcar actividad como completada
  Future<bool> completeActivity(String id) async {
    try {
      final success = await ActivitiesDatasource.completeActivity(id);
      if (success) {
        final updatedList = state.activities.map((a) {
          if (a.id == id) {
            return Activity(
              id: a.id,
              title: a.title,
              description: a.description,
              activityType: a.activityType,
              status: ActivityStatus.completed,
              priority: a.priority,
              startDate: a.startDate,
              endDate: a.endDate,
              dueDate: a.dueDate,
              customerId: a.customerId,
              customerName: a.customerName,
              invoiceId: a.invoiceId,
              amount: a.amount,
              color: a.color,
              icon: a.icon,
              notes: a.notes,
              reminderEnabled: a.reminderEnabled,
              reminderDate: a.reminderDate,
              createdAt: a.createdAt,
              updatedAt: DateTime.now(),
            );
          }
          return a;
        }).toList();
        state = state.copyWith(activities: updatedList);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

/// Provider de actividades
final activitiesProvider =
    NotifierProvider<ActivitiesNotifier, ActivitiesState>(() {
  return ActivitiesNotifier();
});
