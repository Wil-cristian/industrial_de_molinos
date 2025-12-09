import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../data/providers/providers.dart';

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final customersState = ref.watch(customersProvider);
    final productsState = ref.watch(productsProvider);
    final quotationsState = ref.watch(quotationsProvider);
    
    return Scaffold(
      body: Row(
        children: [
          // Navigation Rail (Menú lateral)
          NavigationRail(
            selectedIndex: 0,
            onDestinationSelected: (index) {
              switch (index) {
                case 0:
                  context.go('/');
                  break;
                case 1:
                  context.go('/products');
                  break;
                case 2:
                  context.go('/customers');
                  break;
                case 3:
                  context.go('/invoices');
                  break;
                case 4:
                  context.go('/quotations');
                  break;
                case 5:
                  context.go('/reports');
                  break;
                case 6:
                  context.go('/settings');
                  break;
              }
            },
            labelType: NavigationRailLabelType.all,
            leading: Padding(
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
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Inicio'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: Text('Productos'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Clientes'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: Text('Ventas'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.request_quote_outlined),
                selectedIcon: Icon(Icons.request_quote),
                label: Text('Cotizar'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: Text('Reportes'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Config'),
              ),
            ],
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
                            title: 'Cotizaciones',
                            value: quotationsState.totalQuotations.toString(),
                            icon: Icons.request_quote,
                            color: AppTheme.primaryColor,
                            subtitle: '${quotationsState.approvedCount} aprobadas',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSummaryCard(
                            context,
                            title: 'Cotizaciones Pendientes',
                            value: '${quotationsState.draftCount + quotationsState.sentCount}',
                            icon: Icons.pending_actions,
                            color: AppTheme.warningColor,
                            subtitle: Formatters.currency(quotationsState.totalApprovedAmount),
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
                                  _buildInvoiceRow('F001-00045', 'Juan Pérez', 1250.00, 'Pagado'),
                                  _buildInvoiceRow('F001-00044', 'María García', 890.50, 'Pendiente'),
                                  _buildInvoiceRow('F001-00043', 'Carlos López', 2100.00, 'Pagado'),
                                  _buildInvoiceRow('F001-00042', 'Ana Torres', 450.00, 'Parcial'),
                                  _buildInvoiceRow('F001-00041', 'Pedro Ruiz', 3200.00, 'Pagado'),
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
      default:
        statusColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              number,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(customer),
          ),
          Expanded(
            flex: 2,
            child: Text(
              Formatters.currency(amount),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
