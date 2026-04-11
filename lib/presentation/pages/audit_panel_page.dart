import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/responsive/responsive_helper.dart';
import '../../domain/entities/audit_log.dart';
import '../../data/providers/audit_log_provider.dart';
import '../../core/utils/colombia_time.dart';

/// Página de Panel de Auditoría — Movimientos del sistema
/// Muestra quién hizo qué y cuándo
class AuditPanelPage extends ConsumerStatefulWidget {
  const AuditPanelPage({super.key});

  @override
  ConsumerState<AuditPanelPage> createState() => _AuditPanelPageState();
}

class _AuditPanelPageState extends ConsumerState<AuditPanelPage> {
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'es_CO');
  final _dateOnlyFormat = DateFormat('dd/MM/yyyy', 'es_CO');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(auditLogProvider.notifier).loadLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(auditLogProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Container(
          color: colorScheme.surfaceContainerLowest,
          child: Column(
            children: [
              _buildHeader(context, state),
              _buildFilterBar(context, state),
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.error != null
                    ? _buildErrorState(context, state.error!)
                    : state.logs.isEmpty
                    ? _buildEmptyState(context)
                    : _buildLogList(context, state),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuditLogState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.security, color: colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Panel de Auditoría',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Registro de todos los movimientos del sistema',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Contador de registros
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${state.logs.length} registros',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () => ref.read(auditLogProvider.notifier).loadLogs(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, AuditLogState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = ResponsiveHelper.isMobile(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withAlpha(60)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final dropdownWidth = isMobile
              ? availableWidth
              : (availableWidth - 48) / 4 > 180
              ? 180.0
              : (availableWidth - 48) / 4;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Filtro por módulo
              SizedBox(
                width: isMobile
                    ? double.infinity
                    : dropdownWidth.clamp(120.0, 180.0),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: state.filterModule,
                  decoration: InputDecoration(
                    labelText: 'Módulo',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todos')),
                    DropdownMenuItem(value: 'invoices', child: Text('Ventas')),
                    DropdownMenuItem(value: 'expenses', child: Text('Compras')),
                    DropdownMenuItem(
                      value: 'materials',
                      child: Text('Materiales'),
                    ),
                    DropdownMenuItem(
                      value: 'inventory',
                      child: Text('Inventario'),
                    ),
                    DropdownMenuItem(value: 'cash', child: Text('Caja')),
                    DropdownMenuItem(
                      value: 'production',
                      child: Text('Producción'),
                    ),
                    DropdownMenuItem(
                      value: 'customers',
                      child: Text('Clientes'),
                    ),
                    DropdownMenuItem(
                      value: 'employees',
                      child: Text('Empleados'),
                    ),
                    DropdownMenuItem(
                      value: 'suppliers',
                      child: Text('Proveedores'),
                    ),
                    DropdownMenuItem(
                      value: 'products',
                      child: Text('Productos'),
                    ),
                    DropdownMenuItem(
                      value: 'activities',
                      child: Text('Actividades'),
                    ),
                    DropdownMenuItem(
                      value: 'quotations',
                      child: Text('Cotizaciones'),
                    ),
                    DropdownMenuItem(value: 'assets', child: Text('Activos')),
                    DropdownMenuItem(value: 'iva', child: Text('IVA')),
                    DropdownMenuItem(
                      value: 'settings',
                      child: Text('Configuración'),
                    ),
                    DropdownMenuItem(
                      value: 'composite_products',
                      child: Text('Prod. Compuestos'),
                    ),
                    DropdownMenuItem(
                      value: 'supplier_materials',
                      child: Text('Prov-Materiales'),
                    ),
                    DropdownMenuItem(
                      value: 'material_categories',
                      child: Text('Cat. Materiales'),
                    ),
                    DropdownMenuItem(value: 'recipes', child: Text('Recetas')),
                    DropdownMenuItem(
                      value: 'accounting',
                      child: Text('Contabilidad'),
                    ),
                    DropdownMenuItem(
                      value: 'auth',
                      child: Text('Autenticación'),
                    ),
                    DropdownMenuItem(value: 'users', child: Text('Usuarios')),
                  ],
                  onChanged: (v) =>
                      ref.read(auditLogProvider.notifier).setModuleFilter(v),
                ),
              ),
              // Filtro por acción
              SizedBox(
                width: isMobile
                    ? double.infinity
                    : dropdownWidth.clamp(120.0, 160.0),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: state.filterAction,
                  decoration: InputDecoration(
                    labelText: 'Acción',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todas')),
                    DropdownMenuItem(value: 'create', child: Text('Crear')),
                    DropdownMenuItem(value: 'update', child: Text('Editar')),
                    DropdownMenuItem(value: 'delete', child: Text('Eliminar')),
                    DropdownMenuItem(value: 'approve', child: Text('Aprobar')),
                    DropdownMenuItem(value: 'cancel', child: Text('Anular')),
                    DropdownMenuItem(value: 'login', child: Text('Login')),
                  ],
                  onChanged: (v) =>
                      ref.read(auditLogProvider.notifier).setActionFilter(v),
                ),
              ),
              // Filtro por usuario
              if (state.activeUsers.isNotEmpty)
                SizedBox(
                  width: isMobile
                      ? double.infinity
                      : dropdownWidth.clamp(140.0, 220.0),
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: state.filterUserId,
                    decoration: InputDecoration(
                      labelText: 'Usuario',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos')),
                      ...state.activeUsers.map(
                        (u) => DropdownMenuItem(
                          value: u['user_id'],
                          child: Text(
                            u['user_display_name']?.isNotEmpty == true
                                ? u['user_display_name']!
                                : u['user_email'] ?? 'Sin nombre',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) =>
                        ref.read(auditLogProvider.notifier).setUserFilter(v),
                  ),
                ),
              // Rango de fechas
              ActionChip(
                avatar: const Icon(Icons.date_range, size: 18),
                label: Text(
                  state.filterFromDate != null
                      ? '${_dateOnlyFormat.format(state.filterFromDate!)} - ${state.filterToDate != null ? _dateOnlyFormat.format(state.filterToDate!) : 'Hoy'}'
                      : 'Fechas',
                ),
                onPressed: () => _selectDateRange(context),
              ),
              // Limpiar filtros
              if (state.filterModule != null ||
                  state.filterAction != null ||
                  state.filterUserId != null ||
                  state.filterFromDate != null)
                ActionChip(
                  avatar: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Limpiar'),
                  onPressed: () =>
                      ref.read(auditLogProvider.notifier).clearFilters(),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final now = ColombiaTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 7)),
        end: now,
      ),
      locale: const Locale('es', 'CO'),
    );
    if (result != null) {
      ref
          .read(auditLogProvider.notifier)
          .setDateRange(
            result.start,
            result.end.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
          );
    }
  }

  Widget _buildErrorState(BuildContext context, String error) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 64, color: colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'Error al cargar auditoría',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => ref.read(auditLogProvider.notifier).loadLogs(),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay movimientos registrados',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Los movimientos aparecerán aquí a medida que se realicen operaciones',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogList(BuildContext context, AuditLogState state) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveHelper.isMobile(context);

    // Agrupar por fecha
    final grouped = <String, List<AuditLog>>{};
    for (final log in state.logs) {
      final key = _dateOnlyFormat.format(log.createdAt.toLocal());
      grouped.putIfAbsent(key, () => []).add(log);
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 8,
      ),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final dateKey = grouped.keys.elementAt(index);
        final logsForDate = grouped[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado de fecha
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      dateKey,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${logsForDate.length} movimiento${logsForDate.length > 1 ? "s" : ""}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      indent: 8,
                      color: theme.colorScheme.outlineVariant.withAlpha(80),
                    ),
                  ),
                ],
              ),
            ),
            // Logs del día
            ...logsForDate.map((log) => _buildLogCard(context, log, isMobile)),
          ],
        );
      },
    );
  }

  Widget _buildLogCard(BuildContext context, AuditLog log, bool isMobile) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeStr = DateFormat(
      'HH:mm:ss',
      'es_CO',
    ).format(log.createdAt.toLocal());

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(60)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: log.details != null ? () => _showDetails(context, log) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Icono de acción
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _getActionColor(log.action).withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    _getActionIcon(log.action),
                    size: 18,
                    color: _getActionColor(log.action),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Contenido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Descripción
                    Text(
                      log.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Módulo + usuario + hora
                    Row(
                      children: [
                        _buildChip(
                          context,
                          log.moduleLabel,
                          _getModuleColor(log.module),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            log.employeeName ??
                                log.userDisplayName ??
                                log.userEmail ??
                                'Sistema',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (log.userRole != null) ...[
                          _buildRoleBadge(context, log.userRole!),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Hora
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                  if (log.details != null)
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildRoleBadge(BuildContext context, String role) {
    Color color;
    String label;
    switch (role) {
      case 'admin':
        color = Colors.blue;
        label = 'Admin';
        break;
      case 'dueno':
        color = Colors.purple;
        label = 'Dueño';
        break;
      case 'tecnico':
        color = Colors.amber.shade700;
        label = 'Técnico';
        break;
      case 'employee':
        color = Colors.teal;
        label = 'Empleado';
        break;
      default:
        color = Colors.grey;
        label = role;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 9,
        ),
      ),
    );
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'create':
        return Colors.green;
      case 'update':
        return Colors.blue;
      case 'delete':
        return Colors.red;
      case 'approve':
        return Colors.teal;
      case 'cancel':
        return Colors.orange;
      case 'login':
        return Colors.indigo;
      case 'logout':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'create':
        return Icons.add_circle_outline;
      case 'update':
        return Icons.edit_outlined;
      case 'delete':
        return Icons.delete_outline;
      case 'approve':
        return Icons.check_circle_outline;
      case 'cancel':
        return Icons.cancel_outlined;
      case 'print':
        return Icons.print_outlined;
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      default:
        return Icons.info_outline;
    }
  }

  Color _getModuleColor(String module) {
    switch (module) {
      case 'invoices':
        return Colors.green.shade700;
      case 'expenses':
        return Colors.red.shade700;
      case 'materials':
        return Colors.brown;
      case 'inventory':
        return Colors.orange.shade700;
      case 'cash':
        return Colors.teal.shade700;
      case 'production':
        return Colors.indigo;
      case 'customers':
        return Colors.blue.shade700;
      case 'employees':
        return Colors.purple.shade700;
      case 'quotations':
        return Colors.cyan.shade700;
      case 'assets':
        return Colors.deepOrange;
      case 'accounting':
        return Colors.blueGrey;
      case 'auth':
        return Colors.grey.shade700;
      default:
        return Colors.grey;
    }
  }

  void _showDetails(BuildContext context, AuditLog log) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getActionIcon(log.action),
              color: _getActionColor(log.action),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Detalle del movimiento',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Descripción', log.description),
                _detailRow('Módulo', log.moduleLabel),
                _detailRow('Acción', log.actionLabel),
                _detailRow(
                  'Usuario',
                  log.userDisplayName ?? log.userEmail ?? 'Sistema',
                ),
                _detailRow('Rol', log.userRole ?? 'N/A'),
                if (log.employeeName != null)
                  _detailRow('Empleado', log.employeeName!),
                if (log.employeePosition != null)
                  _detailRow('Cargo', log.employeePosition!),
                if (log.employeeDepartment != null)
                  _detailRow('Departamento', log.employeeDepartment!),
                _detailRow(
                  'Fecha y hora',
                  _dateFormat.format(log.createdAt.toLocal()),
                ),
                if (log.recordId != null)
                  _detailRow('ID Registro', log.recordId!),
                if (log.details != null) ...[
                  const Divider(),
                  Text('Datos adicionales:', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SelectableText(
                      _formatDetails(log.details!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  String _formatDetails(Map<String, dynamic> details) {
    final buffer = StringBuffer();
    for (final entry in details.entries) {
      buffer.writeln('${entry.key}: ${entry.value}');
    }
    return buffer.toString().trimRight();
  }
}
