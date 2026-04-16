---
name: "Flutter Widgets & Pages"
description: "Use when creating or editing Flutter widgets and pages. Covers widget patterns, Material Design 3, responsive breakpoints, dialog conventions for Industrial de Molinos."
applyTo: "**/presentation/**"
---

# Flutter Widget & Page Rules — Industrial de Molinos

## Pages
- Use `ConsumerStatefulWidget` for pages that watch providers
- Load data in `initState` via `Future.microtask(() { ref.read(provider.notifier).loadItems(); })`
- Always dispose `TextEditingController` and other controllers
- Show loading: `CircularProgressIndicator` centered
- Show errors: `Center(child: Text('Error: ${state.error}'))`
- AppBar title in Spanish

## Theme
- Material Design 3, seed color `#1B4F72`
- Import colors from `../../core/theme/app_colors.dart`
- Use `Theme.of(context)` for text styles and colors, not hardcoded values

## Responsive
- Use `MediaQuery.sizeOf(context).width` for breakpoints
- Mobile < 600dp, Tablet 600–1024dp, Desktop > 1024dp
- Dialogs: `showDialog` on desktop/tablet, `MaterialPageRoute` on mobile
- Constrain dialog width: `ConstrainedBox(constraints: BoxConstraints(maxWidth: 500))`

## Dialogs
- Include a static `show()` method for consistent invocation
- Accept optional entity parameter: `null` = create, non-null = edit
- Return `bool?` (saved/cancelled) or the created entity
- Responsive: full-page on mobile, Dialog on desktop

## Do NOT
- Use `Spacer` or `Expanded` inside `AlertDialog.actions`
- Use `MediaQuery.of(context).size` — use `MediaQuery.sizeOf(context)` instead
- Hardcode colors — use theme
- Write user-facing text in English — always Spanish
