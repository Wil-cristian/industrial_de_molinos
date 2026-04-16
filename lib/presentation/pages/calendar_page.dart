import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/calendar_event.dart';
import '../../data/providers/activities_provider.dart';
import '../../data/providers/calendar_events_provider.dart';
import '../../core/utils/colombia_time.dart';

/// Página de Calendario/Organizador
/// Gestión de actividades, eventos y recordatorios
class CalendarPage extends ConsumerStatefulWidget {
  final bool openNewDialog;

  const CalendarPage({super.key, this.openNewDialog = false});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _selectedDate = ColombiaTime.now();
  DateTime _displayedMonth = ColombiaTime.now();
  String _filterType = 'Todas';
  String _filterStatus = 'Todas';
  bool _dialogOpened = false;

  @override
  void initState() {
    super.initState();
    // Cargar actividades al iniciar
    Future.microtask(() {
      ref.read(activitiesProvider.notifier).loadActivities();
      ref.read(calendarEventsProvider.notifier).loadEvents();
      // Abrir diálogo si viene con el parámetro
      if (widget.openNewDialog && !_dialogOpened) {
        _dialogOpened = true;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _showActivityDialog();
        });
      }
    });
  }

  List<Activity> get _filteredActivities {
    final state = ref.watch(activitiesProvider);
    var activities = state.getActivitiesForDay(_selectedDate);

    // Filtrar por tipo
    if (_filterType != 'Todas') {
      activities = activities.where((a) => a.typeLabel == _filterType).toList();
    }

    // Filtrar por estado
    if (_filterStatus != 'Todas') {
      activities = activities
          .where((a) => a.statusLabel == _filterStatus)
          .toList();
    }

    return activities;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  List<Activity> _getActivitiesForDay(DateTime day) {
    final state = ref.watch(activitiesProvider);
    return state.getActivitiesForDay(day);
  }

  /// Actividades vencidas (pendientes con fecha pasada)
  List<Activity> get _overdueActivities {
    final now = ColombiaTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return ref.watch(activitiesProvider).activities.where((a) {
      final date = a.dueDate ?? a.startDate;
      return date.isBefore(today) &&
          a.status != ActivityStatus.completed &&
          a.status != ActivityStatus.cancelled;
    }).toList();
  }

  /// Actividades de hoy pendientes
  List<Activity> get _todayActivities {
    final now = ColombiaTime.now();
    return ref.watch(activitiesProvider).activities.where((a) {
      final date = a.dueDate ?? a.startDate;
      return _isSameDay(date, now) &&
          a.status != ActivityStatus.completed &&
          a.status != ActivityStatus.cancelled;
    }).toList();
  }

  /// Actividades de los proximos 3 dias
  List<Activity> get _upcomingActivities {
    final now = ColombiaTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final limit = today.add(const Duration(days: 4));
    return ref.watch(activitiesProvider).activities.where((a) {
      final date = a.dueDate ?? a.startDate;
      return date.isAfter(today) &&
          date.isBefore(limit) &&
          a.status != ActivityStatus.completed &&
          a.status != ActivityStatus.cancelled;
    }).toList();
  }

  /// Eventos automaticos vencidos
  List<CalendarEvent> get _overdueEvents =>
      ref.watch(calendarEventsProvider).overdueEvents;

  /// Eventos automaticos de hoy
  List<CalendarEvent> get _todayEvents =>
      ref.watch(calendarEventsProvider).todayEvents;

  /// Eventos automaticos proximos 3 dias
  List<CalendarEvent> get _upcomingEvents =>
      ref.watch(calendarEventsProvider).upcomingEvents;

  int get _notificationCount =>
      _overdueActivities.length +
      _todayActivities.length +
      _overdueEvents.length +
      _todayEvents.length;

  void _showNotificationsPanel() {
    final overdue = _overdueActivities;
    final today = _todayActivities;
    final upcoming = _upcomingActivities;
    final overdueEvt = _overdueEvents;
    final todayEvt = _todayEvents;
    final upcomingEvt = _upcomingEvents;
    final isMobile = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: isMobile
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 48)
            : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: isMobile ? double.maxFinite : 420,
          constraints: const BoxConstraints(maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.primary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_active,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Notificaciones',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    if (overdue.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC62828),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${overdue.length} vencidas',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Flexible(
                child:
                    (overdue.isEmpty &&
                        today.isEmpty &&
                        upcoming.isEmpty &&
                        overdueEvt.isEmpty &&
                        todayEvt.isEmpty &&
                        upcomingEvt.isEmpty)
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 48,
                              color: Color(0xFF2E7D32),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Sin pendientes',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        children: [
                          if (overdue.isNotEmpty || overdueEvt.isNotEmpty) ...[
                            _notifSection(
                              'Vencidas',
                              Icons.warning,
                              const Color(0xFFC62828),
                              overdue,
                              ctx,
                              events: overdueEvt,
                            ),
                          ],
                          if (today.isNotEmpty || todayEvt.isNotEmpty) ...[
                            _notifSection(
                              'Hoy',
                              Icons.today,
                              const Color(0xFFF9A825),
                              today,
                              ctx,
                              events: todayEvt,
                            ),
                          ],
                          if (upcoming.isNotEmpty ||
                              upcomingEvt.isNotEmpty) ...[
                            _notifSection(
                              'Proximos dias',
                              Icons.upcoming,
                              const Color(0xFF1565C0),
                              upcoming,
                              ctx,
                              events: upcomingEvt,
                            ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notifSection(
    String title,
    IconData icon,
    Color color,
    List<Activity> activities,
    BuildContext ctx, {
    List<CalendarEvent> events = const [],
  }) {
    final totalCount = activities.length + events.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                '$title ($totalCount)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        ...activities.map((a) => _notifTile(a, ctx)),
        ...events.map((e) => _notifEventTile(e, ctx)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _notifEventTile(CalendarEvent event, BuildContext ctx) {
    final colorVal = Color(
      int.parse('0xFF${event.color.replaceFirst('#', '')}'),
    );
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        setState(() {
          _selectedDate = event.date;
          _displayedMonth = DateTime(event.date.year, event.date.month);
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorVal.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorVal.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(event.icon, size: 18, color: colorVal),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${event.sourceLabel} - ${event.date.day}/${event.date.month}/${event.date.year}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF757575),
                    ),
                  ),
                  if (event.subtitle != null)
                    Text(
                      event.subtitle!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9E9E9E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorVal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                event.sourceLabel,
                style: TextStyle(
                  fontSize: 9,
                  color: colorVal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notifTile(Activity a, BuildContext ctx) {
    final date = a.dueDate ?? a.startDate;
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        setState(() {
          _selectedDate = date;
          _displayedMonth = DateTime(date.year, date.month);
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: a.colorValue.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: a.colorValue.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(a.iconData, size: 18, color: a.colorValue),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${a.typeLabel} - ${date.day}/${date.month}/${date.year}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: a.priorityColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                a.priorityLabel,
                style: TextStyle(
                  fontSize: 9,
                  color: a.priorityColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActivityDialog({Activity? activity}) {
    showDialog(
      context: context,
      builder: (context) => _ActivityDialog(
        activity: activity,
        selectedDate: _selectedDate,
        onSaved: () {
          // Recargar actividades después de guardar
          ref.read(activitiesProvider.notifier).loadActivities();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      floatingActionButton: isMobile
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: FloatingActionButton(
                heroTag: 'calendar',
                onPressed: () => _showActivityDialog(),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                mini: true,
                child: const Icon(Icons.add),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 8,
                vertical: 4,
              ),
              color: Colors.white,
              child: isMobile ? _buildMobileHeader() : _buildDesktopHeader(),
            ),
            // Contenido Principal
            Expanded(
              child: isMobile ? _buildMobileBody() : _buildDesktopBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Row(
      children: [
        Text(
          'Calendario',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        _buildMonthNavigator(),
        const Spacer(),
        _buildNotificationBell(),
        const SizedBox(width: 4),
        _buildCompactFilter('type', _filterType),
        const SizedBox(width: 4),
        _buildCompactFilter('status', _filterStatus),
        const SizedBox(width: 8),
        SizedBox(
          height: 28,
          child: ElevatedButton.icon(
            onPressed: () => _showActivityDialog(),
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Nueva', style: TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileHeader() {
    return Column(
      children: [
        Row(
          children: [
            Text(
              'Calendario',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            _buildNotificationBell(),
            const Spacer(),
            _buildMonthNavigator(),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: _buildCompactFilter('type', _filterType)),
            const SizedBox(width: 6),
            Expanded(child: _buildCompactFilter('status', _filterStatus)),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthNavigator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _displayedMonth = DateTime(
                _displayedMonth.year,
                _displayedMonth.month - 1,
              );
            });
          },
          icon: const Icon(Icons.chevron_left, size: 18),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        Text(
          '${_monthNames[_displayedMonth.month - 1]} ${_displayedMonth.year}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _displayedMonth = DateTime(
                _displayedMonth.year,
                _displayedMonth.month + 1,
              );
            });
          },
          icon: const Icon(Icons.chevron_right, size: 18),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ],
    );
  }

  Widget _buildDesktopBody() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.white,
            margin: const EdgeInsets.all(2),
            child: _buildCalendarGrid(),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.white,
            margin: const EdgeInsets.fromLTRB(0, 2, 2, 2),
            child: Column(
              children: [
                _buildSelectedDateHeader(),
                Expanded(child: _buildActivityList()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBody() {
    return Column(
      children: [
        // Calendario compacto arriba
        Container(
          color: Colors.white,
          margin: const EdgeInsets.fromLTRB(2, 2, 2, 0),
          child: _buildCalendarGrid(isMobile: true),
        ),
        // Separador con fecha seleccionada
        Container(
          color: Colors.white,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          child: _buildSelectedDateHeader(),
        ),
        // Lista de actividades abajo
        Expanded(
          child: Container(
            color: Colors.white,
            margin: const EdgeInsets.fromLTRB(2, 0, 2, 2),
            child: _buildActivityList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDateHeader() {
    final evtCount = ref
        .watch(calendarEventsProvider)
        .getEventsForDay(_selectedDate)
        .length;
    final totalCount = _filteredActivities.length + evtCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.event,
            size: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            _dateFormat(_selectedDate),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const Spacer(),
          Text(
            '$totalCount items',
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBell() {
    final count = _notificationCount;
    return Stack(
      children: [
        IconButton(
          onPressed: _showNotificationsPanel,
          icon: Icon(
            count > 0 ? Icons.notifications_active : Icons.notifications_none,
            size: 20,
            color: count > 0
                ? const Color(0xFFC62828)
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          tooltip: 'Notificaciones',
        ),
        if (count > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0xFFC62828),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompactFilter(String filterType, String currentValue) {
    return PopupMenuButton<String>(
      initialValue: currentValue,
      onSelected: (value) {
        setState(() {
          if (filterType == 'type') {
            _filterType = value;
          } else {
            _filterStatus = value;
          }
        });
      },
      itemBuilder: (context) {
        final options = filterType == 'type'
            ? ['Todas', 'Pago', 'Entrega', 'Reunión', 'Colección', 'Proyecto']
            : ['Todas', 'Pendiente', 'En Progreso', 'Completada', 'Vencida'];
        return options
            .map(
              (option) => PopupMenuItem(
                value: option,
                child: Text(option, style: const TextStyle(fontSize: 12)),
              ),
            )
            .toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentValue,
              style: TextStyle(fontSize: 10, color: const Color(0xFF616161)),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid({bool isMobile = false}) {
    final firstDay = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final lastDay = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    );
    final prevMonthDays = firstDay.weekday - 1;
    final totalCells = prevMonthDays + lastDay.day + (7 - lastDay.weekday % 7);

    final dayHeaders = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    final grid = GridView.builder(
      shrinkWrap: isMobile,
      physics: isMobile ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.all(4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: isMobile ? 1.4 : 1.2,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: 7 + totalCells,
      itemBuilder: (context, index) {
        // Header row (day names)
        if (index < 7) {
          return Center(
            child: Text(
              dayHeaders[index],
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        final cellIndex = index - 7;
        DateTime cellDate;
        bool isCurrentMonth = false;

        if (cellIndex < prevMonthDays) {
          cellDate = DateTime(
            _displayedMonth.year,
            _displayedMonth.month - 1,
            lastDay.day - prevMonthDays + cellIndex + 1,
          );
        } else if (cellIndex < prevMonthDays + lastDay.day) {
          isCurrentMonth = true;
          cellDate = DateTime(
            _displayedMonth.year,
            _displayedMonth.month,
            cellIndex - prevMonthDays + 1,
          );
        } else {
          cellDate = DateTime(
            _displayedMonth.year,
            _displayedMonth.month + 1,
            cellIndex - prevMonthDays - lastDay.day + 1,
          );
        }

        final activities = _getActivitiesForDay(cellDate);
        final dayEvents = ref
            .watch(calendarEventsProvider)
            .getEventsForDay(cellDate);
        final isSelected = _isSameDay(cellDate, _selectedDate);
        final isToday = _isSameDay(cellDate, ColombiaTime.now());
        final hasItems = activities.isNotEmpty || dayEvents.isNotEmpty;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = cellDate;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : isToday
                  ? const Color(0xFFE3F2FD)
                  : isCurrentMonth
                  ? Colors.white
                  : const Color(0xFFFAFAFA),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : isToday
                    ? const Color(0xFF1565C0)
                    : const Color(0xFFE0E0E0),
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${cellDate.day}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : isCurrentMonth
                        ? const Color(0xDD000000)
                        : const Color(0xFFBDBDBD),
                  ),
                ),
                if (hasItems)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < activities.length && i < 2; i++)
                        Container(
                          width: 3,
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(
                              int.parse(
                                '0xFF${activities[i].color.replaceFirst('#', '')}',
                              ),
                            ),
                          ),
                        ),
                      for (
                        int i = 0;
                        i < dayEvents.length &&
                            (i + activities.length.clamp(0, 2)) < 4;
                        i++
                      )
                        Container(
                          width: 3,
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 0.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(
                              int.parse(
                                '0xFF${dayEvents[i].color.replaceFirst('#', '')}',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );

    return grid;
  }

  Widget _buildActivityList() {
    final activities = _filteredActivities;
    final dayEvents = ref
        .watch(calendarEventsProvider)
        .getEventsForDay(_selectedDate);

    if (activities.isEmpty && dayEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_note,
              size: 32,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'Sin actividades',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final totalItems = activities.length + dayEvents.length;

    return ListView.separated(
      padding: const EdgeInsets.all(4),
      itemCount: totalItems,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        if (index < activities.length) {
          final activity = activities[index];
          return _ActivityCard(
            activity: activity,
            onTap: () => _showActivityDialog(activity: activity),
            onEdit: () => _showActivityDialog(activity: activity),
            onDelete: () => _showDeleteConfirmation(activity),
          );
        } else {
          final event = dayEvents[index - activities.length];
          return _EventCard(event: event);
        }
      },
    );
  }

  void _showDeleteConfirmation(Activity activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Actividad'),
        content: Text('¿Está seguro que desea eliminar "${activity.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref
                  .read(activitiesProvider.notifier)
                  .deleteActivity(activity.id);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${activity.title} eliminada'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error al eliminar la actividad'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFC62828),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  String _dateFormat(DateTime date) {
    return '${_dayNames[date.weekday - 1]}, ${date.day} de ${_monthNames[date.month - 1]}';
  }

  static const List<String> _monthNames = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  static const List<String> _dayNames = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];
}

/// Dialog para crear/editar actividades
class _ActivityDialog extends ConsumerStatefulWidget {
  final Activity? activity;
  final DateTime selectedDate;
  final VoidCallback? onSaved;

  const _ActivityDialog({
    this.activity,
    required this.selectedDate,
    this.onSaved,
  });

  @override
  ConsumerState<_ActivityDialog> createState() => _ActivityDialogState();
}

class _ActivityDialogState extends ConsumerState<_ActivityDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  String _selectedType = 'payment';
  String _selectedStatus = 'pending';
  String _selectedPriority = 'medium';
  bool _isSaving = false;

  // Campos de recurrencia
  bool _isRecurring = false;
  String _recurrenceType = 'weekly'; // weekly, biweekly, monthly, yearly
  // ignore: unused_field - Reserved for advanced recurrence
  DateTime? _recurrenceEndDate;
  int _recurrenceCount = 4; // Número de repeticiones por defecto

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.activity?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.activity?.description ?? '',
    );
    _selectedDate = widget.activity?.dueDate ?? widget.selectedDate;
    _selectedType = widget.activity?.activityType.name ?? 'payment';
    _selectedStatus = widget.activity?.status.name ?? 'pending';
    _selectedPriority = widget.activity?.priority.name ?? 'medium';
    // Calcular fecha de fin por defecto (3 meses)
    _recurrenceEndDate = _selectedDate.add(const Duration(days: 90));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _getRecurrencePreview() {
    if (!_isRecurring) return '';

    final lastDate = _calculateRecurrenceDates().last;
    // ignore: unused_local_variable - Reserved for extended recurrence label
    final frequencyText =
        {
          'weekly': 'semana',
          'biweekly': 'quincena',
          'monthly': 'mes',
          'yearly': 'año',
        }[_recurrenceType] ??
        'período';

    return 'Última fecha: ${lastDate.day}/${lastDate.month}/${lastDate.year}';
  }

  List<DateTime> _calculateRecurrenceDates() {
    final dates = <DateTime>[_selectedDate];
    var currentDate = _selectedDate;

    for (int i = 1; i < _recurrenceCount; i++) {
      switch (_recurrenceType) {
        case 'weekly':
          currentDate = currentDate.add(const Duration(days: 7));
          break;
        case 'biweekly':
          currentDate = currentDate.add(const Duration(days: 14));
          break;
        case 'monthly':
          currentDate = DateTime(
            currentDate.year,
            currentDate.month + 1,
            currentDate.day,
          );
          break;
        case 'yearly':
          currentDate = DateTime(
            currentDate.year + 1,
            currentDate.month,
            currentDate.day,
          );
          break;
      }
      dates.add(currentDate);
    }

    return dates;
  }

  String _getRecurrenceLabel() {
    return {
          'weekly': 'Semanal',
          'biweekly': 'Quincenal',
          'monthly': 'Mensual',
          'yearly': 'Anual',
        }[_recurrenceType] ??
        'Recurrente';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      insetPadding: isMobile
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isMobile ? double.maxFinite : screenWidth * 0.5,
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.activity == null
                    ? 'Nueva Actividad'
                    : 'Editar Actividad',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              // Título
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Descripción
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              // Fecha
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Fecha',
                        hintText: _selectedDate.toString().split(' ')[0],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: ColombiaTime.now(),
                          lastDate: ColombiaTime.now().add(Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() => _selectedDate = date);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Tipo y Prioridad
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: isMobile ? double.infinity : 200,
                    child: DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: InputDecoration(
                        labelText: 'Tipo',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'payment', child: Text('Pago')),
                        DropdownMenuItem(
                          value: 'delivery',
                          child: Text('Entrega'),
                        ),
                        DropdownMenuItem(
                          value: 'meeting',
                          child: Text('Reunion'),
                        ),
                        DropdownMenuItem(
                          value: 'collection',
                          child: Text('Cobro'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedType = value);
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: isMobile ? double.infinity : 200,
                    child: DropdownButtonFormField<String>(
                      value: _selectedPriority,
                      decoration: InputDecoration(
                        labelText: 'Prioridad',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Baja')),
                        DropdownMenuItem(value: 'medium', child: Text('Media')),
                        DropdownMenuItem(value: 'high', child: Text('Alta')),
                        DropdownMenuItem(
                          value: 'urgent',
                          child: Text('Urgente'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedPriority = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Estado
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Estado',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pendiente')),
                  DropdownMenuItem(
                    value: 'inProgress',
                    child: Text('En Progreso'),
                  ),
                  DropdownMenuItem(
                    value: 'completed',
                    child: Text('Completada'),
                  ),
                  DropdownMenuItem(
                    value: 'cancelled',
                    child: Text('Cancelada'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _selectedStatus = value);
                },
              ),
              // Sección de Recurrencia (solo para nuevas actividades)
              if (widget.activity == null) ...[
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        title: const Text('Evento Repetitivo'),
                        subtitle: Text(
                          _isRecurring
                              ? 'Se crearán múltiples eventos'
                              : 'Evento único',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF757575),
                          ),
                        ),
                        value: _isRecurring,
                        onChanged: (value) {
                          setState(() => _isRecurring = value ?? false);
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      if (_isRecurring) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              // Tipo de recurrencia
                              DropdownButtonFormField<String>(
                                value: _recurrenceType,
                                decoration: InputDecoration(
                                  labelText: 'Frecuencia',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: const Icon(Icons.repeat),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'weekly',
                                    child: Text('Semanal'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'biweekly',
                                    child: Text('Quincenal'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'monthly',
                                    child: Text('Mensual'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'yearly',
                                    child: Text('Anual'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _recurrenceType = value);
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              // Número de repeticiones
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: _recurrenceCount.toString(),
                                      decoration: InputDecoration(
                                        labelText: 'Repeticiones',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        prefixIcon: const Icon(Icons.numbers),
                                        helperText: _getRecurrencePreview(),
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (value) {
                                        final count = int.tryParse(value);
                                        if (count != null &&
                                            count > 0 &&
                                            count <= 52) {
                                          setState(
                                            () => _recurrenceCount = count,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Botones
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveActivity,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            widget.activity == null ? 'Crear' : 'Actualizar',
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveActivity() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El título es requerido'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Convertir strings a enums
      final activityType = ActivityType.values.firstWhere(
        (e) => e.name == _selectedType,
        orElse: () => ActivityType.payment,
      );
      final status = ActivityStatus.values.firstWhere(
        (e) => e.name == _selectedStatus,
        orElse: () => ActivityStatus.pending,
      );
      final priority = ActivityPriority.values.firstWhere(
        (e) => e.name == _selectedPriority,
        orElse: () => ActivityPriority.medium,
      );

      // Obtener color basado en el tipo
      String color;
      switch (activityType) {
        case ActivityType.payment:
          color = '#FF6B6B';
          break;
        case ActivityType.delivery:
          color = '#4ECDC4';
          break;
        case ActivityType.meeting:
          color = '#95E1D3';
          break;
        case ActivityType.collection:
          color = '#DDA0DD';
          break;
        default:
          color = '#6C757D';
      }

      final activity = Activity(
        id: widget.activity?.id ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        activityType: activityType,
        status: status,
        priority: priority,
        startDate: _selectedDate,
        dueDate: _selectedDate,
        color: color,
        icon: activityType.name,
        createdAt: widget.activity?.createdAt ?? ColombiaTime.now(),
        updatedAt: ColombiaTime.now(),
      );

      bool success;
      if (widget.activity == null) {
        // Para nuevas actividades, verificar si es recurrente
        if (_isRecurring && _recurrenceCount > 1) {
          // Crear múltiples actividades
          final dates = _calculateRecurrenceDates();
          int createdCount = 0;
          int failedCount = 0;

          for (int i = 0; i < dates.length; i++) {
            final recurringActivity = Activity(
              id: '',
              title: _titleController.text.trim(),
              description:
                  '${_descriptionController.text.trim()}${_descriptionController.text.isNotEmpty ? '\n' : ''}[Evento ${i + 1}/$_recurrenceCount - ${_getRecurrenceLabel()}]',
              activityType: activityType,
              status: status,
              priority: priority,
              startDate: dates[i],
              dueDate: dates[i],
              color: color,
              icon: activityType.name,
              createdAt: ColombiaTime.now(),
              updatedAt: ColombiaTime.now(),
            );

            final result = await ref
                .read(activitiesProvider.notifier)
                .createActivity(recurringActivity);
            if (result) {
              createdCount++;
            } else {
              failedCount++;
            }
          }

          success = createdCount > 0;

          if (mounted) {
            if (success) {
              Navigator.pop(context);
              widget.onSaved?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    failedCount > 0
                        ? '$createdCount eventos creados ($failedCount fallaron)'
                        : '$createdCount eventos recurrentes creados exitosamente',
                  ),
                  backgroundColor: failedCount > 0
                      ? const Color(0xFFF9A825)
                      : const Color(0xFF2E7D32),
                ),
              );
            } else {
              setState(() => _isSaving = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Error al crear eventos: ${ref.read(activitiesProvider).error ?? "Error desconocido"}',
                  ),
                  backgroundColor: AppColors.danger,
                ),
              );
            }
          }
          return;
        } else {
          success = await ref
              .read(activitiesProvider.notifier)
              .createActivity(activity);
        }
      } else {
        success = await ref
            .read(activitiesProvider.notifier)
            .updateActivity(activity);
      }

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          widget.onSaved?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.activity == null
                    ? 'Actividad creada exitosamente'
                    : 'Actividad actualizada exitosamente',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error al guardar: ${ref.read(activitiesProvider).error ?? "Error desconocido"}',
              ),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    }
  }
}

/// Tarjeta de Evento auto-generado (facturas, OPs, envios, etc.)
class _EventCard extends StatelessWidget {
  final CalendarEvent event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final colorVal = Color(
      int.parse('0xFF${event.color.replaceFirst('#', '')}'),
    );
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorVal.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorVal.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: colorVal,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Icon(event.icon, size: 20, color: colorVal),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: event.isOverdue ? const Color(0xFFC62828) : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (event.subtitle != null)
                  Text(
                    event.subtitle!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF757575),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colorVal.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              event.sourceLabel,
              style: TextStyle(
                fontSize: 9,
                color: colorVal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (event.isOverdue) ...[
            const SizedBox(width: 4),
            const Icon(Icons.warning_amber, size: 14, color: Color(0xFFC62828)),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta de Actividad
class _ActivityCard extends StatelessWidget {
  final Activity activity;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ActivityCard({
    required this.activity,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isMobile ? 8 : 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Color(
              int.parse('0xFF${activity.color.replaceFirst('#', '')}'),
            ).withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(8),
          color: Color(
            int.parse('0xFF${activity.color.replaceFirst('#', '')}'),
          ).withOpacity(0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Color(
                      int.parse('0xFF${activity.color.replaceFirst('#', '')}'),
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        activity.typeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(onTap: onEdit, child: const Text('Editar')),
                    PopupMenuItem(
                      onTap: onDelete,
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (activity.description != null &&
                activity.description!.isNotEmpty)
              Text(
                activity.description!,
                style: TextStyle(fontSize: 12, color: const Color(0xFF616161)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: activity.statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    activity.statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: activity.statusColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9A825).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    activity.priorityLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFF9A825),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
