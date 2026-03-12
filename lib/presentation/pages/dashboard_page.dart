import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/helpers.dart';
import '../../data/providers/providers.dart';
import '../../data/providers/activities_provider.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/activity.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  DateTime _selectedDate = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(customersProvider.notifier).loadCustomers();
      ref.read(productsProvider.notifier).loadProducts();
      ref.read(quotationsProvider.notifier).loadQuotations();
      ref.read(inventoryProvider.notifier).loadMaterials();
      ref.read(invoicesProvider.notifier).refresh();
      ref.read(activitiesProvider.notifier).loadActivities();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final customersState = ref.watch(customersProvider);
    final productsState = ref.watch(productsProvider);
    final invoicesState = ref.watch(invoicesProvider);
    final recentInvoices = ref.watch(recentInvoicesProvider);
    final inventoryState = ref.watch(inventoryProvider);
    
    final lowStockMaterials = inventoryState.materials
        .where((m) => m.stock <= m.minStock && m.isActive)
        .toList();
    
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(invoicesProvider.notifier).refresh();
          ref.read(inventoryProvider.notifier).loadMaterials();
          ref.read(activitiesProvider.notifier).loadActivities();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, cs, tt),
              const SizedBox(height: AppSpacing.base),
              _buildSummaryCards(context, cs, tt, invoicesState, productsState, customersState),
              const SizedBox(height: AppSpacing.base),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 980) {
                    return Column(
                      children: [
                        _buildNotificationsPanel(context, cs, tt, lowStockMaterials, invoicesState),
                        const SizedBox(height: AppSpacing.md),
                        _buildMiniCalendar(context, cs, tt),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildNotificationsPanel(context, cs, tt, lowStockMaterials, invoicesState)),
                      const SizedBox(width: AppSpacing.base),
                      Expanded(flex: 1, child: _buildMiniCalendar(context, cs, tt)),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildRecentSalesCard(context, cs, tt, invoicesState, recentInvoices),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs, TextTheme tt) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 760;
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Bienvenido!',
                    style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    isNarrow
                        ? Formatters.date(DateTime.now())
                        : Formatters.dateLong(DateTime.now()),
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            _buildStatusChip(icon: Icons.cloud_done, label: 'Conectado', color: AppColors.success),
            const SizedBox(width: AppSpacing.sm),
            CircleAvatar(
              radius: 18,
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.person, color: cs.onPrimaryContainer, size: 20),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCards(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    dynamic invoicesState, 
    dynamic productsState,
    dynamic customersState,
  ) {
    final cards = [
      _KpiData('Ventas', Formatters.currency(invoicesState.totalVentas), Icons.trending_up, AppColors.success, '${invoicesState.invoices.length} registros'),
      _KpiData('Pendiente', Formatters.currency(invoicesState.totalPendiente), Icons.schedule, AppColors.warning, '${invoicesState.countPendientes} por cobrar'),
      _KpiData('Productos', productsState.products.length.toString(), Icons.inventory_2_outlined, productsState.lowStockProducts.isNotEmpty ? AppColors.danger : AppColors.success, '${productsState.lowStockProducts.length} stock bajo'),
      _KpiData('Clientes', customersState.customers.length.toString(), Icons.people_outline, cs.primary, 'Activos'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth < 600 ? 2 : 4;
        final gap = constraints.maxWidth < 600 ? AppSpacing.sm : AppSpacing.md;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childAspectRatio: constraints.maxWidth < 600 ? 1.0 : 1.4,
          ),
          itemCount: cards.length,
          itemBuilder: (context, i) => _buildKpiCard(cs, tt, cards[i]),
        );
      },
    );
  }

  Widget _buildKpiCard(ColorScheme cs, TextTheme tt, _KpiData data) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, color: data.color, size: 22),
          ),
          const Spacer(),
          Text(
            data.title,
            style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              data.value,
              style: tt.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            data.subtitle,
            style: tt.bodySmall?.copyWith(color: data.color, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsPanel(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    List<dynamic> lowStockMaterials,
    dynamic invoicesState,
  ) {
    // Obtener actividades
    final activitiesState = ref.watch(activitiesProvider);
    
    // Crear lista de notificaciones basadas en datos reales
    final notifications = <_NotificationItem>[];
    
    // Actividades pendientes para hoy y próximos días
    final today = DateTime.now();
    final todayActivities = activitiesState.activities.where((a) {
      final activityDate = a.dueDate ?? a.startDate;
      return activityDate.year == today.year &&
             activityDate.month == today.month &&
             activityDate.day == today.day &&
             a.status != ActivityStatus.completed &&
             a.status != ActivityStatus.cancelled;
    }).take(3).toList();
    
    for (var activity in todayActivities) {
      String severity;
      switch (activity.priority) {
        case ActivityPriority.urgent:
          severity = 'error';
          break;
        case ActivityPriority.high:
          severity = 'warning';
          break;
        default:
          severity = 'info';
      }
      
      notifications.add(_NotificationItem(
        icon: activity.iconData,
        title: activity.title,
        message: activity.description ?? activity.typeLabel,
        severity: severity,
        time: 'Hoy',
        route: '/calendar',
      ));
    }
    
    // Actividades vencidas
    final overdueActivities = activitiesState.activities.where((a) {
      final dueDate = a.dueDate ?? a.startDate;
      return dueDate.isBefore(DateTime(today.year, today.month, today.day)) &&
             a.status != ActivityStatus.completed &&
             a.status != ActivityStatus.cancelled;
    }).take(2).toList();
    
    for (var activity in overdueActivities) {
      notifications.add(_NotificationItem(
        icon: Icons.warning_amber,
        title: 'Actividad Vencida: ${activity.title}',
        message: activity.typeLabel,
        severity: 'error',
        time: 'Vencida',
        route: '/calendar',
      ));
    }
    
    // Alertas de stock bajo
    for (var material in lowStockMaterials.take(3)) {
      notifications.add(_NotificationItem(
        icon: Icons.inventory_2,
        title: 'Stock Bajo: ${material.name}',
        message: 'Actual: ${material.stock.toStringAsFixed(1)} ${material.unit}, Mínimo: ${material.minStock.toStringAsFixed(1)}',
        severity: material.stock == 0 ? 'error' : 'warning',
        time: 'Ahora',
        route: '/materials',
      ));
    }
    
    // Facturas vencidas
    final overdueInvoices = invoicesState.invoices
        .where((i) => i.status == InvoiceStatus.overdue || 
                      (i.status != InvoiceStatus.paid && 
                       i.status != InvoiceStatus.cancelled &&
                       i.dueDate != null && 
                       i.dueDate!.isBefore(DateTime.now())))
        .take(3)
        .toList();
    
    for (var invoice in overdueInvoices) {
      notifications.add(_NotificationItem(
        icon: Icons.receipt_long,
        title: 'Recibo Vencido: ${invoice.fullNumber}',
        message: 'Cliente: ${invoice.customerName}, Pendiente: ${Formatters.currency(invoice.pendingAmount)}',
        severity: 'error',
        time: 'Vencida',
        route: '/invoices',
      ));
    }
    
    // Si no hay notificaciones, mostrar mensaje
    if (notifications.isEmpty) {
      notifications.add(_NotificationItem(
        icon: Icons.check_circle,
        title: '¡Todo en orden!',
        message: 'No hay alertas pendientes',
        severity: 'success',
        time: 'Ahora',
      ));
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.notifications_active, color: AppColors.warning, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Notificaciones',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (notifications.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${notifications.length}',
                    style: tt.labelSmall?.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: AppSpacing.md),
          ...notifications.map((n) => _buildNotificationTile(context, cs, tt, n)),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(BuildContext context, ColorScheme cs, TextTheme tt, _NotificationItem notification) {
    Color severityColor;
    switch (notification.severity) {
      case 'error':
        severityColor = AppColors.danger;
        break;
      case 'warning':
        severityColor = AppColors.warning;
        break;
      case 'success':
        severityColor = AppColors.success;
        break;
      default:
        severityColor = AppColors.info;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: notification.route != null 
            ? () => context.go(notification.route!) 
            : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(notification.icon, color: severityColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.message,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                notification.time,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              if (notification.route != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniCalendar(BuildContext context, ColorScheme cs, TextTheme tt) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final firstWeekday = firstDayOfMonth.weekday;
    
    final activitiesState = ref.watch(activitiesProvider);
    
    bool hasActivitiesOnDay(int day) {
      final date = DateTime(now.year, now.month, day);
      return activitiesState.activities.any((a) {
        final activityDate = a.dueDate ?? a.startDate;
        return activityDate.year == date.year &&
               activityDate.month == date.month &&
               activityDate.day == date.day;
      });
    }
    
    final selectedDayActivities = activitiesState.getActivitiesForDay(_selectedDate);
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.calendar_month, color: cs.onPrimaryContainer, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        DateFormat('MMMM yyyy', 'es').format(now),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 18),
                onPressed: () => context.go('/calendar'),
                tooltip: 'Ver calendario completo',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['L', 'M', 'X', 'J', 'V', 'S', 'D']
                .map((d) => SizedBox(
                      width: 28,
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 0.85,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final dayOffset = index - (firstWeekday - 1);
              if (dayOffset < 1 || dayOffset > daysInMonth) {
                return const SizedBox();
              }
              
              final isToday = dayOffset == now.day;
              final isSelected = dayOffset == _selectedDate.day && 
                                 now.month == _selectedDate.month;
              final hasActivities = hasActivitiesOnDay(dayOffset);
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = DateTime(now.year, now.month, dayOffset);
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isToday 
                        ? cs.primary 
                        : isSelected 
                            ? cs.primary.withOpacity(0.12)
                            : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayOffset',
                        style: tt.bodySmall?.copyWith(
                          color: isToday 
                              ? cs.onPrimary 
                              : isSelected 
                                  ? cs.primary 
                                  : cs.onSurface,
                          fontWeight: isToday || isSelected 
                              ? FontWeight.bold 
                              : FontWeight.normal,
                        ),
                      ),
                      if (hasActivities)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isToday ? cs.onPrimary : cs.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: AppSpacing.md),
          
          Text(
            'Actividades del ${_selectedDate.day}/${_selectedDate.month}',
            style: tt.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          
          if (selectedDayActivities.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_available, color: cs.onSurfaceVariant, size: 18),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Sin actividades programadas',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            ...selectedDayActivities.take(2).map((activity) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: GestureDetector(
                onTap: () => context.go('/calendar'),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: activity.colorValue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: activity.colorValue.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 24,
                        decoration: BoxDecoration(
                          color: activity.colorValue,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.title,
                              style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              activity.typeLabel,
                              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 14, color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            )),
          
          if (selectedDayActivities.length > 2)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: () => context.go('/calendar'),
                child: Text(
                  '+${selectedDayActivities.length - 2} más...',
                  style: tt.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentSalesCard(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    dynamic invoicesState,
    List<Invoice> recentInvoices,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.receipt_long, color: AppColors.success, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Últimas Ventas',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => context.go('/invoices'),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Ver todas'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          if (invoicesState.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (recentInvoices.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'No hay ventas registradas',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            ...recentInvoices.take(5).map((invoice) => 
              _buildInvoiceRow(
                cs, tt,
                '${invoice.series}-${invoice.number}',
                invoice.customerName,
                invoice.total,
                _getStatusLabel(invoice.status),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return 'Borrador';
      case InvoiceStatus.issued:
        return 'Pendiente';
      case InvoiceStatus.paid:
        return 'Pagado';
      case InvoiceStatus.partial:
        return 'Parcial';
      case InvoiceStatus.cancelled:
        return 'Cancelada';
      case InvoiceStatus.overdue:
        return 'Vencida';
    }
  }

  Widget _buildInvoiceRow(ColorScheme cs, TextTheme tt, String number, String customer, double amount, String status) {
    Color statusColor;
    switch (status) {
      case 'Pagado':
        statusColor = AppColors.success;
        break;
      case 'Pendiente':
        statusColor = AppColors.warning;
        break;
      case 'Parcial':
        statusColor = AppColors.info;
        break;
      case 'Vencida':
        statusColor = AppColors.danger;
        break;
      default:
        statusColor = cs.onSurfaceVariant;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              number,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Text(
              customer,
              overflow: TextOverflow.ellipsis,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: AppSpacing.base),
          SizedBox(
            width: 120,
            child: Text(
              Formatters.currency(amount),
              textAlign: TextAlign.right,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: AppSpacing.base),
          SizedBox(
            width: 90,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                textAlign: TextAlign.center,
                style: tt.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationItem {
  final IconData icon;
  final String title;
  final String message;
  final String severity;
  final String time;
  final String? route;

  _NotificationItem({
    required this.icon,
    required this.title,
    required this.message,
    required this.severity,
    required this.time,
    this.route,
  });
}

class _KpiData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _KpiData(this.title, this.value, this.icon, this.color, this.subtitle);
}
