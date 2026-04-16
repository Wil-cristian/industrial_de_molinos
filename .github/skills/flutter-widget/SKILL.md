---
name: flutter-widget
description: "Create Flutter widgets following Industrial de Molinos patterns. Use when: building new pages, creating reusable widgets, designing UI components, implementing Material Design 3, responsive layouts, dialogs, forms. Covers ConsumerStatefulWidget, responsive breakpoints, Spanish locale, theme integration."
argument-hint: "Describe the widget you want to create"
---

# Flutter Widget Builder — Industrial de Molinos

## When to Use
- Creating a new page or screen
- Building a reusable dialog or form widget
- Implementing responsive UI components
- Adding Material Design 3 styled widgets

## Project Context
- **Theme**: Material Design 3, seed color `#1B4F72`
- **State**: Riverpod 3.0 — pages use `ConsumerStatefulWidget`
- **Navigation**: GoRouter with `StatefulShellRoute`
- **Locale**: Spanish (`es_CO`), all user-facing text in Spanish
- **Responsive Breakpoints**: Mobile <600dp, Tablet 600–1024dp, Desktop >1024dp

## Page Widget Pattern

Every page follows this structure:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/providers.dart';

class FeatureNamePage extends ConsumerStatefulWidget {
  const FeatureNamePage({super.key});

  @override
  ConsumerState<FeatureNamePage> createState() => _FeatureNamePageState();
}

class _FeatureNamePageState extends ConsumerState<FeatureNamePage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load data via provider on first frame
    Future.microtask(() {
      ref.read(featureProvider.notifier).loadItems();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(featureProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Título en Español')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(child: Text('Error: ${state.error}'))
              : _buildContent(state),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent(FeatureState state) {
    // Build responsive content
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) return _buildMobileLayout(state);
    if (width < 1024) return _buildTabletLayout(state);
    return _buildDesktopLayout(state);
  }
}
```

## Reusable Dialog Pattern

```dart
class FeatureDialog extends StatefulWidget {
  final Feature? item; // null = create, non-null = edit

  const FeatureDialog({super.key, this.item});

  /// Static show method with responsive sizing
  static Future<bool?> show(BuildContext context, {Feature? item}) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final widget = FeatureDialog(item: item);

    if (isMobile) {
      return Navigator.of(context, rootNavigator: true).push<bool?>(
        MaterialPageRoute(builder: (_) => widget),
      );
    }
    return showDialog<bool?>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: widget,
        ),
      ),
    );
  }

  @override
  State<FeatureDialog> createState() => _FeatureDialogState();
}
```

## Key Rules
1. **All text in Spanish** — labels, buttons, hints, errors
2. **Use `MediaQuery.sizeOf(context)`** not `MediaQuery.of(context).size`
3. **Avoid `Spacer`/`Expanded` in AlertDialog.actions** — use `SizedBox` or `actionsAlignment`
4. **Use `isScrollable: true`** on `TabBar` in constrained widths
5. **Switch to `Wrap`** for action bars with many controls on small screens
6. **Use `ConsumerStatefulWidget`** for pages that watch providers
7. **Load data via `Future.microtask()`** in `initState`, not directly
8. **Dispose all controllers** in `dispose()`
9. **Import theme** from `../../core/theme/app_colors.dart`
10. **Currency**: USD format, use `NumberFormat.currency(locale: 'es_CO', symbol: '\$')`
