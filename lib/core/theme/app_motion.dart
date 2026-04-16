import 'package:flutter/animation.dart';

/// Tokens de motion: curvas, duraciones y springs.
class AppMotion {
  AppMotion._();

  // === Curvas ===
  static const Curve standard = Curves.easeInOutCubicEmphasized;
  static const Curve standardAccelerate = Curves.easeInCubic;
  static const Curve standardDecelerate = Curves.easeOutCubic;
  static const Curve expressive = Curves.easeInOutCubicEmphasized;

  // === Duraciones ===
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration mediumSlow = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration extraSlow = Duration(milliseconds: 700);

  // === Springs ===
  static const SpringDescription sheetSpring = SpringDescription(
    mass: 1,
    stiffness: 600,
    damping: 30,
  );
}
