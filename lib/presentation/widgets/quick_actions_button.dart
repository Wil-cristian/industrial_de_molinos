import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/responsive/responsive_helper.dart';
import '../../main.dart';

class QuickActionsButton extends ConsumerStatefulWidget {
  const QuickActionsButton({super.key});

  @override
  ConsumerState<QuickActionsButton> createState() => _QuickActionsButtonState();
}

class _QuickActionsButtonState extends ConsumerState<QuickActionsButton>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  final List<QuickActionItem> _actions = [
    QuickActionItem(
      icon: Icons.refresh,
      label: 'Recargar Vista',
      route: '/',
      color: const Color(0xFF546E7A),
      isReload: true,
    ),
    QuickActionItem(
      icon: Icons.account_balance_wallet,
      label: 'Caja Diaria',
      route: '/daily-cash',
      color: AppColors.success,
    ),
    QuickActionItem(
      icon: Icons.add_shopping_cart,
      label: 'Nueva Venta',
      route: '/invoices/new',
      color: const Color(0xFF1565C0),
    ),
    QuickActionItem(
      icon: Icons.request_quote,
      label: 'Nueva Cotización',
      route: '/quotations/new',
      color: const Color(0xFFF9A825),
    ),
    QuickActionItem(
      icon: Icons.person_add,
      label: 'Nuevo Cliente',
      route: '/customers/new',
      color: const Color(0xFF7B1FA2),
    ),
    QuickActionItem(
      icon: Icons.add_box,
      label: 'Nuevo Producto',
      route: '/products/new',
      color: const Color(0xFF009688),
    ),
    QuickActionItem(
      icon: Icons.add_circle,
      label: 'Nuevo Material',
      route: '/materials?action=new',
      color: const Color(0xFF3F51B5),
    ),
    QuickActionItem(
      icon: Icons.precision_manufacturing,
      label: 'Productos Compuestos',
      route: '/composite-products',
      color: const Color(0xFFFF5722),
    ),
    QuickActionItem(
      icon: Icons.factory,
      label: 'Orden Produccion',
      route: '/production-orders',
      color: const Color(0xFF607D8B),
    ),
    QuickActionItem(
      icon: Icons.badge,
      label: 'Nuevo Empleado',
      route: '/employees?action=new',
      color: const Color(0xFF00BCD4),
    ),
    QuickActionItem(
      icon: Icons.assignment,
      label: 'Nueva Tarea',
      route: '/employees?action=new-task',
      color: const Color(0xFFF9A825),
    ),
    QuickActionItem(
      icon: Icons.business_center,
      label: 'Activos Fijos',
      route: '/assets',
      color: const Color(0xFF795548),
    ),
    QuickActionItem(
      icon: Icons.calendar_today,
      label: 'Nueva Actividad',
      route: '/calendar?action=new',
      color: const Color(0xFFE91E63),
    ),
    QuickActionItem(
      icon: Icons.receipt_long,
      label: 'Control IVA',
      route: '/iva-control',
      color: const Color(0xFFC62828),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  Future<void> _handleQuickActionTap(QuickActionItem action) async {
    if (action.isReload) {
      RestartWidget.restart(context);
      return;
    }
    context.go(action.route);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxPanelHeight =
        screenHeight - 180; // Espacio para el botón y márgenes
    final isMobile = ResponsiveHelper.isMobile(context);

    // En móvil, se usa como FAB simple (sin posicionamiento absoluto)
    if (isMobile) {
      return _buildMobileFab(context, maxPanelHeight);
    }

    return Stack(
      alignment: Alignment.bottomLeft,
      children: [
        // Overlay oscuro cuando está expandido
        if (_isExpanded)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleExpanded,
              child: AnimatedOpacity(
                opacity: _isExpanded ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: const Color(0xFF000000).withOpacity(0.3),
                ),
              ),
            ),
          ),

        // Panel de acciones - posicionado a la izquierda del sidebar
        Positioned(
          left: 90, // A la derecha del sidebar (80px) + margen
          bottom: 20,
          child: AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _expandAnimation.value,
                alignment: Alignment.bottomLeft,
                child: Opacity(opacity: _expandAnimation.value, child: child),
              );
            },
            child: Container(
              width: 260,
              constraints: BoxConstraints(maxHeight: maxPanelHeight),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF000000).withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withOpacity(0.3),
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.flash_on,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Acciones Rápidas',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    // Lista de acciones con scroll
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(_actions.length, (index) {
                            final action = _actions[index];
                            return _buildActionItem(context, action, index);
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Botón FAB principal - posicionado a la izquierda del sidebar
        Positioned(
          left: 90, // A la derecha del sidebar (80px) + margen
          bottom: 20,
          child: AnimatedRotation(
            duration: const Duration(milliseconds: 300),
            turns: _isExpanded ? 0.125 : 0,
            child: Material(
              elevation: 8,
              shadowColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.4),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: _toggleExpanded,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withBlue(150),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _isExpanded ? Icons.close : Icons.bolt,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileFab(BuildContext context, double maxPanelHeight) {
    if (!_isExpanded) {
      return FloatingActionButton(
        heroTag: 'quickActionsOpen',
        onPressed: _toggleExpanded,
        child: const Icon(Icons.bolt, size: 26),
      );
    }

    // Cuando está expandido, mostramos un bottom sheet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isExpanded) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
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
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.flash_on,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Acciones Rápidas',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                  child: GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: 1.1,
                    children: _actions
                        .map(
                          (action) => _MobileActionItem(
                            icon: action.icon,
                            label: action.label,
                            color: action.color,
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() => _isExpanded = false);
                              _animationController.reverse();
                              _handleQuickActionTap(action);
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ).whenComplete(() {
          if (mounted) {
            setState(() {
              _isExpanded = false;
              _animationController.reverse();
            });
          }
        });
      }
    });

    return FloatingActionButton(
      heroTag: 'quickActionsClose',
      onPressed: _toggleExpanded,
      child: const Icon(Icons.close, size: 26),
    );
  }

  Widget _buildActionItem(
    BuildContext context,
    QuickActionItem action,
    int index,
  ) {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        // Calcular opacidad de forma segura (siempre entre 0.0 y 1.0)
        double animValue = 0.0;
        if (_expandAnimation.value > 0) {
          final delay = index * 0.08; // Reducir delay para evitar problemas
          if (_expandAnimation.value > delay) {
            animValue = ((_expandAnimation.value - delay) / (1.0 - delay))
                .clamp(0.0, 1.0);
          }
        }

        return Transform.translate(
          offset: Offset(-20 * (1 - animValue), 0),
          child: Opacity(
            opacity: animValue.isNaN ? 0.0 : animValue.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _toggleExpanded();
              _handleQuickActionTap(action);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: action.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(action.icon, color: action.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      action.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: const Color(0xFFBDBDBD),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class QuickActionItem {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  final bool isReload;

  QuickActionItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
    this.isReload = false,
  });
}

class _MobileActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MobileActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
