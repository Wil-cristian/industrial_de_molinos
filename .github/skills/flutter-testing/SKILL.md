---
name: flutter-testing
description: "Generate tests for Industrial de Molinos Flutter app. Use when: writing unit tests, widget tests, testing Riverpod notifiers, testing datasources, verifying state changes, mocking Supabase calls. Covers test patterns for the project architecture."
argument-hint: "Name of the class or feature to test"
---

# Flutter Testing — Industrial de Molinos

## When to Use
- Writing unit tests for Notifiers and State classes
- Writing unit tests for DataSource methods
- Writing widget tests for pages and dialogs
- Verifying CRUD operations and state transitions

## Test File Location

```
test/
├── data/
│   ├── providers/
│   │   └── feature_name_provider_test.dart
│   └── datasources/
│       └── feature_name_datasource_test.dart
├── domain/
│   └── entities/
│       └── feature_name_test.dart
└── presentation/
    └── pages/
        └── feature_name_page_test.dart
```

**Convention**: Mirror `lib/` structure under `test/`, suffix `_test.dart`.

## 1. Entity Test

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:industrial_de_molinos/domain/entities/feature_name.dart';

void main() {
  group('FeatureName', () {
    test('should create with required fields', () {
      final item = FeatureName(
        id: 'test-id',
        name: 'Test Item',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(item.id, 'test-id');
      expect(item.name, 'Test Item');
      expect(item.isActive, true); // default
    });

    test('copyWith should update specified fields only', () {
      final item = FeatureName(
        id: 'test-id',
        name: 'Original',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = item.copyWith(name: 'Updated');

      expect(updated.name, 'Updated');
      expect(updated.id, 'test-id'); // unchanged
    });

    test('computed getters should work correctly', () {
      // Test entity-specific computed properties
      // e.g., isLowStock, profitMargin, effectiveSalePrice
    });
  });
}
```

## 2. Notifier/State Test (Riverpod 3.0)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:industrial_de_molinos/data/providers/feature_name_provider.dart';

void main() {
  group('FeatureNameState', () {
    test('initial state should have empty items and no loading', () {
      final state = FeatureNameState();

      expect(state.items, isEmpty);
      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.searchQuery, '');
    });

    test('copyWith should preserve unmodified fields', () {
      final state = FeatureNameState(
        isLoading: true,
        searchQuery: 'test',
      );

      final updated = state.copyWith(isLoading: false);

      expect(updated.isLoading, false);
      expect(updated.searchQuery, 'test'); // preserved
    });

    test('filteredItems should filter by search query', () {
      final state = FeatureNameState(
        items: [
          // Create test items here
        ],
        searchQuery: 'búsqueda',
      );

      expect(state.filteredItems.length, /* expected count */);
    });
  });

  group('FeatureNameNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('build should return initial state', () {
      final state = container.read(featureNameProvider);

      expect(state.items, isEmpty);
      expect(state.isLoading, false);
    });

    test('search should update searchQuery in state', () {
      container.read(featureNameProvider.notifier).search('test');
      final state = container.read(featureNameProvider);

      expect(state.searchQuery, 'test');
    });

    test('clearError should set error to null', () {
      container.read(featureNameProvider.notifier).clearError();
      final state = container.read(featureNameProvider);

      expect(state.error, isNull);
    });
  });
}
```

## 3. Widget Test

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:industrial_de_molinos/presentation/pages/feature_name_page.dart';

void main() {
  group('FeatureNamePage', () {
    testWidgets('should show loading indicator initially', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const FeatureNamePage(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show error message on error state', (tester) async {
      // Override provider with error state
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            featureNameProvider.overrideWith(() {
              final notifier = FeatureNameNotifier();
              // Set error state if needed
              return notifier;
            }),
          ],
          child: MaterialApp(
            home: const FeatureNamePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      // Verify error UI
    });

    testWidgets('should display items in list', (tester) async {
      // Override provider with test data
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const FeatureNamePage(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      // Verify list items rendered
    });
  });
}
```

## Key Rules
1. **Group tests** by class/feature using `group()`
2. **Spanish descriptions** in test names when testing business logic
3. **Always dispose** `ProviderContainer` in `tearDown`
4. **Test state transitions**: initial → loading → loaded/error
5. **Test computed getters** (filteredItems, totals, etc.)
6. **Test copyWith** preserves unmodified fields
7. **Use `ProviderScope.overrides`** to inject test data in widget tests
8. **Run tests**: `flutter test` or `flutter test test/path/to/test.dart`
