/// Tokens de espaciado basados en grid de 4dp.
/// Usar estos valores para padding, margin, gap — nunca hardcodear.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double xxxxl = 48;

  /// Margin lateral según breakpoint.
  static const double marginCompact = 16;   // < 600dp
  static const double marginMedium = 24;    // 600–839dp
  static const double marginExpanded = 24;  // 840dp+

  /// Gap entre cards.
  static const double cardGapMobile = 12;
  static const double cardGapDesktop = 16;
}
