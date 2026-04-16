---
name: responsive-layout
description: "Build responsive Flutter layouts for Industrial de Molinos. Use when: implementing responsive design, adapting UI for mobile/tablet/desktop, fixing layout overflow errors, creating adaptive grids, handling constrained widths, building forms that work on all screen sizes."
argument-hint: "Describe the layout or screen to make responsive"
---

# Responsive Layout — Industrial de Molinos

## When to Use
- Making a page work on mobile, tablet, and desktop
- Fixing overflow or constraint errors
- Building adaptive grids and forms
- Converting desktop-only layouts to responsive

## Breakpoints

| Category | Width | Layout Strategy |
|----------|-------|-----------------|
| **Mobile** | < 600dp | Single column, full-width cards, bottom nav |
| **Tablet** | 600–1024dp | 2-column grid, side panel optional |
| **Desktop** | > 1024dp | Multi-column, sidebar nav, data tables |

## Basic Responsive Pattern

```dart
@override
Widget build(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;

  if (width < 600) return _buildMobileLayout();
  if (width < 1024) return _buildTabletLayout();
  return _buildDesktopLayout();
}
```

## LayoutBuilder for Nested Widgets

```dart
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth < 600) {
      return Column(children: items);
    }
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: items.map((item) => SizedBox(
        width: constraints.maxWidth < 1024
            ? (constraints.maxWidth - 16) / 2
            : (constraints.maxWidth - 32) / 3,
        child: item,
      )).toList(),
    );
  },
)
```

## Responsive Card Grid

```dart
Widget _buildCardGrid(List<Widget> cards, double maxWidth) {
  final crossAxisCount = maxWidth < 600 ? 1 : maxWidth < 1024 ? 2 : 3;

  return GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: maxWidth < 600 ? 2.5 : 1.8,
    ),
    itemCount: cards.length,
    itemBuilder: (_, i) => cards[i],
  );
}
```

## Responsive Dialog

```dart
static Future<T?> show<T>(BuildContext context, {required Widget child}) {
  final isMobile = MediaQuery.sizeOf(context).width < 600;

  if (isMobile) {
    return Navigator.of(context, rootNavigator: true).push<T>(
      MaterialPageRoute(builder: (_) => child),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (_) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: child,
      ),
    ),
  );
}
```

## Responsive Form Layout

```dart
Widget _buildFormFields(double maxWidth) {
  final isWide = maxWidth >= 600;

  if (isWide) {
    return Column(
      children: [
        Row(children: [
          Expanded(child: _buildNameField()),
          const SizedBox(width: 16),
          Expanded(child: _buildCodeField()),
        ]),
        Row(children: [
          Expanded(child: _buildPriceField()),
          const SizedBox(width: 16),
          Expanded(child: _buildQuantityField()),
        ]),
      ],
    );
  }
  // Mobile: stack vertically
  return Column(children: [
    _buildNameField(),
    _buildCodeField(),
    _buildPriceField(),
    _buildQuantityField(),
  ]);
}
```

## Responsive Action Buttons

```dart
// WRONG — breaks in constrained widths
actions: [
  Expanded(child: ElevatedButton(...)), // NEVER in AlertDialog
  Spacer(), // NEVER in AlertDialog
]

// CORRECT — safe for all sizes
actionsAlignment: MainAxisAlignment.end,
actions: [
  TextButton(onPressed: onCancel, child: const Text('Cancelar')),
  const SizedBox(width: 8),
  ElevatedButton(onPressed: onSave, child: const Text('Guardar')),
]

// CORRECT — for many buttons, use Wrap
Wrap(
  spacing: 8,
  runSpacing: 8,
  alignment: WrapAlignment.end,
  children: [
    OutlinedButton(...),
    OutlinedButton(...),
    ElevatedButton(...),
  ],
)
```

## Common Pitfalls & Fixes

| Problem | Fix |
|---------|-----|
| `Spacer`/`Expanded` in `AlertDialog.actions` | Use `SizedBox`/`actionsAlignment` |
| `TabBar` overflow on mobile | Add `isScrollable: true` |
| Card rows overflow on tablet | Switch to `Wrap` or 2-column when < 900dp |
| `DataTable` too wide for mobile | Wrap in `SingleChildScrollView(scrollDirection: Axis.horizontal)` |
| Form fields too cramped on mobile | Stack vertically instead of `Row` |
| Dialog too wide on mobile | Use `MaterialPageRoute` instead of `showDialog` |
| Images too large on mobile | Use `ConstrainedBox` with `maxWidth`/`maxHeight` |

## Key Rules
1. **Use `MediaQuery.sizeOf(context)`** — not `MediaQuery.of(context).size`
2. **3 breakpoints**: 600dp and 1024dp
3. **Never use `Expanded`/`Spacer` in AlertDialog**
4. **Prefer `Wrap`** over `Row` for variable number of items
5. **Use `LayoutBuilder`** for widgets that need parent constraints
6. **Dialogs become full-page routes on mobile** (< 600dp)
7. **`TabBar` always `isScrollable: true`** in constrained widths
8. **Test on 360dp width** (smallest common mobile)
