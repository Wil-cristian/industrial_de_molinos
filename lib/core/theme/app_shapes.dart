import 'package:flutter/material.dart';

/// Tokens de forma (corner radius) siguiendo la escala M3 de 10 niveles.
class AppShapes {
  AppShapes._();

  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double lgInc = 20;
  static const double xl = 28;
  static const double xlInc = 32;
  static const double xxl = 48;
  static const double full = 9999;

  // Helpers de BorderRadius por componente
  static final BorderRadius card = BorderRadius.circular(md);
  static final BorderRadius button = BorderRadius.circular(sm);
  static final BorderRadius input = BorderRadius.circular(sm);
  static final BorderRadius dialog = BorderRadius.circular(xl);
  static final BorderRadius bottomSheet = const BorderRadius.vertical(
    top: Radius.circular(lgInc),
  );
  static final BorderRadius chip = BorderRadius.circular(sm);
  static final BorderRadius fab = BorderRadius.circular(lg);
  static final BorderRadius avatar = BorderRadius.circular(full);
  static final BorderRadius searchBar = BorderRadius.circular(xl);
}
