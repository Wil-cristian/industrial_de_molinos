import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

/// Widget que contiene el sidebar con su indicador de selección
/// Usar dentro de un Stack para que el indicador se vea por encima del contenido
class AppSidebar extends StatefulWidget {
  final String currentRoute;
  
  const AppSidebar({
    super.key,
    required this.currentRoute,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  // Altura fija para cada item de navegación
  static const double _itemHeight = 48.0;
  static const double _logoHeight = 52.0;
  
  final List<NavItemData> _navItems = [
    NavItemData(icon: Icons.account_balance_wallet, label: 'Caja', route: '/daily-cash'),
    NavItemData(icon: Icons.inventory_2, label: 'Productos', route: '/products'),
    NavItemData(icon: Icons.people, label: 'Clientes', route: '/customers'),
    NavItemData(icon: Icons.receipt_long, label: 'Ventas', route: '/invoices'),
    NavItemData(icon: Icons.request_quote, label: 'Cotizar', route: '/quotations'),
    NavItemData(icon: Icons.bar_chart, label: 'Reportes', route: '/reports'),
    NavItemData(icon: Icons.calendar_today, label: 'Calendario', route: '/calendar'),
    NavItemData(icon: Icons.badge, label: 'Empleados', route: '/employees'),
    NavItemData(icon: Icons.business_center, label: 'Activos', route: '/assets'),
    NavItemData(icon: Icons.settings, label: 'Config', route: '/settings'),
  ];

  int get _selectedIndex {
    for (int i = 0; i < _navItems.length; i++) {
      if (widget.currentRoute.startsWith(_navItems[i].route)) {
        return i;
      }
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIdx = _selectedIndex;
    
    return SizedBox(
      width: 88, // 80 del sidebar + 8 para la burbuja
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Sidebar
          Container(
            width: 80,
            color: AppTheme.primaryColor,
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
                    padding: EdgeInsets.zero,
                    children: List.generate(_navItems.length, (index) {
                      final item = _navItems[index];
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
          if (selectedIdx >= 0)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              top: _logoHeight + (selectedIdx * _itemHeight) + 4,
              left: 80, // justo al borde del sidebar
              child: Container(
                width: 8,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
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

  NavItemData({
    required this.icon,
    required this.label,
    required this.route,
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
                color: isSelected ? Colors.white : Colors.white70,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
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
