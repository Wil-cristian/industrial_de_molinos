import 'package:flutter/material.dart';
import 'app_sidebar.dart';

/// Layout principal de la aplicación con sidebar
class MainLayout extends StatelessWidget {
  final Widget child;
  final String currentRoute;
  final bool showSidebar;

  const MainLayout({
    super.key,
    required this.child,
    required this.currentRoute,
    this.showSidebar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          if (showSidebar) AppSidebar(currentRoute: currentRoute),
          Expanded(child: child),
        ],
      ),
    );
  }
}
