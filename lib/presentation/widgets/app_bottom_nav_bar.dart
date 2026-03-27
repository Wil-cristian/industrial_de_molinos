import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom navigation bar para vista móvil.
/// Muestra 4 items principales + botón "Más" que abre un drawer.
class AppBottomNavBar extends StatelessWidget {
  final String currentRoute;
  final StatefulNavigationShell navigationShell;

  const AppBottomNavBar({
    super.key,
    required this.currentRoute,
    required this.navigationShell,
  });

  static const _mainItems = [
    _BottomNavItem(
      icon: Icons.account_balance_wallet,
      label: 'Caja',
      route: '/daily-cash',
      branchIndex: 1,
    ),
    _BottomNavItem(
      icon: Icons.receipt_long,
      label: 'Ventas',
      route: '/invoices',
      branchIndex: 6,
    ),
    _BottomNavItem(
      icon: Icons.people,
      label: 'Clientes',
      route: '/customers',
      branchIndex: 5,
    ),
    _BottomNavItem(
      icon: Icons.warehouse,
      label: 'Materiales',
      route: '/materials',
      branchIndex: 4,
    ),
  ];

  static const _moreItems = [
    _BottomNavItem(
      icon: Icons.dashboard,
      label: 'Dashboard',
      route: '/',
      branchIndex: 0,
    ),
    _BottomNavItem(
      icon: Icons.shopping_bag,
      label: 'Compras',
      route: '/expenses',
      branchIndex: 2,
    ),
    _BottomNavItem(
      icon: Icons.layers,
      label: 'Productos',
      route: '/composite-products',
      branchIndex: 14,
    ),
    _BottomNavItem(
      icon: Icons.factory,
      label: 'Produccion',
      route: '/production-orders',
      branchIndex: 15,
    ),
    _BottomNavItem(
      icon: Icons.local_shipping,
      label: 'Entregas',
      route: '/pending-deliveries',
      branchIndex: 16,
    ),
    _BottomNavItem(
      icon: Icons.request_quote,
      label: 'Cotizaciones',
      route: '/quotations',
      branchIndex: 7,
    ),
    _BottomNavItem(
      icon: Icons.bar_chart,
      label: 'Reportes',
      route: '/reports',
      branchIndex: 8,
    ),
    _BottomNavItem(
      icon: Icons.calendar_today,
      label: 'Calendario',
      route: '/calendar',
      branchIndex: 9,
    ),
    _BottomNavItem(
      icon: Icons.badge,
      label: 'Empleados',
      route: '/employees',
      branchIndex: 10,
    ),
    _BottomNavItem(
      icon: Icons.business_center,
      label: 'Activos',
      route: '/assets',
      branchIndex: 11,
    ),
    _BottomNavItem(
      icon: Icons.account_balance,
      label: 'Contabilidad',
      route: '/accounting',
      branchIndex: 12,
    ),
    _BottomNavItem(
      icon: Icons.receipt_long,
      label: 'Control IVA',
      route: '/iva-control',
      branchIndex: 13,
    ),
    _BottomNavItem(
      icon: Icons.manage_accounts,
      label: 'Usuarios',
      route: '/user-management',
      branchIndex: 17,
    ),
    _BottomNavItem(
      icon: Icons.security,
      label: 'Auditoría',
      route: '/audit-panel',
      branchIndex: 18,
    ),
  ];

  int _getSelectedIndex() {
    for (int i = 0; i < _mainItems.length; i++) {
      if (currentRoute.startsWith(_mainItems[i].route) &&
          _mainItems[i].route != '/') {
        return i;
      }
    }
    // Si es dashboard o alguna ruta del menú "Más", resaltar "Más"
    if (currentRoute == '/') return 4;
    for (final item in _moreItems) {
      if (currentRoute.startsWith(item.route) && item.route != '/') return 4;
    }
    return 4; // default: "Más"
  }

  void _onItemTapped(BuildContext context, int index) {
    if (index == 4) {
      _showMoreSheet(context);
      return;
    }
    final item = _mainItems[index];
    navigationShell.goBranch(item.branchIndex);
  }

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MoreMenu(
        items: _moreItems,
        currentRoute: currentRoute,
        onItemTap: (item) {
          Navigator.pop(ctx);
          navigationShell.goBranch(item.branchIndex);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _getSelectedIndex();

    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (int i = 0; i < _mainItems.length; i++)
                Expanded(
                  child: _NavBarItem(
                    icon: _mainItems[i].icon,
                    label: _mainItems[i].label,
                    isSelected: selected == i,
                    onTap: () => _onItemTapped(context, i),
                  ),
                ),
              Expanded(
                child: _NavBarItem(
                  icon: Icons.menu,
                  label: 'Más',
                  isSelected: selected == 4,
                  onTap: () => _onItemTapped(context, 4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isSelected ? cs.primary : cs.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  final List<_BottomNavItem> items;
  final String currentRoute;
  final void Function(_BottomNavItem) onItemTap;

  const _MoreMenu({
    required this.items,
    required this.currentRoute,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(Icons.apps, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Más opciones',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.1,
              children: items.map((item) {
                final isActive =
                    currentRoute.startsWith(item.route) && item.route != '/' ||
                    (item.route == '/' && currentRoute == '/');
                return _MoreMenuItem(
                  icon: item.icon,
                  label: item.label,
                  isActive: isActive,
                  onTap: () => onItemTap(item),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _MoreMenuItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? cs.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem {
  final IconData icon;
  final String label;
  final String route;
  final int branchIndex;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.branchIndex,
  });
}
