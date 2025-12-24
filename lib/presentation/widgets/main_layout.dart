import 'package:flutter/material.dart';
import 'app_sidebar.dart';
import 'quick_actions_button.dart';

/// Layout principal de la aplicación con sidebar y botón de acciones rápidas
class MainLayout extends StatelessWidget {
  final Widget child;
  final String currentRoute;
  final bool showSidebar;
  final bool showQuickActions;

  const MainLayout({
    super.key,
    required this.child,
    required this.currentRoute,
    this.showSidebar = true,
    this.showQuickActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Contenido principal con sidebar
          Row(
            children: [
              if (showSidebar) AppSidebar(currentRoute: currentRoute),
              Expanded(child: child),
            ],
          ),
          
          // Botón flotante de acciones rápidas
          if (showQuickActions)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: QuickActionsButton(),
            ),
        ],
      ),
    );
  }
}
