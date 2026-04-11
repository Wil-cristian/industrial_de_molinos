import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/permissions/screen_permissions.dart';

/// Widget que contiene el sidebar con su indicador de selección
/// Usar dentro de un Stack para que el indicador se vea por encima del contenido
class AppSidebar extends ConsumerStatefulWidget {
  final String currentRoute;

  const AppSidebar({super.key, required this.currentRoute});

  @override
  ConsumerState<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends ConsumerState<AppSidebar> {
  // Altura fija para cada item de navegación
  static const double _itemHeight = 48.0;
  static const double _logoHeight = 52.0;

  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  final List<NavItemData> _allNavItems = [
    NavItemData(
      icon: Icons.account_balance_wallet,
      label: 'Caja',
      route: '/daily-cash',
      screenKey: AppScreen.dailyCash,
    ),
    NavItemData(
      icon: Icons.shopping_bag,
      label: 'Compras',
      route: '/expenses',
      screenKey: AppScreen.expenses,
    ),
    NavItemData(
      icon: Icons.layers,
      label: 'Productos',
      route: '/composite-products',
      screenKey: AppScreen.compositeProducts,
    ),
    NavItemData(
      icon: Icons.factory,
      label: 'Produccion',
      route: '/production-orders',
      screenKey: AppScreen.productionOrders,
    ),
    NavItemData(
      icon: Icons.warehouse,
      label: 'Materiales',
      route: '/materials',
      screenKey: AppScreen.materials,
    ),
    NavItemData(
      icon: Icons.people,
      label: 'Clientes',
      route: '/customers',
      screenKey: AppScreen.customers,
    ),
    NavItemData(
      icon: Icons.receipt_long,
      label: 'Ventas',
      route: '/invoices',
      screenKey: AppScreen.invoices,
    ),
    NavItemData(
      icon: Icons.local_shipping,
      label: 'Remisiones',
      route: '/shipments',
      screenKey: AppScreen.shipments,
    ),
    NavItemData(
      icon: Icons.request_quote,
      label: 'Cotizar',
      route: '/quotations',
      screenKey: AppScreen.quotations,
    ),
    NavItemData(
      icon: Icons.bar_chart,
      label: 'Reportes',
      route: '/reports',
      screenKey: AppScreen.reports,
    ),
    NavItemData(
      icon: Icons.calendar_today,
      label: 'Calendario',
      route: '/calendar',
      screenKey: AppScreen.calendar,
    ),
    NavItemData(
      icon: Icons.badge,
      label: 'Empleados',
      route: '/employees',
      screenKey: AppScreen.employees,
    ),
    NavItemData(
      icon: Icons.business_center,
      label: 'Activos',
      route: '/assets',
      screenKey: AppScreen.assets,
    ),
    NavItemData(
      icon: Icons.account_balance,
      label: 'Contable',
      route: '/accounting',
      screenKey: AppScreen.accounting,
    ),
    NavItemData(
      icon: Icons.receipt_long,
      label: 'IVA',
      route: '/iva-control',
      screenKey: AppScreen.ivaControl,
    ),
    NavItemData(
      icon: Icons.manage_accounts,
      label: 'Usuarios',
      route: '/user-management',
      screenKey: AppScreen.userManagement,
    ),
    NavItemData(
      icon: Icons.security,
      label: 'Auditoría',
      route: '/audit-panel',
      screenKey: AppScreen.auditPanel,
    ),
  ];

  int _selectedIndex(List<NavItemData> navItems) {
    for (int i = 0; i < navItems.length; i++) {
      if (widget.currentRoute.startsWith(navItems[i].route)) {
        return i;
      }
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(screenPermissionsProvider);
    final navItems = _allNavItems
        .where((item) => permissions.canAccess(item.screenKey))
        .toList();
    final selectedIdx = _selectedIndex(navItems);

    return SizedBox(
      width: 88, // 80 del sidebar + 8 para la burbuja
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Sidebar
          Container(
            width: 80,
            color: Theme.of(context).colorScheme.primary,
            child: Column(
              children: [
                // Logo
                SizedBox(
                  height: _logoHeight,
                  child: GestureDetector(
                    onTap: () => context.go('/'),
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'lib/photo/logo_empresa.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Nav Items
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.zero,
                    children: List.generate(navItems.length, (index) {
                      final item = navItems[index];
                      final isSelected = index == selectedIdx;

                      return _NavItemWidget(
                        icon: item.icon,
                        label: item.label,
                        isSelected: isSelected,
                        height: _itemHeight,
                        onTap: () => context.go(item.route),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          // Burbuja indicadora - sale del sidebar hacia la derecha
          // Se ajusta con el scroll offset del ListView
          if (selectedIdx >= 0)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              top:
                  _logoHeight + (selectedIdx * _itemHeight) + 4 - _scrollOffset,
              left: 80, // justo al borde del sidebar
              child: Container(
                width: 8,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class NavItemData {
  final IconData icon;
  final String label;
  final String route;
  final String screenKey;

  NavItemData({
    required this.icon,
    required this.label,
    required this.route,
    required this.screenKey,
  });
}

class _NavItemWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final double height;
  final VoidCallback onTap;

  const _NavItemWidget({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xB3FFFFFF),
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xB3FFFFFF),
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
