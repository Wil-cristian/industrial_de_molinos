---
name: "Riverpod Providers"
description: "Use when creating or editing Riverpod providers, notifiers, and state classes. Covers Riverpod 3.0 Notifier pattern, state immutability, provider structure for Industrial de Molinos."
applyTo: "**/providers/**"
---

# Riverpod Provider Rules — Industrial de Molinos

## Pattern: Riverpod 3.0 with `Notifier<T>`

Each provider file contains three parts in this order:

### 1. State Class (immutable)
```dart
class FeatureState {
  final List<Entity> items;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  FeatureState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery = '',
  });

  FeatureState copyWith({ ... }) { ... }

  // Computed getters (filteredItems, totals, etc.)
  List<Entity> get filteredItems { ... }
}
```

### 2. Notifier Class
```dart
class FeatureNotifier extends Notifier<FeatureState> {
  @override
  FeatureState build() => FeatureState();

  Future<void> loadItems() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await FeatureDataSource.getAll();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
  // CRUD methods follow same pattern
}
```

### 3. Provider Declarations
```dart
final featureProvider = NotifierProvider<FeatureNotifier, FeatureState>(() {
  return FeatureNotifier();
});

// Auxiliary providers for single items, filtered views, etc.
final featureByIdProvider = FutureProvider.family<Entity?, String>((ref, id) async {
  return await FeatureDataSource.getById(id);
});
```

## Rules
- **No repository layer** — Notifiers call DataSource static methods directly
- **State is always immutable** — use `copyWith()` for every mutation
- **Set `error: null`** at the start of every async operation (clear previous error)
- **Always set `isLoading: false`** in both success and catch blocks
- **Optimistic UI**: update local state after successful API call, not before
- **Export** new providers from `providers.dart` barrel file
- Comments and doc strings in Spanish
