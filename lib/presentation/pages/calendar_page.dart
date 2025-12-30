import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/activity.dart';
import '../../data/providers/activities_provider.dart';

/// Página de Calendario/Organizador
/// Gestión de actividades, eventos y recordatorios
class CalendarPage extends ConsumerStatefulWidget {
  final bool openNewDialog;

  const CalendarPage({super.key, this.openNewDialog = false});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _selectedDate = DateTime.now();
  DateTime _displayedMonth = DateTime.now();
  String _filterType = 'Todas';
  String _filterStatus = 'Todas';
  bool _dialogOpened = false;

  @override
  void initState() {
    super.initState();
    // Cargar actividades al iniciar
    Future.microtask(() {
      ref.read(activitiesProvider.notifier).loadActivities();
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Header ultra compacto
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            color: Colors.white,
            child: Row(
              children: [
                Text(
                  'Calendario',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                ),
                const SizedBox(width: 8),
                // Navegador de mes inline
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
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
                Text(
                  '${_monthNames[_displayedMonth.month - 1]} ${_displayedMonth.year}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                            ),
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
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                          ),
                          const Spacer(),
                          // Filtros inline
                          _buildCompactFilter('type', _filterType),
                          const SizedBox(width: 4),
                          _buildCompactFilter('status', _filterStatus),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 28,
                            child: ElevatedButton.icon(
                              onPressed: () => _showActivityDialog(),
                              icon: const Icon(Icons.add, size: 14),
                              label: const Text(
                                'Nueva',
                                style: TextStyle(fontSize: 11),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Contenido Principal
                    Expanded(
                      child: Row(
                        children: [
                          // Calendario
                          Expanded(
                            flex: 1,
                            child: Container(
                              color: Colors.white,
                              margin: const EdgeInsets.all(2),
                              child: _buildCalendarGrid(),
                            ),
                          ),
                          // Lista de Actividades
                          Expanded(
                            flex: 1,
                            child: Container(
                              color: Colors.white,
                              margin: const EdgeInsets.fromLTRB(0, 2, 2, 2),
                              child: Column(
                                children: [
                                  // Título de la fecha seleccionada
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey[200]!,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.event,
                                          size: 14,
                                          color: AppTheme.primaryColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _dateFormat(_selectedDate),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${_filteredActivities.length} actividades',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(child: _buildActivityList()),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentValue,
              style: TextStyle(fontSize: 10, color: Colors.grey[700]),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 14, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final lastDay = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    );
    final prevMonthDays = firstDay.weekday - 1;
    final totalCells = prevMonthDays + lastDay.day + (7 - lastDay.weekday % 7);

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.2,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        DateTime cellDate;
        bool isCurrentMonth = false;

        if (index < prevMonthDays) {
          cellDate = DateTime(
            _displayedMonth.year,
            _displayedMonth.month - 1,
            lastDay.day - prevMonthDays + index + 1,
          );
        } else if (index < prevMonthDays + lastDay.day) {
          isCurrentMonth = true;
          cellDate = DateTime(
            _displayedMonth.year,
            _displayedMonth.month,
            index - prevMonthDays + 1,
          );
        } else {
          cellDate = DateTime(
            _displayedMonth.year,
            _displayedMonth.month + 1,
            index - prevMonthDays - lastDay.day + 1,
          );
        }

        final activities = _getActivitiesForDay(cellDate);
        final isSelected = _isSameDay(cellDate, _selectedDate);
        final isToday = _isSameDay(cellDate, DateTime.now());

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = cellDate;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor
                  : isToday
                  ? Colors.blue[50]
                  : isCurrentMonth
                  ? Colors.white
                  : Colors.grey[50],
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryColor
                    : isToday
                    ? Colors.blue
                    : Colors.grey[300]!,
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
                        ? Colors.black87
                        : Colors.grey[400],
                  ),
                ),
                if (activities.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < activities.length && i < 3; i++)
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
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivityList() {
    final activities = _filteredActivities;

    if (activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 32, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'Sin actividades',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(4),
      itemCount: activities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final activity = activities[index];
        return _ActivityCard(
          activity: activity,
          onTap: () => _showActivityDialog(activity: activity),
          onEdit: () => _showActivityDialog(activity: activity),
          onDelete: () => _showDeleteConfirmation(activity),
        );
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
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error al eliminar la actividad'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.5,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.activity == null
                    ? 'Nueva Actividad'
                    : 'Editar Actividad',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
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
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(Duration(days: 365)),
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
              // Tipo
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: InputDecoration(
                        labelText: 'Tipo',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: ['payment', 'delivery', 'meeting', 'collection']
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedType = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedPriority,
                      decoration: InputDecoration(
                        labelText: 'Prioridad',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: ['low', 'medium', 'high', 'urgent']
                          .map(
                            (priority) => DropdownMenuItem(
                              value: priority,
                              child: Text(priority),
                            ),
                          )
                          .toList(),
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
                items: ['pending', 'inProgress', 'completed', 'cancelled']
                    .map(
                      (status) =>
                          DropdownMenuItem(value: status, child: Text(status)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedStatus = value);
                },
              ),
              // Sección de Recurrencia (solo para nuevas actividades)
              if (widget.activity == null) ...[
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
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
                            color: Colors.grey.shade600,
                          ),
                        ),
                        value: _isRecurring,
                        onChanged: (value) {
                          setState(() => _isRecurring = value ?? false);
                        },
                        activeColor: AppTheme.primaryColor,
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
                      backgroundColor: AppTheme.primaryColor,
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
          backgroundColor: Colors.red,
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
        createdAt: widget.activity?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
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
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
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
                      ? Colors.orange
                      : Colors.green,
                ),
              );
            } else {
              setState(() => _isSaving = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Error al crear eventos: ${ref.read(activitiesProvider).error ?? "Error desconocido"}',
                  ),
                  backgroundColor: Colors.red,
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
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error al guardar: ${ref.read(activitiesProvider).error ?? "Error desconocido"}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
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
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
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
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    activity.priorityLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.amber,
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
