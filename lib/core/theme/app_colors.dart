import 'package:flutter/material.dart';

/// Colores semánticos y de charts que NO provienen del seed de M3.
/// Para colores del tema (primary, surface, etc.) usar Theme.of(context).colorScheme.
class AppColors {
  AppColors._();

  /// Seed color — fuente de todo el ColorScheme.
  static const Color seed = Color(0xFF1B4F72);

  // === Colores semánticos de negocio ===
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color danger = Color(0xFFC62828);
  static const Color info = Color(0xFF1565C0);

  // === Paleta para gráficos (armonizados con el seed) ===
  static const List<Color> chart = [
    Color(0xFF1B4F72),
    Color(0xFF2E86C1),
    Color(0xFF8B5E3C),
    Color(0xFFF39C12),
    Color(0xFF27AE60),
    Color(0xFFE74C3C),
    Color(0xFF8E44AD),
    Color(0xFF16A085),
  ];
}
