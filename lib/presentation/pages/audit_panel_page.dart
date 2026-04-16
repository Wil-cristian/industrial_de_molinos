import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/responsive/responsive_helper.dart';
import '../../domain/entities/audit_log.dart';
import '../../data/providers/audit_log_provider.dart';
import '../../core/utils/colombia_time.dart';
import '../widgets/screen_permissions_manager.dart';

/// Página de Panel de Auditoría — Movimientos del sistema
/// Muestra quién hizo qué y cuándo
class AuditPanelPage extends ConsumerStatefulWidget {
  const AuditPanelPage({super.key});

  @override
  ConsumerState<AuditPanelPage> createState() => _AuditPanelPageState();
}

class _AuditPanelPageState extends ConsumerState<AuditPanelPage>
    with SingleTickerProviderStateMixin {
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'es_CO');
  final _dateOnlyFormat = DateFormat('dd/MM/yyyy', 'es_CO');
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(auditLogProvider.notifier).loadLogs();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
              _buildMainHeader(context),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Auditoría (logs)
                    Column(
                      children: [
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
                    // Tab 2: Permisos de pantalla
                    const ScreenPermissionsManager(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                Icon(Icons.security, color: colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Panel de Auditoría',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.list_alt), text: 'Movimientos'),
              Tab(icon: Icon(Icons.admin_panel_settings), text: 'Permisos'),
            ],
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
                    // Inline detail preview
                    if (log.details != null) ...[
                      const SizedBox(height: 3),
                      _buildInlinePreview(context, log),
                    ],
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

  /// Muestra mini-badges con info clave inline en la tarjeta
  Widget _buildInlinePreview(BuildContext context, AuditLog log) {
    final details = log.details!;
    final chips = <Widget>[];

    // Monto
    final amount = details['amount'] ?? details['payment_amount'] ?? details['total'];
    if (amount != null) {
      final isIncome = details['type'] == 'income' || details.containsKey('payment_amount');
      chips.add(_buildMiniChip(
        context,
        _formatCurrency(amount),
        isIncome ? Colors.green.shade700 : Colors.orange.shade800,
        icon: Icons.attach_money,
      ));
    }

    // Cuenta
    final accountName = details['account_name'] ?? details['from_account_name'];
    if (accountName != null) {
      final toName = details['to_account_name'];
      chips.add(_buildMiniChip(
        context,
        toName != null ? '$accountName → $toName' : accountName.toString(),
        Colors.teal.shade700,
        icon: toName != null ? Icons.swap_horiz : Icons.account_balance,
      ));
    }

    // Cliente 
    final customer = details['customer'];
    if (customer != null && customer.toString().isNotEmpty) {
      chips.add(_buildMiniChip(
        context,
        customer.toString(),
        Colors.blue.shade700,
        icon: Icons.person,
      ));
    }

    // Factura
    final invoiceNum = details['invoice_number'] ?? (details['series'] != null ? '${details['series']}-${details['number']}' : null);
    if (invoiceNum != null) {
      chips.add(_buildMiniChip(
        context,
        invoiceNum.toString(),
        Colors.indigo,
        icon: Icons.receipt,
      ));
    }

    // Estado
    if (details['new_status'] != null) {
      chips.add(_buildMiniChip(
        context,
        _statusName(details['new_status'].toString()),
        Colors.blue,
        icon: Icons.flag,
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: chips,
    );
  }

  Widget _buildMiniChip(BuildContext context, String text, Color color,
      {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 2),
          ],
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 9,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
    final colorScheme = theme.colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getActionColor(log.action).withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  _getActionIcon(log.action),
                  color: _getActionColor(log.action),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detalle del movimiento',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _dateFormat.format(log.createdAt.toLocal()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Descripción principal
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withAlpha(40),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.primaryContainer.withAlpha(80),
                    ),
                  ),
                  child: Text(
                    log.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Información del usuario
                _buildDetailSection(
                  context,
                  icon: Icons.person,
                  title: 'Quién',
                  children: [
                    _detailRow2(context, 'Usuario',
                        log.userDisplayName ?? log.userEmail ?? 'Sistema'),
                    if (log.userRole != null)
                      _detailRow2(context, 'Rol', _roleName(log.userRole!)),
                    if (log.employeeName != null)
                      _detailRow2(context, 'Empleado', log.employeeName!),
                    if (log.employeePosition != null)
                      _detailRow2(context, 'Cargo', log.employeePosition!),
                    if (log.employeeDepartment != null)
                      _detailRow2(
                          context, 'Departamento', log.employeeDepartment!),
                  ],
                ),

                // Información contextual
                _buildDetailSection(
                  context,
                  icon: Icons.info_outline,
                  title: 'Qué',
                  children: [
                    _detailRow2(context, 'Módulo', log.moduleLabel),
                    _detailRow2(context, 'Acción', log.actionLabel),
                    _detailRow2(context, 'Hora',
                        DateFormat('hh:mm:ss a', 'es_CO').format(log.createdAt.toLocal())),
                    if (log.recordId != null)
                      _detailRow2(context, 'ID Registro', log.recordId!),
                  ],
                ),

                // Detalles específicos del módulo (MEJORADO)
                if (log.details != null) ...[
                  _buildSmartDetails(context, log),
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

  /// Construye los detalles específicos según el módulo y acción
  Widget _buildSmartDetails(BuildContext context, AuditLog log) {
    final details = log.details!;
    final module = log.module;

    // Detectar tipo de movimiento y mostrar info relevante
    if (module == 'cash' && details.containsKey('from_account_name')) {
      return _buildTransferDetails(context, details);
    } else if (module == 'cash') {
      return _buildCashMovementDetails(context, details);
    } else if (module == 'invoices' && details.containsKey('payment_amount')) {
      return _buildPaymentDetails(context, details);
    } else if (module == 'invoices' && details.containsKey('new_status')) {
      return _buildStatusChangeDetails(context, details);
    } else if (module == 'invoices' && details.containsKey('customer')) {
      return _buildInvoiceCreateDetails(context, details);
    } else if (module == 'invoices' && details.containsKey('product')) {
      return _buildInvoiceItemDetails(context, details);
    } else if (module == 'production') {
      return _buildProductionDetails(context, details);
    } else if (module == 'customers') {
      return _buildCustomerDetails(context, details);
    } else {
      return _buildGenericDetails(context, details);
    }
  }

  /// Traslado entre cuentas
  Widget _buildTransferDetails(
      BuildContext context, Map<String, dynamic> details) {
    final amount = details['amount'];
    return _buildDetailSection(
      context,
      icon: Icons.swap_horiz,
      title: 'Traslado',
      color: Colors.teal,
      children: [
        _buildTransferArrow(
          context,
          from: details['from_account_name']?.toString() ?? 'Cuenta origen',
          to: details['to_account_name']?.toString() ?? 'Cuenta destino',
        ),
        if (amount != null)
          _detailRow2(context, 'Monto', _formatCurrency(amount)),
        if (details['description'] != null)
          _detailRow2(context, 'Descripción', details['description'].toString()),
      ],
    );
  }

  /// Movimiento de caja (ingreso/egreso)
  Widget _buildCashMovementDetails(
      BuildContext context, Map<String, dynamic> details) {
    final type = details['type']?.toString() ?? '';
    final isIncome = type == 'income';
    return _buildDetailSection(
      context,
      icon: isIncome ? Icons.arrow_downward : Icons.arrow_upward,
      title: isIncome ? 'Ingreso' : 'Egreso',
      color: isIncome ? Colors.green : Colors.red,
      children: [
        if (details['amount'] != null)
          _detailRow2(context, 'Monto', _formatCurrency(details['amount'])),
        if (details['account_name'] != null)
          _detailRow2(context, 'Cuenta', details['account_name'].toString()),
        if (details['category'] != null)
          _detailRow2(context, 'Categoría', _categoryName(details['category'].toString())),
        if (details['person_name'] != null)
          _detailRow2(context, 'Persona', details['person_name'].toString()),
        if (details['description'] != null)
          _detailRow2(context, 'Descripción', details['description'].toString()),
      ],
    );
  }

  /// Pago/Abono a factura
  Widget _buildPaymentDetails(
      BuildContext context, Map<String, dynamic> details) {
    return _buildDetailSection(
      context,
      icon: Icons.payments,
      title: 'Pago / Abono',
      color: Colors.green.shade700,
      children: [
        if (details['customer'] != null)
          _detailRow2(context, 'Cliente', details['customer'].toString()),
        if (details['invoice_number'] != null)
          _detailRow2(context, 'Factura', details['invoice_number'].toString()),
        if (details['payment_amount'] != null)
          _detailRow2(
              context, 'Monto pagado', _formatCurrency(details['payment_amount'])),
        if (details['payment_method'] != null)
          _detailRow2(
              context, 'Método', _paymentMethodName(details['payment_method'].toString())),
        if (details['invoice_total'] != null)
          _detailRow2(
              context, 'Total factura', _formatCurrency(details['invoice_total'])),
        if (details['previously_paid'] != null)
          _detailRow2(
              context, 'Pagado antes', _formatCurrency(details['previously_paid'])),
        if (details['new_paid_amount'] != null)
          _detailRow2(context, 'Total pagado ahora',
              _formatCurrency(details['new_paid_amount'])),
        if (details['remaining'] != null)
          _detailRow2(context, 'Pendiente', _formatCurrency(details['remaining']),
              highlight: (details['remaining'] as num) > 0),
        if (details['new_status'] != null)
          _detailRow2(
              context, 'Nuevo estado', _statusName(details['new_status'].toString())),
        if (details['reference'] != null)
          _detailRow2(context, 'Referencia', details['reference'].toString()),
        if (details['notes'] != null)
          _detailRow2(context, 'Notas', details['notes'].toString()),
      ],
    );
  }

  /// Cambio de estado de factura
  Widget _buildStatusChangeDetails(
      BuildContext context, Map<String, dynamic> details) {
    return _buildDetailSection(
      context,
      icon: Icons.swap_vert,
      title: 'Cambio de Estado',
      color: Colors.blue,
      children: [
        if (details['invoice_number'] != null)
          _detailRow2(context, 'Factura', details['invoice_number'].toString()),
        if (details['customer'] != null)
          _detailRow2(context, 'Cliente', details['customer'].toString()),
        _buildStatusTransition(
          context,
          from: _statusName(details['previous_status']?.toString() ?? ''),
          to: _statusName(details['new_status']?.toString() ?? ''),
        ),
        if (details['total'] != null)
          _detailRow2(context, 'Total', _formatCurrency(details['total'])),
        if (details['paid_amount'] != null && (details['paid_amount'] as num) > 0)
          _detailRow2(
              context, 'Pagado', _formatCurrency(details['paid_amount'])),
      ],
    );
  }

  /// Creación de factura
  Widget _buildInvoiceCreateDetails(
      BuildContext context, Map<String, dynamic> details) {
    return _buildDetailSection(
      context,
      icon: Icons.receipt_long,
      title: 'Factura',
      color: Colors.green.shade700,
      children: [
        if (details['number'] != null)
          _detailRow2(context, 'Número',
              '${details['series'] ?? ''}${details['series'] != null ? '-' : ''}${details['number']}'),
        if (details['customer'] != null)
          _detailRow2(context, 'Cliente', details['customer'].toString()),
        if (details['total'] != null)
          _detailRow2(context, 'Total', _formatCurrency(details['total'])),
      ],
    );
  }

  /// Ítem de factura
  Widget _buildInvoiceItemDetails(
      BuildContext context, Map<String, dynamic> details) {
    return _buildDetailSection(
      context,
      icon: Icons.inventory_2,
      title: 'Ítem',
      color: Colors.orange.shade700,
      children: [
        if (details['product'] != null)
          _detailRow2(context, 'Producto', details['product'].toString()),
        if (details['quantity'] != null)
          _detailRow2(context, 'Cantidad', details['quantity'].toString()),
        if (details['unit_price'] != null)
          _detailRow2(
              context, 'Precio unit.', _formatCurrency(details['unit_price'])),
        if (details['total'] != null)
          _detailRow2(context, 'Total', _formatCurrency(details['total'])),
      ],
    );
  }

  /// Orden de producción
  Widget _buildProductionDetails(
      BuildContext context, Map<String, dynamic> details) {
    return _buildDetailSection(
      context,
      icon: Icons.precision_manufacturing,
      title: 'Producción',
      color: Colors.indigo,
      children: [
        if (details['code'] != null)
          _detailRow2(context, 'Código', details['code'].toString()),
        if (details['invoice_number'] != null)
          _detailRow2(context, 'Factura', details['invoice_number'].toString()),
        if (details['product'] != null)
          _detailRow2(context, 'Producto', details['product'].toString()),
        if (details['stages'] != null)
          _detailRow2(
              context,
              'Etapas',
              details['stages'] is List
                  ? (details['stages'] as List).join(', ')
                  : details['stages'].toString()),
      ],
    );
  }

  /// Cliente
  Widget _buildCustomerDetails(
      BuildContext context, Map<String, dynamic> details) {
    return _buildDetailSection(
      context,
      icon: Icons.person_add,
      title: 'Cliente',
      color: Colors.blue.shade700,
      children: [
        if (details['name'] != null)
          _detailRow2(context, 'Nombre', details['name'].toString()),
        if (details['document'] != null)
          _detailRow2(context, 'Documento', details['document'].toString()),
      ],
    );
  }

  /// Detalles genéricos para módulos no reconocidos
  Widget _buildGenericDetails(
      BuildContext context, Map<String, dynamic> details) {
    return _buildDetailSection(
      context,
      icon: Icons.data_object,
      title: 'Datos adicionales',
      children: details.entries
          .map((e) => _detailRow2(
              context,
              _humanizeKey(e.key),
              e.value is num
                  ? _formatCurrency(e.value)
                  : e.value?.toString() ?? 'N/A'))
          .toList(),
    );
  }

  // ==================== UI HELPERS ====================

  Widget _buildDetailSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sectionColor = color ?? colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: sectionColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: sectionColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(
                  color: sectionColor.withAlpha(40),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: sectionColor.withAlpha(8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: sectionColor.withAlpha(25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow2(BuildContext context, String label, String value,
      {bool highlight = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                color: highlight ? Colors.red.shade700 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferArrow(BuildContext context,
      {required String from, required String to}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('De:', style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  )),
                  Text(from, style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward, color: Colors.teal.shade700, size: 24),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('A:', style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  )),
                  Text(to, style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTransition(BuildContext context,
      {required String from, required String to}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(from, style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            )),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward, size: 18, color: Colors.blue),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(to, style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade700,
            )),
          ),
        ],
      ),
    );
  }

  // ==================== FORMATTERS ====================

  String _formatCurrency(dynamic value) {
    if (value == null) return '\$0';
    final num amount = value is num ? value : double.tryParse(value.toString()) ?? 0;
    final formatted = NumberFormat('#,###', 'es_CO').format(amount.round());
    return '\$$formatted';
  }

  String _statusName(String status) {
    switch (status) {
      case 'draft':
        return 'Borrador';
      case 'issued':
        return 'Emitido';
      case 'partial':
        return 'Parcial';
      case 'paid':
        return 'Pagado';
      case 'cancelled':
        return 'Anulado';
      case 'overdue':
        return 'Vencido';
      default:
        return status;
    }
  }

  String _roleName(String role) {
    switch (role) {
      case 'admin':
        return 'Administrador';
      case 'dueno':
        return 'Dueño';
      case 'tecnico':
        return 'Técnico';
      case 'employee':
        return 'Empleado';
      default:
        return role;
    }
  }

  String _paymentMethodName(String method) {
    switch (method) {
      case 'cash':
        return 'Efectivo';
      case 'transfer':
        return 'Transferencia';
      case 'card':
        return 'Tarjeta';
      case 'check':
        return 'Cheque';
      case 'nequi':
        return 'Nequi';
      case 'daviplata':
        return 'Daviplata';
      default:
        return method;
    }
  }

  String _categoryName(String category) {
    switch (category) {
      case 'sale':
        return 'Venta';
      case 'collection':
        return 'Cobro';
      case 'purchase':
        return 'Compra';
      case 'payroll':
        return 'Nómina';
      case 'loan':
        return 'Préstamo';
      case 'transferIn':
        return 'Traslado entrada';
      case 'transferOut':
        return 'Traslado salida';
      case 'custom':
        return 'Personalizado';
      default:
        return category;
    }
  }

  String _humanizeKey(String key) {
    return key
        .replaceAll('_', ' ')
        .replaceFirst(key[0], key[0].toUpperCase());
  }
}
