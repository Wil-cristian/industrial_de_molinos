import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/providers/providers.dart';
import '../../data/providers/activities_provider.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/activity.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/quick_actions_button.dart';

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
    // Cargar datos al iniciar
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
    final customersState = ref.watch(customersProvider);
    final productsState = ref.watch(productsProvider);
    final invoicesState = ref.watch(invoicesProvider);
    final recentInvoices = ref.watch(recentInvoicesProvider);
    final inventoryState = ref.watch(inventoryProvider);
    
    // Calcular alertas de stock bajo
    final lowStockMaterials = inventoryState.materials
        .where((m) => m.stock <= m.minStock && m.isActive)
        .toList();
    
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              // Sidebar con navegación
              const AppSidebar(currentRoute: '/'),
              
              // Contenido principal
              Expanded(
                child: Container(
                  color: AppTheme.backgroundColor,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        _buildHeader(context),
                        const SizedBox(height: 24),

                        // Cards de resumen
                        _buildSummaryCards(context, invoicesState, productsState, customersState),
                        const SizedBox(height: 24),

                        // Notificaciones y Mini Calendario
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Panel de Notificaciones
                            Expanded(
                              flex: 2,
                              child: _buildNotificationsPanel(
                                context, 
                                lowStockMaterials, 
                                invoicesState,
                              ),
                            ),
                            const SizedBox(width: 16),
                            
                            // Mini Calendario
                            Expanded(
                              flex: 1,
                              child: _buildMiniCalendar(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Últimas ventas
                        _buildRecentSalesCard(context, invoicesState, recentInvoices),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Botón de acciones rápidas
          const QuickActionsButton(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¡Bienvenido!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              Formatters.dateLong(DateTime.now()),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        Row(
          children: [
            _buildStatusChip(
              icon: Icons.cloud_done,
              label: 'Conectado a Supabase',
              color: AppTheme.successColor,
            ),
            const SizedBox(width: 16),
            CircleAvatar(
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.person, color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards(
    BuildContext context, 
    dynamic invoicesState, 
    dynamic productsState,
    dynamic customersState,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            context,
            title: 'Ventas del Mes',
            value: Formatters.currency(invoicesState.totalVentas),
            icon: Icons.attach_money,
            color: AppTheme.successColor,
            subtitle: '${invoicesState.invoices.length} recibos',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            context,
            title: 'Pendiente de Cobro',
            value: Formatters.currency(invoicesState.totalPendiente),
            icon: Icons.pending_actions,
            color: AppTheme.warningColor,
            subtitle: '${invoicesState.countPendientes} recibos',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            context,
            title: 'Productos',
            value: productsState.products.length.toString(),
            icon: Icons.inventory_2,
            color: productsState.lowStockProducts.isNotEmpty 
                ? AppTheme.errorColor 
                : AppTheme.successColor,
            subtitle: '${productsState.lowStockProducts.length} stock bajo',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            context,
            title: 'Clientes Activos',
            value: customersState.customers.length.toString(),
            icon: Icons.people,
            color: AppTheme.accentColor,
            subtitle: 'En la base de datos',
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationsPanel(
    BuildContext context, 
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
        title: 'Factura Vencida: ${invoice.fullNumber}',
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.notifications_active, color: Colors.orange[600], size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Notificaciones',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (notifications.length > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${notifications.length}',
                    style: TextStyle(
                      color: Colors.red[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 8),
          ...notifications.map((n) => _buildNotificationTile(context, n)),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(BuildContext context, _NotificationItem notification) {
    Color severityColor;
    switch (notification.severity) {
      case 'error':
        severityColor = Colors.red;
        break;
      case 'warning':
        severityColor = Colors.orange;
        break;
      case 'success':
        severityColor = Colors.green;
        break;
      default:
        severityColor = Colors.blue;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: notification.route != null 
            ? () => context.go(notification.route!) 
            : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(notification.icon, color: severityColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                notification.time,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11,
                ),
              ),
              if (notification.route != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniCalendar(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final firstWeekday = firstDayOfMonth.weekday;
    
    // Obtener actividades
    final activitiesState = ref.watch(activitiesProvider);
    
    // Helper para verificar si un día tiene actividades
    bool hasActivitiesOnDay(int day) {
      final date = DateTime(now.year, now.month, day);
      return activitiesState.activities.any((a) {
        final activityDate = a.dueDate ?? a.startDate;
        return activityDate.year == date.year &&
               activityDate.month == date.month &&
               activityDate.day == date.day;
      });
    }
    
    // Obtener actividades del día seleccionado
    final selectedDayActivities = activitiesState.getActivitiesForDay(_selectedDate);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.calendar_month, color: Colors.indigo[600], size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('MMMM yyyy', 'es').format(now),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              // Botón para ir al calendario completo
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 18),
                onPressed: () => context.go('/calendar'),
                tooltip: 'Ver calendario completo',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Días de la semana
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['L', 'M', 'X', 'J', 'V', 'S', 'D']
                .map((d) => SizedBox(
                      width: 28,
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          
          // Días del mes
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
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
                        ? AppTheme.primaryColor 
                        : isSelected 
                            ? AppTheme.primaryColor.withOpacity(0.1)
                            : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayOffset',
                        style: TextStyle(
                          color: isToday 
                              ? Colors.white 
                              : isSelected 
                                  ? AppTheme.primaryColor 
                                  : Colors.grey[700],
                          fontSize: 12,
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
                            color: isToday ? Colors.white : AppTheme.primaryColor,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          
          // Actividades del día seleccionado
          Text(
            'Actividades del ${_selectedDate.day}/${_selectedDate.month}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          
          if (selectedDayActivities.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_available, color: Colors.grey[400], size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Sin actividades programadas',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            ...selectedDayActivities.take(3).map((activity) => Padding(
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              activity.typeLabel,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: activity.statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          activity.statusLabel,
                          style: TextStyle(
                            fontSize: 9,
                            color: activity.statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )),
          
          if (selectedDayActivities.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: () => context.go('/calendar'),
                child: Text(
                  '+${selectedDayActivities.length - 3} más...',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 11,
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
    dynamic invoicesState,
    List<Invoice> recentInvoices,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.receipt_long, color: Colors.green[600], size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Últimas Ventas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
            const SizedBox(height: 16),
            if (invoicesState.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (recentInvoices.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No hay ventas registradas'),
                ),
              )
            else
              ...recentInvoices.take(5).map((invoice) => 
                _buildInvoiceRow(
                  '${invoice.series}-${invoice.number}',
                  invoice.customerName,
                  invoice.total,
                  _getStatusLabel(invoice.status),
                ),
              ),
          ],
        ),
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

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                Icon(Icons.more_vert, color: Colors.grey[400]),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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

  Widget _buildInvoiceRow(String number, String customer, double amount, String status) {
    Color statusColor;
    switch (status) {
      case 'Pagado':
        statusColor = AppTheme.successColor;
        break;
      case 'Pendiente':
        statusColor = AppTheme.warningColor;
        break;
      case 'Parcial':
        statusColor = AppTheme.accentColor;
        break;
      case 'Vencida':
        statusColor = AppTheme.errorColor;
        break;
      case 'Borrador':
        statusColor = Colors.grey;
        break;
      case 'Cancelada':
        statusColor = Colors.grey[600]!;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              number,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              customer,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 120,
            child: Text(
              Formatters.currency(amount),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 90,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
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
