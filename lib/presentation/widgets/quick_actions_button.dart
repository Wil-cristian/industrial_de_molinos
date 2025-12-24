import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class QuickActionsButton extends StatefulWidget {
  const QuickActionsButton({super.key});

  @override
  State<QuickActionsButton> createState() => _QuickActionsButtonState();
}

class _QuickActionsButtonState extends State<QuickActionsButton>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  final List<QuickActionItem> _actions = [
    QuickActionItem(
      icon: Icons.account_balance_wallet,
      label: 'Caja Diaria',
      route: '/daily-cash',
      color: AppTheme.successColor,
    ),
    QuickActionItem(
      icon: Icons.add_shopping_cart,
      label: 'Nueva Venta',
      route: '/invoices/new',
      color: Colors.blue,
    ),
    QuickActionItem(
      icon: Icons.request_quote,
      label: 'Nueva Cotización',
      route: '/quotations/new',
      color: Colors.orange,
    ),
    QuickActionItem(
      icon: Icons.person_add,
      label: 'Nuevo Cliente',
      route: '/customers/new',
      color: Colors.purple,
    ),
    QuickActionItem(
      icon: Icons.add_box,
      label: 'Nuevo Producto',
      route: '/products/new',
      color: Colors.teal,
    ),
    QuickActionItem(
      icon: Icons.inventory_2,
      label: 'Materiales',
      route: '/materials',
      color: Colors.indigo,
    ),
    QuickActionItem(
      icon: Icons.precision_manufacturing,
      label: 'Productos Compuestos',
      route: '/composite-products',
      color: Colors.deepOrange,
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

  @override
  Widget build(BuildContext context) {
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
                  color: Colors.black.withOpacity(0.3),
                ),
              ),
            ),
          ),

        // Panel de acciones
        Positioned(
          left: 16,
          bottom: 80,
          child: AnimatedBuilder(
            animation: _expandAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _expandAnimation.value,
                alignment: Alignment.bottomLeft,
                child: Opacity(
                  opacity: _expandAnimation.value,
                  child: child,
                ),
              );
            },
            child: Container(
              width: 280,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.flash_on,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Acciones Rápidas',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  ...List.generate(_actions.length, (index) {
                    final action = _actions[index];
                    return _buildActionItem(context, action, index);
                  }),
                ],
              ),
            ),
          ),
        ),

        // Botón FAB principal
        Positioned(
          left: 16,
          bottom: 16,
          child: AnimatedRotation(
            duration: const Duration(milliseconds: 300),
            turns: _isExpanded ? 0.125 : 0,
            child: Material(
              elevation: 8,
              shadowColor: AppTheme.primaryColor.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: _toggleExpanded,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withBlue(150),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _isExpanded ? Icons.close : Icons.bolt,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionItem(BuildContext context, QuickActionItem action, int index) {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final delay = index * 0.1;
        final animValue = (_expandAnimation.value - delay).clamp(0.0, 1.0) / (1.0 - delay);
        
        return Transform.translate(
          offset: Offset(-20 * (1 - animValue), 0),
          child: Opacity(
            opacity: animValue,
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
              context.go(action.route);
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
                    child: Icon(
                      action.icon,
                      color: action.color,
                      size: 20,
                    ),
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
                    color: Colors.grey[400],
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

  QuickActionItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
  });
}
