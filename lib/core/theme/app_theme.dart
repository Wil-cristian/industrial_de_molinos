import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  // ──────────────────────────────────────────────────────────────
  // LEGACY static colors — mantenidos para compatibilidad.
  // TODO(migrar): Reemplazar cada uso por Theme.of(context).colorScheme.xxx
  // ──────────────────────────────────────────────────────────────
  static const Color primaryColor = Color(0xFF1B4F72);
  static const Color secondaryColor = Color(0xFF526070);
  static const Color accentColor = Color(0xFF8B5E3C);
  static const Color backgroundColor = Color(0xFFF8FAFB);
  static const Color surfaceColor = Colors.white;
  static const Color errorColor = Color(0xFFC62828);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color warningColor = Color(0xFFF9A825);

  // ──────────────────────────────────────────────────────────────
  // LIGHT THEME — generado desde seed color con M3
  // ──────────────────────────────────────────────────────────────
  static ThemeData lightTheme = _buildTheme(Brightness.light);

  // ──────────────────────────────────────────────────────────────
  // DARK THEME
  // ──────────────────────────────────────────────────────────────
  static ThemeData darkTheme = _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,

      // Scaffold
      scaffoldBackgroundColor: colorScheme.surface,

      // App Bar — surface tonal, no pintado de primary
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: colorScheme.surfaceTint,
      ),

      // Cards — flat, tonal elevation
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(64, 40),
        ),
      ),

      // Filled Button
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(64, 40),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(64, 40),
        ),
      ),

      // Inputs — outlined style
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // Navigation Bar (bottom)
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        elevation: 2,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorShape: const StadiumBorder(),
        backgroundColor: colorScheme.surfaceContainer,
        indicatorColor: colorScheme.secondaryContainer,
      ),

      // Navigation Rail
      navigationRailTheme: NavigationRailThemeData(
        minWidth: 80,
        groupAlignment: -0.85,
        labelType: NavigationRailLabelType.all,
        indicatorShape: const StadiumBorder(),
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.secondaryContainer,
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 6,
      ),

      // Bottom Sheets
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // Chips
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),

      // Dividers
      dividerTheme: DividerThemeData(
        thickness: 1,
        space: 1,
        color: colorScheme.outlineVariant,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // DataTable
      dataTableTheme: const DataTableThemeData(
        headingRowHeight: 48,
        dataRowMinHeight: 48,
        dataRowMaxHeight: 56,
        horizontalMargin: 16,
        columnSpacing: 16,
      ),

      // Tab Bar
      tabBarTheme: TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(width: 3, color: colorScheme.primary),
        ),
      ),

      // Tooltips
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: TextStyle(fontSize: 12, color: colorScheme.onInverseSurface),
        waitDuration: const Duration(milliseconds: 500),
      ),
    );
  }
}
