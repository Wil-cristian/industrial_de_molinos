import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../domain/entities/activity.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/quick_actions_button.dart';

/// Página de Calendario/Organizador
/// Gestión de actividades, eventos y recordatorios
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _selectedDate = DateTime.now();
  DateTime _displayedMonth = DateTime.now();
  String _filterType = 'Todas';
  String _filterStatus = 'Todas';

  // Mock data - será reemplazado con datos reales del provider
  final List<Activity> _mockActivities = [
    Activity(
      id: '1',
      title: 'Cobro a Cliente ABC',
      description: 'Seguimiento de pago de factura #001',
      activityType: ActivityType.collection,
      status: ActivityStatus.pending,
      priority: ActivityPriority.high,
      startDate: DateTime.now(),
      dueDate: DateTime.now(),
      customerName: 'Cliente ABC',
      amount: 5000,
      color: '#FF6B6B',
      icon: 'payment',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Activity(
      id: '2',
      title: 'Entrega de Productos',
      description: 'Envío a bodega principal',
      activityType: ActivityType.delivery,
      status: ActivityStatus.inProgress,
      priority: ActivityPriority.medium,
      startDate: DateTime.now().add(Duration(days: 1)),
      dueDate: DateTime.now().add(Duration(days: 2)),
      customerName: 'Distribuidora XYZ',
      color: '#4ECDC4',
      icon: 'local_shipping',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Activity(
      id: '3',
      title: 'Reunión con Proveedor',
      description: 'Discusión sobre nuevas compras de materiales',
      activityType: ActivityType.meeting,
      status: ActivityStatus.pending,
      priority: ActivityPriority.medium,
      startDate: DateTime.now().add(Duration(days: 3)),
      dueDate: DateTime.now().add(Duration(days: 3)),
      color: '#95E1D3',
      icon: 'group',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  List<Activity> get _filteredActivities {
    var activities = _mockActivities
        .where((a) => _isSameDay(a.dueDate ?? a.startDate, _selectedDate))
        .toList();

    // Filtrar por tipo
    if (_filterType != 'Todas') {
      activities = activities
          .where((a) => a.typeLabel == _filterType)
          .toList();
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
    return _mockActivities
        .where((a) => _isSameDay(a.dueDate ?? a.startDate, day))
        .toList();
  }

  void _showActivityDialog({Activity? activity}) {
    showDialog(
      context: context,
      builder: (context) => _ActivityDialog(activity: activity),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Stack(
        children: [
          const QuickActionsButton(),
          Row(
            children: [
              const AppSidebar(currentRoute: '/calendar'),
              Expanded(
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      color: Colors.white,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Calendario & Organizador',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Gestiona actividades, eventos y recordatorios',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showActivityDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Nueva Actividad'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
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
                              child: Column(
                                children: [
                                  _buildMonthNavigator(),
                                  Expanded(
                                    child: _buildCalendarGrid(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 1),
                          // Lista de Actividades
                          Expanded(
                            flex: 1,
                            child: Container(
                              color: Colors.white,
                              child: Column(
                                children: [
                                  _buildActivityFilters(),
                                  Expanded(
                                    child: _buildActivityList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthNavigator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _displayedMonth =
                    DateTime(_displayedMonth.year, _displayedMonth.month - 1);
              });
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            '${_monthNames[_displayedMonth.month - 1]} ${_displayedMonth.year}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _displayedMonth =
                    DateTime(_displayedMonth.year, _displayedMonth.month + 1);
              });
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay =
        DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final lastDay = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    );
    final prevMonthDays = firstDay.weekday - 1;
    final totalCells = prevMonthDays + lastDay.day + (7 - lastDay.weekday % 7);

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
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
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${cellDate.day}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : isCurrentMonth
                              ? Colors.black87
                              : Colors.grey[400],
                    ),
                  ),
                ),
                if (activities.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < activities.length && i < 3; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 1),
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(int.parse(
                                  '0xFF${activities[i].color?.replaceFirst('#', '') ?? 'FF6B6B'}',
                                )),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivityFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filtros',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Filtro de Tipo
              FilterChip(
                label: Text(_filterType),
                onSelected: (_) => _showFilterMenu('type'),
                backgroundColor: Colors.grey[200],
                selectedColor: AppTheme.primaryColor.withOpacity(0.3),
                labelStyle: TextStyle(
                  color: _filterType == 'Todas' ? Colors.grey[600] : Colors.black87,
                ),
              ),
              // Filtro de Estado
              FilterChip(
                label: Text(_filterStatus),
                onSelected: (_) => _showFilterMenu('status'),
                backgroundColor: Colors.grey[200],
                selectedColor: AppTheme.primaryColor.withOpacity(0.3),
                labelStyle: TextStyle(
                  color: _filterStatus == 'Todas' ? Colors.grey[600] : Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList() {
    final activities = _filteredActivities;

    if (activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_note,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Sin actividades',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'para ${_dateFormat(_selectedDate)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: activities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
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

  void _showFilterMenu(String filterType) {
    final options = filterType == 'type'
        ? ['Todas', 'Pago', 'Entrega', 'Reunión', 'Colección', 'Proyecto']
        : ['Todas', 'Pendiente', 'En Progreso', 'Completada', 'Vencida'];

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(0, 0, 0, 0),
      items: options
          .map((option) => PopupMenuItem(
                value: option,
                child: Text(option),
                onTap: () {
                  setState(() {
                    if (filterType == 'type') {
                      _filterType = option;
                    } else {
                      _filterStatus = option;
                    }
                  });
                },
              ))
          .toList(),
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
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${activity.title} eliminada'),
                  backgroundColor: Colors.green,
                ),
              );
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

  const _ActivityDialog({this.activity});

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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.activity?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.activity?.description ?? '');
    _selectedDate = widget.activity?.dueDate ?? DateTime.now();
    _selectedType = widget.activity?.activityType.name ?? 'payment';
    _selectedStatus = widget.activity?.status.name ?? 'pending';
    _selectedPriority = widget.activity?.priority.name ?? 'medium';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
                widget.activity == null ? 'Nueva Actividad' : 'Editar Actividad',
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
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedType = value);
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
                          .map((priority) => DropdownMenuItem(
                                value: priority,
                                child: Text(priority),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedPriority = value);
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
                    .map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedStatus = value);
                },
              ),
              const SizedBox(height: 24),
              // Botones
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      // Guardar actividad
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            widget.activity == null
                                ? 'Actividad creada'
                                : 'Actividad actualizada',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(widget.activity == null ? 'Crear' : 'Actualizar'),
                  ),
                ],
              ),
            ],
          ),
        ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Color(int.parse(
                  '0xFF${activity.color?.replaceFirst('#', '') ?? 'FF6B6B'}',
                ))
                .withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(8),
          color: Color(int.parse(
                '0xFF${activity.color?.replaceFirst('#', '') ?? 'FF6B6B'}',
              ))
              .withOpacity(0.05),
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
                    color: Color(int.parse(
                      '0xFF${activity.color?.replaceFirst('#', '') ?? 'FF6B6B'}',
                    )),
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
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const Text('Editar'),
                      onTap: onEdit,
                    ),
                    PopupMenuItem(
                      child: const Text('Eliminar'),
                      onTap: onDelete,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (activity.description != null && activity.description!.isNotEmpty)
              Text(
                activity.description!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
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
