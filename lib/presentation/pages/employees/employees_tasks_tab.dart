import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/helpers.dart';
import '../../../data/providers/employees_provider.dart';
import '../../../domain/entities/employee.dart';

/// Tab de gestión de tareas de empleados.
class EmployeesTasksTab extends ConsumerStatefulWidget {
  const EmployeesTasksTab({super.key});

  @override
  ConsumerState<EmployeesTasksTab> createState() => EmployeesTasksTabState();
}

class EmployeesTasksTabState extends ConsumerState<EmployeesTasksTab> {
  final _taskSearchController = TextEditingController();
  String _taskFilterStatus = 'todos';
  String _taskFilterCategory = 'todos';
  String _taskFilterAssignee = 'todos';
  DateTimeRange? _taskDateRange;

  /// Public API for shell coordinator to open task creation dialog.
  void showTaskDialog() => _showTaskDialog();

  @override
  void dispose() {
    _taskSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeesProvider);
    final theme = Theme.of(context);
    return _buildTasksTab(theme, state);
  }

  Widget _buildTasksTab(ThemeData theme, EmployeesState state) {
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFFBDBDBD)
        : const Color(0xFF64748B);
    final textMuted = isDark
        ? const Color(0xFF757575)
        : const Color(0xFF94A3B8);

    return Container(
      color: bgColor,
      child: Column(
        children: [
          // Contenido con scroll
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  // Filtros compactos
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        // Búsqueda
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _taskSearchController,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Buscar tarea...',
                              hintStyle: TextStyle(
                                color: textMuted,
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: textMuted,
                                size: 20,
                              ),
                              suffixIcon: _taskSearchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        size: 16,
                                        color: textMuted,
                                      ),
                                      onPressed: () {
                                        _taskSearchController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: bgColor,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Filtros dropdown compactos
                        _buildCompactFilter(
                          'Estado',
                          _taskFilterStatus,
                          {
                            'todos': 'Todos',
                            'pendiente': 'Pendiente',
                            'en_progreso': 'En Progreso',
                            'completada': 'Completada',
                            'cancelada': 'Cancelada',
                          },
                          (v) => setState(() => _taskFilterStatus = v!),
                          theme,
                          borderColor,
                        ),
                        const SizedBox(width: 8),
                        _buildCompactFilter(
                          'Categoría',
                          _taskFilterCategory,
                          {
                            'todos': 'Todas',
                            'General': 'General',
                            'Produccion': 'Producción',
                            'Mantenimiento': 'Mantenimiento',
                            'Limpieza': 'Limpieza',
                            'Reportes': 'Reportes',
                          },
                          (v) => setState(() => _taskFilterCategory = v!),
                          theme,
                          borderColor,
                        ),
                        const SizedBox(width: 8),
                        _buildCompactFilter(
                          'Asignado',
                          _taskFilterAssignee,
                          {
                            'todos': 'Todos',
                            for (var e in state.activeEmployees)
                              e.id: e.fullName,
                          },
                          (v) => setState(() => _taskFilterAssignee = v!),
                          theme,
                          borderColor,
                        ),
                        const SizedBox(width: 8),
                        // Limpiar filtros
                        if (_hasActiveFilters())
                          IconButton(
                            icon: Icon(
                              Icons.filter_alt_off,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            tooltip: 'Limpiar filtros',
                            onPressed: _clearTaskFilters,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tabla de tareas
                  Builder(
                    builder: (context) {
                      final filteredTasks = _getFilteredTasks(state.tasks);

                      return Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF000000,
                              ).withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Header tabla
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(15),
                                ),
                                border: Border(
                                  bottom: BorderSide(color: borderColor),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildTableHeader(
                                    'TAREA',
                                    textSecondary,
                                    flex: 3,
                                  ),
                                  _buildTableHeader(
                                    'UBICACIÓN',
                                    textSecondary,
                                    flex: 2,
                                  ),
                                  _buildTableHeader(
                                    'EQUIPO',
                                    textSecondary,
                                    flex: 2,
                                  ),
                                  _buildTableHeader(
                                    'ESTADO',
                                    textSecondary,
                                    flex: 2,
                                  ),
                                  _buildTableHeader(
                                    'TIEMPO',
                                    textSecondary,
                                    flex: 2,
                                  ),
                                  _buildTableHeader(
                                    'ACCIONES',
                                    textSecondary,
                                    flex: 2,
                                    align: TextAlign.right,
                                  ),
                                ],
                              ),
                            ),
                            // Filas
                            if (filteredTasks.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(48),
                                child: _buildEmptyState(
                                  icon: Icons.task_alt,
                                  title: state.tasks.isEmpty
                                      ? 'Sin tareas'
                                      : 'Sin resultados',
                                  subtitle: state.tasks.isEmpty
                                      ? 'Crea tareas para asignar a tu equipo'
                                      : 'No hay tareas que coincidan con los filtros',
                                  onAction: () => _showTaskDialog(),
                                  actionLabel: 'Crear Tarea',
                                ),
                              )
                            else
                              ...filteredTasks.map(
                                (task) => _buildTaskRow(
                                  theme,
                                  task,
                                  textMain,
                                  textSecondary,
                                  textMuted,
                                  borderColor,
                                  bgColor,
                                ),
                              ),
                            // Footer
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(15),
                                ),
                                border: Border(
                                  top: BorderSide(color: borderColor),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      text: 'Mostrando ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textSecondary,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: '${filteredTasks.length}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: textMain,
                                          ),
                                        ),
                                        TextSpan(text: ' de '),
                                        TextSpan(
                                          text: '${state.tasks.length}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: textMain,
                                          ),
                                        ),
                                        TextSpan(text: ' tareas'),
                                      ],
                                    ),
                                  ),
                                  if (filteredTasks.length !=
                                      state.tasks.length)
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _taskSearchController.clear();
                                          _taskFilterStatus = 'todos';
                                          _taskFilterCategory = 'todos';
                                          _taskFilterAssignee = 'todos';
                                          _taskDateRange = null;
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.filter_alt_off,
                                        size: 16,
                                      ),
                                      label: const Text('Quitar filtros'),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helpers para filtros compactos
  bool _hasActiveFilters() =>
      _taskSearchController.text.isNotEmpty ||
      _taskFilterStatus != 'todos' ||
      _taskFilterCategory != 'todos' ||
      _taskFilterAssignee != 'todos' ||
      _taskDateRange != null;

  void _clearTaskFilters() {
    setState(() {
      _taskSearchController.clear();
      _taskFilterStatus = 'todos';
      _taskFilterCategory = 'todos';
      _taskFilterAssignee = 'todos';
      _taskDateRange = null;
    });
  }

  Widget _buildCompactFilter(
    String label,
    String value,
    Map<String, String> options,
    void Function(String?) onChanged,
    ThemeData theme,
    Color borderColor,
  ) {
    final isActive = value != 'todos';
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      tooltip: label,
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? theme.colorScheme.primary : borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isActive ? (options[value] ?? value) : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
      itemBuilder: (ctx) => options.entries
          .map(
            (e) => PopupMenuItem(
              value: e.key,
              child: Row(
                children: [
                  if (e.key == value)
                    Icon(
                      Icons.check,
                      size: 16,
                      color: theme.colorScheme.primary,
                    )
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(e.value, style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTableHeader(
    String text,
    Color color, {
    int flex = 1,
    TextAlign align = TextAlign.left,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTaskRow(
    ThemeData theme,
    EmployeeTask task,
    Color textMain,
    Color textSecondary,
    Color textMuted,
    Color borderColor,
    Color bgColor,
  ) {
    final employee = ref
        .read(employeesProvider)
        .employees
        .where((e) => e.id == task.employeeId)
        .firstOrNull;

    return InkWell(
      onTap: () => _showTaskDialog(task: task),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: borderColor.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          children: [
            // Tarea
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'ID: #TK-${task.id.substring(0, 4).toUpperCase()}',
                        style: TextStyle(
                          fontSize: 11,
                          color: textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (task.productionOrderId != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF1B4F72,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.precision_manufacturing,
                                size: 10,
                                color: const Color(0xFF1B4F72),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'OP',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1B4F72),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Ubicación
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.location_on,
                      size: 16,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.category,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Equipo
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.primary.withValues(
                      alpha: 0.1,
                    ),
                    backgroundImage: employee?.photoUrl != null
                        ? NetworkImage(employee!.photoUrl!)
                        : null,
                    child: employee?.photoUrl == null
                        ? Text(
                            employee?.initials ?? '?',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            // Estado
            Expanded(
              flex: 2,
              child: _buildStatusBadge(
                task.status,
                task.statusLabel,
                task.statusColor,
              ),
            ),
            // Tiempo
            Expanded(flex: 2, child: _buildTimeCell(task, textSecondary)),
            // Acciones
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Cambiar estado
                  PopupMenuButton<TaskStatus>(
                    tooltip: 'Cambiar estado',
                    icon: Icon(Icons.more_vert, color: textSecondary, size: 20),
                    onSelected: (newStatus) async {
                      if (newStatus == TaskStatus.completada) {
                        await ref
                            .read(employeesProvider.notifier)
                            .completeTask(task.id);
                      } else {
                        final updatedTask = EmployeeTask(
                          id: task.id,
                          employeeId: task.employeeId,
                          employeeName: task.employeeName,
                          title: task.title,
                          description: task.description,
                          assignedDate: task.assignedDate,
                          dueDate: task.dueDate,
                          completedDate: newStatus == TaskStatus.completada
                              ? DateTime.now()
                              : null,
                          status: newStatus,
                          priority: task.priority,
                          category: task.category,
                          estimatedTime: task.estimatedTime,
                          actualTime: task.actualTime,
                          activityId: task.activityId,
                          notes: task.notes,
                          createdAt: task.createdAt,
                          updatedAt: DateTime.now(),
                          assignedBy: task.assignedBy,
                        );
                        await ref
                            .read(employeesProvider.notifier)
                            .updateTask(updatedTask);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: TaskStatus.pendiente,
                        child: Row(
                          children: [
                            Icon(
                              Icons.pending,
                              color: const Color(0xFFF9A825),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Text('Pendiente'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: TaskStatus.enProgreso,
                        child: Row(
                          children: [
                            Icon(
                              Icons.play_circle,
                              color: const Color(0xFF1565C0),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Text('En Progreso'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: TaskStatus.completada,
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: const Color(0xFF2E7D32),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Text('Completada'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: TaskStatus.cancelada,
                        child: Row(
                          children: [
                            Icon(
                              Icons.cancel,
                              color: const Color(0xFFC62828),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Text('Cancelar'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Eliminar
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: const Color(0xFFE57373),
                      size: 20,
                    ),
                    tooltip: 'Eliminar tarea',
                    onPressed: () => _confirmDeleteTask(task),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTask(EmployeeTask task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Tarea'),
        content: Text('¿Estás seguro de eliminar la tarea "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref
                  .read(employeesProvider.notifier)
                  .deleteTask(task.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Tarea eliminada' : 'Error al eliminar',
                    ),
                    backgroundColor: success
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFC62828),
                  ),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(TaskStatus status, String label, Color color) {
    final bgColor = color.withValues(alpha: 0.1);
    final borderColor = color.withValues(alpha: 0.2);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == TaskStatus.completada)
                Icon(Icons.check_circle, size: 14, color: color)
              else
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeCell(EmployeeTask task, Color textColor) {
    if (task.status == TaskStatus.completada) {
      return Row(
        children: [
          Text(
            'A tiempo',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2E7D32),
            ),
          ),
        ],
      );
    }

    final dueDate = task.dueDate;
    if (dueDate == null) {
      return Row(
        children: [
          Icon(Icons.schedule, size: 16, color: textColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Sin fecha',
              style: TextStyle(fontSize: 13, color: textColor),
            ),
          ),
        ],
      );
    }

    final now = DateTime.now();
    final diff = dueDate.difference(now);

    if (diff.isNegative) {
      return Row(
        children: [
          Icon(Icons.warning, size: 16, color: const Color(0xFFC62828)),
          const SizedBox(width: 6),
          Text(
            '-${diff.inHours.abs()}h (Venció)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFC62828),
            ),
          ),
        ],
      );
    }

    final days = diff.inDays;
    final hours = diff.inHours;
    final text = days > 0 ? '$days días restantes' : '${hours}h restantes';

    return Row(
      children: [
        Icon(Icons.schedule, size: 16, color: textColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF757575),
            ),
            textAlign: TextAlign.center,
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  List<EmployeeTask> _getFilteredTasks(List<EmployeeTask> tasks) {
    return tasks.where((task) {
      if (_taskSearchController.text.isNotEmpty) {
        final query = _taskSearchController.text.toLowerCase();
        final matchesTitle = task.title.toLowerCase().contains(query);
        final matchesId = task.id.toLowerCase().contains(query);
        final matchesCategory = task.category.toLowerCase().contains(query);
        if (!matchesTitle && !matchesId && !matchesCategory) return false;
      }
      if (_taskFilterStatus != 'todos') {
        final statusMap = {
          'pendiente': TaskStatus.pendiente,
          'en_progreso': TaskStatus.enProgreso,
          'completada': TaskStatus.completada,
          'cancelada': TaskStatus.cancelada,
        };
        if (task.status != statusMap[_taskFilterStatus]) return false;
      }
      if (_taskFilterCategory != 'todos') {
        if (task.category.toLowerCase() != _taskFilterCategory.toLowerCase()) {
          return false;
        }
      }
      if (_taskFilterAssignee != 'todos') {
        if (task.employeeId != _taskFilterAssignee) return false;
      }
      if (_taskDateRange != null) {
        final taskDate = task.assignedDate;
        if (taskDate.isBefore(_taskDateRange!.start) ||
            taskDate.isAfter(_taskDateRange!.end)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _showTaskDialog({EmployeeTask? task}) {
    final isEditing = task != null;
    final titleController = TextEditingController(text: task?.title ?? '');
    final descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    List<String> selectedEmployeeIds = [];
    if (task?.employeeId != null) {
      selectedEmployeeIds = [task!.employeeId];
    }
    TaskPriority selectedPriority = task?.priority ?? TaskPriority.media;
    // Normalizar categoría: las tareas de producción se guardan como 'produccion'
    final validCategories = [
      'General',
      'Produccion',
      'Mantenimiento',
      'Limpieza',
      'Logistica',
      'Administrativo',
      'Reportes',
    ];
    String selectedCategory = task?.category ?? 'General';
    // Si la categoría no coincide exactamente, buscar case-insensitive
    if (!validCategories.contains(selectedCategory)) {
      final match = validCategories.where(
        (c) => c.toLowerCase() == selectedCategory.toLowerCase(),
      );
      selectedCategory = match.isNotEmpty ? match.first : 'General';
    }
    DateTime selectedDate = task?.assignedDate ?? DateTime.now();
    DateTime? dueDate = task?.dueDate;

    final employees = ref.read(employeesProvider).activeEmployees;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Editar Tarea' : 'Nueva Tarea'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Título de la tarea *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Asignar a *',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (selectedEmployeeIds.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: selectedEmployeeIds.map((id) {
                              final emp = employees.firstWhere(
                                (e) => e.id == id,
                                orElse: () => employees.first,
                              );
                              return Chip(
                                avatar: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.2),
                                  child: Text(
                                    emp.initials,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                label: Text(
                                  emp.fullName,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () => setDialogState(
                                  () => selectedEmployeeIds.remove(id),
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            await showDialog(
                              context: context,
                              builder: (ctx) => StatefulBuilder(
                                builder: (ctx, setInnerState) => AlertDialog(
                                  title: const Text('Seleccionar Empleados'),
                                  content: SizedBox(
                                    width: 300,
                                    height: 300,
                                    child: ListView.builder(
                                      itemCount: employees.length,
                                      itemBuilder: (ctx, i) {
                                        final emp = employees[i];
                                        final isSelected = selectedEmployeeIds
                                            .contains(emp.id);
                                        return CheckboxListTile(
                                          value: isSelected,
                                          title: Text(emp.fullName),
                                          subtitle: Text(
                                            emp.position,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                          secondary: CircleAvatar(
                                            radius: 16,
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.1),
                                            child: Text(
                                              emp.initials,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          onChanged: (val) {
                                            setInnerState(() {
                                              if (val == true) {
                                                selectedEmployeeIds.add(emp.id);
                                              } else {
                                                selectedEmployeeIds.remove(
                                                  emp.id,
                                                );
                                              }
                                            });
                                          },
                                          dense: true,
                                        );
                                      },
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Listo'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            setDialogState(() {});
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                selectedEmployeeIds.isEmpty
                                    ? 'Seleccionar empleados'
                                    : 'Agregar más',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<TaskPriority>(
                          value: selectedPriority,
                          decoration: const InputDecoration(
                            labelText: 'Prioridad',
                            border: OutlineInputBorder(),
                          ),
                          items: TaskPriority.values.map((priority) {
                            return DropdownMenuItem(
                              value: priority,
                              child: Text(
                                priority.name[0].toUpperCase() +
                                    priority.name.substring(1),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() => selectedPriority = value!);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'General',
                              child: Text('General'),
                            ),
                            DropdownMenuItem(
                              value: 'Produccion',
                              child: Text('Producción'),
                            ),
                            DropdownMenuItem(
                              value: 'Mantenimiento',
                              child: Text('Mantenimiento'),
                            ),
                            DropdownMenuItem(
                              value: 'Limpieza',
                              child: Text('Limpieza'),
                            ),
                            DropdownMenuItem(
                              value: 'Logistica',
                              child: Text('Logística'),
                            ),
                            DropdownMenuItem(
                              value: 'Administrativo',
                              child: Text('Administrativo'),
                            ),
                            DropdownMenuItem(
                              value: 'Reportes',
                              child: Text('Reportes'),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() => selectedCategory = value!);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: const Text('Fecha Asignación'),
                          subtitle: Text(Helpers.formatDate(selectedDate)),
                          trailing: const Icon(Icons.calendar_today),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Color(0xFFBDBDBD)),
                          ),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null) {
                              setDialogState(() => selectedDate = date);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ListTile(
                          title: const Text('Fecha Límite'),
                          subtitle: Text(
                            dueDate != null
                                ? Helpers.formatDate(dueDate!)
                                : 'Sin fecha límite',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (dueDate != null)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () =>
                                      setDialogState(() => dueDate = null),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              const SizedBox(width: 4),
                              const Icon(Icons.event),
                            ],
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: dueDate != null
                                  ? const Color(0xFFF9A825)
                                  : const Color(0xFFBDBDBD),
                            ),
                          ),
                          tileColor: dueDate != null
                              ? const Color(0xFFF9A825).withValues(alpha: 0.05)
                              : null,
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate:
                                  dueDate ??
                                  DateTime.now().add(const Duration(days: 7)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null) {
                              setDialogState(() => dueDate = date);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleController.text.isEmpty ||
                    selectedEmployeeIds.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Completa los campos obligatorios'),
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                if (isEditing) {
                  final selectedEmp = employees.firstWhere(
                    (e) => e.id == selectedEmployeeIds.first,
                    orElse: () => employees.first,
                  );
                  final updatedTask = EmployeeTask(
                    id: task.id,
                    employeeId: selectedEmployeeIds.first,
                    employeeName: selectedEmp.fullName,
                    title: titleController.text,
                    description: descriptionController.text.isEmpty
                        ? null
                        : descriptionController.text,
                    assignedDate: selectedDate,
                    dueDate: dueDate,
                    status: task.status,
                    priority: selectedPriority,
                    category: selectedCategory,
                    createdAt: task.createdAt,
                    updatedAt: DateTime.now(),
                  );
                  await ref
                      .read(employeesProvider.notifier)
                      .updateTask(updatedTask);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Tarea actualizada'),
                        backgroundColor: Color(0xFF2E7D32),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } else {
                  bool anySuccess = false;
                  for (final empId in selectedEmployeeIds) {
                    final emp = employees.firstWhere(
                      (e) => e.id == empId,
                      orElse: () => employees.first,
                    );
                    final newTask = EmployeeTask(
                      id: '',
                      employeeId: empId,
                      employeeName: emp.fullName,
                      title: titleController.text,
                      description: descriptionController.text.isEmpty
                          ? null
                          : descriptionController.text,
                      assignedDate: selectedDate,
                      dueDate: dueDate,
                      status: TaskStatus.pendiente,
                      priority: selectedPriority,
                      category: selectedCategory,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    final created = await ref
                        .read(employeesProvider.notifier)
                        .createTask(newTask);
                    if (created != null) anySuccess = true;
                  }
                  if (mounted) {
                    if (anySuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            selectedEmployeeIds.length > 1
                                ? '✅ Tarea asignada a ${selectedEmployeeIds.length} empleados'
                                : '✅ Tarea creada exitosamente',
                          ),
                          backgroundColor: const Color(0xFF2E7D32),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('❌ Error al crear la tarea'),
                          backgroundColor: Color(0xFFC62828),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                }
              },
              child: Text(isEditing ? 'Guardar' : 'Crear'),
            ),
          ],
        ),
      ),
    );
  }
}
