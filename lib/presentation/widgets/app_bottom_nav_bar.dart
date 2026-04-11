import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/permissions/screen_permissions.dart';

/// Bottom navigation bar M3 para vista móvil.
/// Indicador activo pill, filled/outlined icons, animaciones spring,
/// haptic feedback, y menú "Más" categorizado con staggered animations.
class AppBottomNavBar extends ConsumerWidget {
  final String currentRoute;
  final StatefulNavigationShell navigationShell;

  const AppBottomNavBar({
    super.key,
    required this.currentRoute,
    required this.navigationShell,
  });

  // Íconos filled + outlined para M3
  static const _mainItems = [
    _BottomNavItem(
      iconFilled: Icons.account_balance_wallet,
      iconOutlined: Icons.account_balance_wallet_outlined,
      label: 'Caja',
      route: '/daily-cash',
      branchIndex: 1,
      screenKey: AppScreen.dailyCash,
    ),
    _BottomNavItem(
      iconFilled: Icons.receipt_long,
      iconOutlined: Icons.receipt_long_outlined,
      label: 'Ventas',
      route: '/invoices',
      branchIndex: 6,
      screenKey: AppScreen.invoices,
    ),
    _BottomNavItem(
      iconFilled: Icons.people,
      iconOutlined: Icons.people_outlined,
      label: 'Clientes',
      route: '/customers',
      branchIndex: 5,
      screenKey: AppScreen.customers,
    ),
    _BottomNavItem(
      iconFilled: Icons.warehouse,
      iconOutlined: Icons.warehouse_outlined,
      label: 'Materiales',
      route: '/materials',
      branchIndex: 4,
      screenKey: AppScreen.materials,
    ),
  ];

  // Categorías para el menú "Más"
  static const _moreCategories = [
    _MoreCategory(
      title: 'Operaciones',
      color: Color(0xFF2E7D32),
      items: [
        _BottomNavItem(
          iconFilled: Icons.shopping_bag,
          iconOutlined: Icons.shopping_bag_outlined,
          label: 'Compras',
          route: '/expenses',
          branchIndex: 2,
          screenKey: AppScreen.expenses,
        ),
        _BottomNavItem(
          iconFilled: Icons.layers,
          iconOutlined: Icons.layers_outlined,
          label: 'Productos',
          route: '/composite-products',
          branchIndex: 14,
          screenKey: AppScreen.compositeProducts,
        ),
        _BottomNavItem(
          iconFilled: Icons.factory,
          iconOutlined: Icons.factory_outlined,
          label: 'Producción',
          route: '/production-orders',
          branchIndex: 15,
          screenKey: AppScreen.productionOrders,
        ),
        _BottomNavItem(
          iconFilled: Icons.local_shipping,
          iconOutlined: Icons.local_shipping_outlined,
          label: 'Entregas',
          route: '/pending-deliveries',
          branchIndex: 16,
          screenKey: AppScreen.shipments,
        ),
      ],
    ),
    _MoreCategory(
      title: 'Finanzas',
      color: Color(0xFF1565C0),
      items: [
        _BottomNavItem(
          iconFilled: Icons.request_quote,
          iconOutlined: Icons.request_quote_outlined,
          label: 'Cotizaciones',
          route: '/quotations',
          branchIndex: 7,
          screenKey: AppScreen.quotations,
        ),
        _BottomNavItem(
          iconFilled: Icons.account_balance,
          iconOutlined: Icons.account_balance_outlined,
          label: 'Contabilidad',
          route: '/accounting',
          branchIndex: 12,
          screenKey: AppScreen.accounting,
        ),
        _BottomNavItem(
          iconFilled: Icons.receipt,
          iconOutlined: Icons.receipt_outlined,
          label: 'Control IVA',
          route: '/iva-control',
          branchIndex: 13,
          screenKey: AppScreen.ivaControl,
        ),
        _BottomNavItem(
          iconFilled: Icons.bar_chart,
          iconOutlined: Icons.bar_chart_rounded,
          label: 'Reportes',
          route: '/reports',
          branchIndex: 8,
          screenKey: AppScreen.reports,
        ),
      ],
    ),
    _MoreCategory(
      title: 'Personas',
      color: Color(0xFFE65100),
      items: [
        _BottomNavItem(
          iconFilled: Icons.badge,
          iconOutlined: Icons.badge_outlined,
          label: 'Empleados',
          route: '/employees',
          branchIndex: 10,
          screenKey: AppScreen.employees,
        ),
        _BottomNavItem(
          iconFilled: Icons.manage_accounts,
          iconOutlined: Icons.manage_accounts_outlined,
          label: 'Usuarios',
          route: '/user-management',
          branchIndex: 17,
          screenKey: AppScreen.userManagement,
        ),
      ],
    ),
    _MoreCategory(
      title: 'Sistema',
      color: Color(0xFF546E7A),
      items: [
        _BottomNavItem(
          iconFilled: Icons.dashboard,
          iconOutlined: Icons.dashboard_outlined,
          label: 'Dashboard',
          route: '/',
          branchIndex: 0,
          screenKey: AppScreen.dashboard,
        ),
        _BottomNavItem(
          iconFilled: Icons.calendar_today,
          iconOutlined: Icons.calendar_today_outlined,
          label: 'Calendario',
          route: '/calendar',
          branchIndex: 9,
          screenKey: AppScreen.calendar,
        ),
        _BottomNavItem(
          iconFilled: Icons.business_center,
          iconOutlined: Icons.business_center_outlined,
          label: 'Activos',
          route: '/assets',
          branchIndex: 11,
          screenKey: AppScreen.assets,
        ),
        _BottomNavItem(
          iconFilled: Icons.security,
          iconOutlined: Icons.security_outlined,
          label: 'Auditoría',
          route: '/audit-panel',
          branchIndex: 18,
          screenKey: AppScreen.auditPanel,
        ),
      ],
    ),
  ];

