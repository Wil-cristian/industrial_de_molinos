import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/providers/providers.dart';
import '../../domain/entities/invoice.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  void initState() {
    super.initState();
    // Cargar datos al iniciar
    Future.microtask(() {
      ref.read(customersProvider.notifier).loadCustomers();
      ref.read(productsProvider.notifier).loadProducts();
      ref.read(quotationsProvider.notifier).loadQuotations();
      ref.read(materialsProvider.notifier).loadMaterials();
      ref.read(invoicesProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final customersState = ref.watch(customersProvider);
    final productsState = ref.watch(productsProvider);
    // final quotationsState = ref.watch(quotationsProvider);  // TODO: Usar cuando se integre
    final invoicesState = ref.watch(invoicesProvider);
    final recentInvoices = ref.watch(recentInvoicesProvider);
    
    return Scaffold(
      body: Row(
        children: [
          // Navigation Rail (Menú lateral) - Scrollable
          Container(
            width: 80,
            color: AppTheme.primaryColor,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.factory,
                          color: AppTheme.primaryColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Molinos',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _NavItem(
                          icon: Icons.dashboard,
                          label: 'Inicio',
                          onTap: () => context.go('/'),
                        ),
                        _NavItem(
                          icon: Icons.inventory_2,
                          label: 'Productos',
                          onTap: () => context.go('/products'),
                        ),
                        _NavItem(
                          icon: Icons.people,
                          label: 'Clientes',
                          onTap: () => context.go('/customers'),
                        ),
                        _NavItem(
                          icon: Icons.receipt_long,
                          label: 'Ventas',
                          onTap: () => context.go('/invoices'),
                        ),
                        _NavItem(
                          icon: Icons.request_quote,
                          label: 'Cotizar',
                          onTap: () => context.go('/quotations'),
                        ),
                        _NavItem(
                          icon: Icons.bar_chart,
                          label: 'Reportes',
                          onTap: () => context.go('/reports'),
                        ),
                        _NavItem(
                          icon: Icons.settings,
                          label: 'Config',
                          onTap: () => context.go('/settings'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
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
                    Row(
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
                    ),
                    const SizedBox(height: 32),

                    // Cards de resumen
                    Row(
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
                    ),
                    const SizedBox(height: 32),

                    // Sección de acciones rápidas y últimas ventas
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Acciones rápidas
                        Expanded(
                          flex: 1,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Acciones Rápidas',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildQuickAction(
                                    context,
                                    icon: Icons.add_shopping_cart,
                                    label: 'Nueva Venta',
                                    onTap: () => context.go('/invoices/new'),
                                  ),
                                  _buildQuickAction(
                                    context,
                                    icon: Icons.request_quote,
                                    label: 'Nueva Cotización',
                                    onTap: () => context.go('/quotations/new'),
                                  ),
                                  _buildQuickAction(
                                    context,
                                    icon: Icons.person_add,
                                    label: 'Nuevo Cliente',
                                    onTap: () => context.go('/customers/new'),
                                  ),
                                  _buildQuickAction(
                                    context,
                                    icon: Icons.add_box,
                                    label: 'Nuevo Producto',
                                    onTap: () => context.go('/products/new'),
                                  ),
                                  const Divider(height: 24),
                                  _buildQuickAction(
                                    context,
                                    icon: Icons.inventory_2,
                                    label: 'Materiales (Inventario)',
                                    onTap: () => context.go('/materials'),
                                  ),
                                  _buildQuickAction(
                                    context,
                                    icon: Icons.precision_manufacturing,
                                    label: 'Productos Compuestos',
                                    onTap: () => context.go('/composite-products'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Últimas ventas
                        Expanded(
                          flex: 2,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Últimas Ventas',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => context.go('/invoices'),
                                        child: const Text('Ver todas'),
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
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.primaryColor, size: 20),
      ),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
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
          // Número de recibo - ancho fijo
          SizedBox(
            width: 130,
            child: Text(
              number,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          // Cliente - expandido
          Expanded(
            child: Text(
              customer,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          // Monto - ancho fijo alineado a la derecha
          SizedBox(
            width: 120,
            child: Text(
              Formatters.currency(amount),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          // Estado - ancho fijo
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

// Widget personalizado para items del menú navegación
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 64,
            height: 70,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
