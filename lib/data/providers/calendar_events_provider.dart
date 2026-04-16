import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/calendar_event.dart';
import '../datasources/calendar_events_datasource.dart';
import '../../core/utils/colombia_time.dart';

/// Estado de los eventos automaticos del calendario
class CalendarEventsState {
  final List<CalendarEvent> events;
  final bool isLoading;
  final String? error;

  const CalendarEventsState({
    this.events = const [],
    this.isLoading = false,
    this.error,
  });

  CalendarEventsState copyWith({
    List<CalendarEvent>? events,
    bool? isLoading,
    String? error,
  }) {
    return CalendarEventsState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Obtener eventos para un dia especifico
  List<CalendarEvent> getEventsForDay(DateTime day) {
    return events.where((e) {
      return e.date.year == day.year &&
          e.date.month == day.month &&
          e.date.day == day.day;
    }).toList();
  }

  /// Obtener eventos vencidos (overdue)
  List<CalendarEvent> get overdueEvents {
    final now = ColombiaTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return events.where((e) => e.isOverdue && e.date.isBefore(today)).toList();
  }

  /// Obtener eventos de hoy
  List<CalendarEvent> get todayEvents {
    final now = ColombiaTime.now();
    return events.where((e) {
      return e.date.year == now.year &&
          e.date.month == now.month &&
          e.date.day == now.day;
    }).toList();
  }

  /// Obtener eventos de los proximos 3 dias
  List<CalendarEvent> get upcomingEvents {
    final now = ColombiaTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.add(const Duration(days: 1));
    final limit = today.add(const Duration(days: 4));
    return events.where((e) {
      return !e.date.isBefore(start) && e.date.isBefore(limit);
    }).toList();
  }

  /// Dias del mes que tienen eventos (para mostrar indicadores en el calendario)
  Set<int> eventDaysForMonth(int year, int month) {
    return events
        .where((e) => e.date.year == year && e.date.month == month)
        .map((e) => e.date.day)
        .toSet();
  }
}

class CalendarEventsNotifier extends Notifier<CalendarEventsState> {
  @override
  CalendarEventsState build() {
    return const CalendarEventsState();
  }

  Future<void> loadEvents() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final events = await CalendarEventsDatasource.loadAllEvents();
      state = state.copyWith(events: events, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final calendarEventsProvider =
    NotifierProvider<CalendarEventsNotifier, CalendarEventsState>(
      CalendarEventsNotifier.new,
    );