  int _getSelectedIndex() {
    for (int i = 0; i < _mainItems.length; i++) {
      if (currentRoute.startsWith(_mainItems[i].route) &&
          _mainItems[i].route != '/') {
        return i;
      }
    }
    if (currentRoute == '/') return 4;
    for (final cat in _moreCategories) {
      for (final item in cat.items) {
        if (currentRoute.startsWith(item.route) && item.route != '/') return 4;
      }
    }
    return 4;
  }

  void _onItemTapped(
    BuildContext context,
    int index,
    ScreenPermissionsState permissions,
  ) {
    HapticFeedback.lightImpact();
    if (index == 4) {
      _showMoreSheet(context, permissions);
      return;
    }
    final item = _mainItems[index];
    navigationShell.goBranch(item.branchIndex);
  }

  void _showMoreSheet(
    BuildContext context,
    ScreenPermissionsState permissions,
  ) {
    // Filtrar categorías por permisos
    final filteredCategories = _moreCategories
        .map(
          (cat) => _MoreCategory(
            title: cat.title,
            color: cat.color,
            items: cat.items
                .where((item) => permissions.canAccess(item.screenKey))
                .toList(),
          ),
        )
        .where((cat) => cat.items.isNotEmpty)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MoreMenu(
        categories: filteredCategories,
        currentRoute: currentRoute,
        onItemTap: (item) {
          Navigator.pop(ctx);
          HapticFeedback.lightImpact();
          navigationShell.goBranch(item.branchIndex);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(screenPermissionsProvider);
    final selected = _getSelectedIndex();
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (int i = 0; i < _mainItems.length; i++)
                Expanded(
                  child: _NavBarItem(
                    iconFilled: _mainItems[i].iconFilled,
                    iconOutlined: _mainItems[i].iconOutlined,
                    label: _mainItems[i].label,
                    isSelected: selected == i,
                    onTap: () => _onItemTapped(context, i, permissions),
                  ),
                ),
              Expanded(
                child: _NavBarItem(
                  iconFilled: Icons.grid_view_rounded,
                  iconOutlined: Icons.grid_view_outlined,
                  label: 'Más',
                  isSelected: selected == 4,
                  onTap: () => _onItemTapped(context, 4, permissions),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Nav Bar Item con pill indicator animado (M3) ───────────────────────

class _NavBarItem extends StatefulWidget {
  final IconData iconFilled;
  final IconData iconOutlined;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.iconFilled,
    required this.iconOutlined,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _iconScale = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    if (widget.isSelected) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant _NavBarItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward(from: 0);
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final isActive = widget.isSelected;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pill indicator + icon
              SizedBox(
                height: 32,
                width: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Animated pill indicator
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: isActive ? 56 : 0,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isActive
                            ? cs.secondaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    // Icon with scale
                    Transform.scale(
                      scale: _iconScale.value,
                      child: Icon(
                        isActive ? widget.iconFilled : widget.iconOutlined,
                        color: isActive
                            ? cs.onSecondaryContainer
                            : cs.onSurfaceVariant,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              // Label
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: isActive ? cs.onSurface : cs.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: isActive ? 0.1 : 0,
                ),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Menú "Más" categorizado con staggered animations ───────────────────

class _MoreMenu extends StatefulWidget {
  final List<_MoreCategory> categories;
  final String currentRoute;
  final void Function(_BottomNavItem) onItemTap;

  const _MoreMenu({
    required this.categories,
    required this.currentRoute,
    required this.onItemTap,
  });

  @override
  State<_MoreMenu> createState() => _MoreMenuState();
}

class _MoreMenuState extends State<_MoreMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Contar total items para stagger
    int itemIndex = 0;
    final totalItems = widget.categories.fold<int>(
      0,
      (sum, cat) => sum + cat.items.length,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle (M3: 32x4 con 48dp hit target)
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              height: 28,
              alignment: Alignment.center,
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Título
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.apps_rounded,
                    color: cs.onPrimaryContainer,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Más opciones',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          // Categorías
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.categories.map((cat) {
                final catItems = cat.items.map((item) {
                  final idx = itemIndex++;
                  final isActive =
                      (widget.currentRoute.startsWith(item.route) &&
                          item.route != '/') ||
                      (item.route == '/' && widget.currentRoute == '/');
                  return _StaggeredMoreItem(
                    controller: _staggerController,
                    index: idx,
                    totalItems: totalItems,
                    child: _MoreMenuItem(
                      iconFilled: item.iconFilled,
                      iconOutlined: item.iconOutlined,
                      label: item.label,
                      isActive: isActive,
                      categoryColor: cat.color,
                      onTap: () => widget.onItemTap(item),
                    ),
                  );
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 12,
                            decoration: BoxDecoration(
                              color: cat.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            cat.title,
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Items grid (4 columnas)
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                      childAspectRatio: 0.9,
                      children: catItems,
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stagger wrapper para animar cada item con delay ────────────────────

class _StaggeredMoreItem extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final int totalItems;
  final Widget child;

  const _StaggeredMoreItem({
    required this.controller,
    required this.index,
    required this.totalItems,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = (index / totalItems) * 0.6;
    final end = start + 0.4;
    final opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(start, end.clamp(0.0, 1.0), curve: Curves.easeOut),
      ),
    );
    final slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(
              start,
              end.clamp(0.0, 1.0),
              curve: Curves.easeOutCubic,
            ),
          ),
        );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Opacity(
        opacity: opacity.value,
        child: Transform.translate(
          offset: Offset(0, slide.value.dy * 20),
          child: child,
        ),
      ),
    );
  }
}

// ─── Item individual del menú "Más" con ícono circular con color ────────

class _MoreMenuItem extends StatefulWidget {
  final IconData iconFilled;
  final IconData iconOutlined;
  final String label;
  final bool isActive;
  final Color categoryColor;
  final VoidCallback onTap;

  const _MoreMenuItem({
    required this.iconFilled,
    required this.iconOutlined,
    required this.label,
    required this.isActive,
    required this.categoryColor,
    required this.onTap,
  });

  @override
  State<_MoreMenuItem> createState() => _MoreMenuItemState();
}

class _MoreMenuItemState extends State<_MoreMenuItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconBg = widget.isActive
        ? widget.categoryColor
        : widget.categoryColor.withOpacity(0.1);
    final iconColor = widget.isActive ? Colors.white : widget.categoryColor;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isActive
                ? cs.secondaryContainer.withOpacity(0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Circular icon background
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                  boxShadow: widget.isActive
                      ? [
                          BoxShadow(
                            color: widget.categoryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  widget.isActive ? widget.iconFilled : widget.iconOutlined,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: widget.isActive
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: widget.isActive ? cs.onSurface : cs.onSurfaceVariant,
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

// ─── Data models ────────────────────────────────────────────────────────

class _BottomNavItem {
  final IconData iconFilled;
  final IconData iconOutlined;
  final String label;
  final String route;
  final int branchIndex;
  final String screenKey;

  const _BottomNavItem({
    required this.iconFilled,
    required this.iconOutlined,
    required this.label,
    required this.route,
    required this.branchIndex,
    required this.screenKey,
  });
}

class _MoreCategory {
  final String title;
  final Color color;
  final List<_BottomNavItem> items;

  const _MoreCategory({
    required this.title,
    required this.color,
    required this.items,
  });
}
