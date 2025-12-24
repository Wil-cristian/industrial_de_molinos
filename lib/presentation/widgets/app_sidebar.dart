import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../../core/theme/app_theme.dart';

class AppSidebar extends StatefulWidget {
  final String currentRoute;
  
  const AppSidebar({
    super.key,
    required this.currentRoute,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  final List<NavItemData> _navItems = [
    NavItemData(icon: Icons.account_balance_wallet, label: 'Caja', route: '/daily-cash'),
    NavItemData(icon: Icons.inventory_2, label: 'Productos', route: '/products'),
    NavItemData(icon: Icons.people, label: 'Clientes', route: '/customers'),
    NavItemData(icon: Icons.receipt_long, label: 'Ventas', route: '/invoices'),
    NavItemData(icon: Icons.request_quote, label: 'Cotizar', route: '/quotations'),
    NavItemData(icon: Icons.bar_chart, label: 'Reportes', route: '/reports'),
    NavItemData(icon: Icons.calendar_today, label: 'Calendario', route: '/calendar'),
    NavItemData(icon: Icons.settings, label: 'Config', route: '/settings'),
  ];

  int get _selectedIndex {
    for (int i = 0; i < _navItems.length; i++) {
      if (widget.currentRoute.startsWith(_navItems[i].route)) {
        return i;
      }
    }
    return -1; // Dashboard/Home
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedIdx = _selectedIndex;
    
    return Container(
      width: 80,
      color: AppTheme.primaryColor,
      child: Stack(
        children: [
          // Deformación/Bulge del sidebar
          if (selectedIdx >= 0)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              top: 70 + (selectedIdx * 46), // Logo height + item position (ajustado)
              right: 0,
              child: CustomPaint(
                painter: BulgePainter(color: AppTheme.backgroundColor),
                size: const Size(18, 48),
              ),
            ),
          
          // Contenido del sidebar
          Column(
            children: [
              // Logo - Tamaño fijo compacto
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: GestureDetector(
                  onTap: () => context.go('/'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'lib/photo/logo_empresa.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Molinos',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Nav Items - Con scroll para evitar overflow
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_navItems.length, (index) {
                      final item = _navItems[index];
                      final isSelected = index == selectedIdx;
                      
                      return _NavItemWidget(
                        icon: item.icon,
                        label: item.label,
                        isSelected: isSelected,
                        onTap: () => context.go(item.route),
                      );
                    }),
                  ),
                ),
              ),
            ],
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
  final VoidCallback onTap;

  const _NavItemWidget({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 68,
            height: isSelected ? 48 : 44,
            decoration: BoxDecoration(
              color: isSelected 
                  ? Colors.white.withOpacity(0.2) 
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: isSelected ? 22 : 20,
                  ),
                ),
                const SizedBox(height: 1),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: Colors.white.withOpacity(isSelected ? 1 : 0.7),
                    fontSize: isSelected ? 9 : 8,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Painter para el efecto de deformación/bulge
class BulgePainter extends CustomPainter {
  final Color color;
  
  BulgePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Crear curva suave tipo "bulge"
    path.moveTo(size.width, 0);
    path.lineTo(size.width, size.height);
    
    // Curva inferior
    path.quadraticBezierTo(
      size.width * 0.3, size.height * 0.85,
      0, size.height * 0.5,
    );
    
    // Curva superior
    path.quadraticBezierTo(
      size.width * 0.3, size.height * 0.15,
      size.width, 0,
    );
    
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
