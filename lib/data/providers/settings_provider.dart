import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/company_settings.dart';
import '../../domain/entities/material_price.dart';
import '../datasources/settings_datasource.dart';

// =====================================================
// STATE CLASSES
// =====================================================

class SettingsState {
  final CompanySettings companySettings;
  final OperationalCosts operationalCosts;
  final List<ProductCategory> categories;
  final List<PayrollConcept> payrollConcepts;
  final InterestSettings interestSettings;
  final DateTime? lastSyncTime;
  final Map<String, int> dataSummary;
  final bool isLoading;
  final String? error;

  const SettingsState({
    this.companySettings = const CompanySettings(),
    this.operationalCosts = const OperationalCosts(),
    this.categories = const [],
    this.payrollConcepts = const [],
    this.interestSettings = const InterestSettings(),
    this.lastSyncTime,
    this.dataSummary = const {},
    this.isLoading = false,
    this.error,
  });

  SettingsState copyWith({
    CompanySettings? companySettings,
    OperationalCosts? operationalCosts,
    List<ProductCategory>? categories,
    List<PayrollConcept>? payrollConcepts,
    InterestSettings? interestSettings,
    DateTime? lastSyncTime,
    Map<String, int>? dataSummary,
    bool? isLoading,
    String? error,
  }) {
    return SettingsState(
      companySettings: companySettings ?? this.companySettings,
      operationalCosts: operationalCosts ?? this.operationalCosts,
      categories: categories ?? this.categories,
      payrollConcepts: payrollConcepts ?? this.payrollConcepts,
      interestSettings: interestSettings ?? this.interestSettings,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      dataSummary: dataSummary ?? this.dataSummary,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// =====================================================
// SETTINGS NOTIFIER
// =====================================================

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    return const SettingsState();
  }

  /// Cargar toda la configuración
  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final results = await Future.wait([
        SettingsDataSource.getCompanySettings(),
        SettingsDataSource.getOperationalCosts(),
        SettingsDataSource.getCategories(),
        SettingsDataSource.getPayrollConcepts(),
        SettingsDataSource.getLastSyncTime(),
        SettingsDataSource.getDataSummary(),
      ]);

      state = state.copyWith(
        companySettings: results[0] as CompanySettings,
        operationalCosts: results[1] as OperationalCosts,
        categories: results[2] as List<ProductCategory>,
        payrollConcepts: results[3] as List<PayrollConcept>,
        lastSyncTime: results[4] as DateTime?,
        dataSummary: results[5] as Map<String, int>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error al cargar configuración: $e',
      );
    }
  }

  /// Actualizar datos de la empresa
  Future<bool> updateCompanySettings(CompanySettings settings) async {
    try {
      final updated = await SettingsDataSource.updateCompanySettings(settings);
      state = state.copyWith(companySettings: updated);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Error al actualizar empresa: $e');
      return false;
    }
  }

  /// Actualizar costos operativos
  Future<bool> updateOperationalCosts(OperationalCosts costs) async {
    try {
      await SettingsDataSource.updateOperationalCosts(costs);
      state = state.copyWith(operationalCosts: costs);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Error al actualizar costos: $e');
      return false;
    }
  }

  /// Actualizar configuración de intereses
  void updateInterestSettings(InterestSettings settings) {
    state = state.copyWith(interestSettings: settings);
  }

  // =====================================================
  // CATEGORÍAS
  // =====================================================

  /// Agregar categoría
  Future<bool> addCategory(ProductCategory category) async {
    try {
      final created = await SettingsDataSource.createCategory(category);
      state = state.copyWith(
        categories: [...state.categories, created],
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Error al crear categoría: $e');
      return false;
    }
  }

  /// Actualizar categoría
  Future<bool> updateCategory(ProductCategory category) async {
    try {
      final updated = await SettingsDataSource.updateCategory(category);
      final newList = state.categories.map((c) {
        return c.id == category.id ? updated : c;
      }).toList();
      state = state.copyWith(categories: newList);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Error al actualizar categoría: $e');
      return false;
    }
  }

  /// Eliminar categoría
  Future<bool> deleteCategory(String id) async {
    try {
      await SettingsDataSource.deleteCategory(id);
      final newList = state.categories.where((c) => c.id != id).toList();
      state = state.copyWith(categories: newList);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Error al eliminar categoría: $e');
      return false;
    }
  }

  // =====================================================
  // CONCEPTOS DE NÓMINA
  // =====================================================

  /// Agregar concepto de nómina
  Future<bool> addPayrollConcept(PayrollConcept concept) async {
    try {
      final created = await SettingsDataSource.createPayrollConcept(concept);
      state = state.copyWith(
        payrollConcepts: [...state.payrollConcepts, created],
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Error al crear concepto: $e');
      return false;
    }
  }

  /// Actualizar concepto de nómina
  Future<bool> updatePayrollConcept(PayrollConcept concept) async {
    try {
      final updated = await SettingsDataSource.updatePayrollConcept(concept);
      final newList = state.payrollConcepts.map((c) {
        return c.id == concept.id ? updated : c;
      }).toList();
      state = state.copyWith(payrollConcepts: newList);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Error al actualizar concepto: $e');
      return false;
    }
  }

  /// Eliminar concepto de nómina
  Future<bool> deletePayrollConcept(String id) async {
    try {
      await SettingsDataSource.deletePayrollConcept(id);
      final newList = state.payrollConcepts.where((c) => c.id != id).toList();
      state = state.copyWith(payrollConcepts: newList);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Error al eliminar concepto: $e');
      return false;
    }
  }

  /// Refrescar datos
  Future<void> refresh() async {
    await loadAll();
  }

  /// Limpiar error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// =====================================================
// PROVIDERS
// =====================================================

/// Provider principal de configuración
final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});

/// Provider para cargar configuración inicialmente
final settingsLoaderProvider = FutureProvider<void>((ref) async {
  await ref.read(settingsProvider.notifier).loadAll();
});

/// Provider de solo lectura para company settings
final companySettingsProvider = Provider<CompanySettings>((ref) {
  return ref.watch(settingsProvider).companySettings;
});

/// Provider de solo lectura para costos operativos
final operationalCostsSettingsProvider = Provider<OperationalCosts>((ref) {
  return ref.watch(settingsProvider).operationalCosts;
});

/// Provider de categorías
final categoriesProvider = Provider<List<ProductCategory>>((ref) {
  return ref.watch(settingsProvider).categories;
});

/// Provider de conceptos de nómina por tipo
final payrollConceptsByTypeProvider = Provider.family<List<PayrollConcept>, String>((ref, type) {
  return ref.watch(settingsProvider)
      .payrollConcepts
      .where((c) => c.type == type && c.isActive)
      .toList();
});

/// Provider de conceptos de ingreso
final incomeConceptsProvider = Provider<List<PayrollConcept>>((ref) {
  return ref.watch(payrollConceptsByTypeProvider('ingreso'));
});

/// Provider de conceptos de descuento
final deductionConceptsProvider = Provider<List<PayrollConcept>>((ref) {
  return ref.watch(payrollConceptsByTypeProvider('descuento'));
});
