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
      icon: Icons.add_circle,
      label: 'Nuevo Material',
      route: '/materials?action=new',
      color: Colors.indigo,
    ),
    QuickActionItem(
      icon: Icons.precision_manufacturing,
      label: 'Productos Compuestos',
      route: '/composite-products',
      color: Colors.deepOrange,
    ),
    QuickActionItem(
      icon: Icons.badge,
      label: 'Nuevo Empleado',
      route: '/employees?action=new',
      color: Colors.cyan,
    ),
    QuickActionItem(
      icon: Icons.assignment,
      label: 'Nueva Tarea',
      route: '/employees?action=new-task',
      color: Colors.amber,
    ),
    QuickActionItem(
      icon: Icons.business_center,
      label: 'Activos Fijos',
      route: '/assets',
      color: Colors.brown,
    ),
    QuickActionItem(
      icon: Icons.calendar_today,
      label: 'Nueva Actividad',
      route: '/calendar?action=new',
      color: Colors.pink,
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
    final screenHeight = MediaQuery.of(context).size.height;
    final maxPanelHeight = screenHeight - 180; // Espacio para el botón y márgenes
    
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
                child: Opacity(
                  opacity: _expandAnimation.value,
                  child: child,
                ),
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
                    color: Colors.black.withOpacity(0.15),
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
                    // Header fijo
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.05),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
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
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Acciones Rápidas',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
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
              shadowColor: AppTheme.primaryColor.withOpacity(0.4),
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
                        AppTheme.primaryColor,
                        AppTheme.primaryColor.withBlue(150),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _isExpanded ? Icons.close : Icons.bolt,
                    color: Colors.white,
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

  Widget _buildActionItem(BuildContext context, QuickActionItem action, int index) {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        // Calcular opacidad de forma segura (siempre entre 0.0 y 1.0)
        double animValue = 0.0;
        if (_expandAnimation.value > 0) {
          final delay = index * 0.08; // Reducir delay para evitar problemas
          if (_expandAnimation.value > delay) {
            animValue = ((_expandAnimation.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
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
