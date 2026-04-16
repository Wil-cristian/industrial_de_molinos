---
name: riverpod-feature
description: "Scaffold a complete Riverpod 3.0 feature for Industrial de Molinos. Use when: creating new features, adding new modules, building State + Notifier + Provider + DataSource + Entity + Page. Generates all files following project architecture patterns."
argument-hint: "Name of the feature (e.g., 'suppliers', 'purchase_orders')"
---

# Riverpod Feature Scaffolding — Industrial de Molinos

## When to Use
- Adding a new module/feature to the app
- Creating a complete CRUD flow with State + Notifier + Provider + DataSource
- Setting up a new domain entity with its full data pipeline

## Architecture Overview

```
lib/
├── domain/entities/feature_name.dart          # 1. Entity
├── data/
│   ├── datasources/feature_name_datasource.dart  # 2. DataSource (static methods)
│   └── providers/feature_name_provider.dart       # 3. State + Notifier + Provider
└── presentation/
    └── pages/feature_name_page.dart              # 4. Page
```

**Data flow**: Page watches Provider → Notifier calls DataSource → DataSource queries Supabase → returns Entity

## Step 1: Entity (`lib/domain/entities/{name}.dart`)

```dart
class FeatureName {
  final String id;
  final String name;
  // ... all fields with types
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  FeatureName({
    required this.id,
    required this.name,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // Computed getters go here
  // e.g., bool get isLowStock => stock <= minStock;

  FeatureName copyWith({
    String? id,
    String? name,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FeatureName(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
```

## Step 2: DataSource (`lib/data/datasources/{name}_datasource.dart`)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/feature_name.dart';
import 'supabase_datasource.dart';
import 'audit_log_datasource.dart';
import '../../core/utils/colombia_time.dart';
import '../../core/utils/logger.dart';

class FeatureNameDataSource {
  static const String _table = 'feature_names'; // snake_case table name
  static SupabaseClient get _client => SupabaseDataSource.client;

  /// Obtener todos los registros
  static Future<List<FeatureName>> getAll({bool activeOnly = true}) async {
    var query = _client.from(_table).select();
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    final response = await query.order('name', ascending: false);
    return response.map<FeatureName>((json) => _fromJson(json)).toList();
  }

  /// Obtener por ID
  static Future<FeatureName?> getById(String id) async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('id', id)
          .single();
      return _fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Crear registro
  static Future<FeatureName> create(FeatureName item) async {
    final data = _toJson(item);
    data.remove('id');
    data.remove('created_at');
    data.remove('updated_at');

    final response = await _client.from(_table).insert(data).select().single();
    final created = _fromJson(response);
    AuditLogDatasource.log(
      action: 'create',
      module: _table,
      recordId: created.id,
      description: 'Creó registro: ${created.name}',
    );
    return created;
  }

  /// Actualizar registro
  static Future<FeatureName> update(FeatureName item) async {
    final data = _toJson(item);
    data.remove('id');
    data.remove('created_at');
    data.remove('updated_at');

    final response = await _client
        .from(_table)
        .update(data)
        .eq('id', item.id)
        .select()
        .single();
    final updated = _fromJson(response);
    AuditLogDatasource.log(
      action: 'update',
      module: _table,
      recordId: updated.id,
      description: 'Actualizó registro: ${updated.name}',
    );
    return updated;
  }

  /// Eliminar registro
  static Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
    AuditLogDatasource.log(
      action: 'delete',
      module: _table,
      recordId: id,
      description: 'Eliminó registro',
    );
  }

  // ============ HELPERS DE CONVERSIÓN ============
  static FeatureName _fromJson(Map<String, dynamic> json) {
    return FeatureName(
      id: json['id'],
      name: json['name'] ?? '',
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  static Map<String, dynamic> _toJson(FeatureName item) {
    return {
      'id': item.id,
      'name': item.name,
      'is_active': item.isActive,
      'created_at': ColombiaTime.toIso8601(item.createdAt),
    };
  }
}
```

## Step 3: Provider (`lib/data/providers/{name}_provider.dart`)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/feature_name.dart';
import '../datasources/feature_name_datasource.dart';

/// Estado inmutable para la funcionalidad
class FeatureNameState {
  final List<FeatureName> items;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  FeatureNameState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
  });

  FeatureNameState copyWith({
    List<FeatureName>? items,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) {
    return FeatureNameState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  List<FeatureName> get filteredItems {
    if (searchQuery.isEmpty) return items;
    final query = searchQuery.toLowerCase();
    return items.where((i) =>
      i.name.toLowerCase().contains(query)
    ).toList();
  }
}

/// Notifier con lógica de negocio (Riverpod 3.0)
class FeatureNameNotifier extends Notifier<FeatureNameState> {
  @override
  FeatureNameState build() {
    return FeatureNameState();
  }

  Future<void> loadItems({bool activeOnly = true}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await FeatureNameDataSource.getAll(activeOnly: activeOnly);
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void search(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<FeatureName?> createItem(FeatureName item) async {
    try {
      final created = await FeatureNameDataSource.create(item);
      state = state.copyWith(items: [...state.items, created]);
      return created;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<bool> updateItem(FeatureName item) async {
    try {
      final updated = await FeatureNameDataSource.update(item);
      final items = state.items.map((i) =>
        i.id == item.id ? updated : i
      ).toList();
      state = state.copyWith(items: items);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> deleteItem(String id) async {
    try {
      await FeatureNameDataSource.delete(id);
      final items = state.items.where((i) => i.id != id).toList();
      state = state.copyWith(items: items);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider principal
final featureNameProvider = NotifierProvider<FeatureNameNotifier, FeatureNameState>(() {
  return FeatureNameNotifier();
});

/// Provider para item individual (por ID)
final featureNameByIdProvider = FutureProvider.family<FeatureName?, String>((ref, id) async {
  return await FeatureNameDataSource.getById(id);
});
```

## Step 4: Register in Providers Barrel

Add export to `lib/data/providers/providers.dart`:
```dart
export 'feature_name_provider.dart';
```

## Step 5: Add Route in `lib/router.dart`

Add import and route definition following existing pattern.

## Checklist
- [ ] Entity with `copyWith()` and computed getters
- [ ] DataSource with `_fromJson`/`_toJson`, static methods, audit logging
- [ ] State class with `copyWith()`, `filteredItems` getter
- [ ] Notifier with `build()`, CRUD methods, error handling
- [ ] Provider + auxiliary FutureProviders
- [ ] Export in `providers.dart` barrel
- [ ] Page with `ConsumerStatefulWidget` pattern
- [ ] Route registered in `router.dart`
